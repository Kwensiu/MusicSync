import 'package:flutter_test/flutter_test.dart';
import 'package:music_sync/features/settings/state/settings_controller.dart';
import 'package:music_sync/features/settings/state/settings_state.dart';
import 'package:music_sync/services/storage/settings_store.dart';

void main() {
  test('SettingsController saves and reloads normalized ignored extensions',
      () async {
    final _FakeSettingsStore store = _FakeSettingsStore();
    final SettingsController controller = SettingsController(store);
    addTearDown(controller.dispose);

    await controller.load();
    await controller.saveIgnoredExtensions(
      const <String>['.lrc', 'jpg', '..JPG', '  .LRC  '],
    );

    expect(controller.state.ignoredExtensions, <String>['jpg', 'lrc']);
    expect(store.savedIgnoredExtensions, <String>['jpg', 'lrc']);
  });
}

class _FakeSettingsStore extends SettingsStore {
  bool autoStartListening = false;
  List<String> savedIgnoredExtensions = <String>[];
  AppThemeModeSetting savedThemeMode = AppThemeModeSetting.system;
  AppPaletteSetting savedPalette = AppPaletteSetting.neutral;

  @override
  Future<bool> loadAutoStartListening() async => autoStartListening;

  @override
  Future<void> saveAutoStartListening(bool value) async {
    autoStartListening = value;
  }

  @override
  Future<List<String>> loadIgnoredExtensions() async => savedIgnoredExtensions;

  @override
  Future<void> saveIgnoredExtensions(List<String> values) async {
    savedIgnoredExtensions = values
        .map((String value) =>
            value.trim().toLowerCase().replaceFirst(RegExp(r'^\.+'), ''))
        .where((String value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  @override
  Future<AppThemeModeSetting> loadThemeMode() async => savedThemeMode;

  @override
  Future<void> saveThemeMode(AppThemeModeSetting mode) async {
    savedThemeMode = mode;
  }

  @override
  Future<AppPaletteSetting> loadPalette() async => savedPalette;

  @override
  Future<void> savePalette(AppPaletteSetting palette) async {
    savedPalette = palette;
  }
}
