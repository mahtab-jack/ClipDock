#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Single Instance Protection: prevent multiple running instances and tray icon duplicates
  HANDLE hMutex = ::CreateMutexW(nullptr, TRUE, L"ClipDock_SingleInstance_Mutex_Unique_98765");
  if (hMutex != nullptr && ::GetLastError() == ERROR_ALREADY_EXISTS) {
    ::CloseHandle(hMutex);
    ::MessageBoxW(
        nullptr,
        L"Clip Dock is already running in your system tray.\nLook for the clipboard icon in the taskbar notification area.",
        L"Clip Dock",
        MB_OK | MB_ICONINFORMATION);
    return EXIT_SUCCESS;
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(415, 680);
  if (!window.Create(L"cnote", origin, size)) {
    if (hMutex) ::CloseHandle(hMutex);
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  if (hMutex) ::CloseHandle(hMutex);
  return EXIT_SUCCESS;
}
