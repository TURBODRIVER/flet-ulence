#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <shellscalingapi.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
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
  Win32Window::Size size({{ cookiecutter.window_size_width }}, {{ cookiecutter.window_size_height }});

  POINT cursor_pos;
  ::GetCursorPos(&cursor_pos);
  HMONITOR monitor = ::MonitorFromPoint(cursor_pos, MONITOR_DEFAULTTOPRIMARY);

  MONITORINFO mi;
  mi.cbSize = sizeof(MONITORINFO);
  ::GetMonitorInfo(monitor, &mi);

  UINT dpi_x, dpi_y;
  ::GetDpiForMonitor(monitor, MDT_EFFECTIVE_DPI, &dpi_x, &dpi_y);
  float scale = dpi_x / 96.0f;

  int work_left   = static_cast<int>(mi.rcWork.left   / scale);
  int work_top    = static_cast<int>(mi.rcWork.top    / scale);
  int work_width  = static_cast<int>((mi.rcWork.right  - mi.rcWork.left) / scale);
  int work_height = static_cast<int>((mi.rcWork.bottom - mi.rcWork.top)  / scale);

  int origin_x = work_left + (work_width  - size.width)  / 2;
  int origin_y = work_top  + (work_height - size.height) / 2;
  Win32Window::Point origin(origin_x, origin_y);

  if (!window.Create(L"{{ cookiecutter.product_name }}", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
