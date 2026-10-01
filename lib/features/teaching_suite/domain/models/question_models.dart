import 'dart:convert';

/// Question formats supported in the Teaching Suite.
enum QuestionType {
  multipleChoice('Trắc nghiệm 4 lựa chọn (MCQ)'),
  trueFalse('Đúng / Sai'),
  shortAnswer('Trả lời ngắn / Điền khuyết'),
  essay('Tự luận');

  final String label;
  const QuestionType(this.label);

  static QuestionType fromString(String? value) {
    if (value == null) return QuestionType.multipleChoice;
    return QuestionType.values.firstWhere(
      (e) => e.name == value || e.label == value,
      orElse: () => QuestionType.multipleChoice,
    );
  }
}

/// Educational cognitive difficulty levels (GDPT 2018).
enum QuestionDifficulty {
  nhanBiet('Nhận biết', 1),
  thongHieu('Thông hiểu', 2),
  vanDung('Vận dụng', 3),
  vanDungCao('Vận dụng cao', 4);

  final String label;
  final int level;
  const QuestionDifficulty(this.label, this.level);

  static QuestionDifficulty fromString(String? value) {
    if (value == null) return QuestionDifficulty.nhanBiet;
    return QuestionDifficulty.values.firstWhere(
      (e) => e.name == value || e.label == value,
      orElse: () => QuestionDifficulty.nhanBiet,
    );
  }
}

/// A structured question item.
class QuestionItem {
  final String id;
  final String? setId;
  final QuestionType type;
  final String prompt;
  final List<String> choices;
  final String correctAnswer;
  final String? explanation;
  final QuestionDifficulty difficulty;
  final String? learningObjective;
  final int orderIndex;
  final List<String> tags;

  const QuestionItem({
    required this.id,
    this.setId,
    this.type = QuestionType.multipleChoice,
    required this.prompt,
    this.choices = const [],
    required this.correctAnswer,
    this.explanation,
    this.difficulty = QuestionDifficulty.nhanBiet,
    this.learningObjective,
    this.orderIndex = 0,
    this.tags = const [],
  });

  /// Validates standard 4-choice MCQ question integrity:
  /// must have exactly 4 non-empty, distinct choices and correct answer must match a choice.
  bool get isValidMcq {
    if (type != QuestionType.multipleChoice) return true;
    if (choices.length != 4) return false;
    if (choices.any((c) => c.trim().isEmpty)) return false;
    final distinctSet = choices.map((c) => c.trim().toLowerCase()).toSet();
    if (distinctSet.length != 4) return false;
    final normalized = correctAnswer.trim().toUpperCase();
    if (normalized == 'A' || normalized == 'B' || normalized == 'C' || normalized == 'D') {
      return true;
    }
    // Check if correctAnswer matches exact content of one of the choices
    return choices.any((c) => c.trim().toLowerCase() == correctAnswer.trim().toLowerCase());
  }

  QuestionItem copyWith({
    String? id,
    String? setId,
    QuestionType? type,
    String? prompt,
    List<String>? choices,
    String? correctAnswer,
    String? explanation,
    QuestionDifficulty? difficulty,
    String? learningObjective,
    int? orderIndex,
    List<String>? tags,
  }) {
    return QuestionItem(
      id: id ?? this.id,
      setId: setId ?? this.setId,
      type: type ?? this.type,
      prompt: prompt ?? this.prompt,
      choices: choices ?? this.choices,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      explanation: explanation ?? this.explanation,
      difficulty: difficulty ?? this.difficulty,
      learningObjective: learningObjective ?? this.learningObjective,
      orderIndex: orderIndex ?? this.orderIndex,
      tags: tags ?? this.tags,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'setId': setId,
        'type': type.name,
        'prompt': prompt,
        'choices': choices,
        'correctAnswer': correctAnswer,
        'explanation': explanation,
        'difficulty': difficulty.name,
        'learningObjective': learningObjective,
        'orderIndex': orderIndex,
        'tags': tags,
      };

  factory QuestionItem.fromMap(Map<String, dynamic> map) {
    List<String> parsedChoices = [];
    if (map['choices'] is List) {
      parsedChoices = (map['choices'] as List).map((e) => e.toString()).toList();
    } else if (map['choices_json'] is String) {
      try {
        final decoded = jsonDecode(map['choices_json'] as String);
        if (decoded is List) {
          parsedChoices = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }

    List<String> parsedTags = [];
    if (map['tags'] is List) {
      parsedTags = (map['tags'] as List).map((e) => e.toString()).toList();
    } else if (map['metadata_json'] is String) {
      try {
        final decoded = jsonDecode(map['metadata_json'] as String);
        if (decoded is Map && decoded['tags'] is List) {
          parsedTags = (decoded['tags'] as List).map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }

    return QuestionItem(
      id: (map['id'] as String?) ?? 'q_${DateTime.now().millisecondsSinceEpoch}',
      setId: (map['setId'] ?? map['set_id']) as String?,
      type: QuestionType.fromString(map['type'] as String?),
      prompt: (map['prompt'] as String?) ?? '',
      choices: parsedChoices,
      correctAnswer: (map['correctAnswer'] ?? map['correct_answer'] ?? '') as String,
      explanation: (map['explanation'] as String?),
      difficulty: QuestionDifficulty.fromString(map['difficulty'] as String?),
      learningObjective: (map['learningObjective'] ?? map['objective_id']) as String?,
      orderIndex: (map['orderIndex'] ?? map['order_index'] as num?)?.toInt() ?? 0,
      tags: parsedTags,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory QuestionItem.fromJson(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is Map<String, dynamic>) {
        return QuestionItem.fromMap(decoded);
      }
      return QuestionItem(id: 'q_${DateTime.now().millisecondsSinceEpoch}', prompt: '', correctAnswer: '');
    } catch (_) {
      return QuestionItem(id: 'q_${DateTime.now().millisecondsSinceEpoch}', prompt: '', correctAnswer: '');
    }
  }
}

/// A collection of questions attached to a workspace project.
class QuestionSet {
  final String id;
  final String projectId;
  final String title;
  final String subject;
  final String grade;
  final List<QuestionItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  QuestionSet({
    required this.id,
    required this.projectId,
    required this.title,
    this.subject = 'Ngữ văn',
    this.grade = '9',
    this.items = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  QuestionSet copyWith({
    String? id,
    String? projectId,
    String? title,
    String? subject,
    String? grade,
    List<QuestionItem>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return QuestionSet(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      grade: grade ?? this.grade,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'projectId': projectId,
        'title': title,
        'subject': subject,
        'grade': grade,
        'items': items.map((i) => i.toMap()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory QuestionSet.fromMap(Map<String, dynamic> map, {List<QuestionItem> items = const []}) {
    return QuestionSet(
      id: (map['id'] as String?) ?? 'qs_${DateTime.now().millisecondsSinceEpoch}',
      projectId: (map['projectId'] ?? map['project_id'] ?? '') as String,
      title: (map['title'] as String?) ?? '',
      subject: (map['subject'] as String?) ?? '',
      grade: (map['grade'] as String?) ?? '',
      items: items.isNotEmpty
          ? items
          : (map['items'] as List<dynamic>?)
                  ?.map((e) => QuestionItem.fromMap(e as Map<String, dynamic>))
                  .toList() ??
              const [],
      createdAt: map['created_at'] != null || map['createdAt'] != null
          ? DateTime.tryParse((map['created_at'] ?? map['createdAt']) as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updated_at'] != null || map['updatedAt'] != null
          ? DateTime.tryParse((map['updated_at'] ?? map['updatedAt']) as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String toJson() => jsonEncode(toMap());
}
