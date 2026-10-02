import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/modules/module_definition.dart';
import '../../../core/modules/module_registry.dart';
import '../../../core/providers/app_providers.dart';
import 'support_author_dialog.dart';

/// Streamlined, focused sidebar navigation for NguyenDu Tool.
/// Presents the essential tools for school teachers in a clean, uncluttered desktop UI.
class AppSidebar extends ConsumerWidget {
  final bool isCollapsed;
  final String currentRoute;

  const AppSidebar({
    super.key,
    required this.isCollapsed,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final registry = ModuleRegistry.instance;
    final visibleModules = registry.getVisibleModules();

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
                          'Phần mềm hỗ trợ giáo viên',
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

          // Navigation items list: Pure, flat list of active teacher tools
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                for (final module in visibleModules) ...[
                  _buildModuleItem(context, ref, module, isDark),
                  const SizedBox(height: 6),
                ],
              ],
            ),
          ),

          // Author & Support Card
          if (!isCollapsed) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 1.5),
                        child: Icon(Icons.support_agent_rounded, color: Color(0xFFFFA726), size: 15),
                      ),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'Nhận viết tool & nâng cấp theo yêu cầu',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, height: 1.25),
                          maxLines: 2,
                        ),
                      ),
                      const SizedBox(width: 4),
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
                  const SizedBox(height: 5),
                  const Text(
                    'Miễn phí 100% dành cho giáo viên & nhà trường.',
                    style: TextStyle(fontSize: 10, color: AppColors.darkTextSecondary, height: 1.25),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      InkWell(
                        onTap: () {
                          if (Platform.isWindows) {
                            Process.run('cmd.exe', ['/c', 'start', 'https://zalo.me/0917764111']);
                          }
                        },
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
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
                      InkWell(
                        onTap: () {
                          if (Platform.isWindows) {
                            Process.run('cmd.exe', ['/c', 'start', 'https://ibestgroup.vn']);
                          }
                        },
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
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
                    height: 25,
                    child: OutlinedButton.icon(
                      onPressed: () => SupportAuthorDialog.show(context),
                      icon: const Icon(Icons.contact_support_outlined, size: 12, color: Color(0xFFFFA726)),
                      label: const Text('Vui lòng liên hệ', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600)),
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
                tooltip: 'Nhận viết tool & nâng cấp theo yêu cầu\n0917.764.111 - ibestgroup.vn\nVui lòng liên hệ',
                icon: const Icon(Icons.support_agent_rounded, color: Color(0xFFFFA726), size: 20),
                onPressed: () => SupportAuthorDialog.show(context),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModuleItem(
    BuildContext context,
    WidgetRef ref,
    ModuleDefinition module,
    bool isDark,
  ) {
    final isSelected = currentRoute == module.route;
    final accentColor = module.accentColor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Tooltip(
        message: isCollapsed ? '${module.shortName}\n${module.description}' : '',
        waitDuration: const Duration(milliseconds: 500),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              if (module.isLaunchable && module.route != null) {
                ref.read(moduleUsageServiceProvider).recordModuleOpened(module.id);
                if (!isSelected) {
                  context.go(module.route!);
                }
              }
            },
            hoverColor: accentColor.withOpacity(0.08),
            child: Container(
              height: 44,
              padding: EdgeInsets.symmetric(
                horizontal: isCollapsed ? 0 : 12,
              ),
              decoration: BoxDecoration(
                color: isSelected ? accentColor.withOpacity(0.14) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: isSelected
                    ? Border.all(color: accentColor.withOpacity(0.4), width: 1.2)
                    : null,
              ),
              child: Row(
                mainAxisAlignment:
                    isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                children: [
                  Icon(
                    module.icon,
                    size: 20,
                    color: isSelected
                        ? accentColor
                        : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                  ),
                  if (!isCollapsed) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        module.shortName,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? (isDark ? Colors.white : AppColors.lightTextPrimary)
                              : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isSelected)
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accentColor,
                        ),
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
