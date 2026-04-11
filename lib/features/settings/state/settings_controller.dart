import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_sync/features/connection/state/connection_controller.dart';
import 'package:music_sync/features/settings/state/settings_state.dart';
import 'package:music_sync/services/platform/device_display_info_service.dart';
import 'package:music_sync/services/storage/settings_store.dart';

final Provider<SettingsStore> settingsStoreProvider = Provider<SettingsStore>(
  (Ref ref) => SettingsStore(),
);

final NotifierProvider<SettingsController, SettingsState>
settingsControllerProvider =
    NotifierProvider<SettingsController, SettingsState>(SettingsController.new);

class SettingsController extends Notifier<SettingsState> {
  SettingsStore get _store => ref.read(settingsStoreProvider);
  DeviceDisplayInfoService get _deviceDisplayInfo =>
      ref.read(deviceDisplayInfoServiceProvider);

  @override
  SettingsState build() {
    Future<void>.microtask(load);
    return const SettingsState();
  }

  Future<void> load() async {
    final SettingsStore store = _store;
    state = state.copyWith(isLoading: true);
    final String defaultAlias = await _deviceDisplayInfo.defaultAlias();
    if (!ref.mounted) {
      return;
    }
    final String deviceAlias = await store.loadDeviceAlias();
    if (!ref.mounted) {
      return;
    }
    final String deviceDisplayName = deviceAlias.isNotEmpty
        ? deviceAlias
        : defaultAlias;
    final bool autoStartListening = await store.loadAutoStartListening();
    if (!ref.mounted) {
      return;
    }
    final bool httpEncryptionEnabled = await store.loadHttpEncryptionEnabled();
    if (!ref.mounted) {
      return;
    }
    final List<String> ignoredExtensions = await store.loadIgnoredExtensions();
    if (!ref.mounted) {
      return;
    }
    final AppThemeModeSetting themeMode = await store.loadThemeMode();
    if (!ref.mounted) {
      return;
    }
    final AppPaletteSetting palette = await store.loadPalette();
    if (!ref.mounted) {
      return;
    }
    state = state.copyWith(
      isLoading: false,
      deviceAlias: deviceAlias,
      deviceDisplayName: deviceDisplayName,
      autoStartListening: autoStartListening,
      httpEncryptionEnabled: httpEncryptionEnabled,
      ignoredExtensions: ignoredExtensions,
      themeMode: themeMode,
      palette: palette,
    );
  }

  Future<void> setAutoStartListening(bool value) async {
    state = state.copyWith(isLoading: true, autoStartListening: value);
    await _store.saveAutoStartListening(value);
    state = state.copyWith(isLoading: false, autoStartListening: value);
  }

  Future<void> setDeviceAlias(String value) async {
    final String normalized = value.trim();
    final String defaultAlias = await _deviceDisplayInfo.defaultAlias();
    final String nextDisplayName = normalized.isNotEmpty
        ? normalized
        : defaultAlias;
    state = state.copyWith(
      isLoading: true,
      deviceAlias: normalized,
      deviceDisplayName: nextDisplayName,
    );
    await _store.saveDeviceAlias(normalized);
    if (!ref.mounted) {
      return;
    }
    state = state.copyWith(
      isLoading: false,
      deviceAlias: normalized,
      deviceDisplayName: nextDisplayName,
    );
    await ref.read(connectionControllerProvider.notifier).refreshPresence();
  }

  Future<void> setHttpEncryptionEnabled(bool value) async {
    final bool previousValue = state.httpEncryptionEnabled;
    if (value == previousValue) {
      return;
    }

    final ConnectionController connectionController = ref.read(
      connectionControllerProvider.notifier,
    );
    final SettingsStore store = _store;

    state = state.copyWith(isLoading: true, httpEncryptionEnabled: value);

    try {
      await connectionController.resetNetworkStateForProtocolChange();
      await store.saveHttpEncryptionEnabled(value);
      if (!ref.mounted) {
        return;
      }
      state = state.copyWith(isLoading: false, httpEncryptionEnabled: value);
    } catch (error) {
      if (ref.mounted) {
        state = state.copyWith(
          isLoading: true,
          httpEncryptionEnabled: previousValue,
        );
      }
      try {
        await connectionController.resetNetworkStateForProtocolChange();
      } catch (_) {
        // Keep the original switch failure as the surfaced error.
      }
      if (ref.mounted) {
        state = state.copyWith(
          isLoading: false,
          httpEncryptionEnabled: previousValue,
        );
      }
      rethrow;
    }
  }

  Future<void> saveIgnoredExtensions(List<String> values) async {
    state = state.copyWith(isLoading: true, ignoredExtensions: values);
    await _store.saveIgnoredExtensions(values);
    final List<String> reloaded = await _store.loadIgnoredExtensions();
    state = state.copyWith(isLoading: false, ignoredExtensions: reloaded);
  }

  Future<void> setThemeMode(AppThemeModeSetting mode) async {
    state = state.copyWith(isLoading: true, themeMode: mode);
    await _store.saveThemeMode(mode);
    state = state.copyWith(isLoading: false, themeMode: mode);
  }

  Future<void> setPalette(AppPaletteSetting palette) async {
    state = state.copyWith(isLoading: true, palette: palette);
    await _store.savePalette(palette);
    state = state.copyWith(isLoading: false, palette: palette);
  }
}
