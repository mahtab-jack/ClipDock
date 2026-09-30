#include "flutter_window.h"

#include <optional>
#include <dwmapi.h>

#include "flutter/generated_plugin_registrant.h"
#include "drag_drop_helper.h"

#include <fstream>
#include <vector>

static HWND g_last_external_window = NULL;
static HWND g_last_external_focus = NULL;

static void RecordForegroundWindow(HWND self_hwnd) {
  HWND fg = GetForegroundWindow();
  if (fg != NULL && fg != self_hwnd && GetAncestor(fg, GA_ROOT) != self_hwnd) {
    g_last_external_window = fg;

    DWORD target_thread = GetWindowThreadProcessId(fg, NULL);
    GUITHREADINFO gui_info = {};
    gui_info.cbSize = sizeof(GUITHREADINFO);
    if (GetGUIThreadInfo(target_thread, &gui_info)) {
      if (gui_info.hwndFocus && IsWindow(gui_info.hwndFocus)) {
        g_last_external_focus = gui_info.hwndFocus;
      } else if (gui_info.hwndCaret && IsWindow(gui_info.hwndCaret)) {
        g_last_external_focus = gui_info.hwndCaret;
      }
    }
  }
}

static void PasteTextIntoWindow(HWND self_hwnd, const std::wstring& wide_text) {
  // 1. Put text on Windows Clipboard
  if (OpenClipboard(self_hwnd)) {
    EmptyClipboard();
    size_t byte_count = (wide_text.size() + 1) * sizeof(wchar_t);
    HGLOBAL hg = GlobalAlloc(GMEM_MOVEABLE, byte_count);
    if (hg) {
      void* locked = GlobalLock(hg);
      if (locked) {
        memcpy(locked, wide_text.c_str(), byte_count);
        GlobalUnlock(hg);
        SetClipboardData(CF_UNICODETEXT, hg);
      }
    }
    CloseClipboard();
  }

  // 2. Identify target window
  HWND target_hwnd = g_last_external_window;
  if (target_hwnd == NULL || !IsWindow(target_hwnd)) {
    HWND fg = GetForegroundWindow();
    if (fg != NULL && fg != self_hwnd && GetAncestor(fg, GA_ROOT) != self_hwnd) {
      target_hwnd = fg;
    }
  }

  if (target_hwnd == NULL || !IsWindow(target_hwnd)) {
    return;
  }

  DWORD current_thread = GetCurrentThreadId();
  DWORD target_thread = GetWindowThreadProcessId(target_hwnd, NULL);

  // 3. Attach thread input so focus and keystrokes can be transferred
  BOOL attached = FALSE;
  if (current_thread != target_thread) {
    attached = AttachThreadInput(current_thread, target_thread, TRUE);
  }

  AllowSetForegroundWindow(ASFW_ANY);

  // 4. Reactivate target window and restore focus
  SetForegroundWindow(target_hwnd);
  SetActiveWindow(target_hwnd);
  BringWindowToTop(target_hwnd);

  HWND focus_target = g_last_external_focus;
  if (focus_target != NULL && IsWindow(focus_target)) {
    SetFocus(focus_target);
  } else {
    SetFocus(target_hwnd);
  }

  // 5. Short sleep while thread input remains ATTACHED
  Sleep(45);

  // 6. Simulate Ctrl+V using hardware scan codes and keybd_event & SendInput
  keybd_event(VK_CONTROL, 0x1D, 0, 0);
  Sleep(15);
  keybd_event('V', 0x2F, 0, 0);
  Sleep(15);
  keybd_event('V', 0x2F, KEYEVENTF_KEYUP, 0);
  Sleep(15);
  keybd_event(VK_CONTROL, 0x1D, KEYEVENTF_KEYUP, 0);

  Sleep(25);

  // 7. Detach thread input AFTER key events are processed
  if (attached) {
    AttachThreadInput(current_thread, target_thread, FALSE);
  }
}

