import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/features/teaching_suite/domain/models/lesson_project_data.dart';
import 'package:nguyendu_tool/features/teaching_suite/domain/models/worksheet_models.dart';
import 'support/fake_ai_text_generation_service.dart';

void main() {
  group('Teaching Suite - Worksheet Generator Tests', () {
    late FakeAiTextGenerationService fakeAi;
    const sampleProject = LessonProjectData(
      subject: 'Ngữ văn',
      grade: '9',
      bookSeries: 'Kết nối tri thức với cuộc sống',
      lessonTitle: 'Truyện Kiều – Đoạn trích Chị em Thúy Kiều',
      duration: '2 tiết (90 phút)',
    );

  setUp(() {
    fakeAi = FakeAiTextGenerationService();
  });

  test('Generates structured worksheet with tasks and metadata using fake provider', () async {
    final worksheet = await fakeAi.generateWorksheet(
      project: sampleProject,
      preset: WorksheetPreset.luyenTap,
      taskCount: 3,
    );

    expect(worksheet.title, contains('Truyện Kiều'));
    expect(worksheet.preset, equals(WorksheetPreset.luyenTap));
    expect(worksheet.tasks.length, equals(3));
    expect(worksheet.durationMinutes, equals(15));
    expect(worksheet.teacherNotes, isNotNull);

    // Verify tasks
    final task1 = worksheet.tasks[0];
    expect(task1.taskType, equals(WorksheetTaskType.fillBlank));
    expect(task1.content, contains('Làn thu thủy'));
    expect(task1.hint, isNotNull);
  });

  test('WorksheetModel serializes to and deserializes from JSON without loss', () {
    final ws = WorksheetModel(
      id: 'ws_test_999',
      title: 'Phiếu học tập môn Hóa',
      subject: 'Hóa học',
      grade: '10',
      preset: WorksheetPreset.nangCao,
      durationMinutes: 20,
      tasks: const [
        WorksheetTask(
          id: 't_1',
          instruction: 'Viết phương trình ion thu gọn',
          content: 'Phản ứng giữa Ba(OH)2 và H2SO4',
          points: 3,
        ),
      ],
      teacherNotes: 'Chú ý hiện tượng tạo kết tủa trắng',
    );

    final jsonStr = ws.toJson();
    final restored = WorksheetModel.fromJson(jsonStr);

    expect(restored.id, equals('ws_test_999'));
    expect(restored.preset, equals(WorksheetPreset.nangCao));
    expect(restored.tasks.length, equals(1));
    expect(restored.tasks.first.points, equals(3));
    expect(restored.teacherNotes, equals('Chú ý hiện tượng tạo kết tủa trắng'));
  });

  test('All Worksheet presets have valid labels and descriptions', () {
    for (final preset in WorksheetPreset.values) {
      expect(preset.label.isNotEmpty, isTrue);
      expect(preset.description.isNotEmpty, isTrue);
    }
  });
});
}
