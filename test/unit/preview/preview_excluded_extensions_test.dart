import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_sync/features/preview/state/preview_controller.dart';
import 'package:music_sync/features/preview/state/preview_state.dart';
import 'package:music_sync/models/file_entry.dart';
import 'package:music_sync/models/scan_snapshot.dart';
import 'package:music_sync/services/diff/diff_engine.dart';
import 'package:music_sync/services/file_access/file_access_entry.dart';
import 'package:music_sync/services/file_access/file_access_gateway.dart';
import 'package:music_sync/services/file_access/file_access_provider.dart';
import 'package:music_sync/services/scanning/directory_scanner.dart';
import 'package:music_sync/services/scanning/scan_cache_service.dart';

void main() {
  late ProviderContainer container;
  late PreviewController controller;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        diffEngineProvider.overrideWithValue(DiffEngine()),
        fileAccessGatewayProvider.overrideWithValue(_NoopGateway()),
        scanCacheServiceProvider.overrideWithValue(ScanCacheService()),
        directoryScannerProvider.overrideWithValue(
          DirectoryScanner(
            gateway: _NoopGateway(),
            cacheService: ScanCacheService(),
          ),
        ),
      ],
    );
    controller = container.read(previewControllerProvider.notifier);
  });

  tearDown(() => container.dispose());

  test('toggleExcludedExtension removes extension items from plan', () async {
    await controller.buildPreviewFromSnapshots(
      source: _snapshot(<String>[
        'a.mp3',
        'b.flac',
        'c.jpg',
      ], deviceId: 'local'),
      target: _snapshot(<String>[], deviceId: 'remote'),
      deleteEnabled: true,
    );

    expect(controller.state.plan.copyItems.length, 3);
    expect(controller.state.excludedExtensions, <String>{});

    controller.toggleExcludedExtension('flac');

    expect(controller.state.excludedExtensions, <String>{'flac'});
    expect(controller.state.plan.copyItems.map((i) => i.relativePath), <String>[
      'a.mp3',
      'c.jpg',
    ]);
  });

  test(
    'toggleExcludedExtension restores previously excluded extension',
    () async {
      await controller.buildPreviewFromSnapshots(
        source: _snapshot(<String>['a.mp3', 'b.flac'], deviceId: 'local'),
        target: _snapshot(<String>[], deviceId: 'remote'),
        deleteEnabled: true,
      );

      controller.toggleExcludedExtension('flac');
      expect(controller.state.excludedExtensions, <String>{'flac'});

      controller.toggleExcludedExtension('flac');
      expect(controller.state.excludedExtensions, <String>{});
      expect(controller.state.plan.copyItems.length, 2);
    },
  );

  test('availableExtensions still contains excluded extension', () async {
    await controller.buildPreviewFromSnapshots(
      source: _snapshot(<String>['a.mp3', 'b.flac'], deviceId: 'local'),
      target: _snapshot(<String>[], deviceId: 'remote'),
      deleteEnabled: true,
    );

    controller.toggleExcludedExtension('flac');

    expect(controller.state.availableExtensions, contains('flac'));
  });

  test('toggleExcludedExtension on * is a no-op', () async {
    await controller.buildPreviewFromSnapshots(
      source: _snapshot(<String>['a.mp3'], deviceId: 'local'),
      target: _snapshot(<String>[], deviceId: 'remote'),
      deleteEnabled: true,
    );

    controller.toggleExcludedExtension('*');

    expect(controller.state.excludedExtensions, <String>{});
    expect(controller.state.plan.copyItems.length, 1);
  });

  test('excluded extensions combine with ignored extensions', () async {
    await controller.buildPreviewFromSnapshots(
      source: _snapshot(<String>[
        'a.mp3',
        'b.flac',
        'c.jpg',
        'd.lrc',
      ], deviceId: 'local'),
      target: _snapshot(<String>[], deviceId: 'remote'),
      deleteEnabled: true,
      ignoredExtensions: const <String>['jpg'],
    );

    // jpg already filtered by ignored; flac excluded via toggle
    controller.toggleExcludedExtension('flac');

    expect(controller.state.plan.copyItems.map((i) => i.relativePath), <String>[
      'a.mp3',
      'd.lrc',
    ]);
    expect(controller.state.availableExtensions, contains('flac'));
    // jpg is not in availableExtensions because it was globally ignored
  });

  test(
    'buildPreviewFromSnapshots resets excludedExtensions by default',
    () async {
      await controller.buildPreviewFromSnapshots(
        source: _snapshot(<String>['a.mp3', 'b.flac'], deviceId: 'local'),
        target: _snapshot(<String>[], deviceId: 'remote'),
        deleteEnabled: true,
      );

      controller.toggleExcludedExtension('flac');
      expect(controller.state.excludedExtensions, <String>{'flac'});

      // Rebuilding preview without passing excludedExtensions resets it
      await controller.buildPreviewFromSnapshots(
        source: _snapshot(<String>['a.mp3', 'b.flac'], deviceId: 'local'),
        target: _snapshot(<String>[], deviceId: 'remote'),
        deleteEnabled: true,
      );

      expect(controller.state.excludedExtensions, <String>{});
      expect(controller.state.plan.copyItems.length, 2);
    },
  );

  test(
    'buildPreviewFromSnapshots preserves excludedExtensions when passed',
    () async {
      await controller.buildPreviewFromSnapshots(
        source: _snapshot(<String>['a.mp3', 'b.flac'], deviceId: 'local'),
        target: _snapshot(<String>[], deviceId: 'remote'),
        deleteEnabled: true,
      );

      controller.toggleExcludedExtension('flac');

      // Rebuilding with excludedExtensions preserved
      await controller.buildPreviewFromSnapshots(
        source: _snapshot(<String>['a.mp3', 'b.flac'], deviceId: 'local'),
        target: _snapshot(<String>[], deviceId: 'remote'),
        deleteEnabled: true,
        excludedExtensions: controller.state.excludedExtensions,
      );

      expect(controller.state.excludedExtensions, <String>{'flac'});
      expect(controller.state.plan.copyItems.length, 1);
    },
  );

  test('clear resets excludedExtensions', () async {
    await controller.buildPreviewFromSnapshots(
      source: _snapshot(<String>['a.mp3', 'b.flac'], deviceId: 'local'),
      target: _snapshot(<String>[], deviceId: 'remote'),
      deleteEnabled: true,
    );

    controller.toggleExcludedExtension('flac');
    controller.clear();

    expect(controller.state.excludedExtensions, <String>{});
    expect(controller.state.status, PreviewStatus.idle);
  });

  test('exclude removes copy, delete, and conflict items', () async {
    await controller.buildPreviewFromSnapshots(
      source: _snapshot(<String>['new.mp3', 'extra.flac'], deviceId: 'local'),
      target: _snapshot(<String>['old.mp3', 'stale.flac'], deviceId: 'remote'),
      deleteEnabled: true,
    );

    // Before exclusion: mp3 copy, flac copy (new vs old content), flac delete
    controller.toggleExcludedExtension('flac');

    final plan = controller.state.plan;
    expect(
      plan.copyItems.every((i) => !i.relativePath.endsWith('.flac')),
      isTrue,
    );
    expect(
      plan.deleteItems.every((i) => !i.relativePath.endsWith('.flac')),
      isTrue,
    );
    expect(
      plan.conflictItems.every((i) => !i.relativePath.endsWith('.flac')),
      isTrue,
    );
  });
}

