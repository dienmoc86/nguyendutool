import 'dart:convert';

/// Worksheet preset categories.
enum WorksheetPreset {
  coBan('Cơ bản', 'Phù hợp củng cố kiến thức nền tảng và kiểm tra mức độ nhận biết'),
  luyenTap('Luyện tập', 'Tập trung rèn luyện kỹ năng và giải quyết bài tập thông hiểu'),
  nangCao('Nâng cao', 'Định hướng phát triển tư duy, vận dụng và liên hệ thực tiễn'),
  nhom('Hoạt động nhóm', 'Thiết kế bài tập thảo luận, phối hợp nhóm và thuyết trình'),
  onTap('Ôn tập', 'Hệ thống hóa toàn bộ kiến thức trọng tâm của bài học');

  final String label;
  final String description;
  const WorksheetPreset(this.label, this.description);

  static WorksheetPreset fromString(String? value) {
    if (value == null) return WorksheetPreset.luyenTap;
    return WorksheetPreset.values.firstWhere(
      (e) => e.name == value || e.label == value,
      orElse: () => WorksheetPreset.luyenTap,
    );
  }
}

/// Task type within a worksheet.
enum WorksheetTaskType {
  fillBlank('Điền vào chỗ trống'),
  shortAnswer('Trả lời ngắn'),
  matching('Nối cột / Ghép đôi'),
  discussion('Thảo luận câu hỏi'),
  practice('Bài tập thực hành');

  final String label;
  const WorksheetTaskType(this.label);

  static WorksheetTaskType fromString(String? value) {
    if (value == null) return WorksheetTaskType.shortAnswer;
    return WorksheetTaskType.values.firstWhere(
      (e) => e.name == value || e.label == value,
      orElse: () => WorksheetTaskType.shortAnswer,
    );
  }
}

/// A single task / exercise inside a worksheet.
class WorksheetTask {
  final String id;
  final String? worksheetId;
  final String instruction;
  final String content;
  final String? hint;
  final WorksheetTaskType taskType;
  final double points;
  final int orderIndex;

  String? get answerHint => hint;

  const WorksheetTask({
    required this.id,
    this.worksheetId,
    required this.instruction,
    this.content = '',
    this.hint,
    this.taskType = WorksheetTaskType.shortAnswer,
    this.points = 1.0,
    this.orderIndex = 0,
  });

  WorksheetTask copyWith({
    String? id,
    String? worksheetId,
    String? instruction,
    String? content,
    String? hint,
    WorksheetTaskType? taskType,
    double? points,
    int? orderIndex,
  }) {
    return WorksheetTask(
      id: id ?? this.id,
      worksheetId: worksheetId ?? this.worksheetId,
      instruction: instruction ?? this.instruction,
      content: content ?? this.content,
      hint: hint ?? this.hint,
      taskType: taskType ?? this.taskType,
      points: points ?? this.points,
      orderIndex: orderIndex ?? this.orderIndex,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'worksheet_id': worksheetId,
        'instruction': instruction,
        'content': content,
        'task_type': taskType.name,
        'points': points,
        'order_index': orderIndex,
        'answer_hint': hint,
      };

  factory WorksheetTask.fromMap(Map<String, dynamic> map) => WorksheetTask(
        id: (map['id'] as String?) ?? 'task_${DateTime.now().millisecondsSinceEpoch}',
        worksheetId: map['worksheet_id'] as String?,
        instruction: (map['instruction'] as String?) ?? '',
        content: (map['content'] as String?) ?? '',
        hint: (map['answer_hint'] ?? map['hint']) as String?,
        taskType: WorksheetTaskType.fromString((map['task_type'] ?? map['taskType']) as String?),
        points: (map['points'] as num?)?.toDouble() ?? 1.0,
        orderIndex: (map['order_index'] as num?)?.toInt() ?? 0,
      );
}

/// Model for a complete worksheet.
class WorksheetModel {
  final String id;
  final String? projectId;
  final String title;
  final String subject;
  final String grade;
  final WorksheetPreset preset;
  final int durationMinutes;
  final List<WorksheetTask> tasks;
  final String? teacherNotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  WorksheetModel({
    required this.id,
    this.projectId,
    required this.title,
    this.subject = 'Ngữ văn',
    this.grade = '9',
    dynamic preset = WorksheetPreset.luyenTap,
    this.durationMinutes = 15,
    this.tasks = const [],
    this.teacherNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : preset = preset is WorksheetPreset
            ? preset
            : (preset is String ? WorksheetPreset.fromString(preset) : WorksheetPreset.luyenTap),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  WorksheetModel copyWith({
    String? id,
    String? projectId,
    String? title,
    String? subject,
    String? grade,
    dynamic preset,
    int? durationMinutes,
    List<WorksheetTask>? tasks,
    String? teacherNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WorksheetModel(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      grade: grade ?? this.grade,
      preset: preset != null
          ? (preset is WorksheetPreset ? preset : WorksheetPreset.fromString(preset.toString()))
          : this.preset,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      tasks: tasks ?? this.tasks,
      teacherNotes: teacherNotes ?? this.teacherNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'project_id': projectId,
        'title': title,
        'subject': subject,
        'grade': grade,
        'preset': preset.name,
        'durationMinutes': durationMinutes,
        'duration': durationMinutes,
        'tasks': tasks.map((t) => t.toMap()).toList(),
        'teacher_notes': teacherNotes,
        'teacherNotes': teacherNotes,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory WorksheetModel.fromMap(Map<String, dynamic> map, {List<WorksheetTask>? tasks}) => WorksheetModel(
        id: (map['id'] as String?) ?? 'ws_${DateTime.now().millisecondsSinceEpoch}',
        projectId: map['project_id'] as String?,
        title: (map['title'] as String?) ?? '',
        subject: (map['subject'] as String?) ?? '',
        grade: (map['grade'] as String?) ?? '',
        preset: WorksheetPreset.fromString(map['preset'] as String?),
        durationMinutes: ((map['duration'] ?? map['durationMinutes']) as num?)?.toInt() ?? 15,
        tasks: tasks ??
            ((map['tasks'] as List<dynamic>?)
                ?.map((e) => WorksheetTask.fromMap(e as Map<String, dynamic>))
                .toList() ??
                const []),
        teacherNotes: (map['teacher_notes'] ?? map['teacherNotes']) as String?,
        createdAt: map['created_at'] != null
            ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
            : (map['createdAt'] != null ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now() : DateTime.now()),
        updatedAt: map['updated_at'] != null
            ? DateTime.tryParse(map['updated_at'] as String) ?? DateTime.now()
            : DateTime.now(),
      );

  String toJson() => jsonEncode(toMap());

  factory WorksheetModel.fromJson(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is Map<String, dynamic>) {
        return WorksheetModel.fromMap(decoded);
      }
      return WorksheetModel(
        id: 'ws_${DateTime.now().millisecondsSinceEpoch}',
        title: '',
        subject: '',
        grade: '',
      );
    } catch (_) {
      return WorksheetModel(
        id: 'ws_${DateTime.now().millisecondsSinceEpoch}',
        title: '',
        subject: '',
        grade: '',
      );
    }
  }
}
