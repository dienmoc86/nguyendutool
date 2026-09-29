import '../domain/models/tts_chunk.dart';
import '../domain/services/text_chunker.dart';

/// Intelligent rule-based text chunker.
/// Splits long documents into coherent chunks respecting paragraph, sentence, and phrase boundaries
/// without splitting inside numbers, dates, times, abbreviations, or quoted expressions.
class RuleBasedTextChunker implements TextChunker {
  const RuleBasedTextChunker();

  @override
  List<TtsChunk> chunkText({
    required String text,
    required String jobId,
    int maxCharactersPerChunk = 1500,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const [];

    // Ensure sensible bounds
    final limit = maxCharactersPerChunk.clamp(10, 10000);

    // If whole text fits within limit and has no paragraph breaks, return a single chunk
    if (trimmed.length <= limit && !trimmed.contains('\n\n')) {
      return [
        TtsChunk(
          id: '${jobId}_chunk_0',
          jobId: jobId,
          index: 0,
          text: trimmed,
          characterCount: trimmed.length,
          isParagraphBoundary: true,
        ),
      ];
    }

    final rawChunks = <_ChunkPiece>[];
    final paragraphs = trimmed.split(RegExp(r'\n{2,}'));

    for (int pIdx = 0; pIdx < paragraphs.length; pIdx++) {
      final para = paragraphs[pIdx].trim();
      if (para.isEmpty) continue;

      if (para.length <= limit) {
        rawChunks.add(_ChunkPiece(text: para, isParagraphBoundary: true));
      } else {
        // Paragraph exceeds limit: split into sentences
        final sentences = _splitIntoSentences(para);
        final subBuffer = StringBuffer();

        for (int sIdx = 0; sIdx < sentences.length; sIdx++) {
          final sentence = sentences[sIdx].trim();
          if (sentence.isEmpty) continue;

          // Check if adding this sentence exceeds limit
          final currentLen = subBuffer.length;
          final additionLen = (currentLen > 0 ? 1 : 0) + sentence.length;

          if (currentLen + additionLen <= limit) {
            if (currentLen > 0) subBuffer.write(' ');
            subBuffer.write(sentence);
          } else {
            // Flush current buffer if non-empty
            if (subBuffer.isNotEmpty) {
              rawChunks.add(_ChunkPiece(text: subBuffer.toString().trim(), isParagraphBoundary: false));
              subBuffer.clear();
            }

            // If a single sentence itself exceeds limit, split by clauses or words safely
            if (sentence.length > limit) {
              final clauses = _splitSentenceIntoClauses(sentence, limit);
              for (int cIdx = 0; cIdx < clauses.length; cIdx++) {
                final isEnd = (cIdx == clauses.length - 1) && (sIdx == sentences.length - 1);
                rawChunks.add(_ChunkPiece(text: clauses[cIdx], isParagraphBoundary: isEnd));
              }
            } else {
              subBuffer.write(sentence);
            }
          }
        }

        if (subBuffer.isNotEmpty) {
          rawChunks.add(_ChunkPiece(text: subBuffer.toString().trim(), isParagraphBoundary: true));
        }
      }
    }

    // Secondary pass: Combine adjacent small chunks if they together fit nicely under limit
    final mergedPieces = _mergeSmallPieces(rawChunks, limit);

    // Build final TtsChunk list with stable indices
    final result = <TtsChunk>[];
    for (int i = 0; i < mergedPieces.length; i++) {
      final piece = mergedPieces[i];
      result.add(
        TtsChunk(
          id: '${jobId}_chunk_$i',
          jobId: jobId,
          index: i,
          text: piece.text,
          characterCount: piece.text.length,
          isParagraphBoundary: piece.isParagraphBoundary,
        ),
      );
    }

    return result;
  }

  /// Splits paragraph text into sentences preserving abbreviations, numbers, and quotation marks.
  List<String> _splitIntoSentences(String paragraph) {
    final sentences = <String>[];
    // Regex matches sentence-ending punctuation followed by whitespace and a capital letter or quote
    // Negative lookbehind protects common abbreviations like TS., ThS., GS., PGS., BS., TP., v.v.
    final pattern = RegExp(
      r'(?<!\b(?:TS|ThS|GS|PGS|BS|TP|TX|TT|NXB|v\.v|e\.g|i\.e|No|vol))\s*([.?!;]+)(?=\s+["A-ZÀ-Ỹ0-9]|$)',
      caseSensitive: false,
    );

    var lastIndex = 0;
    for (final match in pattern.allMatches(paragraph)) {
      final end = match.end;
      final sentence = paragraph.substring(lastIndex, end).trim();
      if (sentence.isNotEmpty) {
        sentences.add(sentence);
      }
      lastIndex = end;
    }

    if (lastIndex < paragraph.length) {
      final rem = paragraph.substring(lastIndex).trim();
      if (rem.isNotEmpty) {
        sentences.add(rem);
      }
    }

    return sentences.isEmpty ? [paragraph] : sentences;
  }

  /// Splits an overly long sentence by natural clause separators (, / : / -) or words.
  List<String> _splitSentenceIntoClauses(String sentence, int maxLimit) {
    final clauses = <String>[];
    final parts = sentence.split(RegExp(r'(?<=[,:\-\)\]])\s+'));
    final buffer = StringBuffer();

    for (final part in parts) {
      final candidate = buffer.isEmpty ? part : '${buffer.toString()} $part';
      if (candidate.length <= maxLimit) {
        if (buffer.isNotEmpty) buffer.write(' ');
        buffer.write(part);
      } else {
        if (buffer.isNotEmpty) {
          clauses.add(buffer.toString().trim());
          buffer.clear();
        }
        if (part.length > maxLimit) {
          // Hard word split fallback
          final words = part.split(' ');
          for (final word in words) {
            final wCandidate = buffer.isEmpty ? word : '${buffer.toString()} $word';
            if (wCandidate.length <= maxLimit) {
              if (buffer.isNotEmpty) buffer.write(' ');
              buffer.write(word);
            } else {
              if (buffer.isNotEmpty) {
                clauses.add(buffer.toString().trim());
                buffer.clear();
              }
              buffer.write(word);
            }
          }
        } else {
          buffer.write(part);
        }
      }
    }

    if (buffer.isNotEmpty) {
      clauses.add(buffer.toString().trim());
    }

    return clauses.isEmpty ? [sentence] : clauses;
  }

  /// Merges contiguous tiny chunks that belong to the same paragraph to minimize audio fragmentation.
  List<_ChunkPiece> _mergeSmallPieces(List<_ChunkPiece> pieces, int limit) {
    if (pieces.length <= 1) return pieces;

    final merged = <_ChunkPiece>[];
    var currentText = '';
    var isCurrentPara = false;

    for (final piece in pieces) {
      if (currentText.isEmpty) {
        currentText = piece.text;
        isCurrentPara = piece.isParagraphBoundary;
        continue;
      }

      // If previous piece was a paragraph boundary, do not merge across paragraphs unless very small
      if (isCurrentPara) {
        merged.add(_ChunkPiece(text: currentText, isParagraphBoundary: true));
        currentText = piece.text;
        isCurrentPara = piece.isParagraphBoundary;
        continue;
      }

      final combined = '$currentText ${piece.text}';
      if (combined.length <= limit) {
        currentText = combined;
        isCurrentPara = piece.isParagraphBoundary;
      } else {
        merged.add(_ChunkPiece(text: currentText, isParagraphBoundary: isCurrentPara));
        currentText = piece.text;
        isCurrentPara = piece.isParagraphBoundary;
      }
    }

    if (currentText.isNotEmpty) {
      merged.add(_ChunkPiece(text: currentText, isParagraphBoundary: isCurrentPara));
    }

    return merged;
  }
}

class _ChunkPiece {
  final String text;
  final bool isParagraphBoundary;
  const _ChunkPiece({required this.text, required this.isParagraphBoundary});
}
