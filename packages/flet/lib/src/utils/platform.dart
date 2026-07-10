import 'package:flutter/foundation.dart';
import 'enums.dart';

import '../models/control.dart';

/// Checks if the current platform is Windows desktop.
bool isWindowsDesktop() {
  return defaultTargetPlatform == TargetPlatform.windows;
}

/// Checks if the current platform is macOS desktop.
bool isMacOSDesktop() {
  return defaultTargetPlatform == TargetPlatform.macOS;
}

/// Checks if the current platform is Linux desktop.
bool isLinuxDesktop() {
  return defaultTargetPlatform == TargetPlatform.linux;
}

/// Checks if the current platform is an Apple platform (macOS).
bool isApplePlatform() {
  return defaultTargetPlatform == TargetPlatform.macOS;
}

TargetPlatform? parseTargetPlatform(String? value,
    [TargetPlatform? defaultValue]) {
  return parseEnum(TargetPlatform.values, value, defaultValue);
}

extension PlatformParsers on Control {
  TargetPlatform? getTargetPlatform(String propertyName,
      [TargetPlatform? defaultValue]) {
    return parseTargetPlatform(get(propertyName), defaultValue);
  }
}
