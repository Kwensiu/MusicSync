import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_sync/features/preview/state/preview_controller.dart';
import 'package:music_sync/models/file_entry.dart';
import 'package:music_sync/models/scan_snapshot.dart';
import 'package:music_sync/services/diff/diff_engine.dart';
import 'package:music_sync/services/file_access/file_access_entry.dart';
import 'package:music_sync/services/file_access/file_access_gateway.dart';
import 'package:music_sync/services/file_access/file_access_provider.dart';
import 'package:music_sync/services/scanning/directory_scanner.dart';
import 'package:music_sync/services/scanning/scan_cache_service.dart';

void main() {
  test(
    'buildPreviewFromSnapshots excludes ignored extensions from plan and available filters',
    () async {
      final ProviderContainer container = ProviderContainer(
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
      addTearDown(container.dispose);
      final PreviewController controller = container.read(
        previewControllerProvider.notifier,
      );

      await controller.buildPreviewFromSnapshots(
        source: _snapshot(<String>[
          'keep.mp3',
          'cover.jpg',
          'lyrics.lrc',
        ], deviceId: 'local'),
        target: _snapshot(<String>['old.mp3', 'cover.jpg'], deviceId: 'remote'),
        deleteEnabled: true,
        ignoredExtensions: const <String>['jpg', 'lrc'],
      );

      expect(
        controller.state.plan.copyItems.map((item) => item.relativePath),
        <String>['keep.mp3'],
      );
      expect(controller.state.availableExtensions, <String>['*', 'mp3']);
      expect(controller.state.ignoredExtensions, <String>['jpg', 'lrc']);
    },
  );

  test(
    'buildPreviewFromSnapshots normalizes dotted ignored extensions',
    () async {
      final ProviderContainer container = ProviderContainer(
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
      addTearDown(container.dispose);
      final PreviewController controller = container.read(
        previewControllerProvider.notifier,
      );

      await controller.buildPreviewFromSnapshots(
        source: _snapshot(<String>[
          'keep.mp3',
          'cover.jpg',
          'lyrics.lrc',
        ], deviceId: 'local'),
        target: _snapshot(<String>['old.mp3', 'cover.jpg'], deviceId: 'remote'),
        deleteEnabled: true,
        ignoredExtensions: const <String>['.jpg', '..LRC'],
      );

      expect(
        controller.state.plan.copyItems.map((item) => item.relativePath),
        <String>['keep.mp3'],
      );
      expect(controller.state.availableExtensions, <String>['*', 'mp3']);
    },
  );
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
}
