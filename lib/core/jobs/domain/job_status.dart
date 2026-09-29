/// State lifecycle of an asynchronous job in NguyenDu Tool.
enum JobStatus {
  queued('queued', 'Đang xếp hàng'),
  running('running', 'Đang xử lý'),
  completed('completed', 'Hoàn tất'),
  failed('failed', 'Thất bại'),
  cancelled('cancelled', 'Đã hủy');

  final String value;
  final String label;

  const JobStatus(this.value, this.label);

  static JobStatus fromString(String val) {
    return JobStatus.values.firstWhere(
      (e) => e.value.toLowerCase() == val.toLowerCase(),
      orElse: () => JobStatus.queued,
    );
  }

  bool get isTerminal => this == completed || this == failed || this == cancelled;
  bool get isActive => this == queued || this == running;
}
