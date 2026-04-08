import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_sync/features/settings/state/settings_state.dart';
import 'package:music_sync/services/storage/settings_store.dart';

final Provider<SettingsStore> settingsStoreProvider =
    Provider<SettingsStore>((Ref ref) => SettingsStore());

final StateNotifierProvider<SettingsController, SettingsState>
    settingsControllerProvider =
    StateNotifierProvider<SettingsController, SettingsState>(
  (Ref ref) => SettingsController(ref.watch(settingsStoreProvider)),
);

class SettingsController extends StateNotifier<SettingsState> {
  SettingsController(this._store) : super(const SettingsState()) {
    load();
  }

  final SettingsStore _store;

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    final bool autoStartListening = await _store.loadAutoStartListening();
    final List<String> ignoredExtensions = await _store.loadIgnoredExtensions();
    final AppThemeModeSetting themeMode = await _store.loadThemeMode();
    final AppPaletteSetting palette = await _store.loadPalette();
    state = state.copyWith(
      isLoading: false,
      autoStartListening: autoStartListening,
      ignoredExtensions: ignoredExtensions,
      themeMode: themeMode,
      palette: palette,
    );
  }

  Future<void> setAutoStartListening(bool value) async {
    state = state.copyWith(
      isLoading: true,
      autoStartListening: value,
    );
    await _store.saveAutoStartListening(value);
    state = state.copyWith(
      isLoading: false,
      autoStartListening: value,
    );
  }

  Future<void> saveIgnoredExtensions(List<String> values) async {
    state = state.copyWith(
      isLoading: true,
      ignoredExtensions: values,
    );
    await _store.saveIgnoredExtensions(values);
    final List<String> reloaded = await _store.loadIgnoredExtensions();
    state = state.copyWith(
      isLoading: false,
      ignoredExtensions: reloaded,
    );
  }

  Future<void> setThemeMode(AppThemeModeSetting mode) async {
    state = state.copyWith(
      isLoading: true,
      themeMode: mode,
    );
    await _store.saveThemeMode(mode);
    state = state.copyWith(
      isLoading: false,
      themeMode: mode,
    );
  }

  Future<void> setPalette(AppPaletteSetting palette) async {
    state = state.copyWith(
      isLoading: true,
      palette: palette,
    );
    await _store.savePalette(palette);
    state = state.copyWith(
      isLoading: false,
      palette: palette,
    );
  }
}
