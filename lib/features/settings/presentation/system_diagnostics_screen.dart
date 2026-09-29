import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/diagnostics/diagnostic_status.dart';
import '../../../core/diagnostics/system_diagnostics_service.dart';
import '../../../core/filesystem/workspace_manager.dart';
import '../../../core/providers/app_providers.dart';

/// Comprehensive System Diagnostics Screen (Section 13 & 14).
/// Provides live inspection of all native components and sanitized support export.
class SystemDiagnosticsScreen extends ConsumerStatefulWidget {
  const SystemDiagnosticsScreen({super.key});

  @override
  ConsumerState<SystemDiagnosticsScreen> createState() => _SystemDiagnosticsScreenState();
}

class _SystemDiagnosticsScreenState extends ConsumerState<SystemDiagnosticsScreen> {
  bool _isLoading = true;
  List<SystemDiagnosticItem> _items = [];
  bool _isCheckingUpdate = false;
  String? _updateStatusMessage;

  @override
  void initState() {
    super.initState();
    _loadDiagnostics();
  }

  Future<void> _loadDiagnostics() async {
    setState(() => _isLoading = true);
    final ws = ref.read(workspaceManagerProvider);
    final diag = SystemDiagnosticsService(workspaceManager: ws);
    final results = await diag.runFullDiagnostics(
      appVersion: '1.5.1',
      databaseSchemaVersion: 5,
    );
    if (mounted) {
      setState(() {
        _items = results;
        _isLoading = false;
      });
    }
  }

  Future<void> _copyReportToClipboard() async {
    final ws = ref.read(workspaceManagerProvider);
    final diag = SystemDiagnosticsService(workspaceManager: ws);
    final report = diag.generateSanitizedReport(
      items: _items,
      appVersion: '1.5.1',
      databaseSchemaVersion: 5,
    );

    await Clipboard.setData(ClipboardData(text: report));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã sao chép báo cáo chẩn đoán an toàn (không chứa dữ liệu nhạy cảm) vào bộ nhớ tạm!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _exportReportFile() async {
    try {
      final ws = ref.read(workspaceManagerProvider);
      final diag = SystemDiagnosticsService(workspaceManager: ws);
      final file = await diag.exportDiagnosticReportToFile(
        items: _items,
        appVersion: '1.5.1',
        databaseSchemaVersion: 5,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã xuất báo cáo chẩn đoán: ${file.path}'),
            action: SnackBarAction(
              label: 'Mở vị trí',
              onPressed: () => WorkspaceManager.openContainingFolder(file.path),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi xuất báo cáo: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _checkForUpdates() async {
    setState(() {
      _isCheckingUpdate = true;
      _updateStatusMessage = null;
    });

    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() {
        _isCheckingUpdate = false;
        _updateStatusMessage = 'Chưa cấu hình máy chủ cập nhật.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ws = ref.watch(workspaceManagerProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Chẩn đoán hệ thống (System Diagnostics)'),
        actions: [
          IconButton(
            tooltip: 'Làm mới chẩn đoán',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadDiagnostics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Action Header Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.health_and_safety_rounded, color: AppColors.primaryLight, size: 24),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Trung tâm kiểm định & hỗ trợ kỹ thuật',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Báo cáo chẩn đoán được làm sạch (Sanitized). Cam kết KHÔNG chứa API key, mật khẩu hay dữ liệu tài liệu.',
                                    style: TextStyle(fontSize: 12, color: AppColors.darkTextSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: _copyReportToClipboard,
                              icon: const Icon(Icons.copy_rounded, size: 16),
                              label: const Text('Sao chép báo cáo chẩn đoán'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _exportReportFile,
                              icon: const Icon(Icons.download_rounded, size: 16),
                              label: const Text('Xuất tệp chẩn đoán (.txt)'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _isCheckingUpdate ? null : _checkForUpdates,
                              icon: _isCheckingUpdate
                                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.system_update_rounded, size: 16),
                              label: const Text('Kiểm tra bản cập nhật'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => WorkspaceManager.openFolder(ws.logsDir.path),
                              icon: const Icon(Icons.folder_open_rounded, size: 16),
                              label: const Text('Mở thư mục Logs'),
                            ),
                          ],
                        ),
                        if (_updateStatusMessage != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primaryLight),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(_updateStatusMessage!, style: const TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  const Text('Chi tiết trạng thái hệ thống', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  // Diagnostics Items Grid / List
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildStatusBadge(item.status),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(item.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.06),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(item.category, style: const TextStyle(fontSize: 10)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.details,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                  if (item.recommendation != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Khuyến nghị: ${item.recommendation!}',
                                      style: const TextStyle(fontSize: 11, color: AppColors.warning),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusBadge(DiagnosticStatus status) {
    Color color;
    IconData icon;
    String label;

    switch (status) {
      case DiagnosticStatus.ready:
        color = AppColors.success;
        icon = Icons.check_circle_rounded;
        label = 'SẴN SÀNG';
        break;
      case DiagnosticStatus.optionalNotAvailable:
        color = AppColors.info;
        icon = Icons.info_rounded;
        label = 'TÙY CHỌN';
        break;
      case DiagnosticStatus.actionRequired:
        color = AppColors.warning;
        icon = Icons.warning_rounded;
        label = 'CẦN CHÚ Ý';
        break;
      case DiagnosticStatus.failed:
        color = AppColors.error;
        icon = Icons.cancel_rounded;
        label = 'LỖI';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
