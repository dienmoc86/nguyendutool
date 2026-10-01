import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/modules/module_category.dart';
import '../../../core/modules/module_definition.dart';
import '../../../core/modules/module_registry.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/security/credential_service.dart';
import 'support_author_dialog.dart';

/// Grouped collapsible desktop sidebar navigation for NguyenDu Tool (Phase 6A).
class AppSidebar extends ConsumerStatefulWidget {
  final bool isCollapsed;
  final String currentRoute;

  const AppSidebar({
    super.key,
    required this.isCollapsed,
    required this.currentRoute,
  });

  @override
  ConsumerState<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends ConsumerState<AppSidebar> {
  // Generic expansion state keyed by category ID
  final Map<String, bool> _expandedCategories = {
    ModuleCategory.home.id: true,
    ModuleCategory.teaching.id: true,
    ModuleCategory.documents.id: true,
    ModuleCategory.media.id: true,
    ModuleCategory.system.id: true,
  };

  bool _initializedStorage = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedStorage) {
      _loadExpansionState();
      _initializedStorage = true;
    }
  }

  Future<void> _loadExpansionState() async {
    // Default initial expansion states are set in _expandedCategories map
  }

  void _toggleCategory(String categoryId) {
    setState(() {
      final current = _expandedCategories[categoryId] ?? true;
      _expandedCategories[categoryId] = !current;
    });

    try {
      final isExpanded = _expandedCategories[categoryId] ?? true;
      ref
          .read(settingsRepositoryProvider)
          .saveSetting('nav_group_${categoryId}_expanded', isExpanded ? '1' : '0');
    } catch (_) {
      // Ignored for UI smoothness
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final registry = ModuleRegistry.instance;

    // Filter categories that have active/launchable modules
    final activeCategories = ModuleCategory.values.where((cat) {
      final modules = registry.getModulesByCategory(cat).where((m) => m.isVisible).toList();
      return modules.isNotEmpty;
    }).toList();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: widget.isCollapsed ? 72 : 240,
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
                if (!widget.isCollapsed) ...[
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

          const SizedBox(height: 8),

          // Navigation items list grouped by Category
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                for (final cat in activeCategories) ...[
                  _buildCategorySection(cat, registry, isDark),
                  const SizedBox(height: 4),
                ],
                if (!widget.isCollapsed) ...[
                  const SizedBox(height: 4),
                  _buildGeminiSidebarBadge(context, isDark),
                ],
              ],
            ),
          ),

          // Author & Support Card (Subtle, elegant, free community tool)
          if (!widget.isCollapsed) ...[
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
          if (!widget.isCollapsed)
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

  Widget _buildCategorySection(
    ModuleCategory category,
    ModuleRegistry registry,
    bool isDark,
  ) {
    final modules = registry.getModulesByCategory(category).where((m) => m.isVisible).toList();
    final isExpanded = _expandedCategories[category.id] ?? true;

    // In collapsed sidebar, just render module icons
    if (widget.isCollapsed) {
      return Column(
        children: [
          for (final module in modules) _buildModuleItem(module, isDark),
          const Divider(height: 12, thickness: 0.5),
        ],
      );
    }

    // Home category doesn't need collapsible header arrow
    if (category == ModuleCategory.home) {
      return Column(
        children: [
          for (final module in modules) _buildModuleItem(module, isDark),
          const SizedBox(height: 6),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category Header with Collapse Toggle
        InkWell(
          onTap: () => _toggleCategory(category.id),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Text(
                  category.displayName,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
                const Spacer(),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.keyboard_arrow_right_rounded,
                  size: 16,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ],
            ),
          ),
        ),

        // Collapsible Module List
        if (isExpanded)
          Column(
            children: [
              for (final module in modules) _buildModuleItem(module, isDark),
            ],
          ),
      ],
    );
  }

  Widget _buildModuleItem(ModuleDefinition module, bool isDark) {
    final isSelected = widget.currentRoute == module.route;
    final accentColor = module.accentColor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Tooltip(
        message: widget.isCollapsed ? '${module.shortName}\n${module.description}' : '',
        waitDuration: const Duration(milliseconds: 500),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              if (module.isLaunchable && module.route != null) {
                // Track usage
                ref.read(moduleUsageServiceProvider).recordModuleOpened(module.id);
                if (!isSelected) {
                  context.go(module.route!);
                }
              }
            },
            hoverColor: accentColor.withOpacity(0.08),
            child: Container(
              height: 40,
              padding: EdgeInsets.symmetric(
                horizontal: widget.isCollapsed ? 0 : 10,
              ),
              decoration: BoxDecoration(
                color: isSelected ? accentColor.withOpacity(0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: isSelected
                    ? Border.all(color: accentColor.withOpacity(0.35), width: 1)
                    : null,
              ),
              child: Row(
                mainAxisAlignment:
                    widget.isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                children: [
                  Icon(
                    module.icon,
                    size: 19,
                    color: isSelected
                        ? accentColor
                        : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                  ),
                  if (!widget.isCollapsed) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        module.shortName,
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
                    if (module.status.isBeta)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          color: AppColors.accentViolet.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Beta',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppColors.accentViolet,
                          ),
                        ),
                      ),
                    if (isSelected)
                      Container(
                        width: 4,
                        height: 16,
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: BorderRadius.circular(2),
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

  Widget _buildGeminiSidebarBadge(BuildContext context, bool isDark) {
    return FutureBuilder<String?>(
      future: CredentialService().getGeminiApiKey(),
      builder: (context, snapshot) {
        final hasKey = snapshot.data != null && snapshot.data!.trim().isNotEmpty;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Material(
            color: hasKey
                ? (isDark ? const Color(0xFF0F231D) : const Color(0xFFE8F5E9))
                : (isDark ? const Color(0xFF2A1C0A) : const Color(0xFFFFF3E0)),
            borderRadius: BorderRadius.circular(10),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.go(AppRoutes.settings),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: hasKey
                        ? (isDark ? const Color(0xFF1E4633) : const Color(0xFFA5D6A7))
                        : (isDark ? const Color(0xFF4A3415) : const Color(0xFFFFCC80)),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 16,
                      color: hasKey ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Google Gemini AI',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.lightTextPrimary,
                            ),
                          ),
                          Text(
                            hasKey ? 'Đã kích hoạt' : 'Chưa gắn API Key',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: hasKey ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      hasKey ? Icons.check_circle_rounded : Icons.arrow_forward_ios_rounded,
                      size: 11,
                      color: hasKey ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
