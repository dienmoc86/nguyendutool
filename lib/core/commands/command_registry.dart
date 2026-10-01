import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/router/routes.dart';
import '../logging/app_logger.dart';
import 'app_command.dart';

/// Central registry managing all executable actions and navigation commands in NguyenDu Tool.
class CommandRegistry {
  CommandRegistry._();
  static final CommandRegistry instance = CommandRegistry._();

  final Map<String, AppCommand> _commands = {};
  bool _initialized = false;

  /// Returns an unmodifiable list of registered commands.
  List<AppCommand> get allCommands => List.unmodifiable(_commands.values);

  /// Initializes default commands based on core modules and standard actions.
  void initializeDefaults() {
    if (_initialized) return;

    // Navigation commands
    register(AppCommand(
      id: 'nav.dashboard',
      title: 'Mở Trang chủ',
      subtitle: 'Trang tổng quan và truy cập nhanh',
      category: 'Điều hướng',
      icon: Icons.dashboard_outlined,
      keywords: ['trang chu', 'home', 'dashboard', 'tong quan'],
      execute: (context) async => context.go(AppRoutes.dashboard),
    ));

    register(AppCommand(
      id: 'nav.lesson_planner',
      title: 'Mở Trợ lý Giáo án',
      subtitle: 'Soạn bài dạy chuẩn Công văn 5512',
      category: 'Giảng dạy',
      icon: Icons.auto_stories_outlined,
      keywords: ['giao an', 'soan bai', 'bai giang', '5512', 'lesson planner', 'ke hoach bai day'],
      execute: (context) async => context.go(AppRoutes.lessonPlanner),
    ));

    register(AppCommand(
      id: 'nav.pdf_converter',
      title: 'Mở Chuyển đổi PDF & Office',
      subtitle: 'Chuyển đổi PDF sang Word, Excel, văn bản',
      category: 'Tài liệu',
      icon: Icons.picture_as_pdf_outlined,
      keywords: ['pdf', 'word', 'docx', 'excel', 'xlsx', 'chuyen doi', 'ocr'],
      execute: (context) async => context.go(AppRoutes.pdfConverter),
    ));

    register(AppCommand(
      id: 'nav.scanner',
      title: 'Mở Máy quét tài liệu',
      subtitle: 'Quét tài liệu từ máy scan hoặc hình ảnh',
      category: 'Tài liệu',
      icon: Icons.document_scanner_outlined,
      keywords: ['scan', 'quet', 'may quet', 'so hoa', 'tai lieu'],
      execute: (context) async => context.go(AppRoutes.scanner),
    ));

    register(AppCommand(
      id: 'nav.tts',
      title: 'Mở Đọc văn bản (TTS)',
      subtitle: 'Chuyển văn bản thành giọng nói nhân tạo',
      category: 'Media',
      icon: Icons.record_voice_over_outlined,
      keywords: ['tts', 'doc van ban', 'giong noi', 'audio', 'mp3', 'phat am'],
      execute: (context) async => context.go(AppRoutes.textToSpeech),
    ));

    register(AppCommand(
      id: 'nav.video',
      title: 'Mở Video Studio',
      subtitle: 'Tạo video bài giảng và thuyết trình',
      category: 'Media',
      icon: Icons.movie_creation_outlined,
      keywords: ['video', 'studio', 'bai giang', 'clip', 'thuyet trinh', 'render'],
      execute: (context) async => context.go(AppRoutes.videoStudio),
    ));

    register(AppCommand(
      id: 'nav.speech_to_text',
      title: 'Mở Gỡ băng Ghi âm & Video',
      subtitle: 'Bóc băng âm thanh, video bài giảng thành văn bản qua Google Gemini',
      category: 'Media',
      icon: Icons.mic_rounded,
      keywords: ['stt', 'go bang', 'ghi am', 'audio to text', 'video to text', 'boc bang', 'phien am', 'gemini'],
      execute: (context) async => context.go(AppRoutes.speechToText),
    ));

    register(AppCommand(
      id: 'nav.library',
      title: 'Mở Thư viện tài liệu',
      subtitle: 'Quản lý tệp, sản phẩm và kết quả đã lưu',
      category: 'Hệ thống',
      icon: Icons.folder_copy_outlined,
      keywords: ['thu vien', 'library', 'tep', 'file', 'da luu', 'tai lieu'],
      execute: (context) async => context.go(AppRoutes.fileLibrary),
    ));

    register(AppCommand(
      id: 'nav.settings',
      title: 'Mở Cài đặt & Chẩn đoán',
      subtitle: 'Cấu hình hệ thống, AI, bản quyền và thông tin',
      category: 'Hệ thống',
      icon: Icons.settings_outlined,
      keywords: ['cai dat', 'settings', 'cau hinh', 'chan doan', 'gioi thieu', 'about'],
      execute: (context) async => context.go(AppRoutes.settings),
    ));

    // Global Action commands
    register(AppCommand(
      id: 'action.new_lesson_plan',
      title: 'Tạo Kế hoạch bài dạy mới',
      subtitle: 'Soạn giáo án mới theo Công văn 5512',
      category: 'Hành động nhanh',
      icon: Icons.add_circle_outline,
      keywords: ['tao giao an', 'soan giao an', 'new lesson', 'bai day moi'],
      execute: (context) async => context.go(AppRoutes.lessonPlanner),
    ));

    register(AppCommand(
      id: 'action.convert_pdf',
      title: 'Chuyển đổi tệp PDF mới',
      subtitle: 'Bắt đầu phiên trích xuất PDF sang Word',
      category: 'Hành động nhanh',
      icon: Icons.file_upload_outlined,
      keywords: ['chuyen pdf', 'convert pdf', 'pdf to docx'],
      execute: (context) async => context.go(AppRoutes.pdfConverter),
    ));

    register(AppCommand(
      id: 'action.new_scan',
      title: 'Bắt đầu phiên quét mới',
      subtitle: 'Quét tài liệu giấy từ máy scanner',
      category: 'Hành động nhanh',
      icon: Icons.scanner_outlined,
      keywords: ['quet moi', 'new scan', 'bat dau quet'],
      execute: (context) async => context.go(AppRoutes.scanner),
    ));

    register(AppCommand(
      id: 'action.new_tts',
      title: 'Tạo giọng đọc mới',
      subtitle: 'Nhập văn bản để đọc thành âm thanh',
      category: 'Hành động nhanh',
      icon: Icons.mic_none_outlined,
      keywords: ['tao giong doc', 'new tts', 'doc moi'],
      execute: (context) async => context.go(AppRoutes.textToSpeech),
    ));

    register(AppCommand(
      id: 'action.new_video',
      title: 'Tạo dự án Video mới',
      subtitle: 'Tạo video bài giảng mới từ slide / hình ảnh',
      category: 'Hành động nhanh',
      icon: Icons.video_call_outlined,
      keywords: ['tao video', 'new video', 'du an video'],
      execute: (context) async => context.go(AppRoutes.videoStudio),
    ));

    register(AppCommand(
      id: 'action.transcribe_media',
      title: 'Gỡ băng Ghi âm / Video',
      subtitle: 'Chọn tệp âm thanh hoặc video để bóc băng và tóm tắt sư phạm',
      category: 'Hành động nhanh',
      icon: Icons.record_voice_over_rounded,
      keywords: ['go bang moi', 'boc bang video', 'transcribe', 'ghi am sang word', 'stt'],
      execute: (context) async => context.go(AppRoutes.speechToText),
    ));

    register(AppCommand(
      id: 'action.new_teaching_project',
      title: 'Tạo dự án Giảng dạy mới',
      subtitle: 'Khởi tạo bài học tổng thể (giáo án, phiếu học tập, câu hỏi, rubric)',
      category: 'Hành động nhanh',
      icon: Icons.post_add_outlined,
      keywords: ['tao bai hoc', 'du an giang day', 'new lesson project', 'soan bai moi'],
      execute: (context) async => context.go(AppRoutes.lessonPlanner),
    ));

    register(AppCommand(
      id: 'action.generate_lesson_plan',
      title: 'Soạn Giáo án Công văn 5512',
      subtitle: 'Trợ lý thiết kế Kế hoạch bài dạy chuẩn Bộ GD&ĐT',
      category: 'Giảng dạy',
      icon: Icons.auto_awesome_outlined,
      keywords: ['soan giao an', 'ke hoach bai day 5512', 'cv 5512', 'lesson plan'],
      execute: (context) async => context.go(AppRoutes.lessonPlanner),
    ));

    register(AppCommand(
      id: 'action.create_worksheet',
      title: 'Tạo Phiếu học tập',
      subtitle: 'Sinh phiếu học tập, bài tập củng cố và thảo luận nhóm',
      category: 'Giảng dạy',
      icon: Icons.assignment_outlined,
      keywords: ['phieu hoc tap', 'worksheet', 'bai tap', 'thao luan'],
      execute: (context) async => context.go(AppRoutes.lessonPlanner),
    ));

    register(AppCommand(
      id: 'action.create_questions',
      title: 'Tạo Ngân hàng câu hỏi & Đề kiểm tra',
      subtitle: 'Bộ câu hỏi trắc nghiệm, tự luận phân tầng theo 4 mức độ',
      category: 'Giảng dạy',
      icon: Icons.quiz_outlined,
      keywords: ['cau hoi', 'trac nghiem', 'ngan hang de', 'questions', 'mini assessment'],
      execute: (context) async => context.go(AppRoutes.lessonPlanner),
    ));

    register(AppCommand(
      id: 'action.create_rubric',
      title: 'Thiết kế Rubric đánh giá',
      subtitle: 'Bảng tiêu chí và mức độ đánh giá năng lực học sinh',
      category: 'Giảng dạy',
      icon: Icons.fact_check_outlined,
      keywords: ['rubric', 'tieu chi', 'danh gia', 'thang do'],
      execute: (context) async => context.go(AppRoutes.lessonPlanner),
    ));

    _initialized = true;
  }

