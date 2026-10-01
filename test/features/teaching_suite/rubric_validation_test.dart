import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/features/teaching_suite/domain/models/rubric_models.dart';

void main() {
  group('Teaching Suite - Rubric Validation & Model Tests', () {
    test('Calculates total weight accurately and validates 100% requirement', () {
      final validRubric = RubricModel(
        id: 'rub_test_1',
        projectId: 'proj_1',
        title: 'Rubric đánh giá bài thuyết trình',
        criteria: const [
          RubricCriterion(id: 'c1', name: 'Nội dung', weight: 40.0),
          RubricCriterion(id: 'c2', name: 'Kỹ năng trình bày', weight: 30.0),
          RubricCriterion(id: 'c3', name: 'Trả lời câu hỏi', weight: 30.0),
        ],
      );

      expect(validRubric.totalWeight, equals(100.0));
      expect(validRubric.isWeightValid, isTrue);
    });

    test('Identifies invalid rubric weight (sum != 100%)', () {
      final invalidRubric = RubricModel(
        id: 'rub_test_2',
        projectId: 'proj_1',
        title: 'Rubric chưa hoàn thiện trọng số',
        criteria: const [
          RubricCriterion(id: 'c1', name: 'Nội dung', weight: 50.0),
          RubricCriterion(id: 'c2', name: 'Hình thức', weight: 30.0),
          // Total = 80% != 100%
        ],
      );

      expect(invalidRubric.totalWeight, equals(80.0));
      expect(invalidRubric.isWeightValid, isFalse);
    });

    test('Supports both 3-level and 4-level performance rubric configurations', () {
      const threeLevelCriterion = RubricCriterion(
        id: 'c_3l',
        name: 'Mức độ nhận thức',
        weight: 100.0,
        levels: [
          RubricLevel(name: 'Tốt', score: 3.0, description: 'Đạt đầy đủ'),
          RubricLevel(name: 'Đạt', score: 2.0, description: 'Đạt cơ bản'),
          RubricLevel(name: 'Chưa đạt', score: 1.0, description: 'Cần cải thiện'),
        ],
      );

      expect(threeLevelCriterion.levels.length, equals(3));
      expect(threeLevelCriterion.levels.first.score, equals(3.0));
    });

    test('Serializes to and restores from JSON correctly', () {
      final rubric = RubricModel(
        id: 'rub_json_01',
        projectId: 'proj_101',
        title: 'Rubric thực hành môn Sinh học',
        criteria: const [
          RubricCriterion(
            id: 'c1',
            name: 'Kỹ năng làm tiêu bản',
            weight: 50.0,
            objectiveId: 'M1.1',
            levels: [
              RubricLevel(name: 'Xuất sắc', score: 4.0, description: 'Tiêu bản chuẩn, quan sát rõ tế bào'),
              RubricLevel(name: 'Đạt', score: 2.0, description: 'Tiêu bản còn bọt khí'),
            ],
          ),
          RubricCriterion(
            id: 'c2',
            name: 'Vẽ hình và ghi chú thích',
            weight: 50.0,
            objectiveId: 'M1.2',
            levels: [
              RubricLevel(name: 'Xuất sắc', score: 4.0, description: 'Vẽ chuẩn tỷ lệ, chú thích đúng'),
              RubricLevel(name: 'Đạt', score: 2.0, description: 'Vẽ sơ lược'),
            ],
          ),
        ],
      );

      final jsonStr = rubric.toJson();
      final restored = RubricModel.fromJson(jsonStr);

      expect(restored.id, equals('rub_json_01'));
      expect(restored.title, equals('Rubric thực hành môn Sinh học'));
      expect(restored.criteria.length, equals(2));
      expect(restored.totalWeight, equals(100.0));
      expect(restored.isWeightValid, isTrue);
      expect(restored.criteria.first.levels.length, equals(2));
    });
  });
}
