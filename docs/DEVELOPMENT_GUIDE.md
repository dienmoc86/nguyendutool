# Development & Engineering Guide

## 1. Prerequisites
- **Flutter SDK**: 3.24.5 or newer (`channel stable`).
- **Dart SDK**: 3.5.4 or newer.
- **Visual Studio**: Visual Studio Build Tools 2022 / 2026 with "Desktop development with C++" workload and Windows 10/11 SDK.
- **Windows OS**: Windows 10/11 x64.

---

## 2. Setting Up the Environment

1. Clone or open the repository:
   ```bash
   cd "d:\CODE\Nguyen Du tool"
   ```

2. Enable Windows desktop support if not already enabled:
   ```bash
   flutter config --enable-windows-desktop
   ```

3. Fetch dependencies:
   ```bash
   flutter pub get
   ```

---

## 3. Running in Debug Mode
Launch the application on Windows:
```bash
flutter run -d windows
```

---

## 4. Code Quality & Static Analysis
Check the codebase for any analyzer issues or lints:
```bash
flutter analyze
```

---

## 5. Running the Test Suite
Execute all 22 unit tests and widget smoke tests:
```bash
flutter test
```
To run a specific test suite:
```bash
flutter test test/unit/workspace_manager_test.dart
flutter test test/widget/dashboard_smoke_test.dart
```

---

## 6. Building the Release Executable
Compile the optimized native x64 Windows application:
```bash
flutter build windows --release
```
The output binary will be located at:
`build\windows\x64\runner\Release\ischool_tools.exe`

---

## 7. Adding a New Engine Provider
To add a new AI, OCR, TTS, or Video engine:
1. Inherit from `AiProvider`, `OcrProvider`, `TtsProvider`, or `VideoProvider` in `lib/core/providers/`.
2. Implement required contracts and `checkHealth()`.
3. Register the instance in `ProviderRegistry._registerDefaults()` or dynamically via `ref.read(providerRegistryProvider).register(newProvider)`.
