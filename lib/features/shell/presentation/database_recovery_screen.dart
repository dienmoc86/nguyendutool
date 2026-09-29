import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import '../../../app/theme/app_colors.dart';
import '../../../core/database/database_backup_service.dart';

/// Dedicated disaster recovery screen presented when SQLite database fails to initialize (Requirement 28).
/// Offers 4 non-destructive recovery actions without automatically overwriting corrupt data.
class DatabaseRecoveryScreen extends StatefulWidget {
  final String databasePath;
  final String? errorMessage;
  final VoidCallback onRetry;
  final VoidCallback onRestored;

  const DatabaseRecoveryScreen({
    super.key,
    required this.databasePath,
    this.errorMessage,
    required this.onRetry,
    required this.onRestored,
  });

  @override
  State<DatabaseRecoveryScreen> createState() => _DatabaseRecoveryScreenState();
}

class _DatabaseRecoveryScreenState extends State<DatabaseRecoveryScreen> {
  bool _isLoading = false;
  String? _statusMessage;
  List<File> _availableBackups = [];

  @override
  void initState() {
    super.initState();
    _loadBackups();
  }

  void _loadBackups() {
    try {
      final dbFile = File(widget.databasePath);
      final backupsDir = Directory(p.join(p.dirname(p.dirname(widget.databasePath)), 'backups'));
      final backupService = DatabaseBackupService(
        databaseFile: dbFile,
        backupsDirectory: backupsDir,
      );
      setState(() {
        _availableBackups = backupService.listBackups();
      });
    } catch (_) {}
  }

  Future<void> _restoreLatest() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Đang kiểm tra và khôi phục bản sao lưu gần nhất...';
    });

    try {
      final dbFile = File(widget.databasePath);
      final backupsDir = Directory(p.join(p.dirname(p.dirname(widget.databasePath)), 'backups'));
      final backupService = DatabaseBackupService(
        databaseFile: dbFile,
        backupsDirectory: backupsDir,
      );

      final success = await backupService.restoreLatestBackup();
      if (success) {
        setState(() => _statusMessage = 'Khôi phục thành công! Đang khởi động lại...');
        await Future.delayed(const Duration(milliseconds: 800));
        widget.onRestored();
      } else {
        setState(() {
          _statusMessage = 'Lỗi: Không tìm thấy bản sao lưu hợp lệ hoặc kiểm tra toàn vẹn thất bại.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Lỗi khôi phục: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _restoreSpecific(File backup) async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Đang kiểm tra toàn vẹn bản sao lưu: ${p.basename(backup.path)}...';
    });

    try {
      final dbFile = File(widget.databasePath);
      final backupsDir = Directory(p.join(p.dirname(p.dirname(widget.databasePath)), 'backups'));
      final backupService = DatabaseBackupService(
        databaseFile: dbFile,
        backupsDirectory: backupsDir,
      );

      final success = await backupService.restoreFromBackup(backup);
      if (success) {
        setState(() => _statusMessage = 'Khôi phục thành công! Đang khởi động lại...');
        await Future.delayed(const Duration(milliseconds: 800));
        widget.onRestored();
      } else {
        setState(() {
          _statusMessage = 'Lỗi: Bản sao lưu không vượt qua kiểm tra toàn vẹn PRAGMA integrity_check.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Lỗi khôi phục: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _createNewDatabase() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Khởi tạo cơ sở dữ liệu mới?'),
        content: const Text(
          'Dữ liệu bị lỗi hiện tại sẽ được lưu trữ an toàn dưới dạng bản sao lưu phục vụ chẩn đoán kỹ thuật '
          '(nguyendu_tool_corrupt_<timestamp>.db). Ứng dụng sẽ tạo cơ sở dữ liệu trống mới. Bạn có chắc chắn muốn tiếp tục?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Khởi tạo cơ sở dữ liệu mới'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Đang lưu trữ dữ liệu lỗi và tạo mới...';
    });

    try {
      final dbFile = File(widget.databasePath);
      if (dbFile.existsSync()) {
        final backupsDir = Directory(p.join(p.dirname(p.dirname(widget.databasePath)), 'backups'));
        await backupsDir.create(recursive: true);
        final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        final corruptArchive = File(p.join(backupsDir.path, 'nguyendu_tool_corrupt_$ts.db'));
        await dbFile.copy(corruptArchive.path);
        await dbFile.delete();

        final wal = File('${dbFile.path}-wal');
        if (wal.existsSync()) await wal.delete();
        final shm = File('${dbFile.path}-shm');
        if (shm.existsSync()) await shm.delete();
      }

      setState(() => _statusMessage = 'Đã tạo cơ sở dữ liệu mới. Đang khởi động lại...');
      await Future.delayed(const Duration(milliseconds: 800));
      widget.onRestored();
    } catch (e) {
      setState(() {
        _statusMessage = 'Lỗi tạo mới: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF141416),
        fontFamily: 'Segoe UI',
      ),
      home: Scaffold(
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 720),
            padding: const EdgeInsets.all(40),
            margin: const EdgeInsets.symmetric(vertical: 40),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E24),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.error.withOpacity(0.4), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.build_circle_rounded, color: AppColors.error, size: 36),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Phục hồi cơ sở dữ liệu (Database Disaster Recovery)',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Cơ sở dữ liệu SQLite gặp sự cố khi khởi động. Dữ liệu gốc đã được bảo toàn an toàn.',
                              style: TextStyle(fontSize: 13, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Technical details
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tệp cơ sở dữ liệu: ${widget.databasePath}',
                            style: const TextStyle(fontSize: 12, fontFamily: 'Consolas', color: Colors.white70)),
                        if (widget.errorMessage != null) ...[
                          const SizedBox(height: 6),
                          Text('Chi tiết lỗi: ${widget.errorMessage}',
                              style: const TextStyle(fontSize: 12, color: AppColors.error)),
                        ],
                      ],
                    ),
                  ),

                  if (_statusMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.info.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_statusMessage!, style: const TextStyle(fontSize: 13, color: Colors.white)),
                    ),
                  ],

                  const SizedBox(height: 28),
                  const Text('Chọn phương án khôi phục:',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 16),

                  // Actions
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        ),
                        onPressed: _isLoading ? null : widget.onRetry,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Thử lại khởi động (Retry)'),
                      ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.success,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        ),
                        onPressed: _isLoading || _availableBackups.isEmpty ? null : _restoreLatest,
                        icon: const Icon(Icons.restore_page_rounded),
                        label: const Text('Khôi phục bản sao lưu gần nhất'),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        ),
                        onPressed: _isLoading ? null : _createNewDatabase,
                        icon: const Icon(Icons.add_circle_outline_rounded),
                        label: const Text('Tạo cơ sở dữ liệu mới'),
                      ),
                    ],
                  ),

                  if (_availableBackups.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    const Text('Danh sách bản sao lưu có sẵn:',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white70)),
                    const SizedBox(height: 12),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _availableBackups.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final b = _availableBackups[index];
                        final name = p.basename(b.path);
                        final sizeKb = (b.lengthSync() / 1024).toStringAsFixed(1);
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.storage_rounded, size: 20, color: Colors.white60),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                    Text('$sizeKb KB', style: const TextStyle(fontSize: 11, color: Colors.white54)),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryLight.withOpacity(0.2),
                                  foregroundColor: AppColors.primaryLight,
                                ),
                                onPressed: _isLoading ? null : () => _restoreSpecific(b),
                                child: const Text('Khôi phục bản này'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
