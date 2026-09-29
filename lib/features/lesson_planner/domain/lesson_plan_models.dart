/// Model representing a request to generate an educational lesson plan.
class LessonPlanRequest {
  final String subject;
  final String grade;
  final String bookSeries;
  final String lessonTitle;
  final String duration;
  final String? customRequirements;
  final String? referenceText;

  const LessonPlanRequest({
    required this.subject,
    required this.grade,
    required this.bookSeries,
    required this.lessonTitle,
    required this.duration,
    this.customRequirements,
    this.referenceText,
  });

  LessonPlanRequest copyWith({
    String? subject,
    String? grade,
    String? bookSeries,
    String? lessonTitle,
    String? duration,
    String? customRequirements,
    String? referenceText,
  }) {
    return LessonPlanRequest(
      subject: subject ?? this.subject,
      grade: grade ?? this.grade,
      bookSeries: bookSeries ?? this.bookSeries,
      lessonTitle: lessonTitle ?? this.lessonTitle,
      duration: duration ?? this.duration,
      customRequirements: customRequirements ?? this.customRequirements,
      referenceText: referenceText ?? this.referenceText,
    );
  }
}

/// Popular Vietnamese educational subjects
class SchoolSubjects {
  static const List<String> subjects = [
    'Toán học',
    'Ngữ văn / Tiếng Việt',
    'Tiếng Anh',
    'Khoa học tự nhiên',
    'Vật lý',
    'Hóa học',
    'Sinh học',
    'Lịch sử & Địa lý',
    'Lịch sử',
    'Địa lý',
    'Tin học',
    'Giáo dục công dân / GD Kinh tế & Pháp luật',
    'Công nghệ',
    'Giáo dục thể chất',
    'Âm nhạc',
    'Mĩ thuật',
    'Hoạt động trải nghiệm, hướng nghiệp',
  ];

  static const List<String> grades = [
    'Lớp 1', 'Lớp 2', 'Lớp 3', 'Lớp 4', 'Lớp 5',
    'Lớp 6', 'Lớp 7', 'Lớp 8', 'Lớp 9',
    'Lớp 10', 'Lớp 11', 'Lớp 12',
  ];

  static const List<String> bookSeriesList = [
    'Kết nối tri thức với cuộc sống',
    'Chân trời sáng tạo',
    'Cánh diều',
    'Chương trình chung (GDPT 2018)',
  ];

  static const List<String> durations = [
    '1 tiết (45 phút)',
    '2 tiết (90 phút)',
    '3 tiết',
    '4 tiết',
    'Theo chuyên đề',
  ];
}
