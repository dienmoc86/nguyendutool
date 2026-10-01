/// Typed exceptions for Assessment Studio (Requirement 95).
class InvalidExamMatrixException implements Exception {
  final String message;
  final List<String> errors;

  const InvalidExamMatrixException(this.message, [this.errors = const []]);

  @override
  String toString() => 'InvalidExamMatrixException: $message ${errors.isNotEmpty ? errors.join(", ") : ""}';
}

class InsufficientQuestionBankException implements Exception {
  final String message;
  final Map<String, int> shortages;

  const InsufficientQuestionBankException(this.message, [this.shortages = const {}]);

  @override
  String toString() => 'InsufficientQuestionBankException: $message';
}

class ExamNotFinalizedException implements Exception {
  final String message;

  const ExamNotFinalizedException([this.message = 'Đề thi gốc chưa được chốt duyệt (Finalized). Hãy chốt duyệt trước khi tạo mã đề hoặc xuất bản.']);

  @override
  String toString() => 'ExamNotFinalizedException: $message';
}

class ExamCodeVerificationException implements Exception {
  final String message;
  final List<String> mismatches;

  const ExamCodeVerificationException(this.message, [this.mismatches = const []]);

  @override
  String toString() => 'ExamCodeVerificationException: $message ${mismatches.isNotEmpty ? mismatches.join(", ") : ""}';
}

class ExamExportException implements Exception {
  final String message;
  final Object? cause;

  const ExamExportException(this.message, [this.cause]);

  @override
  String toString() => 'ExamExportException: $message ${cause != null ? "($cause)" : ""}';
}
