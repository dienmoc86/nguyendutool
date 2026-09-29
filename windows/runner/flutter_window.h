#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>

#include <memory>

#include "win32_window.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <shellapi.h>
#include <shobjidl.h>

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

  // Handles files dropped onto the window via Win32 shell drag-and-drop.
  void HandleDropFiles(HDROP hDrop);

  // Handles native COM file dialog requests (Requirement 16).
  void HandleNativeFileDialog(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // Method channel for native drag-and-drop file delivery.
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> drop_channel_;

  // Method channel for native COM file dialogs (Requirement 16).
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> dialog_channel_;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
