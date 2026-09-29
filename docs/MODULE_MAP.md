# Module Map & Feature Registry

**Dự án:** NguyenDu Tool  
**Phiên bản:** `1.3.0+5`  
**Giai đoạn hiện tại:** **Phase 3 — Text to Speech**  

This document lists the architectural mapping of features and their planned phase implementations.

| Module | Route | Primary Class | Associated Job Type | Planned Phase | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Trang chủ (Dashboard)** | `/` | `DashboardScreen` | All (Monitor) | Phase 0 | **Active (Completed)** |
| **PDF / Office Converter** | `/pdf-converter` | `PdfConverterScreen` | `pdfConvert`, `ocr` | Phase 1 | **Active (Completed)** |
| **Document Scanner** | `/scanner` | `ScannerScreen` | `scanProcess` | Phase 2 | **Active (Completed with HW Pending)** |
| **Text to Speech** | `/text-to-speech` | `TextToSpeechScreen` | `ttsGenerate` | Phase 3 | **CURRENT (In Progress)** |
| **Video Studio** | `/video-studio` | `VideoStudioScreen` | `videoRender` | Phase 4 | **Architecture Shell Ready** |
| **Thư viện tài liệu** | `/file-library` | `FileLibraryScreen` | N/A | Phase 0 | **Active (Completed)** |
| **Cài đặt hệ thống** | `/settings` | `SettingsScreen` | N/A | Phase 0 | **Active (Completed)** |

---

## Module Boundary Architecture

```
lib/features/<module_name>/
├── presentation/         # Widgets, Screen, Dialogs, State consumption
│   ├── <module>_screen.dart
│   └── widgets/
│
├── application/          # StateNotifier, Use cases, Orchestration
│   └── <module>_notifier.dart
│
├── domain/               # Entity models, Value objects, Pure contracts
│   ├── <model>.dart
│   └── <entity>.dart
│
└── infrastructure/       # Specific repositories, platform adapters
    └── <module>_service.dart
```

When building Phase 3 (Text to Speech), code resides inside `lib/features/tts/` (and alias `lib/features/text_to_speech/`) following clean architectural boundaries without modifying unrelated core features.
