import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/logging/app_logger.dart';
import '../data/teaching_suite_repository.dart';
import '../domain/models/mini_assessment_model.dart';
import '../domain/models/question_models.dart';

class TeachingSuiteQuestionsState {
  final List<QuestionSet> allSets;
  final QuestionSet? activeSet;
  final bool isLoading;
  final String? errorMessage;
  final QuestionDifficulty? filterDifficulty;
  final QuestionType? filterType;

  const TeachingSuiteQuestionsState({
    this.allSets = const [],
    this.activeSet,
    this.isLoading = false,
    this.errorMessage,
    this.filterDifficulty,
    this.filterType,
  });

  TeachingSuiteQuestionsState copyWith({
    List<QuestionSet>? allSets,
    QuestionSet? activeSet,
    bool? isLoading,
    String? errorMessage,
    QuestionDifficulty? filterDifficulty,
    QuestionType? filterType,
    bool clearActiveSet = false,
  }) {
    return TeachingSuiteQuestionsState(
      allSets: allSets ?? this.allSets,
      activeSet: clearActiveSet ? null : (activeSet ?? this.activeSet),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      filterDifficulty: filterDifficulty ?? this.filterDifficulty,
      filterType: filterType ?? this.filterType,
    );
  }
}

class TeachingSuiteQuestionsNotifier extends StateNotifier<TeachingSuiteQuestionsState> {
  final TeachingSuiteRepository _repository;
  static const _uuid = Uuid();

  TeachingSuiteQuestionsNotifier(this._repository)
      : super(const TeachingSuiteQuestionsState());

  /// Loads question sets for a project from SQLite.
  Future<void> loadForProject(
    String projectId, {
    String defaultTitle = 'Bộ câu hỏi bài học',
    String subject = 'Ngữ văn',
    String grade = '9',
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final sets = await _repository.getQuestionSetsForProject(projectId);
      if (sets.isNotEmpty) {
        state = state.copyWith(allSets: sets, activeSet: sets.first, isLoading: false);
      } else {
        // Create initial default set
        final newSet = QuestionSet(
          id: 'qs_${_uuid.v4()}',
          projectId: projectId,
          title: defaultTitle,
          subject: subject,
          grade: grade,
        );
        await _repository.saveQuestionSet(newSet);
        state = state.copyWith(allSets: [newSet], activeSet: newSet, isLoading: false);
      }
    } catch (e, st) {
      AppLogger.error('Lỗi tải danh sách bộ câu hỏi: $e', e, st);
      state = state.copyWith(isLoading: false, errorMessage: 'Không thể tải câu hỏi: $e');
    }
  }

  /// Appends questions into active set and persists.
  Future<void> addQuestions(
    List<QuestionItem> newItems, {
    String? projectId,
    String? subject,
    String? grade,
  }) async {
    final effectiveProjectId = (projectId != null && projectId.isNotEmpty)
        ? projectId
        : state.activeSet?.projectId;

    if (effectiveProjectId == null || effectiveProjectId.isEmpty) {
      throw ArgumentError('Không thể thêm câu hỏi khi chưa chọn hoặc tạo dự án bài dạy.');
    }

    QuestionSet current = state.activeSet ??
        QuestionSet(
          id: 'qs_${_uuid.v4()}',
          projectId: effectiveProjectId,
          title: 'Ngân hàng câu hỏi bài học',
          subject: subject ?? 'Ngữ văn',
          grade: grade ?? '9',
        );

    final updatedItems = List<QuestionItem>.from(current.items);
    int startIndex = updatedItems.length;

    for (final item in newItems) {
      updatedItems.add(item.copyWith(
        id: item.id.isNotEmpty ? item.id : 'q_${_uuid.v4()}',
        setId: current.id,
        orderIndex: startIndex++,
      ));
    }

    final updatedSet = current.copyWith(
      items: updatedItems,
      updatedAt: DateTime.now(),
    );

    try {
      await _repository.saveQuestionSet(updatedSet);
    } catch (e) {
      AppLogger.warning('Không thể lưu QuestionSet vào DB: $e');
    }
    final exists = state.allSets.any((s) => s.id == updatedSet.id);
    final updatedAll = exists
        ? state.allSets.map((s) => s.id == updatedSet.id ? updatedSet : s).toList()
        : [...state.allSets, updatedSet];
    state = state.copyWith(activeSet: updatedSet, allSets: updatedAll);
  }

