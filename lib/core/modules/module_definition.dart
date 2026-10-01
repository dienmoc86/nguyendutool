import 'package:flutter/material.dart';
import 'module_category.dart';
import 'module_status.dart';

/// Metadata definition of an application module in NguyenDu Tool.
class ModuleDefinition {
  final String id;
  final String name;
  final String shortName;
  final String description;
  final IconData icon;
  final ModuleCategory category;
  final String? route;
  final int order;
  final ModuleStatus status;
  final List<String> capabilities;
  final List<String> optionalCapabilities;
  final List<String> keywords;
  final bool isVisible;
  final bool isExperimental;
  final bool requiresNetwork;
  final bool supportsOffline;
  final Color accentColor;
  final String? minimumRequirements;
  final String? intentActionTitle;

  const ModuleDefinition({
    required this.id,
    required this.name,
    required this.shortName,
    required this.description,
    required this.icon,
    required this.category,
    this.route,
    required this.order,
    this.status = ModuleStatus.stable,
    this.capabilities = const [],
    this.optionalCapabilities = const [],
    this.keywords = const [],
    this.isVisible = true,
    this.isExperimental = false,
    this.requiresNetwork = false,
    this.supportsOffline = true,
    this.accentColor = const Color(0xFF2563EB),
    this.minimumRequirements,
    this.intentActionTitle,
  });

  bool get isLaunchable => status.isLaunchable && route != null;

  /// Copy with modifications
  ModuleDefinition copyWith({
    String? id,
    String? name,
    String? shortName,
    String? description,
    IconData? icon,
    ModuleCategory? category,
    String? route,
    int? order,
    ModuleStatus? status,
    List<String>? capabilities,
    List<String>? optionalCapabilities,
    List<String>? keywords,
    bool? isVisible,
    bool? isExperimental,
    bool? requiresNetwork,
    bool? supportsOffline,
    Color? accentColor,
    String? minimumRequirements,
    String? intentActionTitle,
  }) {
    return ModuleDefinition(
      id: id ?? this.id,
      name: name ?? this.name,
      shortName: shortName ?? this.shortName,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      category: category ?? this.category,
      route: route ?? this.route,
      order: order ?? this.order,
      status: status ?? this.status,
      capabilities: capabilities ?? this.capabilities,
      optionalCapabilities: optionalCapabilities ?? this.optionalCapabilities,
      keywords: keywords ?? this.keywords,
      isVisible: isVisible ?? this.isVisible,
      isExperimental: isExperimental ?? this.isExperimental,
      requiresNetwork: requiresNetwork ?? this.requiresNetwork,
      supportsOffline: supportsOffline ?? this.supportsOffline,
      accentColor: accentColor ?? this.accentColor,
      minimumRequirements: minimumRequirements ?? this.minimumRequirements,
      intentActionTitle: intentActionTitle ?? this.intentActionTitle,
    );
  }
}
