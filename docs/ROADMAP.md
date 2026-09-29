# Official Project Roadmap (Phase 0 - 5)

**Dự án:** NguyenDu Tool  
**Phiên bản hiện tại:** `1.4.0+6`  
**Giai đoạn hiện tại:** **Phase 4 — Video Studio (CURRENT)**  

---

## Phase 0: Foundation & App Shell — COMPLETED
- Modular Clean Architecture.
- Local SQLite database & migrations (v1).
- File Workspace Manager.
- Centralized Logger with rotation and secret protection.
- Job / Task infrastructure.
- Provider abstraction & registry.
- Full desktop responsive UI shell (Dashboard, Module Shells, File Library, Settings).
- Automated test suites passing.
- Windows release build passing.

---

## Phase 1: PDF/OCR/Word/Excel — COMPLETED
- Native PDF parser & text layer extractor.
- Local OCR integration (Windows Native WinRT OCR engine with explicit fallback consent).
- Table detection and cell grid reconstructor.
- Output generator: `.docx` (Microsoft Word) and `.xlsx` (Microsoft Excel) preserving layout, fonts, and tables.
- Batch document processing queue.
- SQLite migration v1 → v2.
- 100% acceptance tests passed.

---

## Phase 2: Document Scanner — COMPLETED WITH HARDWARE VALIDATION PENDING
- Windows Image Acquisition (WIA 2.0) interface for flatbed and ADF scanners.
- Multi-format image import (JPG, PNG, BMP, TIFF, WebP) with EXIF orientation baking.
- PDF rasterization import into scan sessions.
- Windows Camera / Webcam capture abstraction.
- Computer Vision document processing pipeline:
  - Document boundary detection (Sobel edge & sanity checks).
  - 4-point perspective correction (Homography warp & manual corner adjustment handles).
  - Deskew (±10°) and canonical orientation pipeline (0°, 90°, 180°, 270°).
  - Otsu binarization, shadow/lighting normalization, blank & duplicate page detection.
- Searchable PDF generation (ISO 32000 compliant: JPEG raster + invisible text layer `3 Tr` with `/ActualText` UTF-16BE spans).
  - *Validated structurally and against tested readers/tools (Adobe Acrobat Reader, Microsoft Edge PDF Viewer, Google Chrome PDF Viewer, Foxit Reader, PDF.js).*
- SQLite migration v2 → v3 (`scan_sessions`, `scan_pages`, `scan_profiles`).
- 25-page genuine raster OCR stress test passed.

---

## Phase 3: Text to Speech (TTS) — COMPLETED WITH REMEDIATION
- Educational speech synthesizer for Vietnamese and multilingual text.
- Offline Windows Native SpeechSynthesizer provider (SAPI / OneCore voices with strict identity verification and zero silent fallback).
- Cloud provider architecture adapters (Google Cloud TTS, Microsoft Azure Speech) with masked secrets.
- Input sources: Manual text, TXT (UTF-8/BOM), DOCX (OpenXML text extraction), PDF (text/OCR extraction), Document Library items.
- Conservative Vietnamese text normalization (dates, percentages, times, numbers, acronyms, raw/normalized separation).
- Intelligent sentence and paragraph text chunking with provider character limits.
- Resumable synthesis and retry mechanism for long documents.
- True audio exports: uncompressed WAV (PCM RIFF) and native MP3 encoding.
- Reusable FFmpeg foundation service (`FfmpegService`).
- Internal audio player with play/pause/stop/seek controls.
- Automatic subtitle generation (.srt and .vtt) in Vietnamese UTF-8 with honest chunk-level timing tags (`isEstimated: true`).
- SQLite migration v3 → v4 (`tts_jobs`, `tts_chunks`, `tts_presets`, `pronunciation_dictionary`).
- 20,000-character stress test synthesized 100% through genuine Windows Speech engine.

---

## Phase 4: Video Studio — CURRENT
- Local-first Video Production pipeline powered by FFmpeg & FFprobe 8.0.1.
- VideoProject model, persistence (`projects/video/<projectId>/project.json`), and SQLite migration v4 → v5.
- Media import: Images (JPG, PNG, WEBP), Videos (MP4, MOV, MKV), Audio (WAV, MP3), Subtitles (SRT, VTT).
- Image scenes with Fit/Fill/Crop, blurred background, Ken Burns motion (Zoom In, Zoom Out, Pan Left, Pan Right).
- Video clips with trim, audio control, fit/crop.
- Desktop timeline UI: Scene strip, durations, transitions, audio tracks, preview canvas (16:9, 9:16, 1:1, 4:3).
- Vietnamese titles and text overlays with Segoe UI Unicode rendering and safe escaping.
- Reusing Phase 3 TTS for scene voiceovers and auto-scene duration from voice length.
- Burn-in subtitles and external SRT/VTT export.
- Background music with real audio ducking presets (Off, Light, Medium, Strong) via FFmpeg sidechain filters.
- Real-time FFmpeg progress parsing (`-progress pipe:1`) and reliable process cancellation without orphan processes.
- 10-scene stress test and >=3-minute video export validation.

---

## Phase 5: Production Hardening, Packaging & Auto-Update
- Windows DPAPI credential manager integration for secure API key storage.
- Inno Setup / MSIX installer creation with digital code-signing.
- Background auto-updater (GitHub Releases / custom manifest).
- Performance tuning, memory optimization, and enterprise school distribution guidelines.
