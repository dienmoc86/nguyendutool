import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import 'support_author_dialog.dart';

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
      title: 'Soạn Giáo án AI (5512)',
      icon: Icons.auto_awesome_rounded,
      route: AppRoutes.lessonPlanner,
      accentColor: AppColors.accentViolet,
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
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/images/ibest_logo.png',
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
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
                          'iBest Group • Giáo dục số',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4CAF50),
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

          // Author & Support Card (Subtle, elegant, free community tool)
          if (!isCollapsed) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF141C2B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? const Color(0xFF223048) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.coffee_rounded, color: Color(0xFFFFA726), size: 15),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'Tác giả: Mr. Điện',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Free',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.greenAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Miễn phí 100%. Nhận viết tool & nâng cấp theo yêu cầu riêng.',
                    style: TextStyle(fontSize: 10, color: AppColors.darkTextSecondary, height: 1.25),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      InkWell(
                        onTap: () {
                          if (Platform.isWindows) {
                            Process.run('cmd.exe', ['/c', 'start', 'https://zalo.me/0917764111']);
                          }
                        },
                        child: const Row(
                          children: [
                            Icon(Icons.phone_android_rounded, size: 11, color: Colors.blueAccent),
                            SizedBox(width: 2),
                            Text(
                              '0917.764.111',
                              style: TextStyle(fontSize: 10, color: Colors.blueAccent, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: () {
                          if (Platform.isWindows) {
                            Process.run('cmd.exe', ['/c', 'start', 'https://ibestgroup.vn']);
                          }
                        },
                        child: const Row(
                          children: [
                            Icon(Icons.language_rounded, size: 11, color: Colors.tealAccent),
                            SizedBox(width: 2),
                            Text(
                              'ibestgroup.vn',
                              style: TextStyle(fontSize: 10, color: Colors.tealAccent, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    height: 24,
                    child: OutlinedButton.icon(
                      onPressed: () => SupportAuthorDialog.show(context),
                      icon: const Icon(Icons.favorite_outline_rounded, size: 12, color: Color(0xFFFFA726)),
                      label: const Text('Mời cà phê ☕', style: TextStyle(fontSize: 10)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFFA726),
                        side: BorderSide(color: const Color(0xFFFFA726).withOpacity(0.4)),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: IconButton(
                tooltip: 'Mr. Điện (0917.764.111) - ibestgroup.vn\nMời tác giả tách cà phê ☕',
                onPressed: () => SupportAuthorDialog.show(context),
                icon: const Icon(Icons.coffee_rounded, size: 18, color: Color(0xFFFFA726)),
              ),
            ),
          ],

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