// Save CF_DIB / CF_DIBV5 from clipboard directly as BMP file
static bool SaveClipboardImageToFile(HWND self_hwnd, const std::wstring& target_path) {
  if (!OpenClipboard(self_hwnd)) {
    return false;
  }

  UINT format = 0;
  if (IsClipboardFormatAvailable(CF_DIBV5)) {
    format = CF_DIBV5;
  } else if (IsClipboardFormatAvailable(CF_DIB)) {
    format = CF_DIB;
  }

  if (format == 0) {
    CloseClipboard();
    return false;
  }

  HANDLE hData = GetClipboardData(format);
  if (!hData) {
    CloseClipboard();
    return false;
  }

  SIZE_T dib_size = GlobalSize(hData);
  void* pDib = GlobalLock(hData);
  if (!pDib || dib_size < sizeof(BITMAPINFOHEADER)) {
    if (pDib) GlobalUnlock(hData);
    CloseClipboard();
    return false;
  }

  BITMAPINFOHEADER* bih = reinterpret_cast<BITMAPINFOHEADER*>(pDib);
  DWORD off_bits = sizeof(BITMAPFILEHEADER) + bih->biSize;

  DWORD colors = 0;
  if (bih->biBitCount <= 8) {
    colors = bih->biClrUsed ? bih->biClrUsed : (1 << bih->biBitCount);
    off_bits += colors * sizeof(RGBQUAD);
  } else if (bih->biCompression == BI_BITFIELDS) {
    off_bits += 3 * sizeof(DWORD);
  }

  BITMAPFILEHEADER bfh = {};
  bfh.bfType = 0x4D42; // 'BM'
  bfh.bfSize = static_cast<DWORD>(sizeof(BITMAPFILEHEADER) + dib_size);
  bfh.bfOffBits = off_bits;

  std::ofstream out(target_path, std::ios::binary);
  if (!out.is_open()) {
    GlobalUnlock(hData);
    CloseClipboard();
    return false;
  }

  out.write(reinterpret_cast<const char*>(&bfh), sizeof(bfh));
  out.write(reinterpret_cast<const char*>(pDib), dib_size);
  out.close();

  GlobalUnlock(hData);
  CloseClipboard();
  return true;
}

// Copy BMP file to Windows clipboard as CF_DIB
static bool CopyBmpFileToClipboard(HWND self_hwnd, const std::wstring& file_path) {
  std::ifstream in(file_path, std::ios::binary | std::ios::ate);
  if (!in.is_open()) return false;

  std::streamsize file_size = in.tellg();
  if (file_size <= static_cast<std::streamsize>(sizeof(BITMAPFILEHEADER))) return false;

  in.seekg(0, std::ios::beg);
  BITMAPFILEHEADER bfh;
  in.read(reinterpret_cast<char*>(&bfh), sizeof(bfh));
  if (bfh.bfType != 0x4D42) return false;

  size_t dib_size = static_cast<size_t>(file_size - sizeof(BITMAPFILEHEADER));
  HGLOBAL hGlobal = GlobalAlloc(GMEM_MOVEABLE, dib_size);
  if (!hGlobal) return false;

  void* pDest = GlobalLock(hGlobal);
  if (!pDest) {
    GlobalFree(hGlobal);
    return false;
  }

  in.read(reinterpret_cast<char*>(pDest), dib_size);
  GlobalUnlock(hGlobal);

  if (OpenClipboard(self_hwnd)) {
    EmptyClipboard();
    SetClipboardData(CF_DIB, hGlobal);
    CloseClipboard();
    return true;
  } else {
    GlobalFree(hGlobal);
    return false;
  }
}

