import 'package:flutter/material.dart';

/// Runtime availability status of a system or service capability.
enum CapabilityAvailability {
  available('available', 'Khả dụng', true),
  unavailable('unavailable', 'Không khả dụng', false),
  notConfigured('notConfigured', 'Chưa cấu hình', false),
  degraded('degraded', 'Hạn chế', true),
  unknown('unknown', 'Đang kiểm tra', false);

  final String id;
  final String displayName;
  final bool isUsable;

  const CapabilityAvailability(this.id, this.displayName, this.isUsable);

  Color getStatusColor() {
    switch (this) {
      case CapabilityAvailability.available:
        return const Color(0xFF10B981);
      case CapabilityAvailability.degraded:
        return const Color(0xFFF59E0B);
      case CapabilityAvailability.notConfigured:
        return const Color(0xFF3B82F6);
      case CapabilityAvailability.unavailable:
        return const Color(0xFFEF4444);
      case CapabilityAvailability.unknown:
        return const Color(0xFF94A3B8);
    }
  }
}
