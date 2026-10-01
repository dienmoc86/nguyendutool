# NguyenDu Tool - Windows Desktop Application

> **Bộ công cụ máy tính đa năng dành cho giáo viên, nhà trường và văn phòng giáo dục.**  
> Chuyển đổi tài liệu PDF/Office • Nhận diện OCR tiếng Việt • Số hóa tài liệu • Giọng đọc AI • Sản xuất Video bài giảng.

---

## 1. Project Overview
**NguyenDu Tool** là ứng dụng Windows Desktop chuẩn **Local-First**, được xây dựng với mục tiêu cung cấp giải pháp chuyển đổi tài liệu, số hóa văn bản giáo dục, tạo giọng nói nhân tạo và dựng bài giảng tự động cho các thầy cô và cán bộ nhà trường mà không phụ thuộc vào nền tảng đám mây hay mạng internet.

- **Phiên bản hiện tại:** `1.6.0+9` (Phát hành chính thức bởi iBest Group)
- **Giai đoạn hiện tại:** **Phase 6A — Product Expansion Foundation (CURRENT)**
- **Lộ trình mở rộng chính thức (Product Roadmap):**
  - **Phase 0 (Foundation Architecture):** HOÀN THÀNH (PASS)
  - **Phase 1 (PDF / OCR / Office):** HOÀN THÀNH (PASS)
  - **Phase 2 (Scanner & Searchable PDF):** HOÀN THÀNH (PASS)
  - **Phase 3 (Text-to-Speech & Subtitles):** HOÀN THÀNH (PASS)
  - **Phase 4 (Video Studio Engine):** HOÀN THÀNH (PASS)
  - **Phase 5 (Production Hardening & RC Gate):** HOÀN THÀNH (PASS)
  - **Phase 6A (Product Expansion Foundation):** ĐANG TRIỂN KHAI (CURRENT)
  - **Phase 6B (Lesson Planner & Teaching Suite Completion):** Kế hoạch tiếp theo
  - **Phase 7 (Assessment / Quiz / Worksheet Studio):** Kế hoạch
  - **Phase 8 (Presentation / PowerPoint Studio):** Kế hoạch
  - **Phase 9 (PDF Toolbox + Office Utilities):** Kế hoạch
  - **Phase 10 (Speech-to-Text + Subtitle Studio):** Kế hoạch
  - **Phase 11 (NguyenDu AI Assistant / Document Q&A):** Kế hoạch
  - **Future (School Utility Pack & Administration):** Dự kiến
- **Nền tảng chính:** Windows Desktop x64 (Windows 10 Build 19041+ / Windows 11)
- **Công nghệ lõi:** Flutter Desktop, Dart 3.5.4, SQLite FFI (Schema v6), Riverpod 2.6.1, GoRouter, Archive (ECMA-376 OpenXML), Windows DPAPI, Windows Runtime APIs (Windows.Data.Pdf, Windows.Media.Ocr, System.Speech), FFmpeg & FFprobe 8.0.1 đóng gói sẵn.

---

## 2. Core Functional Modules
1. **PDF → Word / Excel (Hoàn thành Phase 1):**
   - Phân loại tài liệu thông minh: Văn bản số (`text`), tài liệu scan (`scanned`), hỗn hợp (`mixed`).
   - Kết xuất trang PDF độ phân giải cao qua Windows.Data.Pdf API.
   - Động cơ OCR ngoại tuyến tiếng Việt với bộ hậu xử lý ghép từ gãy dòng, chuẩn hóa dấu thanh và ngày tháng/số liệu.
   - Nhận diện và tái tạo bảng biểu (`TableDetector`).
   - Xuất file Microsoft Word (`.docx`) và Microsoft Excel (`.xlsx`) thuần OpenXML (ECMA-376) mà không cần cài Microsoft Office.
2. **Document Scanner (Hoàn thành Phase 2):**
   - Kết nối máy quét qua Windows Image Acquisition (WIA).
   - Nhập tệp ảnh đa định dạng (JPG, PNG, BMP, TIFF, WebP), tài liệu PDF, chụp camera tài liệu.
   - Xử lý thị giác máy tính: Tự động căn thẳng, chống nghiêng (deskew), khử bóng đổ và cân bằng ánh sáng.
   - Xuất Searchable PDF nhị phân với lớp ảnh raster và lớp chữ vô hình (`3 Tr`) chuẩn ISO 32000.
