import 'package:flutter/cupertino.dart';
import 'package:macos_haptic_feedback/macos_haptic_feedback.dart';

import '../flet_service.dart';
import '../utils/platform.dart';

class DesktopHapticFeedbackService extends FletService {
  DesktopHapticFeedbackService({required super.control});

  MacosHapticFeedback? _macosHapticFeedback;
  bool get _isMacOS => isMacOSDesktop();

  @override
  void init() {
    super.init();
    debugPrint(
        "DesktopHapticFeedbackService(${control.id}).init: ${control.properties}");

    if (_isMacOS) {
      _macosHapticFeedback = MacosHapticFeedback();
    }

    control.addInvokeMethodListener(_invokeMethod);
  }

  @override
  void update() {
    debugPrint(
        "DesktopHapticFeedbackService(${control.id}).update: ${control.properties}");
  }

  @override
  void dispose() {
    debugPrint("DesktopHapticFeedbackService(${control.id}).dispose()");
    control.removeInvokeMethodListener(_invokeMethod);
    _macosHapticFeedback = null;
    super.dispose();
  }

  Future<dynamic> _invokeMethod(String name, dynamic args) async {
    debugPrint("DesktopHapticFeedbackService.$name($args)");

    if (!_isMacOS || _macosHapticFeedback == null) {
      debugPrint("DesktopHapticFeedbackService: ignoring '$name' — not running on macOS.");
      return;
    }

    switch (name) {
      case "macos_generic_haptic":
        await _macosHapticFeedback!.generic();
        break;
      case "macos_alignment_haptic":
        await _macosHapticFeedback!.alignment();
        break;
      case "macos_level_change_haptic":
        await _macosHapticFeedback!.levelChange();
        break;
      default:
        throw Exception("Unknown DesktopHapticFeedback macOS method: $name");
    }
  }
}