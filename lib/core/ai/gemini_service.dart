import 'dart:convert';
import 'dart:io';
import '../logging/app_logger.dart';
import 'ai_model_config.dart';

class GeminiService {
  final String apiKey;
  final String model;

  GeminiService({
    required this.apiKey,
    this.model = AiModelConfig.defaultModel,
  });

  /// Sends a generation prompt to Google Gemini REST API.
  Future<String> generateText(String prompt, {double temperature = 0.7}) async {
    final cleanKey = apiKey.trim();
    if (cleanKey.isEmpty) {
      throw const FormatException('Chưa cấu hình Google Gemini API Key.');
    }

    final endpoint = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$cleanKey',
    );

    final payload = {
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'temperature': temperature,
        'maxOutputTokens': 8192,
      },
    };

    final client = HttpClient();
    try {
      final request = await client.postUrl(endpoint).timeout(const Duration(seconds: 45));
      request.headers.set('Content-Type', 'application/json; charset=UTF-8');
      request.add(utf8.encode(jsonEncode(payload)));

      final response = await request.close().timeout(const Duration(seconds: 45));
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        String errorMsg = 'Lỗi HTTP ${response.statusCode}';
        try {
          final errJson = jsonDecode(responseBody) as Map<String, dynamic>;
          final errObj = errJson['error'] as Map<String, dynamic>?;
          if (errObj != null && errObj['message'] != null) {
            errorMsg = errObj['message'].toString();
          }
        } catch (_) {}
        AppLogger.error('Gemini API Error: $errorMsg');
        throw HttpException('Google Gemini API: $errorMsg');
      }

      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      final candidates = json['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) {
        throw const FormatException('Không nhận được nội dung phản hồi từ mô hình AI.');
      }

      final first = candidates.first as Map<String, dynamic>;
      final content = first['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List<dynamic>?;
      if (parts == null || parts.isEmpty) {
        throw const FormatException('Phản hồi từ AI không chứa dữ liệu văn bản.');
      }

      final text = parts.map((p) => p['text']?.toString() ?? '').join();
      return text.trim();
    } finally {
      client.close();
    }
  }

  /// Builds a high-precision prompt and generates a formal Lesson Plan according to
  /// Vietnamese Ministry of Education & Training Official Dispatch 5512/BGDĐT-GDTrH.
  Future<String> generate5512LessonPlan({
    required String subject,
    required String grade,
    required String bookSeries,
    required String lessonTitle,
    required String duration,
    String? requirements,
    String? sourceMaterial,
  }) async {
    final prompt = '''
Bạn là chuyên gia sư phạm hàng đầu của Bộ Giáo dục và Đào tạo Việt Nam.
Hãy soạn KẾ HOẠCH BÀI DẠY (GIÁO ÁN) hoàn chỉnh, chuẩn xác 100% theo đúng thể thức CÔNG VĂN 5512/BGDĐT-GDTrH của Bộ GD&ĐT.

THÔNG TIN BÀI DẠY:
- Môn học: $subject
- Khối lớp: $grade
- Bộ sách giáo khoa: $bookSeries
- Tên bài dạy: $lessonTitle
- Thời lượng: $duration
${requirements != null && requirements.trim().isNotEmpty ? "- Yêu cầu cần đạt bổ sung: ${requirements.trim()}" : ""}
${sourceMaterial != null && sourceMaterial.trim().isNotEmpty ? "- Dữ liệu tài liệu/sách giáo khoa trích xuất: ${sourceMaterial.trim()}" : ""}

YÊU CẦU CẤU TRÚC BẮT BUỘC THEO CÔNG VĂN 5512:

TÊN BÀI DẠY: ... (Thời lượng: ...)
Môn học: ...; Lớp: ...

I. MỤC TIÊU
1. Về kiến thức: Nêu rõ các kiến thức cốt lõi học sinh tiếp thu được sau bài học.
2. Về năng lực:
   - Năng lực chung: Tự chủ và tự học, Giao tiếp và hợp tác, Giải quyết vấn đề và sáng tạo.
   - Năng lực đặc thù: Các năng lực môn $subject cụ thể.
3. Về phẩm chất: Yêu nước, Nhân ái, Chăm chỉ, Trung thực, Trách nhiệm (gắn liền với bài học).

II. THIẾT BỊ DẠY HỌC VÀ HỌC LIỆU
1. Giáo viên: Giáo án, tivi/máy chiếu, bài giảng PowerPoint, phiếu học tập, đồ dùng dạy học.
2. Học sinh: Sách giáo khoa, vở ghi, đồ dùng học tập theo yêu cầu.

III. TIẾN TRÌNH DẠY HỌC
(Phải trình bày đầy đủ 4 hoạt động chuẩn. Mỗi hoạt động PHẢI CÓ ĐỦ 4 mục: a. Mục tiêu, b. Nội dung, c. Sản phẩm, d. Tổ chức thực hiện theo 4 bước chuẩn:
- Bước 1: Chuyển giao nhiệm vụ
- Bước 2: Thực hiện nhiệm vụ
- Bước 3: Báo cáo, thảo luận
- Bước 4: Kết luận, nhận định)

1. Hoạt động 1: Xác định vấn đề / Khởi động (Khoảng 5-7 phút)
   a. Mục tiêu:
   b. Nội dung:
   c. Sản phẩm:
   d. Tổ chức thực hiện:

2. Hoạt động 2: Hình thành kiến thức mới (Trọng tâm bài học)
   (Chia rõ các mục kiến thức nhỏ 2.1, 2.2... Từng mục đều đủ a, b, c, d)
   a. Mục tiêu:
   b. Nội dung:
   c. Sản phẩm:
   d. Tổ chức thực hiện:

3. Hoạt động 3: Luyện tập (Khoảng 10-15 phút)
   (Đưa ra hệ thống câu hỏi trắc nghiệm và bài tập tự luận củng cố)
   a. Mục tiêu:
   b. Nội dung:
   c. Sản phẩm:
   d. Tổ chức thực hiện:

4. Hoạt động 4: Vận dụng (Nhiệm vụ về nhà / mở rộng thực tiễn)
   a. Mục tiêu:
   b. Nội dung:
   c. Sản phẩm:
   d. Tổ chức thực hiện:

IV. HỒ SƠ DẠY HỌC & ĐÁNH GIÁ (PHỤ LỤC)
1. Phiếu học tập số 1 (kèm đáp án/hướng dẫn).
2. Phiếu học tập số 2 (nếu có).
3. Bảng tiêu chí đánh giá năng lực học sinh (Rubric đánh giá mức độ Đạt/Chưa đạt).

LƯU Ý QUAN TRỌNG:
- Trình bày bài bản, văn phong sư phạm chuẩn mực, chuyên nghiệp, tiếng Việt chuẩn có dấu.
- Chi tiết và thực tế, giáo viên có thể in ra nộp Ban giám hiệu hoặc dùng giảng dạy ngay lập tức.
''';

    return await generateText(prompt, temperature: 0.65);
  }

  /// Quickly validates whether a Gemini API key is functional by calling with a minimal payload.
  static Future<bool> validateKey(String key, {String model = AiModelConfig.defaultModel}) async {
    final cleanKey = key.trim();
    if (cleanKey.isEmpty) return false;
    final endpoint = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$cleanKey',
    );
    final payload = {
      'contents': [
        {
          'parts': [
            {'text': 'ping'}
          ]
        }
      ],
      'generationConfig': {'maxOutputTokens': 5},
    };
    final client = HttpClient();
    try {
      final request = await client.postUrl(endpoint).timeout(const Duration(seconds: 15));
      request.headers.set('Content-Type', 'application/json; charset=UTF-8');
      request.add(utf8.encode(jsonEncode(payload)));
      final response = await request.close().timeout(const Duration(seconds: 15));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      client.close();
    }
  }

  /// Tests the instance connection.
  Future<bool> testConnection() async {
    return await validateKey(apiKey, model: model);
  }

  /// Transcribes audio or video media into timestamped Vietnamese text and pedagogical summary.
  Future<String> transcribeMedia({
    required List<int> mediaBytes,
    required String mimeType,
    String? prompt,
    double temperature = 0.2,
  }) async {
    final cleanKey = apiKey.trim();
    if (cleanKey.isEmpty) {
      throw const FormatException('Chưa cấu hình Google Gemini API Key.');
    }

    final endpoint = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$cleanKey',
    );

    final effectivePrompt = prompt ??
