import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:music_sync/services/network/discovery_service.dart';
import 'package:music_sync/services/network/http/http_sync_client.dart';
import 'package:music_sync/services/network/http/http_sync_dto.dart';
import 'package:music_sync/services/network/http/http_sync_server_service.dart';
import 'package:music_sync/services/storage/recent_items_store.dart';

void main() {
  test(
    'remote preview sequence refreshes remote snapshot before building plan',
    () async {
      final _PreviewFakeHttpSyncClient client = _PreviewFakeHttpSyncClient(
        helloResponse: const HelloResponseDto(
          device: DeviceInfo(
            deviceId: 'peer',
            deviceName: 'Peer',
            platform: 'android',
            address: '',
            port: 44888,
          ),
          directoryReady: true,
        ),
        scanResponses: <ScanResponseDto>[
          ScanResponseDto(snapshot: _remoteSnapshot('Remote Old')),
          ScanResponseDto(snapshot: _remoteSnapshot('Remote New')),
        ],
      );
      final ProviderContainer container = _container(client);
      addTearDown(container.dispose);

      container
          .read(directoryControllerProvider.notifier)
          .setDirectory(
            const DirectoryHandle(entryId: 'local-root', displayName: 'Music'),
          );
      await container
          .read(connectionControllerProvider.notifier)
          .connect(address: '192.168.1.2', port: 44888);

      final ScanSnapshot? refreshed = await container
          .read(connectionControllerProvider.notifier)
          .refreshRemoteSnapshot();
      final ScanSnapshot localSnapshot = await container
          .read(directoryScannerProvider)
          .scan(
            root: const DirectoryHandle(
              entryId: 'local-root',
              displayName: 'Music',
            ),
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

      final PreviewState previewState = container.read(
        previewControllerProvider,
      );
      expect(client.scanRequestCount, 2);
      expect(previewState.mode, PreviewMode.remote);
      expect(previewState.targetSnapshot?.rootDisplayName, 'Remote New');
    },
  );

  test(
    'refreshRemoteSnapshot can preserve execution result while updating remote index',
    () async {
      final _PreviewFakeHttpSyncClient client = _PreviewFakeHttpSyncClient(
        helloResponse: const HelloResponseDto(
          device: DeviceInfo(
            deviceId: 'peer',
            deviceName: 'Peer',
            platform: 'android',
            address: '',
            port: 44888,
          ),
          directoryReady: true,
        ),
        scanResponses: <ScanResponseDto>[
          ScanResponseDto(snapshot: _remoteSnapshot('Remote Old')),
          ScanResponseDto(snapshot: _remoteSnapshot('Remote New')),
        ],
      );
      final ProviderContainer container = _container(client);
      addTearDown(container.dispose);

      await container
          .read(connectionControllerProvider.notifier)
          .connect(address: '192.168.1.2', port: 44888);
      container
          .read(executionControllerProvider.notifier)
          .state = ExecutionState(
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
    },
  );
}

ProviderContainer _container(_PreviewFakeHttpSyncClient client) {
  return ProviderContainer(
    overrides: [
      httpSyncClientProvider.overrideWithValue(client),
      httpSyncServerServiceProvider.overrideWithValue(_NoopHttpServer()),
      discoveryServiceProvider.overrideWithValue(_NoopDiscovery()),
      recentItemsStoreProvider.overrideWithValue(_NoopRecentStore()),
      fileAccessGatewayProvider.overrideWithValue(
        _PreviewFakeFileAccessGateway(),
      ),
    ],
  );
}

class _PreviewFakeHttpSyncClient extends HttpSyncClient {
  _PreviewFakeHttpSyncClient({
    required this.helloResponse,
    required this.scanResponses,
  });

  final HelloResponseDto helloResponse;
  final List<ScanResponseDto> scanResponses;
  int scanRequestCount = 0;

  @override
  Future<HelloResponseDto> hello({
    required String address,
    required int port,
    required DeviceInfo localDevice,
    required bool directoryReady,
    String? directoryDisplayName,
  }) async {
    return helloResponse;
  }

  @override
  Future<DirectoryStatusResponseDto> directoryStatus({
    required String address,
    required int port,
  }) async {
    return const DirectoryStatusResponseDto(directoryReady: true);
  }

  @override
  Future<ScanResponseDto> scan({
    required String address,
    required int port,
  }) async {
    final int index = scanRequestCount < scanResponses.length
        ? scanRequestCount
        : scanResponses.length - 1;
    scanRequestCount++;
    return scanResponses[index];
  }
}

class _NoopHttpServer extends HttpSyncServerService {
  @override
  Future<void> start({
    required int port,
    required HelloHandler onHello,
    required SessionCloseHandler onSessionClose,
    required DirectoryStatusHandler onDirectoryStatus,
    required ScanHandler onScan,
    required EntryDetailHandler onEntryDetail,
    required SyncSessionStateHandler onSyncSessionState,
    required BeginCopyHandler onBeginCopy,
    required WriteChunkHandler onWriteChunk,
    required FinishCopyHandler onFinishCopy,
    required AbortCopyHandler onAbortCopy,
    required DeleteEntryHandler onDeleteEntry,
  }) async {}

  @override
  Future<void> stop() async {}
}

class _NoopDiscovery extends DiscoveryService {
  @override
  Future<void> startReceiving({required DiscoveryCallback onDevice}) async {}

  @override
  Future<void> startBroadcasting(DeviceInfo device) async {}

  @override
  Future<void> sendGoodbye(DeviceInfo device) async {}

  @override
  Future<void> stopBroadcasting() async {}

  @override
  Future<void> dispose() async {}
}

class _NoopRecentStore extends RecentItemsStore {
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
