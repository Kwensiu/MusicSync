import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_sync/features/connection/state/connection_controller.dart';
import 'package:music_sync/features/directory/state/directory_controller.dart';
import 'package:music_sync/features/execution/state/execution_controller.dart';
import 'package:music_sync/features/execution/state/execution_state.dart';
import 'package:music_sync/features/preview/state/preview_controller.dart';
import 'package:music_sync/features/preview/state/preview_state.dart';
import 'package:music_sync/models/device_info.dart';
import 'package:music_sync/models/execution_result.dart';
import 'package:music_sync/models/file_entry.dart';
import 'package:music_sync/models/scan_snapshot.dart';
import 'package:music_sync/services/file_access/file_access_entry.dart';
import 'package:music_sync/services/file_access/file_access_gateway.dart';
import 'package:music_sync/services/file_access/file_access_provider.dart';
import 'package:music_sync/services/network/connection_service.dart';
import 'package:music_sync/services/network/listener_service.dart';
import 'package:music_sync/services/network/peer_session.dart';
import 'package:music_sync/services/storage/recent_items_store.dart';

void main() {
  test('remote preview sequence refreshes remote snapshot before building plan',
      () async {
    final _PreviewFakeConnectionService connectionService =
        _PreviewFakeConnectionService(
      snapshots: <ScanSnapshot>[
        _remoteSnapshot('Remote Old'),
        _remoteSnapshot('Remote New'),
      ],
    );
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        connectionServiceProvider.overrideWithValue(connectionService),
        listenerServiceProvider
            .overrideWithValue(_PreviewFakeListenerService()),
        recentItemsStoreProvider
            .overrideWithValue(_PreviewFakeRecentItemsStore()),
        fileAccessGatewayProvider
            .overrideWithValue(_PreviewFakeFileAccessGateway()),
      ],
    );
    addTearDown(container.dispose);

    container.read(directoryControllerProvider.notifier).setDirectory(
          const DirectoryHandle(entryId: 'local-root', displayName: 'Music'),
        );
    await container.read(connectionControllerProvider.notifier).connect(
          address: '192.168.1.2',
          port: 44888,
        );

    final ScanSnapshot? refreshed = await container
        .read(connectionControllerProvider.notifier)
        .refreshRemoteSnapshot();
    final ScanSnapshot localSnapshot =
        await container.read(directoryScannerProvider).scan(
              root: const DirectoryHandle(
                  entryId: 'local-root', displayName: 'Music'),
              deviceId: 'local-device',
            );
    await container
        .read(previewControllerProvider.notifier)
        .buildPreviewFromSnapshots(
          source: localSnapshot,
          target: refreshed!,
          deleteEnabled: true,
          sourceRootId: 'local-root',
        );

    final PreviewState previewState = container.read(previewControllerProvider);
    expect(connectionService.requestCount, 2);
    expect(previewState.mode, PreviewMode.remote);
    expect(previewState.targetSnapshot?.rootDisplayName, 'Remote New');
  });

  test(
      'refreshRemoteSnapshot can preserve execution result while updating remote index',
      () async {
    final _PreviewFakeConnectionService connectionService =
        _PreviewFakeConnectionService(
      snapshots: <ScanSnapshot>[
        _remoteSnapshot('Remote Old'),
        _remoteSnapshot('Remote New'),
      ],
    );
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        connectionServiceProvider.overrideWithValue(connectionService),
        listenerServiceProvider
            .overrideWithValue(_PreviewFakeListenerService()),
        recentItemsStoreProvider
            .overrideWithValue(_PreviewFakeRecentItemsStore()),
        fileAccessGatewayProvider
            .overrideWithValue(_PreviewFakeFileAccessGateway()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(connectionControllerProvider.notifier).connect(
          address: '192.168.1.2',
          port: 44888,
        );
    container.read(executionControllerProvider.notifier).state = ExecutionState(
      status: ExecutionStatus.completed,
      progress: container.read(executionControllerProvider).progress,
      result: const ExecutionResult(
        copiedCount: 2,
        deletedCount: 1,
        failedCount: 0,
        totalBytes: 128,
        targetRoot: 'remote-root',
      ),
      mode: ExecutionMode.remote,
      targetRoot: 'remote-root',
    );

    final ScanSnapshot? refreshed = await container
        .read(connectionControllerProvider.notifier)
        .refreshRemoteSnapshot(clearTransientState: false);

    expect(refreshed?.rootDisplayName, 'Remote New');
    expect(
      container.read(executionControllerProvider).status,
      ExecutionStatus.completed,
    );
    expect(
      container.read(executionControllerProvider).result.copiedCount,
      2,
    );
  });
}

class _PreviewFakeConnectionService extends ConnectionService {
  _PreviewFakeConnectionService({required this.snapshots});

  final List<ScanSnapshot> snapshots;
  int requestCount = 0;

  @override
  Future<DeviceInfo> connect({
    required String address,
    required int port,
    required DeviceInfo localDevice,
  }) async {
    return DeviceInfo(
      deviceId: 'peer',
      deviceName: 'Peer',
      platform: 'android',
      address: address,
      port: port,
    );
  }

  @override
  Future<ScanSnapshot> requestRemoteScan() async {
    final int index =
        requestCount < snapshots.length ? requestCount : snapshots.length - 1;
    requestCount++;
    return snapshots[index];
  }
}

class _PreviewFakeListenerService extends ListenerService {
  @override
  Future<void> start({
    required int port,
    void Function(PeerSession session)? onClient,
  }) async {}

  @override
  Future<void> stop() async {}
}

class _PreviewFakeRecentItemsStore extends RecentItemsStore {
  @override
  Future<List<String>> loadRecentAddresses() async => const <String>[];

  @override
  Future<List<DirectoryHandle>> loadRecentDirectories() async =>
      const <DirectoryHandle>[];

  @override
  Future<void> saveRecentAddress(String address) async {}

  @override
  Future<void> saveRecentDirectory(DirectoryHandle handle) async {}
}

class _PreviewFakeFileAccessGateway implements FileAccessGateway {
  @override
  Future<String> createDirectory(String parentId, String name) async => '';

  @override
  Future<void> deleteEntry(String entryId) async {}

  @override
  Future<List<FileAccessEntry>> listChildren(String directoryId) async {
    if (directoryId == 'local-root') {
      return <FileAccessEntry>[
        FileAccessEntry(
          entryId: 'song-1',
          name: 'song.mp3',
          isDirectory: false,
          size: 1,
          modifiedTime: DateTime.fromMillisecondsSinceEpoch(0),
        ),
      ];
    }
    return const <FileAccessEntry>[];
  }

  @override
  Stream<List<int>> openRead(String entryId) async* {}

  @override
  Future<FileWriteSession> openWrite(String parentId, String name) {
    throw UnimplementedError();
  }

  @override
  Future<String> renameEntry(String entryId, String newName) async => entryId;

  @override
  Future<DirectoryHandle?> pickDirectory() async => null;

  @override
  Future<FileAccessEntry> stat(String entryId) {
    throw UnimplementedError();
  }
}

ScanSnapshot _remoteSnapshot(String name) {
  return ScanSnapshot(
    rootId: 'remote-root',
    rootDisplayName: name,
    deviceId: 'remote-device',
    scannedAt: DateTime.fromMillisecondsSinceEpoch(0),
    entries: const <FileEntry>[],
    cacheVersion: 1,
  );
}
