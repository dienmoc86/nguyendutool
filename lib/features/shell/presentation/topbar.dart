import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/providers/app_providers.dart';

import '../../../core/update/update_notifier.dart';
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
          const SizedBox(width: 12),
          Text(
            activeTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const Spacer(),

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

          // Version badge
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
              'v1.5.1 Education',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Quick Settings Button
          IconButton(
            tooltip: 'Cài đặt hệ thống',
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
