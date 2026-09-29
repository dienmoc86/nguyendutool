# NguyenDu Tool - Architecture Documentation
**Phiên bản:** `1.3.0+5` | **Giai đoạn hiện tại:** `Phase 3 - Text to Speech`

## 1. Executive Architecture Overview
`NguyenDu Tool` (tiền thân là iSchool Tools) is a local-first desktop application designed for teachers, schools, and educational administration offices on Windows (with future cross-platform extensibility). The application follows **Modular Clean Architecture** combined with **Domain-Driven Design (DDD)** and reactive state management powered by **Riverpod**.

```
+-------------------------------------------------------------------------+
|                              App Shell                                  |
|         (TopBar | Collapsible Sidebar | Diagnostic Screen)              |
+-------------------------------------------------------------------------+
|                  Feature Modules (Presentation / UI)                    |
|  [Dashboard] [PDF/Office] [Doc Scanner] [Text to Speech] [Video Studio] |
|                       [File Library] [Settings]                         |
+-------------------------------------------------------------------------+
|                 Application Layer (State / Notifiers)                   |
|       JobNotifier | FileLibraryNotifier | SettingsNotifier              |
+-------------------------------------------------------------------------+
|                   Domain Layer (Entities & Contracts)                   |
|         JobModel | FileEntry | AppSettings | Provider Contracts         |
+-------------------------------------------------------------------------+
|            Core Infrastructure & Data Access (Local-First)              |
|   AppDatabase (SQLite FFI)  |  WorkspaceManager (dart:io Filesystem)    |
|   AppLogger (File & Console) |  SecureStorageService (Protected Vault)   |
|   ProviderRegistry (Local & Cloud Engine Registry)                      |
+-------------------------------------------------------------------------+
```

---

## 2. Layer Definitions & Directory Boundaries

### 2.1. `lib/app/`
Contains the application initialization, routing, theming, and bootstrap logic.
- `app.dart`: Root widget with reactive theme and routing configuration.
- `bootstrap/bootstrap.dart`: Sequential startup orchestrator (`WidgetsBinding` -> `WorkspaceManager` -> `AppLogger` -> `AppDatabase` -> `SettingsRepository` -> `ProviderRegistry`).
- `router/`: Centralized declarative routing using `go_router` with nested `ShellRoute`.
- `theme/`: Design tokens, colors (`AppColors`), dark and light themes (`AppTheme`).

### 2.2. `lib/core/`
Central shared foundation services. None of the core modules depend on feature modules.
- `database/`: Local SQLite persistence via `sqflite_common_ffi` and `sqlite3`.
- `filesystem/`: `WorkspaceManager` managing structured directory trees (`projects`, `imports`, `exports`, `cache`, `temp`, `logs`) and native Windows Explorer integration.
- `logging/`: `AppLogger` supporting console formatting, rotating log file sinks, and automatic secret/token masking.
- `jobs/`: Asynchronous job tracking system (`JobModel`, `JobStatus`, `JobType`, `JobRepository`, `JobNotifier`).
- `settings/`: System preferences and configuration storage.
- `providers/`: Engine abstraction layer (`AiProvider`, `TtsProvider`, `VideoProvider`, `OcrProvider`) and `ProviderRegistry`.
- `errors/`: Structured error hierarchy (`AppException`, `FileException`, `AppDatabaseException`, `ProviderException`, `JobException`) and `ErrorMapper`.

### 2.3. `lib/features/`
Each feature is partitioned into an isolated module containing its own domain, data, and presentation components:
- `dashboard/`: Welcome screen, quick metrics, core module cards, and live recent jobs monitor.
- `pdf_converter/`: Document conversion and layout OCR interface.
- `scanner/`: TWAIN/WIA document scanning and deskewing interface.
- `text_to_speech/`: Educational neural speech synthesis interface.
- `video_studio/`: Slide-to-video rendering and timeline composer interface.
- `file_library/`: Workspace documents metadata explorer with search and Explorer launch.
- `settings/`: Multi-tab system configuration screen.
- `shell/`: Desktop layout shell (`AppShell`, `AppSidebar`, `TopBar`, `StartupDiagnosticScreen`).

---

## 3. Technology Stack Justification
| Component | Technology | Rationale |
| :--- | :--- | :--- |
| **Framework** | Flutter Desktop (Windows x64) | High performance native rendering, desktop ergonomics, zero web runtime overhead. |
| **Language** | Dart 3.5.4 | Null-safe, pattern matching, expressive type system. |
| **Database** | SQLite via `sqflite_common_ffi` | Zero-configuration, ACID compliant local embedded database. |
| **State Management** | Riverpod 2.6.1 | Compile-safe dependency injection, testable provider overrides, reactive updates. |
| **Routing** | `go_router` 15.1.2 | Declarative URL-like navigation, deep linking, nested shell layout. |
| **Logging** | `logger` 2.8.0 + File Sink | Timestamped log rotation with secret masking. |

---

## 4. Key Design Patterns
1. **Repository Pattern**: Hides SQL details from state notifiers.
2. **Registry Pattern**: Decouples UI from concrete OCR/TTS/AI engine implementations.
3. **Local-First Architecture**: All database records and files reside exclusively on user storage.
4. **Resilient Startup**: Errors during bootstrap are trapped and surfaced in `StartupDiagnosticScreen` without silent application crashes.
