/// Rule-based post-processor for OCR text normalization.
/// Preserves line breaks, paragraph structure, and punctuation without inventing words or fake accents.
class VietnameseOcrPostProcessor {
  /// Cleans and normalizes OCR text while strictly preserving structural line breaks.
  static String processText(String rawText) {
    if (rawText.trim().isEmpty) return '';

    String text = rawText;

    // 1. Normalize line endings to \n
    text = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    // 2. Fix broken hyphenated words at line wraps (e.g. "nghiên-\n cứu" -> "nghiên cứu")
    text = text.replaceAllMapped(
      RegExp(r'(\w+)-\s*\n(\s*)(\w+)', unicode: true),
      (match) {
        final w1 = match.group(1)!;
        final hasSpaceAfter = match.group(2)!.isNotEmpty;
        final w2 = match.group(3)!;
        return hasSpaceAfter ? '$w1 $w2' : '$w1$w2';
      },
    );

    // 3. Fix spaced capital headers (e.g. "C Ộ N G  H Ò A  X Ã  H Ộ I" -> "CỘNG HÒA XÃ HỘI")
    text = _mergeSpacedCapitals(text);

    // 4. Fix safe OCR typos & Vietnamese ambiguous glyphs from vie.DangAmbigs
    text = _fixAmbiguousGlyphs(text);
    text = _fixCommonTypos(text);

    // 5. Fix standard Vietnamese administrative legal formulas & titles
    text = _fixAdministrativeFormulas(text);

    // 6. Fix dates and numbers
    text = _fixDatesAndNumbers(text);

    // 7. Clean whitespace per line without collapsing paragraphs into one line
    text = _normalizeWhitespaceAndPreserveLines(text);

    return text;
  }

  /// Fixes spaced out capital headings like "K I Ể M  T R A" -> "KIỂM TRA".
  static String _mergeSpacedCapitals(String input) {
    final pattern = RegExp(r'\b([A-ZÀ-Ỹ]\s+){2,}[A-ZÀ-Ỹ]\b', unicode: true);
    return input.replaceAllMapped(pattern, (match) {
      final matched = match.group(0)!;
      final words = matched.split(RegExp(r'\s{2,}'));
      return words.map((w) => w.replaceAll(' ', '')).join(' ');
    });
  }

  /// Ambiguous glyph replacements aligned with VietOCR vie.DangAmbigs rules.
  static const Map<String, String> _dangAmbigsPlain = {
    'tmg': 'úng',
    'êĩ-': 'ết',
    'âỳ': 'ấy',
    'oĩ': 'ơi',
    'ôỈ': 'ỡi',
    'êf': 'ết',
    'vđi': 'với',
    'cũa': 'của',
    'phãi': 'phải',
    '—-': '—',
    '-—': '—',
    '––': '—',
    'Ð': 'Đ',
    'âÍ': 'ấ',
  };

  static String _fixAmbiguousGlyphs(String input) {
    String res = input;
    for (final entry in _dangAmbigsPlain.entries) {
      res = res.replaceAll(entry.key, entry.value);
    }
    return res;
  }

  /// Conservative dictionary of deterministic corrections for obvious OCR digit/glyph confusions.
  static final Map<RegExp, String> _safeTypos = {
    RegExp(r'\bQuyét định\b', unicode: true): 'Quyết định',
    RegExp(r'\bHiẹu trưởng\b', unicode: true): 'Hiệu trưởng',
    RegExp(r'\bTRƯÒNG\b', unicode: true): 'TRƯỜNG',
    RegExp(r'\bVIẸT NAM\b', unicode: true): 'VIỆT NAM',
    RegExp(r'\bGIÁO DUC\b', unicode: true): 'GIÁO DỤC',
    RegExp(r'\bKính gủi\b', unicode: true): 'Kính gửi',
  };

  static String _fixCommonTypos(String input) {
    String res = input;
    for (final entry in _safeTypos.entries) {
      res = res.replaceAll(entry.key, entry.value);
    }
    return res;
  }

