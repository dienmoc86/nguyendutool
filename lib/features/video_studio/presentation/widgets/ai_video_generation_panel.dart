import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../application/video_studio_providers.dart';
import '../../domain/models/ai_video_generation_request.dart';
import '../../infrastructure/open_sora_video_service.dart';

/// Desktop panel for generating AI video clips via Open-Sora and AI Diffusion models.
class AiVideoGenerationPanel extends ConsumerStatefulWidget {
  const AiVideoGenerationPanel({super.key});

  @override
  ConsumerState<AiVideoGenerationPanel> createState() => _AiVideoGenerationPanelState();
}

class _AiVideoGenerationPanelState extends ConsumerState<AiVideoGenerationPanel> {
  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _serverUrlController = TextEditingController(text: 'http://127.0.0.1:8000');
  final TextEditingController _apiKeyController = TextEditingController();

  AiVideoBackend _selectedBackend = AiVideoBackend.openSora;
  double _durationSeconds = 5.0;
  bool _isGenerating = false;
  double _generationProgress = 0.0;
  String _generationStage = '';
  String? _lastGeneratedVideoPath;
  String? _connectionStatus;
  bool _isTestingConnection = false;

  static const List<String> _quickPrompts = [
    'Thí nghiệm Hóa học: phản ứng đổi màu dung dịch trong ống nghiệm phát sáng',
    'Vũ trụ học: Trái đất và các hành tinh quay quanh Mặt trời trong không gian',
    'Sinh học: Cấu tạo tế bào sống phóng đại hiển vi 3D chân thực',
    'Lịch sử: Tàu thuyền buồm căng gió lướt sóng trên Vịnh Hạ Long',
    'Toán học: Đồ thị hàm số không gian 3 chiều uốn lượn mượt mà',
  ];

  @override
  void dispose() {
    _promptController.dispose();
    _serverUrlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTestingConnection = true;
      _connectionStatus = null;
    });

    final ok = await OpenSoraVideoService.instance.testConnection(
      _serverUrlController.text,
      apiKey: _apiKeyController.text,
    );

    if (mounted) {
      setState(() {
        _isTestingConnection = false;
        _connectionStatus = ok
            ? 'Đã kết nối thành công tới GPU Server!'
            : 'Máy chủ chưa bật (Sẽ tự động dùng bộ dựng mô phỏng nội bộ)';
      });
    }
  }

  Future<void> _startGenerate() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập kịch bản hoặc mô tả cảnh video muốn tạo.')),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _generationProgress = 0.05;
      _generationStage = 'Khởi tạo tiến trình Open-Sora...';
      _lastGeneratedVideoPath = null;
    });

    final project = ref.read(videoStudioNotifierProvider).currentProject;
    final req = AiVideoGenerationRequest(
      prompt: prompt,
      backend: _selectedBackend,
      serverUrl: _serverUrlController.text,
      apiKey: _apiKeyController.text,
      durationSeconds: _durationSeconds,
      aspectRatio: project.aspectRatio.ratioString,
    );

    try {
      final videoPath = await OpenSoraVideoService.instance.generateVideo(
        request: req,
        onProgress: (p, stage) {
          if (mounted) {
            setState(() {
              _generationProgress = p;
              _generationStage = stage;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isGenerating = false;
          _lastGeneratedVideoPath = videoPath;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tạo video AI thành công!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _generationStage = 'Lỗi: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể tạo video: $e')),
        );
      }
    }
  }

  void _insertIntoTimeline() {
    if (_lastGeneratedVideoPath == null || !File(_lastGeneratedVideoPath!).existsSync()) {
      return;
    }

    final notifier = ref.read(videoStudioNotifierProvider.notifier);
    notifier.addAiGeneratedScene(
      videoPath: _lastGeneratedVideoPath!,
      prompt: _promptController.text.trim().isEmpty ? 'Cảnh video AI' : _promptController.text.trim(),
      durationSeconds: _durationSeconds,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã chèn video AI vào Timeline dự án!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Badge
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.moduleVideo.withOpacity(0.2),
                  Colors.purpleAccent.withOpacity(0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.moduleVideo.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, color: Colors.purpleAccent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Open-Sora AI Video Generator',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        'Sinh video minh họa bài giảng từ mô tả văn bản (HPC-AI Tech).',
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Backend Selector
          const Text('Động cơ AI:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          DropdownButtonFormField<AiVideoBackend>(
            value: _selectedBackend,
            isDense: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            items: AiVideoBackend.values.map((b) {
              return DropdownMenuItem(
                value: b,
                child: Text(b.displayName, style: const TextStyle(fontSize: 12)),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedBackend = val);
            },
          ),
          const SizedBox(height: 10),

          // Server Endpoint URL
          const Text('Địa chỉ máy chủ GPU (Server URL):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _serverUrlController,
                  style: const TextStyle(fontSize: 12),
                  decoration: const InputDecoration(
                    hintText: 'http://127.0.0.1:8000',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              OutlinedButton(
                onPressed: _isTestingConnection ? null : _testConnection,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  visualDensity: VisualDensity.compact,
                ),
                child: _isTestingConnection
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Kiểm tra', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
          if (_connectionStatus != null) ...[
            const SizedBox(height: 4),
            Text(
              _connectionStatus!,
              style: TextStyle(
                fontSize: 11,
                color: _connectionStatus!.contains('thành công') ? Colors.greenAccent : Colors.orangeAccent,
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Text Prompt Input
          const Text('Kịch bản / Mô tả cảnh video:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          TextField(
            controller: _promptController,
            maxLines: 3,
            style: const TextStyle(fontSize: 12),
            decoration: const InputDecoration(
              hintText: 'Ví dụ: Thí nghiệm tạo kết tủa hóa học trong cốc thủy tinh phát sáng...',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(10),
            ),
          ),
          const SizedBox(height: 8),

          // Quick Suggestion Chips
          const Text('Gợi ý chủ đề nhanh:', style: TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: _quickPrompts.map((p) {
              return ActionChip(
                label: Text(
                  p.split(':').first,
                  style: const TextStyle(fontSize: 11),
                ),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                onPressed: () {
                  _promptController.text = p;
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // Duration Slider
          Row(
            children: [
              Text('Thời lượng: ${_durationSeconds.toStringAsFixed(0)} giây',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const Spacer(),
            ],
          ),
          Slider(
            value: _durationSeconds,
            min: 2.0,
            max: 15.0,
            divisions: 13,
            label: '${_durationSeconds.toStringAsFixed(0)}s',
            activeColor: AppColors.moduleVideo,
            onChanged: (val) => setState(() => _durationSeconds = val),
          ),
          const SizedBox(height: 8),

          // Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isGenerating ? null : _startGenerate,
              icon: _isGenerating
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_awesome_rounded, size: 18),
              label: Text(_isGenerating ? 'Đang sinh video...' : 'Tạo Video bằng AI'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.moduleVideo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),

          // Generation Status & Progress
          if (_isGenerating || _generationStage.isNotEmpty) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(value: _generationProgress > 0 ? _generationProgress : null),
            const SizedBox(height: 4),
            Text(_generationStage, style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ],

          // Result Card
          if (_lastGeneratedVideoPath != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 18),
                      SizedBox(width: 6),
                      Text('Video AI đã sẵn sàng!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.greenAccent)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Đường dẫn: ${_lastGeneratedVideoPath!}',
                    style: const TextStyle(fontSize: 10, color: Colors.white60),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _insertIntoTimeline,
                      icon: const Icon(Icons.add_to_photos_rounded, size: 16),
                      label: const Text('Chèn vào Timeline Dự án'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
