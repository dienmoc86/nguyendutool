import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/providers/app_providers.dart';

import '../../../core/product/product_info.dart';
import '../../../core/update/update_notifier.dart';
import 'command_palette_dialog.dart';
import 'update_dialog.dart';

/// Desktop application top bar with active module title, system status, and settings button.
class TopBar extends ConsumerWidget implements PreferredSizeWidget {
  final String activeTitle;
  final VoidCallback onToggleSidebar;
  final bool isSidebarCollapsed;

  const TopBar({
    super.key,
    required this.activeTitle,
    required this.onToggleSidebar,
    required this.isSidebarCollapsed,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final jobsAsync = ref.watch(jobNotifierProvider);
    final updateState = ref.watch(updateNotifierProvider);

    // Count active jobs
    final activeJobCount = jobsAsync.maybeWhen(
      data: (jobs) => jobs.where((j) => j.status.isActive).length,
      orElse: () => 0,
    );

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: isSidebarCollapsed ? 'Mở rộng thanh bên' : 'Thu gọn thanh bên',
            icon: Icon(
              isSidebarCollapsed ? Icons.menu_open_rounded : Icons.menu_rounded,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              size: 20,
            ),
            onPressed: onToggleSidebar,
          ),
          Expanded(
            child: Text(
              activeTitle,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 12),

          // Available Update Banner Chip
          if (updateState.isAvailable)
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => UpdateDialog.show(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.accentViolet],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.upgrade_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Có bản mới v${updateState.manifest!.version}!',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Active Job Status Pill
          if (activeJobCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primaryLight.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryLight),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$activeJobCount tác vụ đang chạy',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryLight,
                    ),
                  ),
                ],
              ),
            ),

          // Global Search / Command Palette Button
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => CommandPaletteDialog.show(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search_rounded,
                    size: 16,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Tìm kiếm...',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Ctrl+K',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Global "+ Mới" (New) Dropdown Action
          PopupMenuButton<String>(
            tooltip: 'Tạo mới',
            offset: const Offset(0, 42),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            onSelected: (route) => context.go(route),
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: AppRoutes.lessonPlanner,
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 18, color: AppColors.accentViolet),
                    SizedBox(width: 10),
                    Text('Soạn Giáo án 5512'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: AppRoutes.pdfConverter,
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf_rounded, size: 18, color: AppColors.modulePdf),
                    SizedBox(width: 10),
                    Text('Chuyển đổi PDF'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: AppRoutes.scanner,
                child: Row(
                  children: [
                    Icon(Icons.document_scanner_rounded, size: 18, color: AppColors.moduleScanner),
                    SizedBox(width: 10),
                    Text('Quét tài liệu'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: AppRoutes.textToSpeech,
                child: Row(
                  children: [
                    Icon(Icons.record_voice_over_rounded, size: 18, color: AppColors.moduleTts),
                    SizedBox(width: 10),
                    Text('Tạo giọng đọc (TTS)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: AppRoutes.videoStudio,
                child: Row(
                  children: [
                    Icon(Icons.movie_creation_rounded, size: 18, color: AppColors.moduleVideo),
                    SizedBox(width: 10),
                    Text('Tạo dự án Video'),
                  ],
                ),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.add_rounded, size: 18, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    'Mới',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Version badge or Update Available Button
          if (updateState.isAvailable) ...[
            InkWell(
              onTap: () => UpdateDialog.show(context),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2E7D32), Color(0xFF388E3C)],
                  ),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_circle_up_rounded, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      'Bản mới v${updateState.manifest!.version}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (updateState.isDownloading) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.primary.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Đang tải ${(updateState.downloadProgress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryLight,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Text(
                'v${ProductInfo.version}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
            ),
          ],
          const SizedBox(width: 8),

          // Quick Settings Button
          IconButton(
            tooltip: 'Cài đặt hệ thống (Ctrl+,)',
            icon: Icon(
              Icons.settings_outlined,
              size: 20,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
            onPressed: () => context.go(AppRoutes.settings),
          ),
        ],
      ),
    );
  }
}
