import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_sync/features/connection/state/connection_controller.dart';
import 'package:music_sync/features/connection/state/connection_state.dart';
import 'package:music_sync/features/settings/state/settings_controller.dart';
import 'package:music_sync/features/settings/state/settings_state.dart';
import 'package:music_sync/services/storage/settings_store.dart';

void main() {
  test(
    'SettingsController saves and reloads normalized ignored extensions',
    () async {
      final _FakeSettingsStore store = _FakeSettingsStore();
      final ProviderContainer container = ProviderContainer(
        overrides: [
          settingsStoreProvider.overrideWithValue(store),
          connectionControllerProvider.overrideWith(
            _FakeConnectionController.new,
          ),
        ],
      );
      addTearDown(container.dispose);
      final SettingsController controller = container.read(
        settingsControllerProvider.notifier,
      );

      await controller.load();
      await controller.saveIgnoredExtensions(const <String>[
        '.lrc',
        'jpg',
        '..JPG',
        '  .LRC  ',
      ]);

      expect(controller.state.ignoredExtensions, <String>['jpg', 'lrc']);
      expect(store.savedIgnoredExtensions, <String>['jpg', 'lrc']);
    },
  );

  test('SettingsController loads persisted HTTP encryption setting', () async {
    final _FakeSettingsStore store = _FakeSettingsStore()
      ..httpEncryptionEnabled = false;
    final ProviderContainer container = ProviderContainer(
      overrides: [
        settingsStoreProvider.overrideWithValue(store),
        connectionControllerProvider.overrideWith(
          _FakeConnectionController.new,
        ),
      ],
    );
    addTearDown(container.dispose);

    final SettingsController controller = container.read(
      settingsControllerProvider.notifier,
    );
    await controller.load();

    expect(controller.state.httpEncryptionEnabled, isFalse);
  });

  test(
    'SettingsController applies HTTP encryption switch and persists after reset',
    () async {
      final _FakeSettingsStore store = _FakeSettingsStore();
      final ProviderContainer container = ProviderContainer(
        overrides: [
          settingsStoreProvider.overrideWithValue(store),
          connectionControllerProvider.overrideWith(
            _FakeConnectionController.new,
          ),
        ],
      );
      addTearDown(container.dispose);

      final SettingsController controller = container.read(
        settingsControllerProvider.notifier,
      );
      final _FakeConnectionController connectionController =
          container.read(connectionControllerProvider.notifier)
              as _FakeConnectionController;

      await controller.load();
      await controller.setHttpEncryptionEnabled(false);

      expect(connectionController.resetCallCount, 1);
      expect(controller.state.httpEncryptionEnabled, isFalse);
      expect(store.httpEncryptionEnabled, isFalse);
    },
  );

  test(
    'SettingsController rolls back HTTP encryption switch when reset fails',
    () async {
      final _FakeSettingsStore store = _FakeSettingsStore();
      final ProviderContainer container = ProviderContainer(
        overrides: [
          settingsStoreProvider.overrideWithValue(store),
          connectionControllerProvider.overrideWith(
            _FailingConnectionController.new,
          ),
        ],
      );
      addTearDown(container.dispose);

      final SettingsController controller = container.read(
        settingsControllerProvider.notifier,
      );
      final _FailingConnectionController connectionController =
          container.read(connectionControllerProvider.notifier)
              as _FailingConnectionController;

      await controller.load();

      await expectLater(
        controller.setHttpEncryptionEnabled(false),
        throwsA(isA<StateError>()),
      );

      expect(connectionController.resetCallCount, 2);
      expect(controller.state.httpEncryptionEnabled, isTrue);
      expect(store.httpEncryptionEnabled, isTrue);
      expect(controller.state.isLoading, isFalse);
    },
  );
}

class _FakeSettingsStore extends SettingsStore {
  bool autoStartListening = false;
  bool httpEncryptionEnabled = true;
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
  Future<bool> loadHttpEncryptionEnabled() async => httpEncryptionEnabled;

  @override
  Future<void> saveHttpEncryptionEnabled(bool value) async {
    httpEncryptionEnabled = value;
  }

  @override
  Future<List<String>> loadIgnoredExtensions() async => savedIgnoredExtensions;

  @override
  Future<void> saveIgnoredExtensions(List<String> values) async {
    savedIgnoredExtensions =
        values
            .map(
              (String value) =>
                  value.trim().toLowerCase().replaceFirst(RegExp(r'^\.+'), ''),
            )
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

class _FakeConnectionController extends ConnectionController {
  int resetCallCount = 0;

  @override
  ConnectionState build() => ConnectionState.initial();

  @override
  Future<void> resetNetworkStateForProtocolChange() async {
    resetCallCount++;
  }
}

class _FailingConnectionController extends _FakeConnectionController {
  @override
  Future<void> resetNetworkStateForProtocolChange() async {
    resetCallCount++;
    if (resetCallCount == 1) {
      throw StateError('reset failed');
    }
  }
}
