import 'capability_availability.dart';

/// Representation of a functional runtime capability in NguyenDu Tool.
class AppCapability {
  final String id;
  final String displayName;
  final String description;
  final CapabilityAvailability availability;
  final String provider;
  final String? reason;
  final DateTime? lastChecked;

  const AppCapability({
    required this.id,
    required this.displayName,
    required this.description,
    required this.availability,
    this.provider = '',
    this.reason,
    this.lastChecked,
  });

  bool get isAvailable => availability == CapabilityAvailability.available || availability == CapabilityAvailability.degraded;

  AppCapability copyWith({
    String? id,
    String? displayName,
    String? description,
    CapabilityAvailability? availability,
    String? provider,
    String? reason,
    DateTime? lastChecked,
  }) {
    return AppCapability(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      description: description ?? this.description,
      availability: availability ?? this.availability,
      provider: provider ?? this.provider,
      reason: reason ?? this.reason,
      lastChecked: lastChecked ?? this.lastChecked,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'displayName': displayName,
        'description': description,
        'availability': availability.id,
        'provider': provider,
        'reason': reason,
        'lastChecked': lastChecked?.toIso8601String(),
      };
}