'''Bạn là trợ lý AI chuyên nghiệp phục vụ giáo viên và nhà trường Việt Nam.
Nhiệm vụ của bạn là gỡ băng (speech-to-text) tệp âm thanh/video này thành văn bản tiếng Việt chuẩn mực.

YÊU CẦU BẮT BUỘC:
1. GỠ BĂNG CHI TIẾT (TRANSCRIPTION):
- Chuyển toàn bộ lời nói thành văn bản tiếng Việt chuẩn xác 100%, đúng chính tả, có dấu đầy đủ, chấm phẩy ngắt câu tự nhiên.
- Đặt mốc thời gian dạng [mm:ss] ở đầu mỗi đoạn phát biểu.
- Phân biệt người nói rõ ràng (ví dụ: [Thầy giáo], [Cô giáo], [Học sinh], [Người nói 1], [Người nói 2]...) nếu nhận diện được.

2. TÓM TẮT & TRỌNG TÂM SƯ PHẠM (EDUCATIONAL SUMMARY):
Ở cuối văn bản, hãy thêm một phần phân cách bằng dòng "---" và đề mục:
### TÓM TẮT NỘI DUNG & Ý CHÍNH BÀI HỌC / CUỘC HỌP
- Chủ đề chính: ...
- Các luận điểm / kiến thức cốt lõi:
  + ...
- Nhiệm vụ học tập / Kết luận:
  + ...
- Từ khóa quan trọng: ...''';

    final payload = {
      'contents': [
        {
          'parts': [
            {
              'inlineData': {
                'mimeType': mimeType,
                'data': base64Encode(mediaBytes),
              }
            },
            {
              'text': effectivePrompt,
            }
          ]
        }
      ],
      'generationConfig': {
        'temperature': temperature,
        'maxOutputTokens': 8192,
      },
    };

    final client = HttpClient();
    try {
      final request = await client.postUrl(endpoint).timeout(const Duration(seconds: 180));
      request.headers.set('Content-Type', 'application/json; charset=UTF-8');
      request.add(utf8.encode(jsonEncode(payload)));

      final response = await request.close().timeout(const Duration(seconds: 180));
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        String errorMsg = 'Lỗi HTTP ${response.statusCode}';
        try {
          final errJson = jsonDecode(responseBody) as Map<String, dynamic>;
          final errObj = errJson['error'] as Map<String, dynamic>?;
          if (errObj != null && errObj['message'] != null) {
            errorMsg = errObj['message'].toString();
          }
        } catch (_) {}
        AppLogger.error('Gemini Transcription Error: $errorMsg');
        throw HttpException('Google Gemini API ($model): $errorMsg');
      }

      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      final candidates = json['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) {
        throw const FormatException('Không nhận được nội dung phản hồi từ mô hình AI.');
      }

      final first = candidates.first as Map<String, dynamic>;
      final content = first['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List<dynamic>?;
      if (parts == null || parts.isEmpty) {
        throw const FormatException('Phản hồi từ AI không chứa dữ liệu văn bản gỡ băng.');
      }

      final text = parts.map((p) => p['text']?.toString() ?? '').join();
      return text.trim();
    } finally {
      client.close();
    }
  }
}
