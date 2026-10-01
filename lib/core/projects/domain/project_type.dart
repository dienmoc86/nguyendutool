/// Supported workspace project types in NguyenDu Tool.
enum ProjectType {
  lesson('lesson', 'Giáo án (Kế hoạch bài dạy)'),
  presentation('presentation', 'Bài giảng Trình chiếu (PowerPoint)'),
  video('video', 'Video Bài giảng E-Learning'),
  document('document', 'Tài liệu & Số hóa'),
  assessment('assessment', 'Đề kiểm tra & Đánh giá'),
  other('other', 'Dự án khác');

  final String id;
  final String displayName;

  const ProjectType(this.id, this.displayName);

  static ProjectType fromId(String id) {
    return ProjectType.values.firstWhere(
      (t) => t.id == id,
      orElse: () => ProjectType.other,
    );
  }
}
