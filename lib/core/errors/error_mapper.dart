import 'app_exceptions.dart';

/// Maps exceptions to human-friendly Vietnamese user messages for presentation.
class ErrorMapper {
  static String toUserMessage(Object error) {
    if (error is AppException) {
      switch (error) {
        case FileException():
          return 'Lỗi thao tác tệp: ${error.message}';
        case DatabaseException():
          return 'Cơ sở dữ liệu cục bộ gặp sự cố: ${error.message}';
        case ProviderException():
          return 'Dịch vụ xử lý (Provider) gặp lỗi: ${error.message}';
        case JobException():
          return 'Tác vụ gặp lỗi khi thực thi: ${error.message}';
        case BootstrapException():
          return 'Khởi động ứng dụng thất bại tại bước: ${error.failedStep}.';
        case ScanException():
          return 'Lỗi quét tài liệu: ${error.message}';
        case TtsException():
          return 'Lỗi giọng nói (TTS): ${error.message}';
        case SecureStorageUnavailableException():
          return 'Dịch vụ lưu mật khẩu bảo mật (DPAPI) không khả dụng: ${error.message}';
        case LegacyPlaintextSecretDetectedException():
          return 'Phát hiện mật khẩu chưa mã hóa kế thừa (Legacy Plaintext): ${error.message}';
        case SingleInstanceLockException():
          return 'Ứng dụng đã đang chạy trong một phiên làm việc khác.';
        case DatabaseCorruptBootstrapException():
          return 'Cơ sở dữ liệu ứng dụng bị hỏng hoặc lỗi cấu trúc: ${error.message}';
        case AssessmentException():
          return 'Lỗi khảo thí & đánh giá: ${error.message}';
      }
    }

    return 'Đã xảy ra lỗi không xác định. Vui lòng kiểm tra nhật ký hệ thống.';
  }

  static String toTechnicalDetail(Object error, [StackTrace? stackTrace]) {
    if (error is AppException && error.technicalDetails != null) {
      return '${error.message}\nChi tiết: ${error.technicalDetails}';
    }
    return '$error\n${stackTrace ?? ''}';
  }
}