3. **Text to Speech (Hoàn thành Phase 3):**
   - Chuyển văn bản giáo án, bài đọc thành giọng nói tự nhiên qua Windows SAPI Desktop và WinRT OneCore offline synthesis.
   - Chuẩn hóa văn bản tiếng Việt bảo thủ (ngày tháng, tiền tệ, số đo, viết tắt).
   - Tự động phân đoạn thông minh (`RuleBasedTextChunker`).
   - Xuất file âm thanh WAV PCM và MP3 chuẩn mã hóa FFmpeg kèm phụ đề SRT/VTT.
4. **Video Studio (Hoàn thành Phase 4):**
   - Dựng video clip bài giảng, thông báo nhà trường, slideshow ảnh hoạt động, video thuyết trình.
   - Kết hợp hình ảnh, video clip, giọng đọc thuyết minh TTS, phụ đề chữ cứng (burn-in subtitles), nhạc nền và audio ducking.
   - Động cơ kết xuất cục bộ hoàn toàn qua FFmpeg 8.0.1 đóng gói sẵn.
5. **Thư viện tài liệu (Document Library):** Quản lý tập trung mọi tài liệu, sản phẩm xuất trong thư mục Workspace cục bộ.
6. **Bảo mật & Cài đặt hệ thống (Phase 5 Hardening):**
   - Bảo mật khóa API bằng Windows DPAPI (CurrentUser scope).
   - Giao diện hướng dẫn ban đầu (First-Run Wizard) và Chẩn đoán hệ thống (System Diagnostics).
   - Tự động sao lưu cơ sở dữ liệu (Database rolling backups) và phục hồi khi lỗi.
   - Trình cài đặt chuẩn Windows (Inno Setup) và bản di động (Portable ZIP).

---

## 3. Architecture & Principles
Ứng dụng tuân theo mô hình **Modular Clean Architecture**:
- Ranh giới giữa các module độc lập tuyệt đối.
- Quản lý tệp cục bộ có cấu trúc thông qua `WorkspaceManager` (`%USERPROFILE%\Documents\NguyenDu Tool\`).
- Cơ sở dữ liệu SQLite cục bộ (`nguyendu_tool.db`) với hệ thống lược đồ **Schema v5**.

```
lib/
├── app/                  # Application Shell, Router, Theme & Bootstrap
├── core/                 # Core Foundation Services
│   ├── database/         # SQLite persistence (Schema v5), auto-backups & recovery
│   ├── diagnostics/      # SystemDiagnosticsService & live probes
│   ├── errors/           # AppException hierarchy & CrashHandler
│   ├── filesystem/       # WorkspaceManager & file utilities
│   ├── jobs/             # Job system (Model, Repo, Notifier)
│   ├── logging/          # Centralized AppLogger with secret masking
│   ├── media/            # FfmpegService & bundled binary discovery
│   ├── platform/         # SingleInstanceGuard & Windows STA file picker
│   ├── providers/        # Provider abstraction & registry
│   ├── recovery/         # CrashRecoveryService & safe temp cleanup
│   ├── security/         # WindowsDpapiSecureStorage (dart:ffi calling crypt32.dll)
│   ├── settings/         # AppSettings storage & state
│   └── update/           # Secure UpdateService (HTTPS & SHA256 integrity)
├── features/             # Feature Modules
│   ├── dashboard/        # Welcome overview, metrics, cards & recent jobs
│   ├── pdf_converter/    # PDF Analyzer, OCR Engine, Table Detector, DOCX/XLSX
│   ├── scanner/          # Document Scanner module
│   ├── text_to_speech/   # TTS synthesis module
│   ├── video_studio/     # Slide video composer module
│   ├── file_library/     # Workspace file explorer & actions
│   ├── settings/         # System configuration & System Diagnostics
│   └── shell/            # TopBar, Sidebar, AppShell & FirstRunWizard
└── main.dart             # Resilient startup entrypoint with runZonedGuarded
```

---

## 4. Cài đặt & Phân phối (Release Distribution)
Các tệp phát hành chính thức được lưu trữ tại `release/1.5.0/`:
- **Bộ cài đặt Setup (Inno Setup)**: `NguyenDuTool_Setup_1.5.0.exe` (Cài đặt theo người dùng, không cần quyền Admin).
- **Bản nén di động (Portable)**: `NguyenDuTool_Portable_1.5.0.zip` (Chạy trực tiếp, phù hợp phòng lab / USB).
- **Bảng mã băm xác thực**: `SHA256SUMS.txt`.
- **Siêu dữ liệu phát hành**: `RELEASE_MANIFEST.json`.
