import 'dart:math';

import 'package:music_sync/core/utils/extension_normalizer.dart';
import 'package:music_sync/features/settings/state/settings_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsStore {
  static const String _autoStartListeningKey = 'auto_start_listening';
  static const String _httpEncryptionEnabledKey = 'http_encryption_enabled';
  static const String _ignoredExtensionsKey = 'ignored_extensions';
  static const String _themeModeKey = 'theme_mode';
  static const String _paletteKey = 'palette';
  static const String _deviceIdentityKey = 'device_identity';
  static const String _deviceAliasKey = 'device_alias';

  Future<bool> loadAutoStartListening() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_autoStartListeningKey) ?? true;
  }

  Future<void> saveAutoStartListening(bool value) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_autoStartListeningKey, value);
  }

  Future<bool> loadHttpEncryptionEnabled() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_httpEncryptionEnabledKey) ?? true;
  }

  Future<void> saveHttpEncryptionEnabled(bool value) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_httpEncryptionEnabledKey, value);
  }

  Future<List<String>> loadIgnoredExtensions() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final List<String> values =
        preferences.getStringList(_ignoredExtensionsKey) ?? const <String>[];
    return values
        .map(normalizeExtensionRule)
        .where((String value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  Future<void> saveIgnoredExtensions(List<String> values) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final List<String> normalized =
        values
            .map(normalizeExtensionRule)
            .where((String value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    await preferences.setStringList(_ignoredExtensionsKey, normalized);
  }

  Future<AppThemeModeSetting> loadThemeMode() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final String raw = preferences.getString(_themeModeKey) ?? 'system';
    return switch (raw) {
      'light' => AppThemeModeSetting.light,
      'dark' => AppThemeModeSetting.dark,
      _ => AppThemeModeSetting.system,
    };
  }

  Future<void> saveThemeMode(AppThemeModeSetting mode) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final String raw = switch (mode) {
      AppThemeModeSetting.system => 'system',
      AppThemeModeSetting.light => 'light',
      AppThemeModeSetting.dark => 'dark',
    };
    await preferences.setString(_themeModeKey, raw);
  }

  Future<AppPaletteSetting> loadPalette() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final String raw = preferences.getString(_paletteKey) ?? 'neutral';
    return switch (raw) {
      'expressive' => AppPaletteSetting.expressive,
      'tonal_spot' => AppPaletteSetting.tonalSpot,
      _ => AppPaletteSetting.neutral,
    };
  }

  Future<void> savePalette(AppPaletteSetting palette) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final String raw = switch (palette) {
      AppPaletteSetting.neutral => 'neutral',
      AppPaletteSetting.expressive => 'expressive',
      AppPaletteSetting.tonalSpot => 'tonal_spot',
    };
    await preferences.setString(_paletteKey, raw);
  }

  Future<String> loadDeviceAlias() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    return preferences.getString(_deviceAliasKey)?.trim() ?? '';
  }

  Future<void> saveDeviceAlias(String value) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final String normalized = value.trim();
    if (normalized.isEmpty) {
      await preferences.remove(_deviceAliasKey);
      return;
    }
    await preferences.setString(_deviceAliasKey, normalized);
  }

  Future<String> loadOrCreateDeviceIdentity() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final String? existing = preferences.getString(_deviceIdentityKey)?.trim();
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final String created = _generateDeviceIdentity();
    await preferences.setString(_deviceIdentityKey, created);
    return created;
  }

  String _generateDeviceIdentity() {
    final Random random = Random.secure();
    final String randomHex = List<String>.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    return 'ms-${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}-$randomHex';
  }
}