  /// High-accuracy deterministic corrections for scanned Vietnamese administrative documents.
  static final Map<RegExp, String> _administrativeFormulas = {
    // 1. National header
    RegExp(
      r'\b(Céng|Cóng|Cộng)\s+(hda|hòa)\s+(xä|xã)\s+(héi|hội)\s+(chñ|chủ)\s+(nghïa|nghĩa)\s+(viét|việt)\s+(nam)\b',
      caseSensitive: false,
      unicode: true,
    ): 'CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM',

    // 2. National motto: e.g. "Dic lip - TY' do - Hqnh phúc" -> "Độc lập - Tự do - Hạnh phúc"
    RegExp(
      r'\b(Dic|Đic|Độc|Doc)\s+(lip|lâp|lập|lap)\s*[-–—]\s*(TY\x27?|Tjr|Tự|Tu)\s*do\s*[-–—]\s*(Hqnh|Hạnh|Hanh)\s+(phúc|phuc)\b',
      caseSensitive: false,
      unicode: true,
    ): 'Độc lập - Tự do - Hạnh phúc',

    // 3. People's Committee: "uy BAN NHAN DAN" -> "ỦY BAN NHÂN DÂN"
    RegExp(r'\b(uy|ùy|Uy|Ủy)\s+BAN\s+NHAN\s+DAN\b', unicode: true):
        'ỦY BAN NHÂN DÂN',
    RegExp(r'\b(uy|ùy|Uy|Ủy)\s+ban\s+nhân\s+dân\b', unicode: true):
        'Ủy ban nhân dân',

    // 4. Decision: "QUYET DINH" -> "QUYẾT ĐỊNH"
    RegExp(r'\b(QUYET\s+DINH|QUYÊT\s+ĐINH)\b', unicode: true):
        'QUYẾT ĐỊNH',

    // 5. Amendments: "sica dõi, bö simg" -> "sửa đổi, bổ sung"
    RegExp(r'\b(sica\s+dõi|sửa\s+đôi)\b', caseSensitive: false, unicode: true):
        'sửa đổi',
    RegExp(r'\b(bö\s+simg|bồ\s+sung|bô\s+sung)\b', caseSensitive: false, unicode: true):
        'bổ sung',

    // 6. Articles: "mét Sö diéu" -> "một số điều"
    RegExp(
      r'\b(mét\s+Sö\s+diéu|môt\s+sô\s+điêu|mét\s+số\s+điều)\b',
      caseSensitive: false,
      unicode: true,
    ): 'một số điều',

    // 7. Project approval: "Phö duyQt Do ản" -> "Phê duyệt Đồ án"
    RegExp(
      r'\b(Phö\s+duyQt|Phê\s+duyêt)\s+(Do\s+ản|Đô\s+án)\b',
      caseSensitive: false,
      unicode: true,
    ): 'Phê duyệt Đồ án',

    // 8. Legal basis: "CAN CU" -> "CĂN CỨ"
    RegExp(r'\b(CAN\s+CU|CÃN\s+CỨ)\b', unicode: true):
        'CĂN CỨ',

    // 9. Recommendation: "THEO DE NGHI" -> "THEO ĐỀ NGHỊ"
    RegExp(r'\b(THEO\s+DE\s+NGHI|THEO\s+ĐÊ\s+NGHI)\b', unicode: true):
        'THEO ĐỀ NGHỊ',
  };

  static String _fixAdministrativeFormulas(String input) {
    String res = input;
    for (final entry in _administrativeFormulas.entries) {
      res = res.replaceAll(entry.key, entry.value);
    }
    return res;
  }

  /// Fixes formatted date strings and numerical expressions.
  static String _fixDatesAndNumbers(String input) {
    String res = input;

    // "ngày  15  tháng  09  năm  2026" -> "ngày 15 tháng 09 năm 2026"
    res = res.replaceAllMapped(
      RegExp(r'ngày\s+(\d{1,2})\s+tháng\s+(\d{1,2})\s+năm\s+(\d{4})', caseSensitive: false),
      (m) => 'ngày ${m.group(1)} tháng ${m.group(2)} năm ${m.group(3)}',
    );

    // "15 / 09 / 2026" -> "15/09/2026"
    res = res.replaceAllMapped(
      RegExp(r'(\d{1,2})\s*/\s*(\d{1,2})\s*/\s*(\d{2,4})'),
      (m) => '${m.group(1)}/${m.group(2)}/${m.group(3)}',
    );

    // Number with isolated capital O instead of 0 in years e.g. "2O26" -> "2026"
    res = res.replaceAllMapped(
      RegExp(r'\b(19|20|[12])([O|o])(\d{1,2})\b'),
      (m) => '${m.group(1)}0${m.group(3)}',
    );

    return res;
  }

  /// Normalizes whitespace within each line while strictly preserving every line break.
  static String _normalizeWhitespaceAndPreserveLines(String input) {
    final lines = input.split('\n');
    final processedLines = <String>[];

    for (final line in lines) {
      final trimmed = line.replaceAll(RegExp(r'[ \t]+'), ' ').trim();
      processedLines.add(trimmed);
    }

    return processedLines.join('\n');
  }
}
