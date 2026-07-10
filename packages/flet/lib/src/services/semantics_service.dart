import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../flet_service.dart';

class SemanticsServiceControl extends FletService {
  SemanticsServiceControl({required super.control});

  @override
  void init() {
    super.init();
    debugPrint("SemanticsService(${control.id}).init: ${control.properties}");
    control.addInvokeMethodListener(_invokeMethod);
  }

  @override
  void dispose() {
    debugPrint("SemanticsService(${control.id}).dispose()");
    control.removeInvokeMethodListener(_invokeMethod);
    super.dispose();
  }

  Future<dynamic> _invokeMethod(String name, dynamic args) async {
    debugPrint("SemanticsService.$name($args)");
    switch (name) {
      case "announce_message":
        var message = args["message"].toString();
        final view = WidgetsBinding.instance.platformDispatcher.implicitView;
        if (view == null) {
          return;
        }
        return SemanticsService.sendAnnouncement(
            view, message, args["rtl"] ? TextDirection.rtl : TextDirection.ltr);
      case "get_accessibility_features":
        var features = SemanticsBinding.instance.accessibilityFeatures;
        return {
          "accessible_navigation": features.accessibleNavigation,
          "bold_text": features.boldText,
          "disable_animations": features.disableAnimations,
          "invert_colors": features.invertColors,
          "supports_announcements": features.supportsAnnounce,
        };
      default:
        throw Exception("Unknown SemanticsService method: $name");
    }
  }
}
