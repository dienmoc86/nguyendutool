import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/logging/app_logger.dart';
import '../data/teaching_suite_repository.dart';
import '../domain/models/worksheet_models.dart';

class TeachingSuiteWorksheetState {
  final WorksheetModel? worksheet;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;

  const TeachingSuiteWorksheetState({
    this.worksheet,
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
  });

  TeachingSuiteWorksheetState copyWith({
    WorksheetModel? worksheet,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    bool clearWorksheet = false,
  }) {
    return TeachingSuiteWorksheetState(
      worksheet: clearWorksheet ? null : (worksheet ?? this.worksheet),
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class TeachingSuiteWorksheetNotifier extends StateNotifier<TeachingSuiteWorksheetState> {
  final TeachingSuiteRepository _repository;
  static const _uuid = Uuid();
  Timer? _debounceSaveTimer;

  TeachingSuiteWorksheetNotifier(this._repository)
      : super(const TeachingSuiteWorksheetState());

  @override
  void dispose() {
    _debounceSaveTimer?.cancel();
    super.dispose();
  }

  /// Loads worksheet for a project from SQLite persistence.
  Future<void> loadForProject(
    String projectId, {
    String defaultTitle = 'Phiếu học tập bài học',
    String subject = 'Ngữ văn',
    String grade = '9',
    WorksheetPreset preset = WorksheetPreset.luyenTap,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final existing = await _repository.getWorksheetForProject(projectId);
      if (existing != null) {
        state = state.copyWith(worksheet: existing, isLoading: false);
      } else {
        // Create initial default template worksheet
        final defaultWs = WorksheetModel(
          id: 'ws_${_uuid.v4()}',
          projectId: projectId,
          title: '$defaultTitle (Template mặc định)',
          subject: subject,
          grade: grade,
          preset: preset,
          durationMinutes: 15,
          tasks: [
            WorksheetTask(
              id: 'task_${_uuid.v4()}',
              instruction: 'Khởi động / Tìm hiểu bài học',
              content: 'Nêu các luận điểm và chi tiết tiêu biểu trong bài học.',
              taskType: WorksheetTaskType.shortAnswer,
              points: 2,
              orderIndex: 0,
            ),
          ],
        );
        await _repository.saveWorksheet(projectId, defaultWs);
        state = state.copyWith(worksheet: defaultWs, isLoading: false);
      }
    } catch (e, st) {
      AppLogger.error('Lỗi tải phiếu học tập dự án: $e', e, st);
      state = state.copyWith(isLoading: false, errorMessage: 'Không thể tải phiếu học tập: $e');
    }
  }

  /// Updates or replaces the whole worksheet and persists.
  Future<void> setWorksheet(WorksheetModel ws) async {
    state = state.copyWith(worksheet: ws);
    final pId = ws.projectId;
    if (pId != null && pId.isNotEmpty) {
      await _repository.saveWorksheet(pId, ws);
    }
  }

  /// Adds a new task to the worksheet and persists.
  Future<void> addTask(WorksheetTask task) async {
    final current = state.worksheet;
    if (current == null) return;

    final updatedTasks = List<WorksheetTask>.from(current.tasks);
    final newTask = task.copyWith(
      worksheetId: current.id,
      orderIndex: updatedTasks.length,
    );
    updatedTasks.add(newTask);

    final updatedWs = current.copyWith(
      tasks: updatedTasks,
      updatedAt: DateTime.now(),
    );
    state = state.copyWith(worksheet: updatedWs);

    final pId = current.projectId;
    if (pId != null && pId.isNotEmpty) {
      await _repository.saveWorksheet(pId, updatedWs);
    }
  }

  /// Updates an existing task by ID and persists.
  Future<void> updateTask(WorksheetTask updatedTask) async {
    final current = state.worksheet;
    if (current == null) return;

    final updatedTasks = current.tasks.map((t) {
      return t.id == updatedTask.id ? updatedTask : t;
    }).toList();

    final updatedWs = current.copyWith(
      tasks: updatedTasks,
      updatedAt: DateTime.now(),
    );
    state = state.copyWith(worksheet: updatedWs);

    _debounceSaveTimer?.cancel();
    _debounceSaveTimer = Timer(const Duration(milliseconds: 600), () async {
      final pId = current.projectId;
      if (pId != null && pId.isNotEmpty) {
        await _repository.saveWorksheet(pId, updatedWs);
      }
    });
  }

  /// Deletes a task by ID, re-indexes remaining tasks, and persists.
  Future<void> deleteTask(String taskId) async {
    final current = state.worksheet;
    if (current == null) return;

    final updatedTasks = current.tasks.where((t) => t.id != taskId).toList();
    for (int i = 0; i < updatedTasks.length; i++) {
      updatedTasks[i] = updatedTasks[i].copyWith(orderIndex: i);
    }

    final updatedWs = current.copyWith(
      tasks: updatedTasks,
      updatedAt: DateTime.now(),
    );
    state = state.copyWith(worksheet: updatedWs);

    final pId = current.projectId;
    if (pId != null && pId.isNotEmpty) {
      await _repository.saveWorksheet(pId, updatedWs);
    }
  }

  /// Reorders tasks (drag and drop) and persists.
  Future<void> reorderTasks(int oldIndex, int newIndex) async {
    final current = state.worksheet;
    if (current == null) return;

    final updatedTasks = List<WorksheetTask>.from(current.tasks);
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = updatedTasks.removeAt(oldIndex);
    updatedTasks.insert(newIndex, item);

    for (int i = 0; i < updatedTasks.length; i++) {
      updatedTasks[i] = updatedTasks[i].copyWith(orderIndex: i);
    }

    final updatedWs = current.copyWith(
      tasks: updatedTasks,
      updatedAt: DateTime.now(),
    );
    state = state.copyWith(worksheet: updatedWs);

    final pId = current.projectId;
    if (pId != null && pId.isNotEmpty) {
      await _repository.saveWorksheet(pId, updatedWs);
    }
  }

  /// Updates title or preset metadata.
  Future<void> updateMetadata({
    String? title,
    WorksheetPreset? preset,
    int? durationMinutes,
    String? teacherNotes,
  }) async {
    final current = state.worksheet;
    if (current == null) return;

    final updatedWs = current.copyWith(
      title: title ?? current.title,
      preset: preset ?? current.preset,
      durationMinutes: durationMinutes ?? current.durationMinutes,
      teacherNotes: teacherNotes ?? current.teacherNotes,
      updatedAt: DateTime.now(),
    );
    state = state.copyWith(worksheet: updatedWs);

    final pId = current.projectId;
    if (pId != null && pId.isNotEmpty) {
      await _repository.saveWorksheet(pId, updatedWs);
    }
  }
}
