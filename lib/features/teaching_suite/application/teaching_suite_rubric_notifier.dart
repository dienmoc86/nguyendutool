import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/logging/app_logger.dart';
import '../data/teaching_suite_repository.dart';
import '../domain/models/rubric_models.dart';

class TeachingSuiteRubricState {
  final RubricModel? activeRubric;
  final List<RubricModel> allRubrics;
  final bool isLoading;
  final String? errorMessage;

  const TeachingSuiteRubricState({
    this.activeRubric,
    this.allRubrics = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  TeachingSuiteRubricState copyWith({
    RubricModel? activeRubric,
    List<RubricModel>? allRubrics,
    bool? isLoading,
    String? errorMessage,
  }) {
    return TeachingSuiteRubricState(
      activeRubric: activeRubric ?? this.activeRubric,
      allRubrics: allRubrics ?? this.allRubrics,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class TeachingSuiteRubricNotifier extends StateNotifier<TeachingSuiteRubricState> {
  final TeachingSuiteRepository _repository;

  TeachingSuiteRubricNotifier(this._repository)
      : super(const TeachingSuiteRubricState());

  /// Loads rubrics for a project.
  Future<void> loadForProject(String projectId, {String defaultTitle = 'Rubric đánh giá bài học'}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final rubrics = await _repository.getRubricsForProject(projectId);
      if (rubrics.isNotEmpty) {
        state = state.copyWith(allRubrics: rubrics, activeRubric: rubrics.first, isLoading: false);
      } else {
        final newRubric = RubricModel(
          id: 'rub_${DateTime.now().millisecondsSinceEpoch}',
          projectId: projectId,
          title: '$defaultTitle (Template mặc định)',
          criteria: const [
            RubricCriterion(
              id: 'c1',
              name: 'Nội dung và kiến thức trọng tâm',
              weight: 40.0,
              levels: [
                RubricLevel(name: 'Xuất sắc', score: 4.0, description: 'Nắm vững kiến thức toàn diện, phân tích sâu.'),
                RubricLevel(name: 'Tốt', score: 3.0, description: 'Nắm vững các ý chính, diễn đạt rõ ràng.'),
                RubricLevel(name: 'Đạt', score: 2.0, description: 'Nhớ được nội dung cơ bản nhưng còn sơ lược.'),
                RubricLevel(name: 'Cần cố gắng', score: 1.0, description: 'Chưa đạt yêu cầu kiến thức tối thiểu.'),
              ],
            ),
            RubricCriterion(
              id: 'c2',
              name: 'Kỹ năng vận dụng và liên hệ thực tế',
              weight: 30.0,
              levels: [
                RubricLevel(name: 'Xuất sắc', score: 4.0, description: 'Liên hệ sáng tạo, phong phú.'),
                RubricLevel(name: 'Tốt', score: 3.0, description: 'Có ví dụ minh họa phù hợp.'),
                RubricLevel(name: 'Đạt', score: 2.0, description: 'Liên hệ còn gượng ép.'),
                RubricLevel(name: 'Cần cố gắng', score: 1.0, description: 'Chưa có liên hệ.'),
              ],
            ),
            RubricCriterion(
              id: 'c3',
              name: 'Hình thức trình bày và thái độ học tập',
              weight: 30.0,
              levels: [
                RubricLevel(name: 'Xuất sắc', score: 4.0, description: 'Trình bày khoa học, đẹp mắt, tích cực.'),
                RubricLevel(name: 'Tốt', score: 3.0, description: 'Bố cục sạch sẽ, chăm chỉ.'),
                RubricLevel(name: 'Đạt', score: 2.0, description: 'Trình bày còn lộn xộn.'),
                RubricLevel(name: 'Cần cố gắng', score: 1.0, description: 'Cẩu thả, thiếu ý thức.'),
              ],
            ),
          ],
        );

        await _repository.saveRubric(newRubric);
        state = state.copyWith(allRubrics: [newRubric], activeRubric: newRubric, isLoading: false);
      }
    } catch (e, st) {
      AppLogger.error('Lỗi tải Rubric: $e', e, st);
      state = state.copyWith(isLoading: false, errorMessage: 'Không thể tải Rubric: $e');
    }
  }

  /// Sets or updates the active rubric.
  Future<void> setRubric(RubricModel rubric) async {
    await _repository.saveRubric(rubric);
    final updatedAll = state.allRubrics.map((r) => r.id == rubric.id ? rubric : r).toList();
    if (!updatedAll.any((r) => r.id == rubric.id)) {
      updatedAll.add(rubric);
    }
    state = state.copyWith(activeRubric: rubric, allRubrics: updatedAll);
  }

  /// Updates a single criterion in the active rubric.
  Future<void> updateCriterion(RubricCriterion updatedCriterion) async {
    final current = state.activeRubric;
    if (current == null) return;

    final updatedCriteria = current.criteria.map((c) => c.id == updatedCriterion.id ? updatedCriterion : c).toList();
    final updatedRubric = current.copyWith(criteria: updatedCriteria, updatedAt: DateTime.now());
    await setRubric(updatedRubric);
  }

  /// Adds a new criterion to active rubric.
  Future<void> addCriterion(RubricCriterion criterion) async {
    final current = state.activeRubric;
    if (current == null) return;

    final updatedCriteria = List<RubricCriterion>.from(current.criteria)..add(criterion);
    final updatedRubric = current.copyWith(criteria: updatedCriteria, updatedAt: DateTime.now());
    await setRubric(updatedRubric);
  }

  /// Deletes a criterion from active rubric.
  Future<void> deleteCriterion(String criterionId) async {
    final current = state.activeRubric;
    if (current == null) return;

    final updatedCriteria = current.criteria.where((c) => c.id != criterionId).toList();
    final updatedRubric = current.copyWith(criteria: updatedCriteria, updatedAt: DateTime.now());
    await setRubric(updatedRubric);
  }
}
