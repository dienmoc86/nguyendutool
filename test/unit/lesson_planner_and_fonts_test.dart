import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/core/ai/google_auth_service.dart';
import 'package:nguyendu_tool/core/fonts/vietnamese_font_service.dart';
import 'package:nguyendu_tool/core/providers/secure_storage_abstraction.dart';
import 'package:nguyendu_tool/features/lesson_planner/domain/lesson_plan_models.dart';
import 'package:nguyendu_tool/features/lesson_planner/infrastructure/lesson_plan_docx_exporter.dart';
import 'package:archive/archive.dart';

void main() {
  group('VietnameseFontService Tests', () {
    test('TCVN3 (.VNTime) decoding to Unicode UTF-8', () {
      // In TCVN3, 'Toán học' has legacy byte mapping
      final legacyTcvn3 = String.fromCharCodes([84, 111, 184, 110, 32, 104, 228, 99]); // T, o, á, n, ' ', h, ọ, c
      final decoded = VietnameseFontService.convertTcvn3ToUnicode(legacyTcvn3);
      expect(decoded, equals('Toán học'));
    });

    test('VNI decoding to Unicode UTF-8', () {
      const vniText = 'Giaùo aùn Toaùn hoïc lôùp 6';
      final decoded = VietnameseFontService.convertVniToUnicode(vniText);
      expect(decoded, equals('Giáo án Toán học lớp 6'));
    });

    test('autoFixVietnameseEncoding handles standard Unicode with no corruptions', () {
      const regularText = 'Kế hoạch bài dạy môn Ngữ văn';
      final result = VietnameseFontService.autoFixVietnameseEncoding(regularText);
      expect(result, equals(regularText));
    });

    test('Educational font discovery returns status map', () async {
      final fontMap = await VietnameseFontService.checkInstalledEducationalFonts();
      expect(fontMap, isA<Map<String, bool>>());
      expect(fontMap.containsKey('Times New Roman'), isTrue);
      expect(fontMap.containsKey('Arial'), isTrue);
      expect(fontMap.containsKey('HP001 4 hàng'), isTrue);
    });
  });

  group('GoogleAuthService Tests', () {
    late ISecureStorage mockStorage;
    late GoogleAuthService authService;

    setUp(() {
      mockStorage = SecureStorageService();
      authService = GoogleAuthService(mockStorage);
    });

    test('Save and retrieve Google Gemini credentials', () async {
      expect(await authService.isAuthenticated(), isFalse);

      await authService.saveCredentials(
        apiKey: 'AIzaSyFakeTestKey123456789',
        displayName: 'Cô Nguyễn Thị Mai',
        email: 'ntmai@thcsnguyendu.edu.vn',
      );

      expect(await authService.isAuthenticated(), isTrue);
      expect(await authService.getApiKey(), equals('AIzaSyFakeTestKey123456789'));

      final profile = await authService.getUserProfile();
      expect(profile, isNotNull);
      expect(profile!.displayName, equals('Cô Nguyễn Thị Mai'));
      expect(profile.email, equals('ntmai@thcsnguyendu.edu.vn'));

      // Sign out
      await authService.signOut();
      expect(await authService.isAuthenticated(), isFalse);
      expect(await authService.getApiKey(), isNull);
    });
  });

  group('LessonPlanDocxExporter Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('docx_test_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Exports valid MOET 5512 OpenXML Word document (.docx)', () async {
      final outputPath = '${tempDir.path}\\GiaoAn_Test_5512.docx';
      const samplePlan = '''
I. MỤC TIÊU
1. Về kiến thức: Học sinh nắm được khái niệm số nguyên tố.
2. Về năng lực: Năng lực tư duy và lập luận toán học.
3. Về phẩm chất: Chăm chỉ, trung thực.

II. THIẾT BỊ DẠY HỌC VÀ HỌC LIỆU
1. Giáo viên: Bảng phụ, phiếu học tập.
2. Học sinh: Vở ghi, đồ dùng học tập.

III. TIẾN TRÌNH DẠY HỌC
1. Hoạt động 1: Khởi động (5 phút)
a. Mục tiêu: Tạo hứng thú học tập.
b. Nội dung: Học sinh giải câu đố nhanh.
c. Sản phẩm: Câu trả lời của học sinh.
d. Tổ chức thực hiện:
- Bước 1: Chuyển giao nhiệm vụ
- Bước 2: Thực hiện nhiệm vụ
- Bước 3: Báo cáo thảo luận
- Bước 4: Kết luận nhận định

IV. HỒ SƠ DẠY HỌC
1. Phiếu học tập số 1.
''';

      final file = await LessonPlanDocxExporter.export(
        title: 'Bài 10: Số nguyên tố',
        subject: 'Toán học',
        grade: 'Lớp 6',
        content: samplePlan,
        outputPath: outputPath,
      );

      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(1000));

      // Validate DOCX structure (unzip archive and inspect XML parts)
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final fileNames = archive.files.map((f) => f.name).toList();
      expect(fileNames, contains('[Content_Types].xml'));
      expect(fileNames, contains('_rels/.rels'));
      expect(fileNames, contains('word/document.xml'));
      expect(fileNames, contains('word/styles.xml'));
      expect(fileNames, contains('word/_rels/document.xml.rels'));

      // Check document XML content
      final docFile = archive.findFile('word/document.xml');
      expect(docFile, isNotNull);
      final docXml = utf8.decode(docFile!.content as List<int>);
      expect(docXml, contains('KẾ HOẠCH BÀI DẠY (CÔNG VĂN 5512/BGDĐT-GDTrH)'));
      expect(docXml, contains('Môn học: Toán học - Lớp 6'));
      expect(docXml, contains('SỐ NGUYÊN TỐ'));
      expect(docXml, contains('Hoạt động 1: Khởi động'));
    });
  });

  group('LessonPlanModels Tests', () {
    test('SchoolSubjects provides standard educational lists', () {
      expect(SchoolSubjects.subjects, contains('Toán học'));
      expect(SchoolSubjects.subjects, contains('Ngữ văn / Tiếng Việt'));
      expect(SchoolSubjects.subjects, contains('Tiếng Anh'));
      expect(SchoolSubjects.grades.length, equals(12));
      expect(SchoolSubjects.bookSeriesList, contains('Kết nối tri thức với cuộc sống'));
      expect(SchoolSubjects.bookSeriesList, contains('Chân trời sáng tạo'));
      expect(SchoolSubjects.bookSeriesList, contains('Cánh diều'));
    });
  });
}
