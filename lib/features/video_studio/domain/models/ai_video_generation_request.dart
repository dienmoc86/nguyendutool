/// Supported AI video generation backend services.
enum AiVideoBackend {
  openSora(
    'Open-Sora GPU Server (HPC-AI Tech)',
    'Kết nối tới máy chủ GPU chạy Open-Sora (PyTorch / FastAPI / Gradio / Colab)',
  ),
  replicate(
    'Replicate Cloud Diffusion',
    'Dịch vụ điện toán đám mây AI sinh video chất lượng cao',
  ),
  custom(
    'Tùy chỉnh Endpoint REST',
    'Địa chỉ máy chủ cục bộ hoặc server trường học',
  );

  final String displayName;
  final String description;
  const AiVideoBackend(this.displayName, this.description);
}

/// Request parameters for generating an AI video clip from text.
class AiVideoGenerationRequest {
  final String prompt;
  final String? negativePrompt;
  final AiVideoBackend backend;
  final String serverUrl;
  final String? apiKey;
  final double durationSeconds;
  final String aspectRatio; // '16:9', '9:16', '1:1'
  final String resolution; // '480p', '720p', '1080p'
  final int fps;

  const AiVideoGenerationRequest({
    required this.prompt,
    this.negativePrompt,
    this.backend = AiVideoBackend.openSora,
    this.serverUrl = 'http://127.0.0.1:8000',
    this.apiKey,
    this.durationSeconds = 4.0,
    this.aspectRatio = '16:9',
    this.resolution = '720p',
    this.fps = 24,
  });

  Map<String, dynamic> toJson() => {
        'prompt': prompt,
        'negative_prompt': negativePrompt,
        'backend': backend.name,
        'server_url': serverUrl,
        'duration_seconds': durationSeconds,
        'aspect_ratio': aspectRatio,
        'resolution': resolution,
        'fps': fps,
      };
}
