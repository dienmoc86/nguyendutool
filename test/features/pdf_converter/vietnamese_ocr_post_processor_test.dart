import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/features/pdf_converter/infrastructure/vietnamese_ocr_post_processor.dart';

void main() {
  group('VietnameseOcrPostProcessor Tests', () {
    test('Fixes spaced capital words in official headings', () {
      const input = 'C Ộ N G  H Ò A  X Ã  H Ộ I  C H Ủ  N G H Ĩ A  V I Ệ T  N A M';
      final output = VietnameseOcrPostProcessor.processText(input);
      expect(output, contains('CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM'));
    });

    test('Fixes broken words split across line breaks with hyphens', () {
      const input = 'nhà trường đang tiến hành nghiên-\n cứu đổi mới phương pháp giảng dạy.';
      final output = VietnameseOcrPostProcessor.processText(input);
      expect(output, contains('nghiên cứu'));
    });

    test('Normalizes dates with excessive whitespace', () {
      const input = 'Hà Nội, ngày  15  tháng  09  năm  2026';
      final output = VietnameseOcrPostProcessor.processText(input);
      expect(output, contains('ngày 15 tháng 09 năm 2026'));
    });

    test('Normalizes slash dates', () {
      const input = 'Hạn nộp báo cáo: 20 / 11 / 2026';
      final output = VietnameseOcrPostProcessor.processText(input);
      expect(output, contains('20/11/2026'));
    });

    test('Fixes letter O in years', () {
      const input = 'Năm học 2O26-2027';
      final output = VietnameseOcrPostProcessor.processText(input);
      expect(output, contains('2026-2027'));
    });

    test('Corrects common OCR misrecognitions from word rules', () {
      const input = 'Quyét định của Hiẹu trưởng TRƯÒNG THCS';
      final output = VietnameseOcrPostProcessor.processText(input);
      expect(output, contains('Quyết định'));
      expect(output, contains('Hiệu trưởng'));
      expect(output, contains('TRƯỜNG'));
    });

    test('Corrects mangled administrative scan formulas from user documents', () {
      const input = '''
Céng hda xä héi chñ nghïa viét nam
Dic lip - TY' do - Hqnh phúc
uy BAN NHAN DAN TINH THAI BINH
QUYET DINH
Về việc Phö duyQt Do ản sica dõi, bö simg mét Sö diéu
CAN CU Luat To chuc
THEO DE NGHI cua So
''';
      final output = VietnameseOcrPostProcessor.processText(input);
      expect(output, contains('CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM'));
      expect(output, contains('Độc lập - Tự do - Hạnh phúc'));
      expect(output, contains('ỦY BAN NHÂN DÂN'));
      expect(output, contains('QUYẾT ĐỊNH'));
      expect(output, contains('Phê duyệt Đồ án'));
      expect(output, contains('sửa đổi'));
      expect(output, contains('bổ sung'));
      expect(output, contains('một số điều'));
      expect(output, contains('CĂN CỨ'));
      expect(output, contains('THEO ĐỀ NGHỊ'));
    });

    test('Replaces VietOCR ambiguous glyphs correctly', () {
      const input = 'vđi tinh thần củng cố cũa phãi Ðoàn';
      final output = VietnameseOcrPostProcessor.processText(input);
      expect(output, contains('với tinh thần củng cố của phải Đoàn'));
    });
  });
}