ScanSnapshot _snapshot(List<String> paths, {required String deviceId}) {
  return ScanSnapshot(
    rootId: '$deviceId-root',
    rootDisplayName: deviceId,
    deviceId: deviceId,
    scannedAt: DateTime.fromMillisecondsSinceEpoch(0),
    entries: paths
        .map(
          (String path) => FileEntry(
            relativePath: path,
            entryId: path,
            sourceId: deviceId,
            isDirectory: false,
            size: 1,
            modifiedTime: DateTime.fromMillisecondsSinceEpoch(0),
          ),
        )
        .toList(),
    cacheVersion: 1,
  );
}

class _NoopGateway implements FileAccessGateway {
  @override
  Future<String> createDirectory(String parentId, String name) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteEntry(String entryId) {
    throw UnimplementedError();
  }

  @override
  Future<List<FileAccessEntry>> listChildren(String directoryId) {
    throw UnimplementedError();
  }

  @override
  Stream<List<int>> openRead(String entryId) async* {}

  @override
  Future<FileWriteSession> openWrite(String parentId, String name) {
    throw UnimplementedError();
  }

  @override
  Future<DirectoryHandle?> pickDirectory() async => null;

  @override
  Future<String> renameEntry(String entryId, String newName) {
    throw UnimplementedError();
  }

  @override
  Future<FileAccessEntry> stat(String entryId) {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, String?>?> getAudioMetadata(String entryId) async => null;
}
