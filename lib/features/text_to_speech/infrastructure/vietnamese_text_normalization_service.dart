import '../domain/services/text_normalization_service.dart';

/// Conservative Vietnamese text normalization service for speech synthesis.
/// Carefully normalizes dates, times, percentages, abbreviations, and punctuation
/// without changing the core meaning or structure of educational documents.
class VietnameseTextNormalizationService implements TextNormalizationService {
  const VietnameseTextNormalizationService();

  @override
  String normalize(String rawText, {String language = 'vi-VN'}) {
    if (rawText.trim().isEmpty) return '';

    var text = rawText;

    // 1. Whitespace & Line breaks normalization
    text = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    text = text.replaceAll(RegExp(r'[ \t]+'), ' '); // Collapse horizontal whitespace
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n'); // Max 2 consecutive newlines

    // 2. Smart quotes, typography & dashes
    text = text
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('‘', "'")
        .replaceAll('’', "'")
        .replaceAll('«', '"')
        .replaceAll('»', '"')
        .replaceAll('…', '...')
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('―', '-');

    // 3. Dates: 15/09/2026 -> ngày 15 tháng 9 năm 2026
    text = text.replaceAllMapped(
      RegExp(r'(?:\bngày\s+)?\b(\d{1,2})/(\d{1,2})/(\d{4})\b', caseSensitive: false),
      (m) {
        final day = int.parse(m.group(1)!);
        final month = int.parse(m.group(2)!);
        final year = m.group(3)!;
        if (day >= 1 && day <= 31 && month >= 1 && month <= 12) {
          return 'ngày $day tháng $month năm $year';
        }
        return m.group(0)!;
      },
    );

    // Month/Year: 09/2026 -> tháng 9 năm 2026
    text = text.replaceAllMapped(
      RegExp(r'(?<!\d/)tháng\s*(\d{1,2})/(\d{4})\b', caseSensitive: false),
      (m) {
        final month = int.parse(m.group(1)!);
        final year = m.group(2)!;
        if (month >= 1 && month <= 12) {
          return 'tháng $month năm $year';
        }
        return m.group(0)!;
      },
    );

    // 4. Times: 12:30 -> 12 giờ 30 phút
    text = text.replaceAllMapped(
      RegExp(r'\b(\d{1,2}):(\d{2})\b'),
      (m) {
        final hours = int.parse(m.group(1)!);
        final mins = int.parse(m.group(2)!);
        if (hours >= 0 && hours <= 23 && mins >= 0 && mins <= 59) {
          if (mins == 0) {
            return '$hours giờ';
          }
          return '$hours giờ $mins phút';
        }
        return m.group(0)!;
      },
    );

    // 5. Percentages: 10% -> 10 phần trăm, 99.5% -> 99 phẩy 5 phần trăm
    text = text.replaceAllMapped(
      RegExp(r'(\d+)(?:[.,](\d+))?\s*%'),
      (m) {
        final whole = m.group(1)!;
        final frac = m.group(2);
        if (frac != null) {
          return '$whole phẩy $frac phần trăm';
        }
        return '$whole phần trăm';
      },
    );

    // 6. Decimals: 3.14 or 3,14 -> 3 phẩy 14 (when isolated between digits)
    text = text.replaceAllMapped(
      RegExp(r'(?<=\d)[,](?=\d{1,4}\b)'),
      (m) => ' phẩy ',
    );

    // 7. Common Educational and Administrative Abbreviations in Vietnam
    text = text
        .replaceAll(RegExp(r'\bTP\.HCM\b', caseSensitive: false), 'thành phố Hồ Chí Minh')
        .replaceAll(RegExp(r'\bTp\.HCM\b'), 'thành phố Hồ Chí Minh')
        .replaceAll(RegExp(r'\bTP\.\s*Hồ Chí Minh\b', caseSensitive: false), 'thành phố Hồ Chí Minh')
        .replaceAll(RegExp(r'\bTP\.\s*Hà Nội\b', caseSensitive: false), 'thành phố Hà Nội')
        .replaceAll(RegExp(r'\bTP\.\s*Đà Nẵng\b', caseSensitive: false), 'thành phố Đà Nẵng')
        .replaceAll(RegExp(r'\bGD&ĐT\b', caseSensitive: false), 'Giáo dục và Đào tạo')
        .replaceAll(RegExp(r'\bGD-ĐT\b', caseSensitive: false), 'Giáo dục và Đào tạo')
        .replaceAll(RegExp(r'\bTHCS\b'), 'Trung học cơ sở')
        .replaceAll(RegExp(r'\bTHPT\b'), 'Trung học phổ thông')
        .replaceAll(RegExp(r'\bUBND\b'), 'Ủy ban nhân dân')
        .replaceAll(RegExp(r'\bHĐND\b'), 'Hội đồng nhân dân')
        .replaceAll(RegExp(r'\bCNTT\b'), 'Công nghệ thông tin')
        .replaceAll(RegExp(r'\bNXB\b'), 'Nhà xuất bản')
        .replaceAll(RegExp(r'\bGS\.\s*'), 'Giáo sư ')
        .replaceAll(RegExp(r'\bPGS\.\s*'), 'Phó Giáo sư ')
        .replaceAll(RegExp(r'\bTS\.\s*'), 'Tiến sĩ ')
        .replaceAll(RegExp(r'\bThS\.\s*'), 'Thạc sĩ ')
        .replaceAll(RegExp(r'\bBS\.\s*'), 'Bác sĩ ');

    // 8. Currency: 50.000 VNĐ / 50000 đ
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:[.,]\d+)*)\s*(?:vnđ|vnd|đ|Đ)(?![a-zA-Z\u00C0-\u024F\u1EA0-\u1EF9])', caseSensitive: false),
      (m) => '${m.group(1)} đồng',
    );


    // 9. Roman numerals in curriculum sections: "Bài I", "Phần II", "Tiết III", "Lớp IV"
    text = text.replaceAllMapped(
      RegExp(r'\b(Bài|Phần|Mục|Tiết|Chương|Lớp|Kỳ)\s+(XII|XI|X|IX|VIII|VII|VI|V|IV|III|II|I)\b'),
      (m) {
        final prefix = m.group(1)!;
        final roman = m.group(2)!;
        final val = _romanToInt(roman);
        return '$prefix $val';
      },
    );

    // 10. Clean up extra punctuation spacing
    text = text
        .replaceAllMapped(RegExp(r'\s+([,.:;?!])'), (m) => m.group(1)!)
        .replaceAllMapped(RegExp(r'([,.:;?!])(?=[^\s\d])'), (m) => '${m.group(1)} ');

    return text.trim();
  }

  @override
  List<TextSegmentWithPause> parsePauseMarkers(String text) {
    if (text.isEmpty) return const [];

    final segments = <TextSegmentWithPause>[];
    final markerRegex = RegExp(r'\[(?:pause|nghỉ)\s+(\d+)\s*(?:ms|s)?\]', caseSensitive: false);

    var lastIndex = 0;
    for (final match in markerRegex.allMatches(text)) {
      final precedingText = text.substring(lastIndex, match.start).trim();
      final numStr = match.group(1)!;
      var pauseMs = int.tryParse(numStr) ?? 500;
      if (match.group(0)!.contains('s') && !match.group(0)!.contains('ms')) {
        pauseMs *= 1000;
      }

      if (precedingText.isNotEmpty) {
        segments.add(TextSegmentWithPause(text: precedingText, pauseMs: pauseMs));
      } else if (segments.isNotEmpty) {
        // Append pause to previous segment
        final prev = segments.removeLast();
        segments.add(TextSegmentWithPause(text: prev.text, pauseMs: prev.pauseMs + pauseMs));
      }

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      final remaining = text.substring(lastIndex).trim();
      if (remaining.isNotEmpty) {
        segments.add(TextSegmentWithPause(text: remaining, pauseMs: 0));
      }
    }

    return segments.isEmpty ? [TextSegmentWithPause(text: text, pauseMs: 0)] : segments;
  }

  static int _romanToInt(String roman) {
    switch (roman) {
      case 'I':
        return 1;
      case 'II':
        return 2;
      case 'III':
        return 3;
      case 'IV':
        return 4;
      case 'V':
        return 5;
      case 'VI':
        return 6;
      case 'VII':
        return 7;
      case 'VIII':
        return 8;
      case 'IX':
        return 9;
      case 'X':
        return 10;
      case 'XI':
        return 11;
      case 'XII':
        return 12;
      default:
        return 1;
    }
  }
}
