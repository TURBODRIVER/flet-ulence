import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

import '../models/window_state.dart';
import 'platform.dart';

Future setWindowTitle(String title) async {
  debugPrint("setWindowTitle($title)");
  await windowManager.setTitle(title);
}

Future setWindowBackgroundColor(Color bgcolor) async {
  debugPrint("setWindowBackgroundColor($bgcolor)");
  await windowManager.setBackgroundColor(bgcolor);
}

Future setWindowSize(double? width, double? height) async {
  debugPrint("setWindowSize($width, $height)");
  var currentSize = await windowManager.getSize();
  await windowManager.setSize(
      Size(width ?? currentSize.width, height ?? currentSize.height),
      animate: defaultTargetPlatform != TargetPlatform.macOS);
}

Future setWindowMinSize(double? minWidth, double? minHeight) async {
  debugPrint("setWindowMinSize($minWidth, $minHeight)");
  await windowManager.setMinimumSize(Size(minWidth ?? 0, minHeight ?? 0));
}

Future setWindowMaxSize(double? maxWidth, double? maxHeight) async {
  debugPrint("setWindowMaxSize($maxWidth, $maxHeight)");
  await windowManager.setMaximumSize(Size(maxWidth ?? -1, maxHeight ?? -1));
}

Future setWindowPosition(double? top, double? left) async {
  debugPrint("setWindowPosition($top, $left)");
  var currentPos = await windowManager.getPosition();
  await windowManager.setPosition(
      Offset(left ?? currentPos.dx, top ?? currentPos.dy),
      animate: defaultTargetPlatform != TargetPlatform.macOS);
}

Future setWindowOpacity(double opacity) async {
  debugPrint("setWindowOpacity($opacity)");
  await windowManager.setOpacity(opacity);
}

Future setWindowMinimizability(bool minimizable) async {
  debugPrint("setWindowMinimizability($minimizable)");
  await windowManager.setMinimizable(minimizable);
}

Future setWindowMaximizability(bool maximizable) async {
  debugPrint("setWindowMaximizability($maximizable)");
  await windowManager.setMaximizable(maximizable);
}

Future setWindowResizability(bool resizable) async {
  debugPrint("setWindowResizability($resizable)");
  await windowManager.setResizable(resizable);
}

Future setWindowMovability(bool movable) async {
  debugPrint("setWindowMovability($movable)");
  await windowManager.setMovable(movable);
}

Future setWindowFullScreen(bool fullScreen) async {
  if (await windowManager.isFullScreen() != fullScreen) {
    debugPrint("setWindowFullScreen($fullScreen)");
    await windowManager.setFullScreen(fullScreen);
  }
}

Future setWindowAlwaysOnTop(bool alwaysOnTop) async {
  if (await windowManager.isAlwaysOnTop() != alwaysOnTop) {
    debugPrint("setWindowAlwaysOnTop($alwaysOnTop)");
    await windowManager.setAlwaysOnTop(alwaysOnTop);
  }
}

Future setWindowAlwaysOnBottom(bool alwaysOnBottom) async {
  if (isLinuxDesktop() || isWindowsDesktop()) {
    debugPrint("setWindowAlwaysOnBottom($alwaysOnBottom)");
    await windowManager.setAlwaysOnBottom(alwaysOnBottom);
  }
}

Future setWindowPreventClose(bool preventClose) async {
  debugPrint("setWindowPreventClose($preventClose)");
  await windowManager.setPreventClose(preventClose);
}

Future setWindowTitleBarVisibility(
    bool titleBarHidden, bool titleBarButtonsHidden) async {
  debugPrint("setWindowTitleBarVisibility()");
  await windowManager.setTitleBarStyle(
      titleBarHidden ? TitleBarStyle.hidden : TitleBarStyle.normal,
      windowButtonVisibility: !titleBarButtonsHidden);
}

Future setWindowSkipTaskBar(bool skipTaskBar) async {
  debugPrint("setWindowSkipTaskBar($skipTaskBar)");
  await windowManager.setSkipTaskbar(skipTaskBar);
}

Future setWindowFrameless() async {
  debugPrint("setWindowFrameless()");
  await windowManager.setAsFrameless();
}

Future setWindowProgressBar(double progress) async {
  debugPrint("setWindowProgressBar($progress)");
  await windowManager.setProgressBar(progress);
}

Future setWindowShadow(bool hasShadow) async {
  debugPrint("setWindowHasShadow($hasShadow)");
  debugPrint("${windowManager.hasShadow()}");
  await windowManager.setHasShadow(hasShadow);
}

