import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_sync/features/connection/state/connection_controller.dart';
import 'package:music_sync/features/connection/state/connection_state.dart'
    as peer_connection;
import 'package:music_sync/features/directory/state/directory_controller.dart';
import 'package:music_sync/features/directory/state/directory_state.dart';
import 'package:music_sync/features/execution/state/execution_controller.dart';
import 'package:music_sync/features/execution/state/execution_state.dart';
import 'package:music_sync/features/preview/presentation/pages/preview_page.dart';
import 'package:music_sync/features/preview/state/preview_controller.dart';
import 'package:music_sync/features/settings/state/settings_controller.dart';
import 'package:music_sync/features/settings/state/settings_state.dart';
import 'package:music_sync/l10n/generated/app_localizations.dart';
import 'package:music_sync/models/device_info.dart';
import 'package:music_sync/models/file_entry.dart';
import 'package:music_sync/models/scan_snapshot.dart';
import 'package:music_sync/services/file_access/file_access_entry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('long press excludes extension and shows compact feedback', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await _pumpPreviewPage(tester);
    final Finder flacChip = find.byKey(
      const ValueKey<String>('preview-extension-chip-flac'),
    );

    await tester.ensureVisible(flacChip);
    await tester.longPress(flacChip);
    await tester.pumpAndSettle();

    final PreviewController controller = container.read(
      previewControllerProvider.notifier,
    );
    expect(controller.state.excludedExtensions, <String>{'flac'});
    expect(
      controller.state.plan.copyItems.map((item) => item.relativePath),
      <String>['keep.mp3'],
    );
    expect(find.byIcon(Icons.block), findsOneWidget);
    expect(find.text('Excluded .flac'), findsOneWidget);
  });

  testWidgets('long press on excluded extension restores it', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await _pumpPreviewPage(tester);
    final Finder flacChip = find.byKey(
      const ValueKey<String>('preview-extension-chip-flac'),
    );

    await tester.ensureVisible(flacChip);
    await tester.longPress(flacChip);
    await tester.pumpAndSettle();
    await tester.ensureVisible(flacChip);
    await tester.longPress(flacChip);
    await tester.pumpAndSettle();

    final PreviewController controller = container.read(
      previewControllerProvider.notifier,
    );
    expect(controller.state.excludedExtensions, isEmpty);
    expect(
      controller.state.plan.copyItems.map((item) => item.relativePath).toSet(),
      <String>{'keep.mp3', 'keep.flac'},
    );
    expect(find.byIcon(Icons.block), findsNothing);
  });

  testWidgets('tap on excluded extension does not restore or reselect it', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await _pumpPreviewPage(tester);
    final Finder flacChip = find.byKey(
      const ValueKey<String>('preview-extension-chip-flac'),
    );

    await tester.ensureVisible(flacChip);
    await tester.longPress(flacChip);
    await tester.pumpAndSettle();
    await tester.ensureVisible(flacChip);
    await tester.tap(flacChip, warnIfMissed: false);
    await tester.pumpAndSettle();

    final PreviewController controller = container.read(
      previewControllerProvider.notifier,
    );
    expect(controller.state.excludedExtensions, <String>{'flac'});
    expect(
      controller.state.plan.copyItems.map((item) => item.relativePath),
      <String>['keep.mp3'],
    );
    expect(find.text('Restored .flac'), findsNothing);
    expect(find.byIcon(Icons.block), findsOneWidget);
  });

  testWidgets('summary follows selected file type filter', (
    WidgetTester tester,
  ) async {
    await _pumpPreviewPage(tester);
    final Finder flacChip = find.byKey(
      const ValueKey<String>('preview-extension-chip-flac'),
    );

    expect(find.text('Copy: 2'), findsOneWidget);

    await tester.ensureVisible(flacChip);
    await tester.tap(flacChip);
    await tester.pumpAndSettle();

    expect(find.text('Copy: 2'), findsNothing);
    expect(find.text('Copy: 1'), findsOneWidget);
  });
}

Future<ProviderContainer> _pumpPreviewPage(WidgetTester tester) async {
  final ProviderContainer container = ProviderContainer(
    overrides: [
      connectionControllerProvider.overrideWith(
        _PreviewExtensionConnectionController.new,
      ),
      directoryControllerProvider.overrideWith(
        _PreviewExtensionDirectoryController.new,
      ),
      executionControllerProvider.overrideWith(
        _PreviewExtensionExecutionController.new,
      ),
      settingsControllerProvider.overrideWith(
        _PreviewExtensionSettingsController.new,
      ),
    ],
  );
  addTearDown(container.dispose);

  final PreviewController controller = container.read(
    previewControllerProvider.notifier,
  );
  await controller.buildPreviewFromSnapshots(
    source: _localSnapshot(),
    target: _remoteSnapshot(),
    deleteEnabled: true,
  );

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PreviewPage(),
      ),
    ),
  );
  await tester.pump();
  return container;
}

class _PreviewExtensionConnectionController extends ConnectionController {
  @override
  peer_connection.ConnectionState build() {
    return peer_connection.ConnectionState(
      status: peer_connection.ConnectionStatus.connected,
      peer: const DeviceInfo(
        deviceId: 'peer-device',
        deviceName: 'Peer',
        platform: 'android',
        address: '192.168.1.8',
        port: 44888,
      ),
      remoteSnapshot: _remoteSnapshot(),
      isRemoteDirectoryReady: true,
    );
  }
}

class _PreviewExtensionDirectoryController extends DirectoryController {
  @override
  DirectoryState build() {
    return const DirectoryState(
      handle: DirectoryHandle(entryId: 'local-root', displayName: 'Music'),
    );
  }
}

class _PreviewExtensionExecutionController extends ExecutionController {
  @override
  ExecutionState build() => ExecutionState.initial();
}

class _PreviewExtensionSettingsController extends SettingsController {
  @override
  SettingsState build() {
    return const SettingsState(
      deviceAlias: 'Studio PC',
      deviceDisplayName: 'Studio PC',
    );
  }
}

ScanSnapshot _localSnapshot() {
  return ScanSnapshot(
    rootId: 'local-root',
    rootDisplayName: 'Music',
    deviceId: 'local-device',
    scannedAt: DateTime.fromMillisecondsSinceEpoch(0),
    entries: <FileEntry>[
      _fileEntry('keep.mp3', 'local-device'),
      _fileEntry('keep.flac', 'local-device'),
    ],
    cacheVersion: 1,
  );
}

ScanSnapshot _remoteSnapshot() {
  return ScanSnapshot(
    rootId: 'remote-root',
    rootDisplayName: 'Remote',
    deviceId: 'peer-device',
    scannedAt: DateTime.fromMillisecondsSinceEpoch(0),
    entries: const <FileEntry>[],
    cacheVersion: 1,
  );
}

FileEntry _fileEntry(String path, String sourceId) {
  return FileEntry(
    relativePath: path,
    entryId: path,
    sourceId: sourceId,
    isDirectory: false,
    size: 1,
    modifiedTime: DateTime.fromMillisecondsSinceEpoch(0),
  );
}
