#include "flutter_window.h"

#include <commctrl.h>
#include <optional>
#include <vector>

#include "flutter/generated_plugin_registrant.h"

namespace {

// Subclass window proc for the child Flutter view to intercept WM_DROPFILES.
static LRESULT CALLBACK ChildDropSubclassProc(
    HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam,
    UINT_PTR uIdSubclass, DWORD_PTR dwRefData) {
  if (uMsg == WM_DROPFILES) {
    auto* window = reinterpret_cast<FlutterWindow*>(dwRefData);
    if (window != nullptr) {
      window->HandleDropFiles(reinterpret_cast<HDROP>(wParam));
    }
    return 0;
  }
  return DefSubclassProc(hwnd, uMsg, wParam, lParam);
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());

  HWND childHwnd = flutter_controller_->view()->GetNativeWindow();
  SetChildContent(childHwnd);

  // Enable native Win32 shell drag-and-drop for both frame and child Flutter view.
  DragAcceptFiles(GetHandle(), TRUE);
  DragAcceptFiles(childHwnd, TRUE);
  SetWindowSubclass(childHwnd, ChildDropSubclassProc, 101, reinterpret_cast<DWORD_PTR>(this));

  drop_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(),
      "nguyendu_tool/native_drop",
      &flutter::StandardMethodCodec::GetInstance());

  dialog_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(),
      "nguyendu_tool/native_file_dialog",
      &flutter::StandardMethodCodec::GetInstance());

  dialog_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        this->HandleNativeFileDialog(call, std::move(result));
      });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_ && flutter_controller_->view()) {
    HWND childHwnd = flutter_controller_->view()->GetNativeWindow();
    RemoveWindowSubclass(childHwnd, ChildDropSubclassProc, 101);
  }
  drop_channel_ = nullptr;
  dialog_channel_ = nullptr;

  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

