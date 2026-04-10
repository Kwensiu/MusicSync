import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_sync/features/connection/state/connection_controller.dart';
import 'package:music_sync/features/settings/state/settings_state.dart';
import 'package:music_sync/services/storage/settings_store.dart';

final Provider<SettingsStore> settingsStoreProvider = Provider<SettingsStore>(
  (Ref ref) => SettingsStore(),
);

final NotifierProvider<SettingsController, SettingsState>
settingsControllerProvider =
    NotifierProvider<SettingsController, SettingsState>(SettingsController.new);

class SettingsController extends Notifier<SettingsState> {
  SettingsStore get _store => ref.read(settingsStoreProvider);

  @override
  SettingsState build() {
    Future<void>.microtask(load);
    return const SettingsState();
  }

  Future<void> load() async {
    final SettingsStore store = _store;
    state = state.copyWith(isLoading: true);
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
