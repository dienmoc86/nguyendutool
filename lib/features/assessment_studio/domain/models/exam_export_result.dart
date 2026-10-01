/// Structured result of the exam package export operation (Sections 48, 50, 51).
class ExamExportResult {
  final bool successful;
  final String exportDirectory;
  final List<String> successfulFiles;
  final List<String> failedFiles;
  final List<String> errors;

  const ExamExportResult({
    required this.successful,
    required this.exportDirectory,
    this.successfulFiles = const [],
    this.failedFiles = const [],
    this.errors = const [],
  });

  int get totalFiles => successfulFiles.length + failedFiles.length;
}