static void PasteImageIntoWindow(HWND self_hwnd, const std::wstring& file_path) {
  if (CopyBmpFileToClipboard(self_hwnd, file_path)) {
    // Identify target window and send Ctrl+V
    HWND target_hwnd = g_last_external_window;
    if (target_hwnd == NULL || !IsWindow(target_hwnd)) {
      HWND fg = GetForegroundWindow();
      if (fg != NULL && fg != self_hwnd && GetAncestor(fg, GA_ROOT) != self_hwnd) {
        target_hwnd = fg;
      }
    }

    if (target_hwnd == NULL || !IsWindow(target_hwnd)) {
      return;
    }

    DWORD current_thread = GetCurrentThreadId();
    DWORD target_thread = GetWindowThreadProcessId(target_hwnd, NULL);

    BOOL attached = FALSE;
    if (current_thread != target_thread) {
      attached = AttachThreadInput(current_thread, target_thread, TRUE);
    }

    AllowSetForegroundWindow(ASFW_ANY);

    SetForegroundWindow(target_hwnd);
    SetActiveWindow(target_hwnd);
    BringWindowToTop(target_hwnd);

    HWND focus_target = g_last_external_focus;
    if (focus_target != NULL && IsWindow(focus_target)) {
      SetFocus(focus_target);
    } else {
      SetFocus(target_hwnd);
    }

    Sleep(45);

    keybd_event(VK_CONTROL, 0x1D, 0, 0);
    Sleep(15);
    keybd_event('V', 0x2F, 0, 0);
    Sleep(15);
    keybd_event('V', 0x2F, KEYEVENTF_KEYUP, 0);
    Sleep(15);
    keybd_event(VK_CONTROL, 0x1D, KEYEVENTF_KEYUP, 0);

    Sleep(25);

    if (attached) {
      AttachThreadInput(current_thread, target_thread, FALSE);
    }
  }
}

typedef enum _ACCENT_STATE {
    ACCENT_DISABLED = 0,
    ACCENT_ENABLE_GRADIENT = 1,
    ACCENT_ENABLE_TRANSPARENTGRADIENT = 2,
    ACCENT_ENABLE_BLURBEHIND = 3,
    ACCENT_ENABLE_ACRYLICBLURBEHIND = 4,
    ACCENT_ENABLE_HOSTBACKDROP = 5,
    ACCENT_INVALID_STATE = 6
} ACCENT_STATE;

typedef struct _ACCENT_POLICY {
    ACCENT_STATE AccentState;
    DWORD AccentFlags;
    DWORD GradientColor;
    DWORD AnimationId;
} ACCENT_POLICY;

typedef struct _WINDOWCOMPOSITIONATTRIBDATA {
    DWORD Attrib;
    PVOID pvData;
    SIZE_T cbData;
} WINDOWCOMPOSITIONATTRIBDATA;

typedef BOOL(WINAPI* pfnSetWindowCompositionAttribute)(HWND, WINDOWCOMPOSITIONATTRIBDATA*);