void FlutterWindow::HandleDropFiles(HDROP hDrop) {
  if (hDrop == nullptr) {
    return;
  }

  UINT fileCount = DragQueryFileW(hDrop, 0xFFFFFFFF, nullptr, 0);
  std::vector<flutter::EncodableValue> fileList;

  for (UINT i = 0; i < fileCount; ++i) {
    UINT length = DragQueryFileW(hDrop, i, nullptr, 0);
    if (length > 0) {
      std::wstring wpath(length + 1, L'\0');
      DragQueryFileW(hDrop, i, &wpath[0], length + 1);
      int utf8Length = WideCharToMultiByte(CP_UTF8, 0, wpath.c_str(), -1, nullptr, 0, nullptr, nullptr);
      if (utf8Length > 0) {
        std::string u8path(utf8Length, '\0');
        WideCharToMultiByte(CP_UTF8, 0, wpath.c_str(), -1, &u8path[0], utf8Length, nullptr, nullptr);
        if (!u8path.empty() && u8path.back() == '\0') {
          u8path.pop_back();
        }
        fileList.push_back(flutter::EncodableValue(u8path));
      }
    }
  }

  DragFinish(hDrop);

  if (drop_channel_ != nullptr && !fileList.empty()) {
    drop_channel_->InvokeMethod("onFilesDropped", std::make_unique<flutter::EncodableValue>(fileList));
  }
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_DROPFILES:
      HandleDropFiles(reinterpret_cast<HDROP>(wparam));
      return 0;

    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

void FlutterWindow::HandleNativeFileDialog(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name() != "showOpenDialog") {
    result->NotImplemented();
    return;
  }

  const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
  std::wstring title = L"Chọn tệp";
  bool multiSelect = false;

  if (arguments != nullptr) {
    auto title_it = arguments->find(flutter::EncodableValue("title"));
    if (title_it != arguments->end() && std::holds_alternative<std::string>(title_it->second)) {
      std::string sTitle = std::get<std::string>(title_it->second);
      int wlen = MultiByteToWideChar(CP_UTF8, 0, sTitle.c_str(), -1, nullptr, 0);
      if (wlen > 0) {
        title.resize(wlen - 1);
        MultiByteToWideChar(CP_UTF8, 0, sTitle.c_str(), -1, &title[0], wlen);
      }
    }

    auto multi_it = arguments->find(flutter::EncodableValue("multiSelect"));
    if (multi_it != arguments->end() && std::holds_alternative<bool>(multi_it->second)) {
      multiSelect = std::get<bool>(multi_it->second);
    }
  }

  HRESULT hrCo = CoInitializeEx(NULL, COINIT_APARTMENTTHREADED | COINIT_DISABLE_OLE1DDE);

  IFileOpenDialog* pFileOpen = nullptr;
  HRESULT hr = CoCreateInstance(CLSID_FileOpenDialog, NULL, CLSCTX_ALL, IID_IFileOpenDialog, reinterpret_cast<void**>(&pFileOpen));

  if (!SUCCEEDED(hr) || pFileOpen == nullptr) {
    if (SUCCEEDED(hrCo)) CoUninitialize();
    flutter::EncodableMap res;
    res[flutter::EncodableValue("status")] = flutter::EncodableValue("error");
    res[flutter::EncodableValue("errorMessage")] = flutter::EncodableValue("Khởi tạo COM IFileOpenDialog thất bại.");
    result->Success(flutter::EncodableValue(res));
    return;
  }

  FILEOPENDIALOGOPTIONS opt;
  pFileOpen->GetOptions(&opt);
  opt |= FOS_FORCEFILESYSTEM | FOS_FILEMUSTEXIST;
  if (multiSelect) {
    opt |= FOS_ALLOWMULTISELECT;
  }
  pFileOpen->SetOptions(opt);
  pFileOpen->SetTitle(title.c_str());

  std::string filterType = "all";
  if (arguments != nullptr) {
    auto filter_it = arguments->find(flutter::EncodableValue("filterType"));
    if (filter_it != arguments->end() && std::holds_alternative<std::string>(filter_it->second)) {
      filterType = std::get<std::string>(filter_it->second);
    }
  }

  std::vector<COMDLG_FILTERSPEC> fileTypes;
  if (filterType == "pdf") {
    fileTypes = {
      { L"Tài liệu PDF (*.pdf)", L"*.pdf" },
      { L"Tất cả các tệp (*.*)", L"*.*" }
    };
  } else if (filterType == "image") {
    fileTypes = {
      { L"Tệp hình ảnh (*.jpg;*.jpeg;*.png;*.bmp;*.webp;*.tiff)", L"*.jpg;*.jpeg;*.png;*.bmp;*.webp;*.tiff" },
      { L"Tất cả các tệp (*.*)", L"*.*" }
    };
  } else if (filterType == "tts") {
    fileTypes = {
      { L"Tài liệu văn bản (*.txt;*.docx;*.pdf)", L"*.txt;*.docx;*.pdf" },
      { L"Tệp văn bản TXT (*.txt)", L"*.txt" },
      { L"Tài liệu Word (*.docx)", L"*.docx" },
      { L"Tài liệu PDF (*.pdf)", L"*.pdf" },
      { L"Tất cả các tệp (*.*)", L"*.*" }
    };
  } else if (filterType == "audio") {
    fileTypes = {
      { L"Tệp âm thanh (*.wav;*.mp3;*.m4a;*.aac;*.ogg)", L"*.wav;*.mp3;*.m4a;*.aac;*.ogg" },
      { L"Tất cả các tệp (*.*)", L"*.*" }
    };
  } else if (filterType == "media") {
    fileTypes = {
      { L"Tệp Media đa phương tiện (*.jpg;*.jpeg;*.png;*.mp4;*.wav;*.mp3)", L"*.jpg;*.jpeg;*.png;*.mp4;*.wav;*.mp3" },
      { L"Tất cả các tệp (*.*)", L"*.*" }
    };
  } else {
    fileTypes = {
      { L"Tất cả các tệp (*.*)", L"*.*" }
    };
  }

  pFileOpen->SetFileTypes(static_cast<UINT>(fileTypes.size()), fileTypes.data());

  hr = pFileOpen->Show(GetHandle());

  if (hr == HRESULT_FROM_WIN32(ERROR_CANCELLED)) {
    pFileOpen->Release();
    if (SUCCEEDED(hrCo)) CoUninitialize();
    flutter::EncodableMap res;
    res[flutter::EncodableValue("status")] = flutter::EncodableValue("cancelled");
    result->Success(flutter::EncodableValue(res));
    return;
  }

  if (!SUCCEEDED(hr)) {
    pFileOpen->Release();
    if (SUCCEEDED(hrCo)) CoUninitialize();
    flutter::EncodableMap res;
    res[flutter::EncodableValue("status")] = flutter::EncodableValue("error");
    res[flutter::EncodableValue("errorMessage")] = flutter::EncodableValue("Hộp thoại tệp gặp lỗi Win32: " + std::to_string(hr));
    result->Success(flutter::EncodableValue(res));
    return;
  }

  std::vector<flutter::EncodableValue> paths;

  if (multiSelect) {
    IShellItemArray* pItemArray = nullptr;
    if (SUCCEEDED(pFileOpen->GetResults(&pItemArray)) && pItemArray != nullptr) {
      DWORD itemCount = 0;
      pItemArray->GetCount(&itemCount);
      for (DWORD i = 0; i < itemCount; ++i) {
        IShellItem* pItem = nullptr;
        if (SUCCEEDED(pItemArray->GetItemAt(i, &pItem)) && pItem != nullptr) {
          PWSTR pszFilePath = nullptr;
          if (SUCCEEDED(pItem->GetDisplayName(SIGDN_FILESYSPATH, &pszFilePath)) && pszFilePath != nullptr) {
            int utf8Len = WideCharToMultiByte(CP_UTF8, 0, pszFilePath, -1, nullptr, 0, nullptr, nullptr);
            if (utf8Len > 0) {
              std::string u8(utf8Len, '\0');
              WideCharToMultiByte(CP_UTF8, 0, pszFilePath, -1, &u8[0], utf8Len, nullptr, nullptr);
              if (!u8.empty() && u8.back() == '\0') u8.pop_back();
              paths.push_back(flutter::EncodableValue(u8));
            }
            CoTaskMemFree(pszFilePath);
          }
          pItem->Release();
        }
      }
      pItemArray->Release();
    }
  } else {
    IShellItem* pItem = nullptr;
    if (SUCCEEDED(pFileOpen->GetResult(&pItem)) && pItem != nullptr) {
      PWSTR pszFilePath = nullptr;
      if (SUCCEEDED(pItem->GetDisplayName(SIGDN_FILESYSPATH, &pszFilePath)) && pszFilePath != nullptr) {
        int utf8Len = WideCharToMultiByte(CP_UTF8, 0, pszFilePath, -1, nullptr, 0, nullptr, nullptr);
        if (utf8Len > 0) {
          std::string u8(utf8Len, '\0');
          WideCharToMultiByte(CP_UTF8, 0, pszFilePath, -1, &u8[0], utf8Len, nullptr, nullptr);
          if (!u8.empty() && u8.back() == '\0') u8.pop_back();
          paths.push_back(flutter::EncodableValue(u8));
        }
        CoTaskMemFree(pszFilePath);
      }
      pItem->Release();
    }
  }

  pFileOpen->Release();
  if (SUCCEEDED(hrCo)) CoUninitialize();

  flutter::EncodableMap res;
  res[flutter::EncodableValue("status")] = flutter::EncodableValue("selected");
  res[flutter::EncodableValue("paths")] = flutter::EncodableValue(paths);
  result->Success(flutter::EncodableValue(res));
}

