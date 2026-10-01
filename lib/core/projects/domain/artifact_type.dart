/// Extensible artifact types associated with workspace projects.
enum ArtifactType {
  docx('docx', 'Tài liệu Word', '.docx'),
  xlsx('xlsx', 'Bảng tính Excel', '.xlsx'),
  pdf('pdf', 'Tài liệu PDF', '.pdf'),
  pptx('pptx', 'Trình chiếu PowerPoint', '.pptx'),
  image('image', 'Hình ảnh học liệu', '.jpg'),
  audio('audio', 'Âm thanh / Giọng đọc', '.mp3'),
  video('video', 'Video bài giảng', '.mp4'),
  subtitle('subtitle', 'Phụ đề bài giảng', '.srt'),
  text('text', 'Văn bản thuần', '.txt'),
  other('other', 'Tệp tin khác', '');

  final String id;
  final String displayName;
  final String defaultExtension;

  const ArtifactType(this.id, this.displayName, this.defaultExtension);

  static ArtifactType fromId(String id) {
    return ArtifactType.values.firstWhere(
      (t) => t.id == id,
      orElse: () => ArtifactType.other,
    );
  }
}
