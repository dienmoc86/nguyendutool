# Phase 0 Scope - Foundation & App Shell

## 1. Objective of Phase 0
Phase 0 establishes the entire **architectural foundation, workspace lifecycle, local persistence, logging, task infrastructure, and responsive desktop UI shell** for the `iSchool Tools` Windows desktop application.

The primary requirement of Phase 0 is to ensure that all core abstractions, providers, database tables, and navigation shells are firmly in place so that subsequent Phases (1 through 5) can implement deep engine integrations without architectural refactoring.

---

## 2. In Scope (Delivered in Phase 0)
- [x] **Desktop Windows App**: Compiled, executed, and validated on Windows x64.
- [x] **Responsive Desktop UI Shell**:
  - Minimum resolution support: 1366x768, 1920x1080, and 2K.
  - Collapsible desktop sidebar with brand accents.
  - Application top bar with active module titles, live active task indicator, and settings access.
  - Resilient startup diagnostic screen.
- [x] **Dashboard Module**:
  - 4 prominent module cards (PDF Converter, Document Scanner, Text to Speech, Video Studio).
  - Quick statistics overview.
  - Live recent jobs monitoring widget with real-time demo job trigger.
- [x] **Functional Module Placeholders**:
  - Full UI layouts with configurations and controls.
  - "Module đang được chuẩn bị" status banners indicating architectural readiness.
- [x] **Local SQLite Database**:
  - Five core tables (`app_settings`, `projects`, `files`, `jobs`, `providers`).
  - Safe in-memory testing mode and automated migration hooks.
- [x] **File Workspace Manager**:
  - Dedicated `iSchool Tools` directory with subfolders: `projects/`, `imports/`, `exports/`, `cache/`, `temp/`, `logs/`.
  - Windows File Explorer integrations (`openFolder`, `openContainingFolder`).
- [x] **Job / Task Infrastructure**:
  - `JobType` & `JobStatus` lifecycles.
  - `JobRepository` with persistent state updates and progress tracking.
- [x] **Provider Architecture**:
  - Abstract base contracts (`AiProvider`, `TtsProvider`, `VideoProvider`, `OcrProvider`).
  - Central `ProviderRegistry` with registration, enabling, and disabling APIs.
  - Secure storage abstraction ready for Windows DPAPI integration.
- [x] **File Library**:
  - Real-time search filter, metadata management, and Windows Explorer interaction.
- [x] **Centralized Logging**:
  - Log levels (debug, info, warning, error), daily log file rotation, and secret masking.
- [x] **Testing & Verification**:
  - 22 automated unit and widget smoke tests passing.
  - Zero static analysis issues (`flutter analyze` PASS).
  - Native release compilation passing (`flutter build windows --release` PASS).

---

## 3. Explicitly Out of Scope for Phase 0
The following features are reserved for future phases and deliberately excluded to prevent scope creep:
- Heavy OCR engine execution (Tesseract / PaddleOCR / Windows OCR production inference).
- Native PDF to Word (.docx) / Excel (.xlsx) converter engine.
- Production AI video composition and Veo cloud API integration.
- Cloud synchronization and user authentication / accounts.
- School attendance management, eDoc, or student record (học bạ số) modules.