Future setWindowBadgeLabel(String label) async {
  debugPrint("setWindowBadgeLabel($label)");
  await windowManager.setBadgeLabel(label);
}

Future setWindowIcon(String iconPath) async {
  if (isWindowsDesktop()) {
    debugPrint("setWindowIcon($iconPath)");
    await windowManager.setIcon(iconPath);
  }
}

Future setWindowAlignment(Alignment alignment, [bool animate = true]) async {
  debugPrint("setWindowAlignment($alignment, animate: $animate)");
  await windowManager.setAlignment(alignment, animate: animate);
}

Future setWindowAspectRatio(double value) async {
  await windowManager.setAspectRatio(value);
}

Future setWindowBrightness(Brightness value) async {
  await windowManager.setBrightness(value);
}

Future minimizeWindow() async {
  if (!await windowManager.isMinimized()) {
    debugPrint("minimizeWindow()");
    await windowManager.minimize();
  }
}

Future restoreWindow() async {
  if (await windowManager.isMinimized()) {
    debugPrint("restoreWindow()");
    await windowManager.restore();
  }
}

Future maximizeWindow() async {
  if (!await windowManager.isMaximized()) {
    debugPrint("maximizeWindow()");
    await windowManager.maximize();
  }
}

Future unmaximizeWindow() async {
  if (await windowManager.isMaximized()) {
    debugPrint("unmaximizeWindow()");
    await windowManager.unmaximize();
  }
}

Future showWindow() async {
  if (!await windowManager.isVisible()) {
    debugPrint("showWindow()");
    await windowManager.show();
  }
}

Future hideWindow() async {
  if (await windowManager.isVisible()) {
    debugPrint("hideWindow()");
    await windowManager.hide();
  }
}

Future focusWindow() async {
  if (!await windowManager.isFocused() && !await windowManager.isMinimized()) {
    debugPrint("focusWindow()");
    await windowManager.focus();
  }
}

Future windowToFront() async {
  // Bring the window to the front, activating the app over other apps
  // (window_manager.show() calls NSApp.activate(ignoringOtherApps: true)).
  await windowManager.show();
}

Future startDraggingWindow() async {
  await windowManager.startDragging();
}

Future startResizingWindow(ResizeEdge edge) async {
  if (isWindowsDesktop() || isLinuxDesktop()) {
    await windowManager.startResizing(edge);
  }
}

Future blurWindow() async {
  if ((defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS) &&
      await windowManager.isFocused()) {
    debugPrint("blurWindow()");
    await windowManager.blur();
  }
}

Future destroyWindow() async {
  debugPrint("destroyWindow()");
  if (isWindowsDesktop()) {
    // Work around window_manager.destroy() stalling on Windows:
    // https://github.com/leanflutter/window_manager/issues/478#issuecomment-2423413104
    if (await windowManager.isPreventClose()) {
      await windowManager.setPreventClose(false);
    }
    await windowManager.close();
    return;
  }
  await windowManager.destroy();
}

Future waitUntilReadyToShow() async {
  debugPrint("waitUntilReadyToShow()");
  await windowManager.waitUntilReadyToShow();
}

Future centerWindow() async {
  debugPrint("centerWindow()");
  await windowManager.center();
}

Future closeWindow() async {
  debugPrint("closeWindow()");
  await windowManager.close();
}

Future isFocused() async {
  if (defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.macOS) {
    return await windowManager.isFocused();
  } else {
    return false;
  }
}

Future setIgnoreMouseEvents(bool ignore) async {
  debugPrint("setIgnoreMouseEvents($ignore)");
  await windowManager.setIgnoreMouseEvents(ignore);
}

Future<WindowState> getWindowState() async {
  final size = await windowManager.getSize();
  final pos = await windowManager.getPosition();

  return WindowState(
    maximized: await windowManager.isMaximized(),
    minimized: await windowManager.isMinimized(),
    fullScreen: await windowManager.isFullScreen(),
    alwaysOnTop: await windowManager.isAlwaysOnTop(),
    focused: await isFocused(),
    visible: await windowManager.isVisible(),
    opacity: await windowManager.getOpacity(),
    minimizable: await windowManager.isMinimizable(),
    maximizable: await windowManager.isMaximizable(),
    resizable: await windowManager.isResizable(),
    preventClose: await windowManager.isPreventClose(),
    skipTaskBar: await windowManager.isSkipTaskbar(),
    width: size.width.toDouble(),
    height: size.height.toDouble(),
    top: pos.dy.toDouble(),
    left: pos.dx.toDouble(),
  );
}
