import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/filesystem/workspace_manager.dart';
import '../../../core/providers/app_providers.dart';

/// Screen displaying tracked workspace files and documents.
class FileLibraryScreen extends ConsumerStatefulWidget {
  const FileLibraryScreen({super.key});

  @override
  ConsumerState<FileLibraryScreen> createState() => _FileLibraryScreenState();
}

class _FileLibraryScreenState extends ConsumerState<FileLibraryScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fileListAsync = ref.watch(fileLibraryNotifierProvider);
    final fileNotifier = ref.read(fileLibraryNotifierProvider.notifier);
    final workspace = ref.watch(workspaceManagerProvider);
    final dateFormat = DateFormat('HH:mm dd/MM/yyyy');

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Thư viện tài liệu (Document Library)',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Quản lý tất cả tài liệu PDF, trang scan, bản ghi âm và video được lưu trữ trong Workspace cục bộ.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => WorkspaceManager.openFolder(workspace.importsDir.path),
                      icon: const Icon(Icons.folder_open_rounded, size: 18),
                      label: const Text('Mở thư mục Imports'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.moduleLibrary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        await fileNotifier.createDemoSampleFile();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Đã ghi nhận tệp tài liệu mẫu vào thư viện!')),
                          );
                        }
                      },
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Thêm tệp mẫu'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Search bar
            Container(
              constraints: const BoxConstraints(maxWidth: 420),
              child: TextField(
                controller: _searchController,
                onChanged: (query) => fileNotifier.refresh(query: query),
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm tệp theo tên...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            fileNotifier.refresh(query: '');
                          },
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Files Data Table
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: fileListAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(
                    child: Text('Lỗi: $err', style: const TextStyle(color: AppColors.error)),
                  ),
                  data: (files) {
                    if (files.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.folder_off_outlined,
                              size: 48,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Chưa có tài liệu nào trong thư viện.',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Nhấn "Thêm tệp mẫu" để ghi nhận tài liệu vào hệ quản trị.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                        ),
                        columns: const [
                          DataColumn(label: Text('Tên tệp', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Định dạng', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Dung lượng', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Ngày tạo', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Thao tác', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: files.map((file) {
                          return DataRow(
                            cells: [
                              DataCell(
                                Row(
                                  children: [
                                    const Icon(Icons.insert_drive_file_outlined, size: 18, color: AppColors.primaryLight),
                                    const SizedBox(width: 8),
                                    Text(file.originalName, style: const TextStyle(fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ),
                              DataCell(Text(file.mimeType ?? 'application/octet-stream')),
                              DataCell(Text(file.formattedSize)),
                              DataCell(Text(dateFormat.format(file.createdAt))),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Mở vị trí tệp trong Explorer',
                                      icon: const Icon(Icons.folder_open_outlined, size: 18),
                                      onPressed: () => fileNotifier.openFileLocation(file.localPath),
                                    ),
                                    IconButton(
                                      tooltip: 'Xóa bản ghi',
                                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                                      onPressed: () => fileNotifier.deleteEntry(file.id),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
