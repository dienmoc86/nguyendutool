import 'dart:convert';

/// Represents a single activity within the CV 5512 lesson plan.
class LessonPlanActivity {
  final String title;
  final String objective;
  final String content;
  final String product;
  final String implementation;

  const LessonPlanActivity({
    required this.title,
    this.objective = '',
    this.content = '',
    this.product = '',
    this.implementation = '',
  });

  LessonPlanActivity copyWith({
    String? title,
    String? objective,
    String? content,
    String? product,
    String? implementation,
  }) {
    return LessonPlanActivity(
      title: title ?? this.title,
      objective: objective ?? this.objective,
      content: content ?? this.content,
      product: product ?? this.product,
      implementation: implementation ?? this.implementation,
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'objective': objective,
        'content': content,
        'product': product,
        'implementation': implementation,
      };

  factory LessonPlanActivity.fromMap(Map<String, dynamic> map) => LessonPlanActivity(
        title: (map['title'] as String?) ?? '',
        objective: (map['objective'] as String?) ?? '',
        content: (map['content'] as String?) ?? '',
        product: (map['product'] as String?) ?? '',
        implementation: (map['implementation'] as String?) ?? '',
      );
}

/// Structured document model for a lesson plan (Công văn 5512/BGDĐT).
class LessonPlanDocument {
  final String title;
  final String subject;
  final String grade;
  final String duration;
  final String bookSeries;
  final String objectives; // I. MỤC TIÊU (Kiến thức, Năng lực, Phẩm chất)
  final String equipment; // II. THIẾT BỊ DẠY HỌC VÀ HỌC LIỆU
  final List<LessonPlanActivity> activities; // III. TIẾN TRÌNH DẠY HỌC
  final String assessment; // IV. HỒ SƠ DẠY HỌC / ĐÁNH GIÁ
  final String appendices; // Phụ lục
  final String rawContent; // Full markdown content for editing and rendering
  final DateTime? lastModified;

  const LessonPlanDocument({
    this.title = '',
    this.subject = '',
    this.grade = '',
    this.duration = '',
    this.bookSeries = '',
    this.objectives = '',
    this.equipment = '',
    this.activities = const [],
    this.assessment = '',
    this.appendices = '',
    this.rawContent = '',
    this.lastModified,
  });

  LessonPlanDocument copyWith({
    String? title,
    String? subject,
    String? grade,
    String? duration,
    String? bookSeries,
    String? objectives,
    String? equipment,
    List<LessonPlanActivity>? activities,
    String? assessment,
    String? appendices,
    String? rawContent,
    DateTime? lastModified,
  }) {
    return LessonPlanDocument(
      title: title ?? this.title,
      subject: subject ?? this.subject,
      grade: grade ?? this.grade,
      duration: duration ?? this.duration,
      bookSeries: bookSeries ?? this.bookSeries,
      objectives: objectives ?? this.objectives,
      equipment: equipment ?? this.equipment,
      activities: activities ?? this.activities,
      assessment: assessment ?? this.assessment,
      appendices: appendices ?? this.appendices,
      rawContent: rawContent ?? this.rawContent,
      lastModified: lastModified ?? this.lastModified,
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'subject': subject,
        'grade': grade,
        'duration': duration,
        'bookSeries': bookSeries,
        'objectives': objectives,
        'equipment': equipment,
        'activities': activities.map((a) => a.toMap()).toList(),
        'assessment': assessment,
        'appendices': appendices,
        'rawContent': rawContent,
        'lastModified': lastModified?.toIso8601String(),
      };

  factory LessonPlanDocument.fromMap(Map<String, dynamic> map) => LessonPlanDocument(
        title: (map['title'] as String?) ?? '',
        subject: (map['subject'] as String?) ?? '',
        grade: (map['grade'] as String?) ?? '',
        duration: (map['duration'] as String?) ?? '',
        bookSeries: (map['bookSeries'] as String?) ?? '',
        objectives: (map['objectives'] as String?) ?? '',
        equipment: (map['equipment'] as String?) ?? '',
        activities: (map['activities'] as List<dynamic>?)
                ?.map((e) => LessonPlanActivity.fromMap(e as Map<String, dynamic>))
                .toList() ??
            const [],
        assessment: (map['assessment'] as String?) ?? '',
        appendices: (map['appendices'] as String?) ?? '',
        rawContent: (map['rawContent'] as String?) ?? '',
        lastModified: map['lastModified'] != null
            ? DateTime.tryParse(map['lastModified'] as String)
            : null,
      );

  String toJson() => jsonEncode(toMap());

  factory LessonPlanDocument.fromJson(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is Map<String, dynamic>) {
        return LessonPlanDocument.fromMap(decoded);
      }
      return const LessonPlanDocument();
    } catch (_) {
      return const LessonPlanDocument();
    }
  }

