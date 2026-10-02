import 'package:flutter/material.dart';
import '../../app/router/routes.dart';
import '../../app/theme/app_colors.dart';
import 'module_category.dart';
import 'module_definition.dart';
import 'module_status.dart';

/// Central authoritative registry for all functional modules and planned expansion modules.
class ModuleRegistry {
  static final ModuleRegistry instance = ModuleRegistry._internal();

  final Map<String, ModuleDefinition> _modules = {};
  bool _initialized = false;

  ModuleRegistry._internal() {
    _registerDefaultModules();
  }

  void _registerDefaultModules() {
    if (_initialized) return;

    // ==========================================
    // 1. ACTIVE PRODUCTION / STABLE MODULES
    // ==========================================

    register(const ModuleDefinition(
      id: 'dashboard',
      name: 'Trang chủ',
      shortName: 'Trang chủ',
      description: 'Tổng quan bàn làm việc, tác vụ gần đây và khởi tạo nhanh nghiệp vụ.',
      icon: Icons.dashboard_rounded,
      category: ModuleCategory.home,
      route: AppRoutes.dashboard,
      order: 0,
      status: ModuleStatus.stable,
      keywords: ['trang chủ', 'bàn làm việc', 'dashboard', 'tổng quan', 'bắt đầu'],
      accentColor: AppColors.primary,
      supportsOffline: true,
      requiresNetwork: false,
    ));

    register(const ModuleDefinition(
      id: 'lesson_planner',
      name: 'Trợ lý Giảng dạy (Teaching Suite)',
      shortName: 'Trợ lý giảng dạy',
      description: 'Bộ công cụ toàn diện soạn Kế hoạch bài dạy (CV 5512), phiếu học tập, ngân hàng câu hỏi, ma trận đề và rubric đánh giá.',
      icon: Icons.auto_stories_rounded,
      category: ModuleCategory.teaching,
      route: AppRoutes.lessonPlanner,
      order: 10,
      status: ModuleStatus.beta,
      isVisible: false,
      keywords: ['giảng dạy', 'giáo án', 'bài dạy', '5512', 'kế hoạch bài dạy', 'phiếu học tập', 'câu hỏi', 'rubric', 'đề thi', 'teaching suite', 'soạn bài', 'word', 'docx'],
      capabilities: ['document.docx.write'],
      optionalCapabilities: ['ai.text.generate'],
      intentActionTitle: 'Soạn bài & Giảng dạy',
      accentColor: AppColors.accentViolet,
      supportsOffline: true,
      requiresNetwork: false, // Core templating & editor is offline; AI assistant optionally cloud
    ));

    register(const ModuleDefinition(
      id: 'pdf_converter',
      name: 'Chuyển đổi PDF & Tài liệu',
      shortName: 'Chuyển đổi PDF',
      description: 'Chuyển đổi PDF sang Microsoft Word (.docx), Excel (.xlsx), trích xuất bảng biểu tự động không cần cài Office.',
      icon: Icons.picture_as_pdf_rounded,
      category: ModuleCategory.documents,
      route: AppRoutes.pdfConverter,
      order: 20,
      status: ModuleStatus.stable,
      keywords: ['pdf', 'word', 'excel', 'docx', 'xlsx', 'chuyển đổi', 'convert', 'bảng biểu'],
      capabilities: ['document.pdf.read', 'document.docx.write', 'document.xlsx.write'],
      intentActionTitle: 'Chuyển đổi PDF',
      accentColor: AppColors.modulePdf,
      supportsOffline: true,
      requiresNetwork: false,
    ));

    register(const ModuleDefinition(
      id: 'scanner',
      name: 'Quét Đề thi & Số hóa Học liệu',
      shortName: 'Quét tài liệu',
      description: 'Kết nối máy scan WIA, căn chỉnh chống nghiêng, khử bóng và tạo tệp Searchable PDF chuẩn văn thư.',
      icon: Icons.scanner_rounded,
      category: ModuleCategory.documents,
      route: AppRoutes.scanner,
      order: 21,
      status: ModuleStatus.stable,
      isVisible: true,
      keywords: ['scan', 'quét', 'số hóa', 'đề thi', 'sổ sách', 'ocr', 'wia', 'searchable pdf', 'máy scan', 'camera', 'điện thoại'],
      capabilities: ['scanner.wia', 'document.ocr'],
      intentActionTitle: 'Quét tài liệu',
      accentColor: AppColors.moduleScanner,
      supportsOffline: true,
      requiresNetwork: false,
    ));

    register(const ModuleDefinition(
      id: 'text_to_speech',
      name: 'Đọc văn bản & Lồng tiếng (TTS)',
      shortName: 'Đọc văn bản',
      description: 'Chuyển văn bản giáo án, bài đọc thành giọng nói tiếng Việt tự nhiên, tự sinh phụ đề đồng bộ và xuất file MP3/WAV.',
      icon: Icons.record_voice_over_rounded,
      category: ModuleCategory.media,
      route: AppRoutes.textToSpeech,
      order: 30,
      status: ModuleStatus.stable,
      isVisible: true,
      keywords: ['tts', 'đọc văn bản', 'giọng nói', 'lồng tiếng', 'mp3', 'wav', 'phụ đề', 'voice', 'audio'],
      capabilities: ['media.tts'],
      intentActionTitle: 'Tạo Giọng đọc',
      accentColor: AppColors.moduleTts,
      supportsOffline: true,
      requiresNetwork: false,
    ));

    register(const ModuleDefinition(
      id: 'video_studio',
      name: 'Xưởng dựng Video Bài giảng',
      shortName: 'Xưởng video',
      description: 'Dựng video clip bài giảng điện tử E-Learning, ghép giọng thuyết minh tự động khớp thời lượng, chèn phụ đề chữ cứng.',
      icon: Icons.video_collection_rounded,
      category: ModuleCategory.media,
      route: AppRoutes.videoStudio,
      order: 31,
      status: ModuleStatus.stable,
      isVisible: false,
      keywords: ['video', 'bài giảng', 'e-learning', 'studio', 'ffmpeg', 'slideshow', 'clip', 'dựng phim'],
      capabilities: ['media.ffmpeg', 'media.video.render'],
      intentActionTitle: 'Tạo Video bài giảng',
      accentColor: AppColors.moduleVideo,
      supportsOffline: true,
      requiresNetwork: false,
    ));

    register(const ModuleDefinition(
      id: 'file_library',
      name: 'Kho Học liệu số & Tài liệu',
      shortName: 'Kho học liệu',
      description: 'Lưu trữ, tra cứu và tái sử dụng toàn bộ tệp kết xuất, âm thanh, video, giáo án và tài liệu số hóa nội bộ.',
      icon: Icons.folder_shared_rounded,
      category: ModuleCategory.system,
      route: AppRoutes.fileLibrary,
      order: 40,
      status: ModuleStatus.stable,
      isVisible: false,
      keywords: ['thư viện', 'kho học liệu', 'tệp', 'lưu trữ', 'files', 'library', 'tìm kiếm'],
      intentActionTitle: 'Mở Kho học liệu',
      accentColor: AppColors.moduleLibrary,
      supportsOffline: true,
      requiresNetwork: false,
    ));

    register(const ModuleDefinition(
      id: 'settings',
      name: 'Cài đặt hệ thống',
      shortName: 'Cài đặt',
      description: 'Cấu hình thư mục làm việc, quản lý khoá API, chẩn đoán động cơ FFmpeg, sao lưu và kiểm tra tính toàn vẹn.',
      icon: Icons.settings_rounded,
      category: ModuleCategory.system,
      route: AppRoutes.settings,
      order: 41,
      status: ModuleStatus.stable,
      isVisible: true,
      keywords: ['cài đặt', 'hệ thống', 'settings', 'cấu hình', 'diagnostics', 'chẩn đoán', 'phục hồi'],
      capabilities: ['security.dpapi'],
      intentActionTitle: 'Cài đặt',
      accentColor: AppColors.darkTextSecondary,
      supportsOffline: true,
      requiresNetwork: false,
    ));

    // ==========================================
    // 2. FUTURE EXPANSION MODULES (HONEST ROADMAP)
    // ==========================================

    register(const ModuleDefinition(
      id: 'presentation_studio',
      name: 'PowerPoint & Trình chiếu Bài giảng',
      shortName: 'Trình chiếu',
      description: 'Soạn thảo và tạo slide trình chiếu bài giảng điện tử sinh động từ nội dung Kế hoạch bài dạy.',
      icon: Icons.slideshow_rounded,
      category: ModuleCategory.teaching,
      route: null,
      order: 11,
      status: ModuleStatus.comingSoon,
      isVisible: false, // Not cluttering main sidebar, shown in discovery & roadmap
      keywords: ['powerpoint', 'pptx', 'trình chiếu', 'slide', 'bài giảng'],
      accentColor: Color(0xFFD97706),
    ));

    register(const ModuleDefinition(
      id: 'assessment_studio',
      name: 'Xưởng Đề kiểm tra & Đánh giá',
      shortName: 'Đề kiểm tra & Đánh giá',
      description: 'Xây dựng ma trận đề kiểm tra, ngân hàng câu hỏi chuẩn GDPT 2018, sinh đa mã đề và xuất file Word.',
      icon: Icons.quiz_rounded,
      category: ModuleCategory.teaching,
      route: AppRoutes.assessmentStudio,
      order: 12,
      status: ModuleStatus.beta,
      isVisible: false,
      keywords: ['đề thi', 'đề kiểm tra', 'ma trận', 'đặc tả', 'trắc nghiệm', 'tự luận', 'đáp án', 'mã đề', 'assessment', 'exam', 'quiz'],
      accentColor: Color(0xFF059669),
    ));

    register(const ModuleDefinition(
      id: 'pdf_toolbox',
      name: 'Hộp công cụ PDF Chuyên sâu',
      shortName: 'Công cụ PDF',
      description: 'Ghép nối, phân tách, nén dung lượng, xoay trang và đóng dấu bản quyền cho tài liệu PDF.',
      icon: Icons.handyman_rounded,
      category: ModuleCategory.documents,
      route: null,
      order: 22,
      status: ModuleStatus.comingSoon,
      isVisible: false,
      keywords: ['pdf toolbox', 'ghép pdf', 'tách pdf', 'nén pdf', 'bảo mật pdf', 'watermark'],
      accentColor: Color(0xFFDC2626),
    ));

    register(const ModuleDefinition(
      id: 'speech_to_text',
      name: 'Ghi âm & Video thành Văn bản (Google Gemini AI)',
      shortName: 'Gỡ băng Âm thanh / Video',
      description: 'Gỡ băng bài giảng, chuyển file ghi âm hội nghị, tiết giảng, video bài giảng thành văn bản Word tự động bằng Google Gemini AI.',
      icon: Icons.mic_rounded,
      category: ModuleCategory.media,
      route: AppRoutes.speechToText,
      order: 32,
      status: ModuleStatus.stable,
      isVisible: false,
      keywords: ['speech to text', 'stt', 'nhận dạng giọng nói', 'gemini', 'gỡ băng', 'ghi âm', 'video', 'mp3', 'mp4'],
      accentColor: Color(0xFF2563EB),
      supportsOffline: false,
      requiresNetwork: true,
      intentActionTitle: 'Gỡ băng Âm thanh / Video',
    ));

    register(const ModuleDefinition(
      id: 'subtitle_studio',
      name: 'Xưởng phụ đề tự động',
      shortName: 'Phụ đề video',
      description: 'Biên dịch, căn chỉnh dòng thời gian và xuất file phụ đề .srt, .vtt cho video bài giảng.',
      icon: Icons.subtitles_rounded,
      category: ModuleCategory.media,
      route: null,
      order: 33,
      status: ModuleStatus.comingSoon,
      isVisible: false,
      keywords: ['phụ đề', 'subtitle', 'srt', 'vtt', 'tự động tạo phụ đề'],
      accentColor: Color(0xFF7C3AED),
    ));

    register(const ModuleDefinition(
      id: 'ai_assistant',
      name: 'Trợ lý AI Tra cứu Giáo dục & Q&A',
      shortName: 'Trợ lý AI',
      description: 'Tra cứu văn bản quy phạm giáo dục, tham vấn phương pháp sư phạm tích cực và tóm tắt học liệu.',
      icon: Icons.psychology_rounded,
      category: ModuleCategory.ai,
      route: null,
      order: 35,
      status: ModuleStatus.comingSoon,
      isVisible: false,
      keywords: ['ai', 'trợ lý', 'chat', 'hỏi đáp', 'q&a', 'tra cứu', 'thông tư'],
      accentColor: Color(0xFFEC4899),
    ));

    register(const ModuleDefinition(
      id: 'mail_merge',
      name: 'Trộn Thư & Giấy khen Tự động',
      shortName: 'Trộn thư & Giấy khen',
      description: 'Nhập danh sách học sinh từ Excel và in hàng loạt giấy khen, phiếu điểm, thư mời họp phụ huynh.',
      icon: Icons.mark_email_read_rounded,
      category: ModuleCategory.utilities,
      route: null,
      order: 42,
      status: ModuleStatus.comingSoon,
      isVisible: false,
      keywords: ['trộn thư', 'giấy khen', 'bằng khen', 'mail merge', 'in hàng loạt', 'excel'],
      accentColor: Color(0xFF0284C7),
    ));

    register(const ModuleDefinition(
      id: 'image_tools',
      name: 'Công cụ Xử lý Ảnh & Biểu mẫu',
      shortName: 'Xử lý ảnh',
      description: 'Cắt ghép, nâng cao độ nét, khử nhiễu ảnh tài liệu học tập và tối ưu kích thước ảnh bài giảng.',
      icon: Icons.image_rounded,
      category: ModuleCategory.utilities,
      route: null,
      order: 43,
      status: ModuleStatus.comingSoon,
      isVisible: false,
      keywords: ['ảnh', 'image', 'nén ảnh', 'cắt ảnh', 'làm nét', 'biểu mẫu'],
      accentColor: Color(0xFF0D9488),
    ));

    register(const ModuleDefinition(
      id: 'qr_tools',
      name: 'Tạo & Quét Mã QR Học liệu',
      shortName: 'Mã QR học liệu',
      description: 'Tạo mã QR đính kèm phiếu bài tập, sách giáo khoa dẫn tới video bài giảng và tài liệu trực tuyến.',
      icon: Icons.qr_code_2_rounded,
      category: ModuleCategory.utilities,
      route: null,
      order: 44,
      status: ModuleStatus.comingSoon,
      isVisible: false,
      keywords: ['qr', 'mã qr', 'tạo qr', 'quét qr', 'liên kết học liệu'],
      accentColor: Color(0xFF6366F1),
    ));

    _initialized = true;
  }

