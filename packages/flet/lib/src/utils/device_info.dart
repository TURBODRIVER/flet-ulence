import 'dart:ui';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flet/src/utils/locale.dart';

import 'platform.dart';

/// Returns device information as a Map.
Future<Map<String, dynamic>> getDeviceInfo() async {
  BaseDeviceInfo deviceInfo = await DeviceInfoPlugin().deviceInfo;
  return deviceInfo.asMap();
}

List<Map<String, String?>> getDeviceLocales() =>
    PlatformDispatcher.instance.locales
        .map((locale) => locale.toMap())
        .toList();

extension DeviceInfoExtension on BaseDeviceInfo {
  Map<String, dynamic> asMap() {
    var deviceInfo = this;
    final deviceLocales = getDeviceLocales();
    if (isLinuxDesktop()) {
      deviceInfo = (deviceInfo as LinuxDeviceInfo);
      return {
        "name": deviceInfo.name,
        "id": deviceInfo.id,
        "pretty_name": deviceInfo.prettyName,
        "version": deviceInfo.version,
        "id_like": deviceInfo.idLike,
        "version_code_name": deviceInfo.versionCodename,
        "version_id": deviceInfo.versionId,
        "build_id": deviceInfo.buildId,
        "variant": deviceInfo.variant,
        "variant_id": deviceInfo.variantId,
        "machine_id": deviceInfo.machineId,
        "locales": deviceLocales,
      };
    } else if (isMacOSDesktop()) {
      deviceInfo = (deviceInfo as MacOsDeviceInfo);
      return {
        "active_cpus": deviceInfo.activeCPUs,
        "arch": deviceInfo.arch,
        "computer_name": deviceInfo.computerName,
        "cpu_frequency": deviceInfo.cpuFrequency,
        "host_name": deviceInfo.hostName,
        "kernel_version": deviceInfo.kernelVersion,
        "major_version": deviceInfo.majorVersion,
        "memory_size": deviceInfo.memorySize,
        "minor_version": deviceInfo.minorVersion,
        "model": deviceInfo.model,
        "model_name": deviceInfo.modelName,
        "os_release": deviceInfo.osRelease,
        "patch_version": deviceInfo.patchVersion,
        "system_guid": deviceInfo.systemGUID,
        "locales": deviceLocales,
      };
    } else if (isWindowsDesktop()) {
      deviceInfo = (deviceInfo as WindowsDeviceInfo);
      return {
        "computer_name": deviceInfo.computerName,
        "number_of_cores": deviceInfo.numberOfCores,
        "system_memory": deviceInfo.systemMemoryInMegabytes,
        "user_name": deviceInfo.userName,
        "major_version": deviceInfo.majorVersion,
        "minor_version": deviceInfo.minorVersion,
        "build_number": deviceInfo.buildNumber,
        "platform_id": deviceInfo.platformId,
        "csd_version": deviceInfo.csdVersion,
        "service_pack_major": deviceInfo.servicePackMajor,
        "service_pack_minor": deviceInfo.servicePackMinor,
        "suit_mask": deviceInfo.suitMask,
        "product_type": deviceInfo.productType,
        "reserved": deviceInfo.reserved,
        "build_lab": deviceInfo.buildLab,
        "build_lab_ex": deviceInfo.buildLabEx,
        // "digital_product_id": deviceInfo.digitalProductId,
        "display_version": deviceInfo.displayVersion,
        "edition_id": deviceInfo.editionId,
        "install_date": deviceInfo.installDate,
        "product_id": deviceInfo.productId,
        "product_name": deviceInfo.productName,
        "registered_owner": deviceInfo.registeredOwner,
        "release_id": deviceInfo.releaseId,
        "device_id": deviceInfo.deviceId,
        "locales": deviceLocales,
      };
    }
    return {};
  }
}
