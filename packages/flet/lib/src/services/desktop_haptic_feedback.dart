import 'package:flutter/cupertino.dart';
import 'package:macos_haptic_feedback/macos_haptic_feedback.dart';

import '../flet_service.dart';

class DesktopHapticFeedbackService extends FletService {
  DesktopHapticFeedbackService({required super.control});

  final _macosHapticFeedback = MacosHapticFeedback();

  @override
  void init() {
    super.init();
    debugPrint(
        "DesktopHapticFeedbackService(${control.id}).init: ${control.properties}");
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
    super.dispose();
  }

  Future<dynamic> _invokeMethod(String name, dynamic args) async {
    debugPrint("DesktopHapticFeedbackService.$name($args)");
    switch (name) {
      case "macos_generic_haptic":
        await _macosHapticFeedback.generic();
        break;
      case "macos_alignment_haptic":
        await _macosHapticFeedback.alignment();
        break;
      case "macos_level_change_haptic":
        await _macosHapticFeedback.levelChange();
        break;
      default:
        throw Exception("Unknown DesktopHapticFeedback method: $name");
    }
  }
}