  /// Registers a module into the registry
  void register(ModuleDefinition definition) {
    if (_modules.containsKey(definition.id) && _initialized) {
      // In production log warning, in debug/test allow override or throw during validation
    }
    _modules[definition.id] = definition;
  }

  /// Retrieves module definition by ID
  ModuleDefinition? getModule(String id) => _modules[id];

  /// Returns all registered modules
  List<ModuleDefinition> getAllModules() {
    final list = _modules.values.toList();
    list.sort((a, b) => a.order.compareTo(b.order));
    return list;
  }

  /// Returns visible modules for navigation
  List<ModuleDefinition> getVisibleModules({bool includeComingSoon = false}) {
    return getAllModules().where((m) {
      if (!m.isVisible && !includeComingSoon) return false;
      if (!includeComingSoon && m.status == ModuleStatus.comingSoon) return false;
      return true;
    }).toList();
  }

  /// Returns modules grouped by category
  Map<ModuleCategory, List<ModuleDefinition>> getModulesGroupedByCategory({
    bool includeHidden = false,
    bool includeComingSoon = false,
  }) {
    final Map<ModuleCategory, List<ModuleDefinition>> result = {};
    for (final category in ModuleCategory.values) {
      final list = getAllModules().where((m) {
        if (m.category != category) return false;
        if (!includeHidden && !m.isVisible) return false;
        if (!includeComingSoon && m.status == ModuleStatus.comingSoon) return false;
        return true;
      }).toList();

      if (list.isNotEmpty) {
        result[category] = list;
      }
    }
    return result;
  }