  /// Registers a new command. Throws [ArgumentError] if a command with the same ID already exists.
  ///
  /// To intentionally overwrite an existing command, call [registerOrReplace].
  void register(AppCommand command) {
    if (_commands.containsKey(command.id)) {
      throw ArgumentError(
        'Command with ID "${command.id}" is already registered. '
        'Use registerOrReplace() to explicitly overwrite an existing command.',
      );
    }
    _commands[command.id] = command;
  }

  /// Registers a new command or overwrites an existing command with the same ID.
  void registerOrReplace(AppCommand command) {
    if (_commands.containsKey(command.id)) {
      AppLogger.info('Overwriting existing command with ID: ${command.id}');
    }
    _commands[command.id] = command;
  }

  /// Finds commands matching a query string.
  List<AppCommand> search(String query) {
    final clean = query.trim();
    if (clean.isEmpty) {
      return allCommands;
    }
    return _commands.values.where((cmd) => cmd.matches(clean)).toList();
  }

  /// Validates consistency of all registered commands.
  List<String> validate() {
    final errors = <String>[];
    for (final cmd in _commands.values) {
      if (cmd.id.trim().isEmpty) {
        errors.add('Command has empty ID.');
      }
      if (cmd.title.trim().isEmpty) {
        errors.add('Command "${cmd.id}" has empty title.');
      }
      if (cmd.category.trim().isEmpty) {
        errors.add('Command "${cmd.id}" has empty category.');
      }
    }
    return errors;
  }

  /// Clears all commands (useful for testing).
  @visibleForTesting
  void clear() {
    _commands.clear();
    _initialized = false;
  }
}
