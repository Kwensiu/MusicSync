import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final Provider<DeviceDisplayInfoService> deviceDisplayInfoServiceProvider =
    Provider<DeviceDisplayInfoService>(
      (Ref ref) => const DeviceDisplayInfoService(),
    );

class DeviceDisplayInfoService {
  const DeviceDisplayInfoService();

  Future<String> defaultAlias() async {
    if (Platform.isAndroid) {
      final String? androidModel = await _loadAndroidModel();
      if (androidModel != null && androidModel.isNotEmpty) {
        return androidModel;
      }
      return 'Android';
    }
    if (Platform.isWindows) {
      final String? windowsComputerName = _firstNonEmpty(<String?>[
        Platform.localHostname,
        Platform.environment['COMPUTERNAME'],
      ]);
      if (windowsComputerName != null) {
        return windowsComputerName;
      }
      return 'Windows';
    }
    if (Platform.isMacOS) {
      return 'macOS';
    }
    if (Platform.isLinux) {
      return 'Linux';
    }
    return 'MusicSync';
  }

  Future<String?> _loadAndroidModel() async {
    try {
      final AndroidDeviceInfo info = await DeviceInfoPlugin().androidInfo;
      final List<String> candidates = <String>[
        info.model,
        info.product,
        info.device,
        info.brand,
      ];
      for (final String candidate in candidates) {
        final String normalized = candidate.trim();
        if (normalized.isEmpty) {
          continue;
        }
        if (normalized.toLowerCase() == 'unknown') {
          continue;
        }
        return normalized;
      }
    } catch (_) {
      // Fall back to the generic Android label if the plugin is unavailable.
    }
    return null;
  }

  String? _firstNonEmpty(List<String?> values) {
    for (final String? value in values) {
      final String normalized = value?.trim() ?? '';
      if (normalized.isEmpty) {
        continue;
      }
      if (normalized.toLowerCase() == 'localhost') {
        continue;
      }
      return normalized;
    }
    return null;
  }
}
