/// Represents the type of asynchronous task/job in NguyenDu Tool.
enum JobType {
  pdfConvert('pdfConvert', 'Chuyển đổi PDF/Office'),
  ocr('ocr', 'Nhận diện OCR văn bản'),
  scanProcess('scanProcess', 'Xử lý quét tài liệu'),
  ttsGenerate('ttsGenerate', 'Chuyển văn bản thành giọng nói'),
  videoRender('videoRender', 'Xuất/Render video bài giảng');

  final String value;
  final String label;

  const JobType(this.value, this.label);

  static JobType fromString(String val) {
    return JobType.values.firstWhere(
      (e) => e.value.toLowerCase() == val.toLowerCase(),
      orElse: () => JobType.pdfConvert,
    );
  }
}
