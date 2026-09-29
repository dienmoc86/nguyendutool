import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_providers.dart';
import '../infrastructure/pronunciation_dictionary_service.dart';
import 'tts_notifier.dart';
import 'tts_service.dart';
import 'tts_state.dart';

/// Provider for PronunciationDictionaryService.
final pronunciationDictionaryServiceProvider = Provider<PronunciationDictionaryService>((ref) {
  final db = ref.watch(databaseProvider);
  return PronunciationDictionaryService(database: db);
});

/// Provider for TtsService.
final ttsServiceProvider = Provider<TtsService>((ref) {
  final db = ref.watch(databaseProvider);
  final jobRepo = ref.watch(jobRepositoryProvider);
  final fileRepo = ref.watch(fileRepositoryProvider);
  final pronunService = ref.watch(pronunciationDictionaryServiceProvider);

  return TtsService(
    database: db,
    jobRepository: jobRepo,
    fileRepository: fileRepo,
    pronunciationService: pronunService,
  );
});

/// StateNotifierProvider for TtsNotifier / TtsState.
final ttsStateProvider = StateNotifierProvider<TtsNotifier, TtsState>((ref) {
  final ttsService = ref.watch(ttsServiceProvider);
  final db = ref.watch(databaseProvider);

  return TtsNotifier(
    ttsService: ttsService,
    database: db,
  );
});