  /// Returns visible active modules
  List<ModuleDefinition> get activeModules => getVisibleModules();

  /// Returns all coming soon roadmap modules
  List<ModuleDefinition> get comingSoonModules => getComingSoonModules();

  /// Returns all modules belonging to a specific category
  List<ModuleDefinition> getModulesByCategory(ModuleCategory category) {
    return getAllModules().where((m) => m.category == category).toList();
  }

  /// Returns all coming soon roadmap modules
  List<ModuleDefinition> getComingSoonModules() {
    return getAllModules().where((m) => m.status == ModuleStatus.comingSoon).toList();
  }

  /// Validates registry integrity. Throws [StateError] on failure.
  void validateRegistry() {
    final seenIds = <String>{};
    for (final m in _modules.values) {
      if (m.id.isEmpty) {
        throw StateError('Module with empty ID encountered');
      }
      if (seenIds.contains(m.id)) {
        throw StateError('Duplicate module ID found: ${m.id}');
      }
      seenIds.add(m.id);

      if (m.isLaunchable && (m.route == null || m.route!.isEmpty)) {
        throw StateError('Launchable module "${m.id}" must have a valid route.');
      }
      if (m.keywords.isEmpty && m.status == ModuleStatus.stable) {
        throw StateError('Stable module "${m.id}" must have search keywords defined.');
      }
    }
  }
}
