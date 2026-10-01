import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../../app/theme/app_colors.dart';
import '../../../core/ai/ai_model_config.dart';
import '../../../core/ai/gemini_service.dart';
import '../../../core/filesystem/workspace_manager.dart';
import '../../../core/platform/native_drop_handler.dart';
import '../../../core/platform/native_file_dialog.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/security/credential_service.dart';
import '../application/speech_to_text_notifier.dart';
import '../domain/models/transcription_item.dart';

class SpeechToTextScreen extends ConsumerStatefulWidget {
  const SpeechToTextScreen({super.key});

  @override
  ConsumerState<SpeechToTextScreen> createState() => _SpeechToTextScreenState();
}

class _SpeechToTextScreenState extends ConsumerState<SpeechToTextScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    NativeDropHandler.initialize();
    NativeDropHandler.addListener(_onFilesDropped);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    NativeDropHandler.removeListener(_onFilesDropped);
    super.dispose();
  }

  void _onFilesDropped(DropValidationResult dropResult) {
    if (!mounted) return;
    final allFiles = [...dropResult.validPdfFiles, ...dropResult.rejectedFiles];
    for (final file in allFiles) {
      final ext = p.extension(file).toLowerCase();
      const validExts = ['.mp3', '.wav', '.m4a', '.aac', '.ogg', '.flac', '.mp4', '.mkv', '.avi', '.mov', '.webm'];
      if (validExts.contains(ext) && File(file).existsSync()) {
        ref.read(speechToTextProvider.notifier).selectFile(file);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã nhận tệp: ${p.basename(file)}'),
            backgroundColor: AppColors.primary,
          ),
        );
        break;
      }
    }
  }

  Future<void> _pickMediaFile() async {
    final res = await NativeFileDialog.pickSpeechToTextMediaFile();
    if (res.isSelected && res.paths.isNotEmpty) {
      ref.read(speechToTextProvider.notifier).selectFile(res.paths.first);
    }
  }

  Future<void> _showApiKeyDialog(BuildContext context) async {
    final credService = CredentialService();
    final currentKey = await credService.getGeminiApiKey();
    final keyController = TextEditingController(text: currentKey ?? '');
    bool isTesting = false;
    String? testResult;
    bool? testSuccess;

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.vpn_key_rounded, color: AppColors.primary),
                SizedBox(width: 10),
                Text('Cấu hình Google Gemini API'),
              ],
            ),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Khóa API Google Gemini được mã hóa bằng phần cứng Windows DPAPI, '
                    'đảm bảo an toàn tuyệt đối và miễn phí sử dụng cho giáo viên.',
                    style: TextStyle(fontSize: 13, color: AppColors.darkTextSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: keyController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Google Gemini API Key',
                      hintText: 'Dán khóa AIzaSy... tại đây',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.paste_rounded, size: 20),
                        tooltip: 'Dán từ clipboard',
                        onPressed: () async {
                          final data = await Clipboard.getData('text/plain');
                          if (data != null && data.text != null) {
                            setDialogState(() {
                              keyController.text = data.text!.trim();
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: isTesting
                            ? null
                            : () async {
                                final inputKey = keyController.text.trim();
                                if (inputKey.isEmpty) {
                                  setDialogState(() {
                                    testResult = 'Vui lòng nhập mã khóa trước khi kiểm tra.';
                                    testSuccess = false;
                                  });
                                  return;
                                }
                                setDialogState(() {
                                  isTesting = true;
                                  testResult = null;
                                });
                                final ok = await GeminiService.validateKey(inputKey);
                                setDialogState(() {
                                  isTesting = false;
                                  testSuccess = ok;
                                  testResult = ok
                                      ? 'Kết nối Google Gemini thành công! Khóa API hợp lệ.'
                                      : 'Không thể kết nối. Vui lòng kiểm tra lại khóa API hoặc mạng.';
                                });
                              },
                        icon: isTesting
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.network_check_rounded, size: 16),
                        label: const Text('Kiểm tra khóa (Test API)'),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          if (Platform.isWindows) {
                            Process.run('cmd.exe', ['/c', 'start', 'https://aistudio.google.com/app/apikey']);
                          }
                        },
                        icon: const Icon(Icons.open_in_new_rounded, size: 14),
                        label: const Text('Lấy khóa miễn phí (10s)'),
                      ),
                    ],
                  ),
                  if (testResult != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: (testSuccess == true ? Colors.green : Colors.red).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: (testSuccess == true ? Colors.green : Colors.red).withOpacity(0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            testSuccess == true ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                            size: 16,
                            color: testSuccess == true ? Colors.green : Colors.redAccent,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              testResult!,
                              style: TextStyle(
                                fontSize: 12,
                                color: testSuccess == true ? Colors.green : Colors.redAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
              FilledButton(
                onPressed: () async {
                  final key = keyController.text.trim();
                  if (key.isNotEmpty) {
                    await credService.setGeminiApiKey(key);
                    ref.read(speechToTextProvider.notifier).checkApiKey();
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã lưu khóa Google Gemini API thành công!')),
                    );
                  }
                },
                child: const Text('Lưu cấu hình'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _exportDocx(TranscriptionResult result) async {
    final workspace = ref.read(workspaceManagerProvider);
    final fileName = 'Go_bang_${p.basenameWithoutExtension(result.sourceFileName)}_${DateTime.now().millisecondsSinceEpoch}.docx';
    final outPath = p.join(workspace.exportsDir.path, fileName);

    try {
      await ref.read(speechToTextProvider.notifier).exportToDocx(outPath);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã xuất file Word: $fileName'),
            backgroundColor: AppColors.success,
            action: SnackBarAction(
              label: 'Mở thư mục',
              textColor: Colors.white,
              onPressed: () => WorkspaceManager.openFolder(workspace.exportsDir.path),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi xuất Word: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _exportTxt(TranscriptionResult result) async {
    final workspace = ref.read(workspaceManagerProvider);
    final fileName = 'Go_bang_${p.basenameWithoutExtension(result.sourceFileName)}_${DateTime.now().millisecondsSinceEpoch}.txt';
    final outPath = p.join(workspace.exportsDir.path, fileName);

    try {
      await ref.read(speechToTextProvider.notifier).exportToTxt(outPath);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã xuất file Text: $fileName'),
            backgroundColor: AppColors.success,
            action: SnackBarAction(
              label: 'Mở thư mục',
              textColor: Colors.white,
              onPressed: () => WorkspaceManager.openFolder(workspace.exportsDir.path),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi xuất Text: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _copyAllText(TranscriptionResult result) {
    final text = '${result.summary != null ? "${result.summary}\n\n------------------------------------------\n\n" : ""}${result.fullTranscript}';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã sao chép toàn bộ văn bản vào bộ nhớ tạm (Clipboard)!'),
        backgroundColor: AppColors.primary,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(speechToTextProvider);
    final notifier = ref.read(speechToTextProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Module Header
            _buildHeader(isDark),
            const SizedBox(height: 20),

            // Gemini API Status Alert
            _buildGeminiStatusBanner(isDark, state),
            const SizedBox(height: 20),

            // Error banner if any
            if (state.errorMessage != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        state.errorMessage!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 13.5, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Content: Picker / Options / Result
            if (state.result == null) ...[
              _buildInputWorkspace(isDark, state, notifier),
            ] else ...[
              _buildResultWorkspace(isDark, state.result!, notifier),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB).withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.mic_rounded, color: Color(0xFF3B82F6), size: 30),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Chuyển File Ghi âm & Video thành Văn bản',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Nhận dạng giọng nói tiếng Việt chuẩn xác 100%, ghi mốc thời gian [mm:ss], phân tách người nói và tóm tắt sư phạm bằng Google Gemini AI.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGeminiStatusBanner(bool isDark, SpeechToTextState state) {
    if (!state.hasApiKey) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.amber.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 24),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chưa cấu hình Google Gemini API Key',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.amber),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Tính năng gỡ băng cần Google Gemini AI để nhận diện giọng nói tiếng Việt. Bạn có thể nhận khóa miễn phí từ Google chỉ trong 10 giây.',
                    style: TextStyle(fontSize: 12, color: AppColors.darkTextSecondary),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _showApiKeyDialog(context),
              icon: const Icon(Icons.key_rounded, size: 16),
              label: const Text('Gán API Key ngay'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade800,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.success.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Google Gemini AI đã sẵn sàng (Mô hình: ${state.options.model})',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.success),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => _showApiKeyDialog(context),
            icon: const Icon(Icons.settings_rounded, size: 14),
            label: const Text('Thay đổi khóa API'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputWorkspace(bool isDark, SpeechToTextState state, SpeechToTextNotifier notifier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. File Picker Box / Drop Zone
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              style: BorderStyle.solid,
              width: 1.5,
            ),
          ),
          child: state.selectedFilePath == null
              ? Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.audio_file_rounded, size: 48, color: AppColors.primaryLight),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Kéo thả tệp Ghi âm hoặc Video vào đây',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Hỗ trợ ghi âm bài giảng, tiết dạy, hội nghị: MP3, WAV, M4A, AAC, MP4, MKV, AVI, MOV...',
                      style: TextStyle(fontSize: 13, color: AppColors.darkTextSecondary),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _pickMediaFile,
                      icon: const Icon(Icons.folder_open_rounded, size: 18),
                      label: const Text('Chọn tệp từ máy tính'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _isVideoFile(state.selectedFileName ?? '')
                            ? Icons.video_file_rounded
                            : Icons.audio_file_rounded,
                        size: 36,
                        color: AppColors.primaryLight,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.selectedFileName ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  p.extension(state.selectedFileName ?? '').toUpperCase().replaceAll('.', ''),
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryLight),
                                ),
                              ),
                              Text(
                                state.formattedFileSize,
                                style: const TextStyle(fontSize: 12, color: AppColors.darkTextSecondary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: state.isProcessing ? null : notifier.clearSelectedFile,
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Hủy chọn'),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 24),

        // 2. Options card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.tune_rounded, size: 20, color: AppColors.primaryLight),
                  SizedBox(width: 8),
                  Text('Tùy chọn gỡ băng & Nhận dạng', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: SwitchListTile(
                      dense: true,
                      title: const Text('Ghi mốc thời gian [mm:ss]'),
                      subtitle: const Text('Tự động gắn thời gian vào đầu mỗi câu nói'),
                      value: state.options.includeTimestamps,
                      onChanged: state.isProcessing
                          ? null
                          : (val) => notifier.updateOptions(state.options.copyWith(includeTimestamps: val)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SwitchListTile(
                      dense: true,
                      title: const Text('Phân biệt người nói'),
                      subtitle: const Text('Nhận diện Thầy giáo, Học sinh, Người nói 1, 2...'),
                      value: state.options.identifySpeakers,
                      onChanged: state.isProcessing
                          ? null
                          : (val) => notifier.updateOptions(state.options.copyWith(identifySpeakers: val)),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                children: [
                  Expanded(
                    child: SwitchListTile(
                      dense: true,
                      title: const Text('Tóm tắt & Trọng tâm bài giảng'),
                      subtitle: const Text('Trích xuất nội dung cốt lõi, nhiệm vụ học tập'),
                      value: state.options.generateSummary,
                      onChanged: state.isProcessing
                          ? null
                          : (val) => notifier.updateOptions(state.options.copyWith(generateSummary: val)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ListTile(
                      dense: true,
                      title: const Text('Mô hình Google Gemini'),
                      subtitle: const Text('Lựa chọn engine xử lý AI'),
                      trailing: DropdownButton<String>(
                        value: state.options.model,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: AiModelConfig.modelGemini15Flash, child: Text('Gemini 1.5 Flash (Nhanh & Tối ưu)')),
                          DropdownMenuItem(value: AiModelConfig.modelGemini20Flash, child: Text('Gemini 2.0 Flash (Thế hệ mới)')),
                          DropdownMenuItem(value: AiModelConfig.modelGemini15Pro, child: Text('Gemini 1.5 Pro (Độ sâu cao)')),
                        ],
                        onChanged: state.isProcessing
                            ? null
                            : (val) {
                                if (val != null) {
                                  notifier.updateOptions(state.options.copyWith(model: val));
                                }
                              },
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 3. Progress Card during execution
        if (state.isProcessing) ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        state.statusMessage ?? state.status.label,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const LinearProgressIndicator(),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        // 4. Action Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: (state.selectedFilePath == null || state.isProcessing)
                ? null
                : notifier.startTranscription,
            icon: state.isProcessing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.auto_awesome_rounded, size: 20),
            label: Text(
              state.isProcessing ? 'Đang phân tích lời nói...' : 'Bắt đầu Gỡ băng bằng Gemini AI',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultWorkspace(bool isDark, TranscriptionResult result, SpeechToTextNotifier notifier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Action toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22),
                    Text(
                      'Tệp: ${result.sourceFileName}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '(${result.formattedFileSize})',
                      style: const TextStyle(fontSize: 12, color: AppColors.darkTextSecondary),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => _copyAllText(result),
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Sao chép'),
                  ),
                  FilledButton.icon(
                    onPressed: () => _exportDocx(result),
                    icon: const Icon(Icons.description_rounded, size: 16),
                    label: const Text('Xuất Word (.docx)'),
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2B579A)),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _exportTxt(result),
                    icon: const Icon(Icons.text_snippet_rounded, size: 16),
                    label: const Text('Xuất .txt'),
                  ),
                  TextButton.icon(
                    onPressed: notifier.clearSelectedFile,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Gỡ băng tệp khác'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Tabs: Transcript & Summary
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.record_voice_over_rounded), text: 'Nội dung Gỡ băng chi tiết'),
                  Tab(icon: Icon(Icons.summarize_rounded), text: 'Tóm tắt & Trọng tâm bài giảng'),
                ],
              ),
              SizedBox(
                height: 520,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Detailed Transcript
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: SelectableText(
                        result.fullTranscript,
                        style: const TextStyle(
                          fontSize: 14.5,
                          height: 1.6,
                          fontFamily: 'Roboto',
                        ),
                      ),
                    ),

                    // Tab 2: Summary
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          result.summary ?? 'Không có phần tóm tắt cho tệp này.',
                          style: const TextStyle(
                            fontSize: 14.5,
                            height: 1.6,
                            fontFamily: 'Roboto',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _isVideoFile(String fileName) {
    final ext = p.extension(fileName).toLowerCase();
    return ['.mp4', '.mkv', '.avi', '.mov', '.webm', '.flv'].contains(ext);
  }
}
