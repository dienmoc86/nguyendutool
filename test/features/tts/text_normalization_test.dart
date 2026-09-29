import 'package:flutter_test/flutter_test.dart';
import 'package:nguyendu_tool/features/text_to_speech/infrastructure/vietnamese_text_normalization_service.dart';

void main() {
  group('VietnameseTextNormalizationService Tests', () {
    const service = VietnameseTextNormalizationService();

    test('Normalizes dates in dd/MM/yyyy format conservatively', () {
      const input = 'Khai giảng năm học mới vào ngày 15/09/2026 tại sân trường.';
      final result = service.normalize(input);
      expect(result, contains('ngày 15 tháng 9 năm 2026'));
    });

    test('Normalizes times in hh:mm format', () {
      const input = 'Buổi lễ bắt đầu lúc 07:30 sáng và kết thúc lúc 12:00 trưa.';
      final result = service.normalize(input);
      expect(result, contains('7 giờ 30 phút'));
      expect(result, contains('12 giờ'));
    });

    test('Normalizes percentages and decimal numbers', () {
      const input = 'Tỷ lệ học sinh đạt chuẩn là 95% và tăng 4.5% so với năm ngoái.';
      final result = service.normalize(input);
      expect(result, contains('95 phần trăm'));
      expect(result, contains('4 phẩy 5 phần trăm'));
    });

    test('Normalizes currency and units', () {
      const input = 'Mỗi phần thưởng trị giá 500.000đ dành cho học sinh giỏi.';
      final result = service.normalize(input);
      expect(result, contains('500.000 đồng'));
    });

    test('Normalizes educational abbreviations conservatively', () {
      const input = 'Học sinh trường THCS Nguyễn Du tại TP.HCM tham gia ngày hội STEM.';
      final result = service.normalize(input);
      expect(result, contains('Trung học cơ sở'));
      expect(result, contains('thành phố Hồ Chí Minh'));
    });

    test('Normalizes smart quotes, em-dashes, and ellipses', () {
      const input = '“Chào các em” — thầy hiệu trưởng nói…';
      final result = service.normalize(input);
      expect(result, contains('"Chào các em"'));
      expect(result, contains('- thầy hiệu trưởng'));
    });

    test('Normalizes excess whitespace and empty line breaks', () {
      const input = '   Dòng 1     với    nhiều   khoảng trắng. \n\n\n\n  Dòng 2.   ';
      final result = service.normalize(input);
      expect(result, isNot(contains('     ')));
      expect(result, isNot(contains('\n\n\n\n')));
    });

    test('Preserves manual pause markers for parser without corruption', () {
      const input = 'Xin kính chào quý thầy cô. [pause 500ms] Hôm nay chúng ta bắt đầu bài học. [pause 1s]';
      final result = service.normalize(input);
      expect(result, contains('[pause 500ms]'));
      expect(result, contains('[pause 1s]'));
    });

    test('Normalization is deterministic and idempotent', () {
      const input = 'Ngày 20/11/2026, trường THCS Nguyễn Du tại TP.HCM đạt 100% chỉ tiêu với kinh phí 2.500.000đ.';
      final once = service.normalize(input);
      final twice = service.normalize(once);
      expect(twice, equals(once));
    });
  });
}
