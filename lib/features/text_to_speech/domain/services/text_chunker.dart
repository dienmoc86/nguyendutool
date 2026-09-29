import '../models/tts_chunk.dart';

/// Contract for text chunking service for splitting large documents into synthesizable chunks.
abstract class TextChunker {
  /// Splits [text] into ordered [TtsChunk] list respecting [maxCharactersPerChunk].
  /// Preserves sentence and paragraph boundaries without splitting inside numbers, abbreviations, or quotes.
  List<TtsChunk> chunkText({
    required String text,
    required String jobId,
    int maxCharactersPerChunk = 1500,
  });
}
