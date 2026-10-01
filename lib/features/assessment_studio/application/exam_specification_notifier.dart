import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/logging/app_logger.dart';
import '../data/assessment_repository.dart';
import '../domain/models/exam_specification.dart';
import 'assessment_project_notifier.dart';

class ExamSpecificationState {
  final ExamSpecification? specification;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;

  const ExamSpecificationState({
    this.specification,
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
  });

  ExamSpecificationState copyWith({
    ExamSpecification? specification,
    bool clearSpec = false,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
  }) {
    return ExamSpecificationState(
      specification: clearSpec ? null : (specification ?? this.specification),
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: errorMessage,
    );
  }
}

class ExamSpecificationNotifier extends StateNotifier<ExamSpecificationState> {
  final AssessmentRepository _repository;

  ExamSpecificationNotifier(this._repository) : super(const ExamSpecificationState());

  /// Loads specification for an assessment project, or creates default.
  Future<ExamSpecification> loadForProject({
    required String projectId,
    required String subject,
    required String grade,
    int durationMinutes = 45,
    double totalScore = 10.0,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      var spec = await _repository.getSpecification(projectId);
      if (spec == null) {
        spec = ExamSpecification(
          id: 'spec_$projectId',
          projectId: projectId,
          title: 'Đặc tả đề kiểm tra môn $subject lớp $grade',
          subject: subject,
          grade: grade,
          durationMinutes: durationMinutes,
          totalScore: totalScore,
          questionCount: 10,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await _repository.saveSpecification(spec);
      }

      state = state.copyWith(specification: spec, isLoading: false);
      return spec;
    } catch (e, st) {
      AppLogger.error('Failed to load specification for $projectId', e, st);
      state = state.copyWith(isLoading: false, errorMessage: 'Lỗi tải đặc tả: $e');
      rethrow;
    }
  }

  /// Updates and persists specification.
  Future<void> updateSpecification(ExamSpecification updated) async {
    state = state.copyWith(isSaving: true);
    try {
      final withTimestamp = updated.copyWith(updatedAt: DateTime.now());
      await _repository.saveSpecification(withTimestamp);
      state = state.copyWith(specification: withTimestamp, isSaving: false);
    } catch (e) {
      AppLogger.error('Failed to update specification: $e');
      state = state.copyWith(isSaving: false, errorMessage: 'Lỗi lưu đặc tả: $e');
    }
  }

  void reset() {
    state = const ExamSpecificationState();
  }
}

final examSpecificationNotifierProvider =
    StateNotifierProvider<ExamSpecificationNotifier, ExamSpecificationState>((ref) {
  final repo = ref.watch(assessmentRepositoryProvider);
  return ExamSpecificationNotifier(repo);
});
