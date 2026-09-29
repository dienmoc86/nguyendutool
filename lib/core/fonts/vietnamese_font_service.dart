import 'dart:io';
import '../logging/app_logger.dart';

/// Service providing Vietnamese legacy font encoding conversion (TCVN3/VNI -> Unicode)
/// and system educational font diagnostic checks.
class VietnameseFontService {
  // Mapping for TCVN3 (ABC / .VNTime) to Unicode
  static final Map<int, String> _tcvn3Map = {
    184: 'á', 181: 'à', 182: 'ả', 183: 'ã', 185: 'ạ',
    168: 'ă', 190: 'ắ', 187: 'ằ', 188: 'ẳ', 189: 'ẵ', 198: 'ặ',
    169: 'â', 202: 'ấ', 199: 'ầ', 200: 'ẩ', 201: 'ẫ', 203: 'ậ',
    208: 'é', 204: 'è', 206: 'ẻ', 207: 'ẽ', 209: 'ẹ',
    170: 'ê', 213: 'ế', 210: 'ề', 211: 'ể', 212: 'ễ', 214: 'ệ',
    221: 'í', 215: 'ì', 216: 'ỉ', 220: 'ĩ', 222: 'ị',
    227: 'ó', 223: 'ò', 225: 'ỏ', 226: 'õ', 228: 'ọ',
    171: 'ô', 233: 'ố', 229: 'ồ', 230: 'ổ', 231: 'ỗ', 234: 'ộ',
    172: 'ơ', 238: 'ớ', 235: 'ờ', 236: 'ở', 237: 'ỡ', 239: 'ợ',
    243: 'ú', 241: 'ù', 242: 'ủ', 244: 'ũ', 246: 'ụ',
    173: 'ư', 250: 'ứ', 247: 'ừ', 248: 'ử', 249: 'ữ', 252: 'ự',
    253: 'ý', 251: 'ỳ', 254: 'ỷ', 255: 'ỹ', 245: 'ỵ',
    174: 'đ',
    // Capital cases in TCVN3
    193: 'Á', 192: 'À', 195: 'Ả', 196: 'Ã', 197: 'Ạ',
    161: 'Ă', 162: 'Â', 163: 'Ê', 164: 'Ô', 165: 'Ơ', 166: 'Ư', 167: 'Đ',
  };

  /// Converts TCVN3 (.VNTime, .VNArial) encoded text to modern Unicode UTF-8.
  static String convertTcvn3ToUnicode(String input) {
    if (input.isEmpty) return input;
    final buffer = StringBuffer();
    for (int i = 0; i < input.length; i++) {
      final codeUnit = input.codeUnitAt(i);
      if (_tcvn3Map.containsKey(codeUnit)) {
        buffer.write(_tcvn3Map[codeUnit]);
      } else {
        buffer.writeCharCode(codeUnit);
      }
    }
    return buffer.toString();
  }

  /// Converts common VNI-encoded text (e.g. VNI-Times) to Unicode UTF-8.
  static String convertVniToUnicode(String input) {
    if (input.isEmpty) return input;
    var result = input;
    // Replace composite VNI characters in order of specificity (3-char sequences first, then 2-char)
    const vniReplacements = {
      // 3-char sequences: diacritics on complex vowels
      'aêù': 'ắ', 'aêø': 'ằ', 'aêû': 'ẳ', 'aêõ': 'ẵ', 'aêï': 'ặ',
      'aâù': 'ấ', 'aâø': 'ầ', 'aâû': 'ẩ', 'aâõ': 'ẫ', 'aâï': 'ậ',
      'eâù': 'ế', 'eâø': 'ề', 'eâû': 'ể', 'eâõ': 'ễ', 'eâï': 'ệ',
      'oâù': 'ố', 'oâø': 'ồ', 'oâû': 'ổ', 'oâõ': 'ỗ', 'oâï': 'ộ',
      'ôù': 'ớ', 'ôø': 'ờ', 'ôû': 'ở', 'ôõ': 'ỡ', 'ôï': 'ợ',
      'öù': 'ứ', 'öø': 'ừ', 'öû': 'ử', 'öõ': 'ữ', 'öï': 'ự',

      // 2-char base vowels
      'aê': 'ă', 'aâ': 'â', 'eâ': 'ê', 'oâ': 'ô', 'ô': 'ơ', 'ö': 'ư',

      // Simple vowels with tones
      'aù': 'á', 'aø': 'à', 'aû': 'ả', 'aõ': 'ã', 'aï': 'ạ',
      'eù': 'é', 'eø': 'è', 'eû': 'ẻ', 'eõ': 'ẽ', 'eï': 'ẹ',
      'í': 'í', 'ì': 'ì', 'ỉ': 'ỉ', 'ĩ': 'ĩ', 'ị': 'ị',
      'où': 'ó', 'oø': 'ò', 'oû': 'ỏ', 'oõ': 'õ', 'oï': 'ọ',
      'uù': 'ú', 'uø': 'ù', 'uû': 'ủ', 'uõ': 'ũ', 'uï': 'ụ',
      'yù': 'ý', 'yø': 'ỳ', 'yû': 'ỷ', 'yõ': 'ỹ', 'î': 'ỵ',
      'ñ': 'đ', 'Ñ': 'Đ',
    };

    vniReplacements.forEach((vni, uni) {
      result = result.replaceAll(vni, uni);
    });
    return result;
  }

  /// Automatically detects if text looks like TCVN3/VNI legacy encoding and fixes it.
  static String autoFixVietnameseEncoding(String input) {
    if (input.isEmpty) return input;
    // Count legacy characters
    int tcvn3Matches = 0;
    for (int i = 0; i < input.length; i++) {
      if (_tcvn3Map.containsKey(input.codeUnitAt(i))) {
        tcvn3Matches++;
      }
    }

    if (tcvn3Matches > 3) {
      return convertTcvn3ToUnicode(input);
    }

    if (input.contains('aù') || input.contains('eù') || input.contains('où') || input.contains('ñ')) {
      return convertVniToUnicode(input);
    }

    return input;
  }

  /// Checks if key school and administrative fonts are installed on the local Windows system.
  static Future<Map<String, bool>> checkInstalledEducationalFonts() async {
    final fontsToCheck = [
      'Times New Roman',
      'Arial',
      'Calibri',
      'Segoe UI',
      'HP001 4 hàng', // Primary school handwriting font
      'HP001 Tapviet',
      'ThuPhap',
    ];

    final result = <String, bool>{};
    final windowsFontsDir = Directory('C:\\Windows\\Fonts');

    if (!await windowsFontsDir.exists()) {
      for (final font in fontsToCheck) {
        result[font] = false;
      }
      return result;
    }

    try {
      final fontFiles = await windowsFontsDir.list().map((e) => e.path.toLowerCase()).toList();

      result['Times New Roman'] = fontFiles.any((f) => f.contains('times'));
      result['Arial'] = fontFiles.any((f) => f.contains('arial'));
      result['Calibri'] = fontFiles.any((f) => f.contains('calibri'));
      result['Segoe UI'] = fontFiles.any((f) => f.contains('segoe'));
      result['HP001 4 hàng'] = fontFiles.any((f) => f.contains('hp001') || f.contains('tieuhoc'));
      result['HP001 Tapviet'] = fontFiles.any((f) => f.contains('tapviet'));
      result['ThuPhap'] = fontFiles.any((f) => f.contains('thuphap') || f.contains('vni-quang'));
    } catch (e) {
      AppLogger.warning('Font discovery notice: $e');
    }

    return result;
  }
}
