import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/modules/module_definition.dart';
import '../../../../core/modules/module_status.dart';

/// Desktop Card representing a functional or planned module on the Dashboard.
class ModuleCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback? onTap;
  final String statusBadge;
  final Color? statusBadgeColor;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;
  final bool isComingSoon;
  final bool isUnavailable;
  final String? unavailableReason;
  final bool isOffline;
  final bool requiresNetwork;

  const ModuleCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    this.onTap,
    this.statusBadge = 'Sẵn sàng kiến trúc',
    this.statusBadgeColor,
    this.isFavorite = false,
    this.onToggleFavorite,
    this.isComingSoon = false,
    this.isUnavailable = false,
    this.unavailableReason,
    this.isOffline = true,
    this.requiresNetwork = false,
  });

  /// Factory constructor to create ModuleCard directly from ModuleDefinition.
  factory ModuleCard.fromDefinition({
    Key? key,
    required ModuleDefinition module,
    VoidCallback? onTap,
    bool isFavorite = false,
    VoidCallback? onToggleFavorite,
  }) {
    String badge = 'Khả dụng';
    Color? badgeColor;

    if (module.status == ModuleStatus.beta) {
      badge = 'Beta';
      badgeColor = AppColors.accentViolet;
    } else if (module.status == ModuleStatus.comingSoon) {
      badge = 'Sắp ra mắt';
      badgeColor = Colors.orangeAccent;
    } else if (module.status == ModuleStatus.unavailable) {
      badge = 'Yêu cầu cấu hình';
      badgeColor = Colors.redAccent;
    } else if (module.status == ModuleStatus.experimental) {
      badge = 'Thử nghiệm';
      badgeColor = Colors.amber;
    }

    return ModuleCard(
      key: key,
      title: module.name,
      subtitle: module.description,
      icon: module.icon,
      accentColor: module.accentColor,
      onTap: module.isLaunchable ? onTap : null,
      statusBadge: badge,
      statusBadgeColor: badgeColor,
      isFavorite: isFavorite,
      onToggleFavorite: onToggleFavorite,
      isComingSoon: module.status == ModuleStatus.comingSoon,
      isUnavailable: module.status == ModuleStatus.unavailable,
      unavailableReason: module.status == ModuleStatus.unavailable ? 'Chưa cấu hình tài nguyên' : null,
      isOffline: module.supportsOffline,
      requiresNetwork: module.requiresNetwork,
    );
  }

  @override
  State<ModuleCard> createState() => _ModuleCardState();
}

class _ModuleCardState extends State<ModuleCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isInteractive = !widget.isComingSoon && !widget.isUnavailable && widget.onTap != null;
    final badgeColor = widget.statusBadgeColor ?? widget.accentColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: isInteractive ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: isInteractive ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          transform: Matrix4.identity()..translate(0.0, _isHovered && isInteractive ? -4.0 : 0.0),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: widget.isComingSoon
                ? (isDark ? const Color(0xFF161C26) : const Color(0xFFF8FAFC))
                : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isHovered && isInteractive
                  ? widget.accentColor.withOpacity(0.7)
                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              width: _isHovered && isInteractive ? 1.5 : 1,
            ),
            boxShadow: [
              if (_isHovered && isInteractive)
                BoxShadow(
                  color: widget.accentColor.withOpacity(0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                )
              else
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Card Top: Icon, Badge, and Favorite
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: widget.isComingSoon
                          ? Colors.grey.withOpacity(0.15)
                          : widget.accentColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: widget.isComingSoon
                            ? Colors.grey.withOpacity(0.25)
                            : widget.accentColor.withOpacity(0.25),
                      ),
                    ),
                    child: Icon(
                      widget.icon,
                      color: widget.isComingSoon ? Colors.grey : widget.accentColor,
                      size: 24,
                    ),
                  ),
                  const Spacer(),
                  // Cloud / Offline chip
                  if (!widget.isComingSoon) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        widget.requiresNetwork ? 'AI Cloud' : 'Offline',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ),
                  ],
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: badgeColor.withOpacity(0.35)),
                    ),
                    child: Text(
                      widget.statusBadge,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: badgeColor,
                      ),
                    ),
                  ),
                  // Favorite Star Button
                  if (widget.onToggleFavorite != null) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(
                        widget.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                        color: widget.isFavorite ? Colors.amber : (isDark ? Colors.white38 : Colors.grey),
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                      tooltip: widget.isFavorite ? 'Bỏ yêu thích' : 'Đánh dấu yêu thích',
                      onPressed: widget.onToggleFavorite,
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 10),

              // Title and Description
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: widget.isComingSoon
                          ? (isDark ? Colors.white60 : Colors.black54)
                          : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.subtitle,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Card Bottom Action or Planned State
              if (widget.isComingSoon)
                Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: 14, color: Colors.orange.shade300),
                    const SizedBox(width: 6),
                    Text(
                      'Kế hoạch mở rộng theo lộ trình',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: isDark ? Colors.white38 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                )
              else if (widget.isUnavailable)
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.redAccent),
                    const SizedBox(width: 6),
                    Text(
                      widget.unavailableReason ?? 'Chưa sẵn sàng',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Text(
                      'Khởi chạy phân hệ',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: widget.accentColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 15,
                      color: widget.accentColor,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
