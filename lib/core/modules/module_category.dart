import 'package:flutter/material.dart';

/// Categories grouping NguyenDu Tool modules.
enum ModuleCategory {
  home('home', 'Trang chủ', 0, Icons.home_rounded),
  teaching('teaching', 'GIẢNG DẠY', 1, Icons.school_rounded),
  documents('documents', 'TÀI LIỆU', 2, Icons.description_rounded),
  media('media', 'MEDIA', 3, Icons.perm_media_rounded),
  ai('ai', 'AI', 4, Icons.auto_awesome_rounded),
  utilities('utilities', 'TIỆN ÍCH', 5, Icons.handyman_rounded),
  system('system', 'HỆ THỐNG', 6, Icons.settings_applications_rounded);

  final String id;
  final String displayName;
  final int sortOrder;
  final IconData icon;

  const ModuleCategory(this.id, this.displayName, this.sortOrder, this.icon);

  static ModuleCategory fromId(String id) {
    return ModuleCategory.values.firstWhere(
      (c) => c.id == id,
      orElse: () => ModuleCategory.utilities,
    );
  }
}