static void SetNativeWindowBlur(HWND hwnd, bool enable, DWORD tintColorABGR = 0x01000000) {
  HMODULE user32 = GetModuleHandleA("user32.dll");
  if (!user32) {
    user32 = LoadLibraryA("user32.dll");
  }
  if (user32) {
    pfnSetWindowCompositionAttribute setWindowCompositionAttribute =
        (pfnSetWindowCompositionAttribute)GetProcAddress(user32, "SetWindowCompositionAttribute");
    if (setWindowCompositionAttribute) {
      ACCENT_POLICY policy = {};
      if (enable) {
        policy.AccentState = ACCENT_ENABLE_ACRYLICBLURBEHIND;
        policy.AccentFlags = 2;
        policy.GradientColor = tintColorABGR;
      } else {
        policy.AccentState = ACCENT_DISABLED;
      }
      WINDOWCOMPOSITIONATTRIBDATA data = {};
      data.Attrib = 19; // WCA_ACCENT_POLICY
      data.pvData = &policy;
      data.cbData = sizeof(policy);
      setWindowCompositionAttribute(hwnd, &data);
    }
  }
}

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // Setup drag & drop and active window paste fill method channel
  drag_drop_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "cnote/drag_drop",
      &flutter::StandardMethodCodec::GetInstance());

  HWND self_hwnd = GetHandle();

  // Enable initial blur behind window for transparent frosted glass effect
  SetNativeWindowBlur(self_hwnd, true);

  drag_drop_channel_->SetMethodCallHandler(
      [self_hwnd](const flutter::MethodCall<flutter::EncodableValue>& call,
                  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "setWindowBlur") {
          const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
          bool enable = true;
          DWORD tintColor = 0x01000000;
          if (arguments) {
            auto blur_it = arguments->find(flutter::EncodableValue("enable"));
            if (blur_it != arguments->end() && std::holds_alternative<bool>(blur_it->second)) {
              enable = std::get<bool>(blur_it->second);
            }
            auto tint_it = arguments->find(flutter::EncodableValue("tintColor"));
            if (tint_it != arguments->end() && std::holds_alternative<int32_t>(tint_it->second)) {
              tintColor = static_cast<DWORD>(std::get<int32_t>(tint_it->second));
            } else if (tint_it != arguments->end() && std::holds_alternative<int64_t>(tint_it->second)) {
              tintColor = static_cast<DWORD>(std::get<int64_t>(tint_it->second));
            }
          }
          SetNativeWindowBlur(self_hwnd, enable, tintColor);
          result->Success(flutter::EncodableValue(true));
          return;
        }
        if (call.method_name() == "captureActiveWindow") {
          RecordForegroundWindow(self_hwnd);
          result->Success(flutter::EncodableValue(true));
          return;
        }

        if (call.method_name() == "fillTextIntoActiveWindow") {
          const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
          if (arguments) {
            auto text_it = arguments->find(flutter::EncodableValue("text"));
            if (text_it != arguments->end() && std::holds_alternative<std::string>(text_it->second)) {
              std::string utf8_text = std::get<std::string>(text_it->second);
              int wlen = MultiByteToWideChar(CP_UTF8, 0, utf8_text.c_str(), -1, nullptr, 0);
              if (wlen > 0) {
                std::wstring wide_text(wlen, 0);
                MultiByteToWideChar(CP_UTF8, 0, utf8_text.c_str(), -1, &wide_text[0], wlen);
                if (!wide_text.empty() && wide_text.back() == L'\0') {
                  wide_text.pop_back();
                }
                PasteTextIntoWindow(self_hwnd, wide_text);
              }
              result->Success(flutter::EncodableValue(true));
              return;
            }
          }
          result->Error("BAD_ARGS", "Missing text argument");
          return;
        }

        if (call.method_name() == "startDragText") {
          const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
          if (arguments) {
            auto text_it = arguments->find(flutter::EncodableValue("text"));
            if (text_it != arguments->end() && std::holds_alternative<std::string>(text_it->second)) {
              std::string utf8_text = std::get<std::string>(text_it->second);
              int wlen = MultiByteToWideChar(CP_UTF8, 0, utf8_text.c_str(), -1, nullptr, 0);
              if (wlen > 0) {
                std::wstring wide_text(wlen, 0);
                MultiByteToWideChar(CP_UTF8, 0, utf8_text.c_str(), -1, &wide_text[0], wlen);
                if (!wide_text.empty() && wide_text.back() == L'\0') {
                  wide_text.pop_back();
                }
                clipdock::PerformTextDragDrop(wide_text);
              }
              result->Success(flutter::EncodableValue(true));
              return;
            }
          }
          result->Error("BAD_ARGS", "Missing text argument");
          return;
        }

        if (call.method_name() == "hasClipboardImage") {
          bool has_image = false;
          if (OpenClipboard(self_hwnd)) {
            has_image = IsClipboardFormatAvailable(CF_DIB) || IsClipboardFormatAvailable(CF_DIBV5);
            CloseClipboard();
          }
          result->Success(flutter::EncodableValue(has_image));
          return;
        }

        if (call.method_name() == "saveClipboardImage") {
          const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
          if (arguments) {
            auto path_it = arguments->find(flutter::EncodableValue("filePath"));
            if (path_it != arguments->end() && std::holds_alternative<std::string>(path_it->second)) {
              std::string utf8_path = std::get<std::string>(path_it->second);
              int wlen = MultiByteToWideChar(CP_UTF8, 0, utf8_path.c_str(), -1, nullptr, 0);
              if (wlen > 0) {
                std::wstring wide_path(wlen, 0);
                MultiByteToWideChar(CP_UTF8, 0, utf8_path.c_str(), -1, &wide_path[0], wlen);
                if (!wide_path.empty() && wide_path.back() == L'\0') {
                  wide_path.pop_back();
                }
                bool ok = SaveClipboardImageToFile(self_hwnd, wide_path);
                result->Success(flutter::EncodableValue(ok));
                return;
              }
            }
          }
          result->Error("BAD_ARGS", "Missing filePath argument");
          return;
        }

        if (call.method_name() == "copyImageToClipboard") {
          const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
          if (arguments) {
            auto path_it = arguments->find(flutter::EncodableValue("filePath"));
            if (path_it != arguments->end() && std::holds_alternative<std::string>(path_it->second)) {
              std::string utf8_path = std::get<std::string>(path_it->second);
              int wlen = MultiByteToWideChar(CP_UTF8, 0, utf8_path.c_str(), -1, nullptr, 0);
              if (wlen > 0) {
                std::wstring wide_path(wlen, 0);
                MultiByteToWideChar(CP_UTF8, 0, utf8_path.c_str(), -1, &wide_path[0], wlen);
                if (!wide_path.empty() && wide_path.back() == L'\0') {
                  wide_path.pop_back();
                }
                bool ok = CopyBmpFileToClipboard(self_hwnd, wide_path);
                result->Success(flutter::EncodableValue(ok));
                return;
              }
            }
          }
          result->Error("BAD_ARGS", "Missing filePath argument");
          return;
        }

        if (call.method_name() == "fillImageIntoActiveWindow") {
          const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
          if (arguments) {
            auto path_it = arguments->find(flutter::EncodableValue("filePath"));
            if (path_it != arguments->end() && std::holds_alternative<std::string>(path_it->second)) {
              std::string utf8_path = std::get<std::string>(path_it->second);
              int wlen = MultiByteToWideChar(CP_UTF8, 0, utf8_path.c_str(), -1, nullptr, 0);
              if (wlen > 0) {
                std::wstring wide_path(wlen, 0);
                MultiByteToWideChar(CP_UTF8, 0, utf8_path.c_str(), -1, &wide_path[0], wlen);
                if (!wide_path.empty() && wide_path.back() == L'\0') {
                  wide_path.pop_back();
                }
                PasteImageIntoWindow(self_hwnd, wide_path);
                result->Success(flutter::EncodableValue(true));
                return;
              }
            }
          }
          result->Error("BAD_ARGS", "Missing filePath argument");
          return;
        }

        result->NotImplemented();
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
  drag_drop_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (message == WM_MOUSEMOVE || message == WM_SETCURSOR || message == WM_NCMOUSEMOVE ||
      message == WM_MOUSEACTIVATE || message == WM_ACTIVATE) {
    RecordForegroundWindow(hwnd);
  }

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
    case WM_GETMINMAXINFO: {
      auto info = reinterpret_cast<MINMAXINFO*>(lparam);
      info->ptMinTrackSize.x = 280;
      info->ptMinTrackSize.y = 680;
      info->ptMaxTrackSize.x = 1400;
      info->ptMaxTrackSize.y = 680;
      return 0;
    }
    case WM_ERASEBKGND:
      return 1;
    case WM_NCHITTEST: {
      LRESULT hit = DefWindowProc(hwnd, message, wparam, lparam);
      if (hit == HTLEFT || hit == HTRIGHT || hit == HTTOP || hit == HTBOTTOM ||
          hit == HTTOPLEFT || hit == HTTOPRIGHT || hit == HTBOTTOMLEFT || hit == HTBOTTOMRIGHT) {
        return HTCLIENT;
      }
      return hit;
    }
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
