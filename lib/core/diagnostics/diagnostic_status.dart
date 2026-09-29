/// Standard statuses for system checks and diagnostic probes.
enum DiagnosticStatus {
  /// Component is fully operational and verified.
  ready,

  /// Component is optional and currently unavailable (e.g. physical scanner or cloud API).
  optionalNotAvailable,

  /// Action required by user or system administrator (e.g. install Vietnamese voice).
  actionRequired,

  /// Critical check failed (e.g. disk full, read-only workspace).
  failed,
}

extension DiagnosticStatusX on DiagnosticStatus {
  String get label {
    switch (this) {
      case DiagnosticStatus.ready:
        return 'READY';
      case DiagnosticStatus.optionalNotAvailable:
        return 'OPTIONAL_NOT_AVAILABLE';
      case DiagnosticStatus.actionRequired:
        return 'ACTION_REQUIRED';
      case DiagnosticStatus.failed:
        return 'FAILED';
    }
  }

  String get vietnameseLabel {
    switch (this) {
      case DiagnosticStatus.ready:
        return 'Sẵn sàng';
      case DiagnosticStatus.optionalNotAvailable:
        return 'Không khả dụng (Tùy chọn)';
      case DiagnosticStatus.actionRequired:
        return 'Cần thiết lập';
      case DiagnosticStatus.failed:
        return 'Lỗi nghiêm trọng';
    }
  }
}

/// An individual diagnostic inspection result.
class SystemDiagnosticItem {
  final String id;
  final String title;
  final String description;
  final DiagnosticStatus status;
  final String details;
  final String? recommendation;
  final String category;

  const SystemDiagnosticItem({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.details,
    this.recommendation,
    required this.category,
  });

  bool get isReady => status == DiagnosticStatus.ready;
  bool get isActionRequired => status == DiagnosticStatus.actionRequired;
  bool get isFailed => status == DiagnosticStatus.failed;
}
