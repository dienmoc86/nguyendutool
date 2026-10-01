import 'package:flutter/material.dart';

/// Readiness state of a module in NguyenDu Tool.
enum ModuleStatus {
  stable('stable', null, true),
  beta('beta', 'Beta', true),
  experimental('experimental', 'Thử nghiệm', true),
  comingSoon('comingSoon', 'Sắp ra mắt', false),
  disabled('disabled', 'Tạm khóa', false),
  unavailable('unavailable', 'Yêu cầu cấu hình', false);

  final String id;
  final String? badgeText;
  final bool isLaunchable;

  const ModuleStatus(this.id, this.badgeText, this.isLaunchable);

  bool get isBeta => this == ModuleStatus.beta;
  bool get isStable => this == ModuleStatus.stable;
  bool get isComingSoon => this == ModuleStatus.comingSoon;
  bool get isUnavailable => this == ModuleStatus.unavailable;

  static ModuleStatus fromId(String id) {
    return ModuleStatus.values.firstWhere(
      (s) => s.id == id,
      orElse: () => ModuleStatus.unavailable,
    );
  }

  Color getBadgeColor(BuildContext context, {Color fallback = const Color(0xFF64748B)}) {
    switch (this) {
      case ModuleStatus.stable:
        return const Color(0xFF10B981);
      case ModuleStatus.beta:
        return const Color(0xFF3B82F6);
      case ModuleStatus.experimental:
        return const Color(0xFFF59E0B);
      case ModuleStatus.comingSoon:
        return const Color(0xFF8B5CF6);
      case ModuleStatus.disabled:
        return const Color(0xFF6B7280);
      case ModuleStatus.unavailable:
        return const Color(0xFFEF4444);
    }
  }
}