  /// Updates a single question item in active set.
  Future<void> updateQuestion(QuestionItem updated) async {
    final current = state.activeSet;
    if (current == null) return;

    final updatedItems = current.items.map((q) => q.id == updated.id ? updated : q).toList();
    final updatedSet = current.copyWith(items: updatedItems, updatedAt: DateTime.now());

    await _repository.saveQuestionSet(updatedSet);
    final updatedAll = state.allSets.map((s) => s.id == updatedSet.id ? updatedSet : s).toList();
    state = state.copyWith(activeSet: updatedSet, allSets: updatedAll);
  }

  /// Deletes a question item from active set.
  Future<void> deleteQuestion(String questionId) async {
    final current = state.activeSet;
    if (current == null) return;

    final updatedItems = current.items.where((q) => q.id != questionId).toList();
    final updatedSet = current.copyWith(items: updatedItems, updatedAt: DateTime.now());

    await _repository.saveQuestionSet(updatedSet);
    final updatedAll = state.allSets.map((s) => s.id == updatedSet.id ? updatedSet : s).toList();
    state = state.copyWith(activeSet: updatedSet, allSets: updatedAll);
  }

  /// Duplicates a question item.
  Future<void> duplicateQuestion(String questionId) async {
    final current = state.activeSet;
    if (current == null) return;

    final index = current.items.indexWhere((q) => q.id == questionId);
    if (index == -1) return;

    final original = current.items[index];
    final copy = original.copyWith(
      id: 'q_${_uuid.v4()}',
      prompt: '${original.prompt} (Bản sao)',
    );

    final updatedItems = List<QuestionItem>.from(current.items);
    updatedItems.insert(index + 1, copy);

    final updatedSet = current.copyWith(items: updatedItems, updatedAt: DateTime.now());
    await _repository.saveQuestionSet(updatedSet);
    final updatedAll = state.allSets.map((s) => s.id == updatedSet.id ? updatedSet : s).toList();
    state = state.copyWith(activeSet: updatedSet, allSets: updatedAll);
  }

  /// Reorders questions in the active set.
  Future<void> reorderQuestions(int oldIndex, int newIndex) async {
    final current = state.activeSet;
    if (current == null) return;

    final items = List<QuestionItem>.from(current.items);
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);

    for (int i = 0; i < items.length; i++) {
      items[i] = items[i].copyWith(orderIndex: i);
    }

    final updatedSet = current.copyWith(items: items, updatedAt: DateTime.now());
    await _repository.saveQuestionSet(updatedSet);
    final updatedAll = state.allSets.map((s) => s.id == updatedSet.id ? updatedSet : s).toList();
    state = state.copyWith(activeSet: updatedSet, allSets: updatedAll);
  }

  /// Builds and persists a deterministic mini assessment from active set questions.
  Future<MiniAssessment?> buildMiniAssessment(MiniAssessmentConfig config) async {
    final current = state.activeSet;
    if (current == null || current.items.isEmpty) return null;

    var filtered = current.items.where((q) {
      final matchesType = config.allowedTypes.contains(q.type);
      final matchesDiff = config.allowedDifficulties.contains(q.difficulty);
      return matchesType && matchesDiff;
    }).toList();

    if (config.shuffleQuestions) {
      filtered.shuffle();
    }

    final selected = filtered.take(config.totalQuestions).toList();
    if (selected.isEmpty) return null;

    final assessment = MiniAssessment(
      id: 'ma_${_uuid.v4()}',
      projectId: current.projectId,
      sourceQuestionSetId: current.id,
      title: config.title,
      durationMinutes: config.durationMinutes,
      questions: selected,
    );

    // Persist to SQLite table mini_assessments & mini_assessment_items
    try {
      await _repository.saveMiniAssessment(assessment);
    } catch (e) {
      AppLogger.warning('Lỗi lưu MiniAssessment vào DB: $e');
    }

    return assessment;
  }

  /// Sets active question set by ID.
  void selectSet(String setId) {
    final found = state.allSets.firstWhere((s) => s.id == setId, orElse: () => state.activeSet!);
    state = state.copyWith(activeSet: found);
  }

  /// Sets difficulty filter.
  void setDifficultyFilter(QuestionDifficulty? diff) {
    state = state.copyWith(filterDifficulty: diff);
  }

  /// Sets type filter.
  void setTypeFilter(QuestionType? type) {
    state = state.copyWith(filterType: type);
  }
}
