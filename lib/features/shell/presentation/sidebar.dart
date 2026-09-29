import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';

class NavItem {
  final String title;
  final IconData icon;
  final String route;
  final Color accentColor;

  const NavItem({
    required this.title,
    required this.icon,
    required this.route,
    required this.accentColor,
  });
}

/// Collapsible desktop sidebar navigation for NguyenDu Tool.
class AppSidebar extends StatelessWidget {
  final bool isCollapsed;
  final String currentRoute;

  const AppSidebar({
    super.key,
    required this.isCollapsed,
    required this.currentRoute,
  });

  static const List<NavItem> navItems = [
    NavItem(
      title: 'Bàn làm việc',
      icon: Icons.dashboard_rounded,
      route: AppRoutes.dashboard,
      accentColor: AppColors.primary,
    ),
    NavItem(
      title: 'Giáo án & Bài giảng',
      icon: Icons.picture_as_pdf_rounded,
      route: AppRoutes.pdfConverter,
      accentColor: AppColors.modulePdf,
    ),
    NavItem(
      title: 'Quét Đề thi & Hồ sơ',
      icon: Icons.scanner_rounded,
      route: AppRoutes.scanner,
      accentColor: AppColors.moduleScanner,
    ),
    NavItem(
      title: 'Đọc & Thuyết minh',
      icon: Icons.record_voice_over_rounded,
      route: AppRoutes.textToSpeech,
      accentColor: AppColors.moduleTts,
    ),
    NavItem(
      title: 'Video Bài giảng',
      icon: Icons.video_collection_rounded,
      route: AppRoutes.videoStudio,
      accentColor: AppColors.moduleVideo,
    ),
    NavItem(
      title: 'Kho Học liệu số',
      icon: Icons.folder_shared_rounded,
      route: AppRoutes.fileLibrary,
      accentColor: AppColors.moduleLibrary,
    ),
    NavItem(
      title: 'Cài đặt',
      icon: Icons.tune_rounded,
      route: AppRoutes.settings,
      accentColor: AppColors.secondary,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: isCollapsed ? 72 : 240,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSidebar : AppColors.lightSidebar,
        border: Border(
          right: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // App Header / Brand Logo
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.accentViolet],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.school_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                if (!isCollapsed) ...[
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'NguyenDu Tool',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Trợ lý số Giáo viên',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Navigation items list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: navItems.length,
              itemBuilder: (context, index) {
                final item = navItems[index];
                final isSelected = currentRoute == item.route;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () {
                        if (!isSelected) {
                          context.go(item.route);
                        }
                      },
                      hoverColor: item.accentColor.withOpacity(0.08),
                      child: Container(
                        height: 44,
                        padding: EdgeInsets.symmetric(
                          horizontal: isCollapsed ? 0 : 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? item.accentColor.withOpacity(0.12) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected
                              ? Border.all(color: item.accentColor.withOpacity(0.3), width: 1)
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: isCollapsed
                              ? MainAxisAlignment.center
                              : MainAxisAlignment.start,
                          children: [
                            Icon(
                              item.icon,
                              size: 20,
                              color: isSelected
                                  ? item.accentColor
                                  : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                            ),
                            if (!isCollapsed) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                    color: isSelected
                                        ? (isDark ? Colors.white : AppColors.lightTextPrimary)
                                        : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isSelected)
                                Container(
                                  width: 4,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: item.accentColor,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Footer workspace label
          if (!isCollapsed)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.security_rounded,
                    size: 16,
                    color: AppColors.success,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Local-First Desktop',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