  /// Parses markdown text into structured LessonPlanDocument sections without losing text.
  factory LessonPlanDocument.parseFromMarkdown({
    required String title,
    required String subject,
    required String grade,
    required String duration,
    required String bookSeries,
    required String markdown,
  }) {
    String objectives = '';
    String equipment = '';
    String assessment = '';
    String appendices = '';
    final List<LessonPlanActivity> activities = [];

    // Simple robust regex parsing for major 5512 sections
    final objMatch = RegExp(r'(?:I\.|#\s*I\.|MỤC TIÊU)([\s\S]*?)(?=(?:II\.|#\s*II\.|THIẾT BỊ|$))', caseSensitive: false).firstMatch(markdown);
    if (objMatch != null) {
      objectives = objMatch.group(1)?.trim() ?? '';
    }

    final eqMatch = RegExp(r'(?:II\.|#\s*II\.|THIẾT BỊ)([\s\S]*?)(?=(?:III\.|#\s*III\.|TIẾN TRÌNH|$))', caseSensitive: false).firstMatch(markdown);
    if (eqMatch != null) {
      equipment = eqMatch.group(1)?.trim() ?? '';
    }

    final assMatch = RegExp(r'(?:IV\.|#\s*IV\.|ĐÁNH GIÁ|HỒ SƠ)([\s\S]*?)(?=(?:V\.|#\s*V\.|PHỤ LỤC|$))', caseSensitive: false).firstMatch(markdown);
    if (assMatch != null) {
      assessment = assMatch.group(1)?.trim() ?? '';
    }

    final appMatch = RegExp(r'(?:V\.|#\s*V\.|PHỤ LỤC)([\s\S]*)$', caseSensitive: false).firstMatch(markdown);
    if (appMatch != null) {
      appendices = appMatch.group(1)?.trim() ?? '';
    }

    // Parse activities (Hoạt động 1, 2, 3, 4)
    final actMatches = RegExp(r'(Hoạt động \d+[^:\n]*[:\n][\s\S]*?)(?=(?:Hoạt động \d+|IV\.|#\s*IV\.|V\.|#\s*V\.|$))', caseSensitive: false).allMatches(markdown);
    for (final m in actMatches) {
      final actText = m.group(1)?.trim() ?? '';
      if (actText.isNotEmpty) {
        final firstLine = actText.split('\n').first.replaceAll(RegExp(r'^[#*]+'), '').trim();
        activities.add(LessonPlanActivity(
          title: firstLine,
          content: actText,
        ));
      }
    }

    return LessonPlanDocument(
      title: title,
      subject: subject,
      grade: grade,
      duration: duration,
      bookSeries: bookSeries,
      objectives: objectives,
      equipment: equipment,
      activities: activities,
      assessment: assessment,
      appendices: appendices,
      rawContent: markdown,
      lastModified: DateTime.now(),
    );
  }

  /// Creates a standard default 5512 lesson plan template.
  factory LessonPlanDocument.createDefault5512({
    required String topic,
    String grade = '9',
    String subject = 'Ngữ văn',
    String duration = '2 tiết (90 phút)',
    String bookSeries = 'Kết nối tri thức',
  }) {
    return LessonPlanDocument(
      title: 'Kế hoạch bài dạy: $topic',
      subject: subject,
      grade: grade,
      duration: duration,
      bookSeries: bookSeries,
      objectives: '1. Về kiến thức: Giúp học sinh nắm vững nội dung bài học $topic.\n2. Về năng lực: Phát triển năng lực ngôn ngữ và tư duy.\n3. Về phẩm chất: Bồi dưỡng phẩm chất chăm chỉ, trách nhiệm.',
      equipment: '1. Giáo viên: SGK, bài giảng số, phiếu học tập.\n2. Học sinh: SGK, vở ghi bài.',
      activities: [
        LessonPlanActivity(
          title: 'Hoạt động 1: Khởi động',
          objective: 'Tạo tâm thế tích cực cho học sinh.',
          content: 'GV đặt câu hỏi gợi mở liên quan đến chủ đề $topic.',
          product: 'Câu trả lời của học sinh.',
          implementation: 'Giao nhiệm vụ -> Học sinh thực hiện -> Báo cáo thảo luận.',
        ),
        LessonPlanActivity(
          title: 'Hoạt động 2: Hình thành kiến thức',
          objective: 'Khám phá nội dung trọng tâm bài học.',
          content: 'Đọc hiểu và khai thác các khía cạnh chủ đề $topic.',
          product: 'Kết quả làm việc cá nhân / nhóm trên phiếu học tập.',
          implementation: 'Tổ chức thảo luận nhóm và giáo viên tổng kết.',
        ),
      ],
      assessment: 'Đánh giá qua quá trình tham gia hoạt động và kết quả bài tập.',
      appendices: 'Phiếu học tập và thang đo rubric đi kèm.',
      rawContent: '# KẾ HOẠCH BÀI DẠY: $topic',
      lastModified: DateTime.now(),
    );
  }
}
