import 'dart:convert';

/// Domain model for teaching project data (GDPT 2018 / CV 5512).
class LessonProjectData {
  final String subject;
  final String grade;
  final String bookSeries;
  final String lessonTitle;
  final String duration;
  final String learningObjectives;
  final String requirements;
  final String referenceMaterial;
  final String notes;

  const LessonProjectData({
    this.subject = 'Ngữ văn',
    this.grade = '9',
    this.bookSeries = 'Kết nối tri thức với cuộc sống',
    this.lessonTitle = '',
    this.duration = '2 tiết (90 phút)',
    this.learningObjectives = '',
    this.requirements = '',
    this.referenceMaterial = '',
    this.notes = '',
  });

  LessonProjectData copyWith({
    String? subject,
    String? grade,
    String? bookSeries,
    String? lessonTitle,
    String? duration,
    String? learningObjectives,
    String? requirements,
    String? referenceMaterial,
    String? notes,
  }) {
    return LessonProjectData(
      subject: subject ?? this.subject,
      grade: grade ?? this.grade,
      bookSeries: bookSeries ?? this.bookSeries,
      lessonTitle: lessonTitle ?? this.lessonTitle,
      duration: duration ?? this.duration,
      learningObjectives: learningObjectives ?? this.learningObjectives,
      requirements: requirements ?? this.requirements,
      referenceMaterial: referenceMaterial ?? this.referenceMaterial,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'subject': subject,
      'grade': grade,
      'bookSeries': bookSeries,
      'lessonTitle': lessonTitle,
      'duration': duration,
      'learningObjectives': learningObjectives,
      'requirements': requirements,
      'referenceMaterial': referenceMaterial,
      'notes': notes,
    };
  }

  factory LessonProjectData.fromMap(Map<String, dynamic> map) {
    return LessonProjectData(
      subject: (map['subject'] as String?) ?? 'Ngữ văn',
      grade: (map['grade'] as String?) ?? '9',
      bookSeries: (map['bookSeries'] as String?) ?? 'Kết nối tri thức với cuộc sống',
      lessonTitle: (map['lessonTitle'] as String?) ?? '',
      duration: (map['duration'] as String?) ?? '2 tiết (90 phút)',
      learningObjectives: (map['learningObjectives'] as String?) ?? '',
      requirements: (map['requirements'] as String?) ?? '',
      referenceMaterial: (map['referenceMaterial'] as String?) ?? '',
      notes: (map['notes'] as String?) ?? '',
    );
  }

  String toJson() => jsonEncode(toMap());

  factory LessonProjectData.fromJson(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is Map<String, dynamic>) {
        return LessonProjectData.fromMap(decoded);
      }
      return const LessonProjectData();
    } catch (_) {
      return const LessonProjectData();
    }
  }
}
