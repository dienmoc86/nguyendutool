import 'dart:convert';

/// Common exam types in Vietnamese educational framework (Section 5).
enum ExamType {
  quick15('15 phút / Kiểm tra nhanh'),
  periodic45('45 phút / Kiểm tra định kỳ'),
  midterm('Kiểm tra Giữa học kỳ'),
  finalExam('Kiểm tra Cuối học kỳ'),
  custom('Tùy chỉnh');

  final String label;
  const ExamType(this.label);

  static ExamType fromString(String? value) {
    if (value == null) return ExamType.periodic45;
    return ExamType.values.firstWhere(
      (e) => e.name == value || e.label == value,
      orElse: () => ExamType.periodic45,
    );
  }
}

/// Configurable exam header for Vietnamese schools (Sections 41 & 42).
class ExamHeaderConfig {
  final String schoolName;
  final String subject;
  final String grade;
  final String examTitle;
  final String schoolYear;
  final String semester;
  final int durationMinutes;
  final String studentNameLine;
  final String classLine;

  const ExamHeaderConfig({
    this.schoolName = 'TRƯỜNG THCS & THPT NGUYỄN DU',
    this.subject = 'Ngữ văn',
    this.grade = '9',
    this.examTitle = 'ĐỀ KIỂM TRA ĐỊNH KỲ',
    this.schoolYear = '2026 - 2027',
    this.semester = 'Học kỳ I',
    this.durationMinutes = 45,
    this.studentNameLine = 'Họ và tên thí sinh: ..............................................................',
    this.classLine = 'Lớp: ......................... SBD: ............................',
  });

  ExamHeaderConfig copyWith({
    String? schoolName,
    String? subject,
    String? grade,
    String? examTitle,
    String? schoolYear,
    String? semester,
    int? durationMinutes,
    String? studentNameLine,
    String? classLine,
  }) {
    return ExamHeaderConfig(
      schoolName: schoolName ?? this.schoolName,
      subject: subject ?? this.subject,
      grade: grade ?? this.grade,
      examTitle: examTitle ?? this.examTitle,
      schoolYear: schoolYear ?? this.schoolYear,
      semester: semester ?? this.semester,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      studentNameLine: studentNameLine ?? this.studentNameLine,
      classLine: classLine ?? this.classLine,
    );
  }

  Map<String, dynamic> toMap() => {
        'school_name': schoolName,
        'subject': subject,
        'grade': grade,
        'exam_title': examTitle,
        'school_year': schoolYear,
        'semester': semester,
        'duration_minutes': durationMinutes,
        'student_name_line': studentNameLine,
        'class_line': classLine,
      };

  factory ExamHeaderConfig.fromMap(Map<String, dynamic> map) => ExamHeaderConfig(
        schoolName: (map['school_name'] as String?) ?? 'TRƯỜNG THCS & THPT NGUYỄN DU',
        subject: (map['subject'] as String?) ?? 'Ngữ văn',
        grade: (map['grade'] as String?) ?? '9',
        examTitle: (map['exam_title'] as String?) ?? 'ĐỀ KIỂM TRA ĐỊNH KỲ',
        schoolYear: (map['school_year'] as String?) ?? '2026 - 2027',
        semester: (map['semester'] as String?) ?? 'Học kỳ I',
        durationMinutes: (map['duration_minutes'] as num?)?.toInt() ?? 45,
        studentNameLine: (map['student_name_line'] as String?) ??
            'Họ và tên thí sinh: ..............................................................',
        classLine: (map['class_line'] as String?) ??
            'Lớp: ......................... SBD: ............................',
      );
}

/// Project data model for Assessment Studio (Section 4).
class AssessmentProjectData {
  final String id;
  final String name;
  final String subject;
  final String grade;
  final ExamType examType;
  final int durationMinutes;
  final double totalScore;
  final String schoolYear;
  final String semester;
  final String? lessonProjectId;
  final ExamHeaderConfig headerConfig;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AssessmentProjectData({
    required this.id,
    required this.name,
    this.subject = 'Ngữ văn',
    this.grade = '9',
    this.examType = ExamType.periodic45,
    this.durationMinutes = 45,
    this.totalScore = 10.0,
    this.schoolYear = '2026 - 2027',
    this.semester = 'Học kỳ I',
    this.lessonProjectId,
    this.headerConfig = const ExamHeaderConfig(),
    required this.createdAt,
    required this.updatedAt,
  });

  AssessmentProjectData copyWith({
    String? id,
    String? name,
    String? subject,
    String? grade,
    ExamType? examType,
    int? durationMinutes,
    double? totalScore,
    String? schoolYear,
    String? semester,
    String? lessonProjectId,
    ExamHeaderConfig? headerConfig,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AssessmentProjectData(
      id: id ?? this.id,
      name: name ?? this.name,
      subject: subject ?? this.subject,
      grade: grade ?? this.grade,
      examType: examType ?? this.examType,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      totalScore: totalScore ?? this.totalScore,
      schoolYear: schoolYear ?? this.schoolYear,
      semester: semester ?? this.semester,
      lessonProjectId: lessonProjectId ?? this.lessonProjectId,
      headerConfig: headerConfig ?? this.headerConfig,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'subject': subject,
        'grade': grade,
        'exam_type': examType.name,
        'duration_minutes': durationMinutes,
        'total_score': totalScore,
        'school_year': schoolYear,
        'semester': semester,
        'lesson_project_id': lessonProjectId,
        'header_config': headerConfig.toMap(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory AssessmentProjectData.fromMap(Map<String, dynamic> map) {
    return AssessmentProjectData(
      id: (map['id'] as String?) ?? '',
      name: (map['name'] as String?) ?? 'Đề kiểm tra mới',
      subject: (map['subject'] as String?) ?? 'Ngữ văn',
      grade: (map['grade'] as String?) ?? '9',
      examType: ExamType.fromString(map['exam_type'] as String?),
      durationMinutes: (map['duration_minutes'] as num?)?.toInt() ?? 45,
      totalScore: (map['total_score'] as num?)?.toDouble() ?? 10.0,
      schoolYear: (map['school_year'] as String?) ?? '2026 - 2027',
      semester: (map['semester'] as String?) ?? 'Học kỳ I',
      lessonProjectId: map['lesson_project_id'] as String?,
      headerConfig: map['header_config'] is Map<String, dynamic>
          ? ExamHeaderConfig.fromMap(map['header_config'] as Map<String, dynamic>)
          : const ExamHeaderConfig(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory AssessmentProjectData.fromJson(String source) =>
      AssessmentProjectData.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
