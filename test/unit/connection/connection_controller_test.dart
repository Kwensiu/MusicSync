import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_sync/features/connection/state/connection_controller.dart';
import 'package:music_sync/features/connection/state/connection_state.dart';
import 'package:music_sync/features/directory/state/directory_controller.dart';
import 'package:music_sync/features/execution/state/execution_controller.dart';
import 'package:music_sync/features/preview/models/diff_item_detail_view_data.dart';
import 'package:music_sync/models/device_info.dart';
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
  group('ConnectionController (HTTP)', () {
    test('connect succeeds even when remote shared directory is not selected yet',
        () async {
      final _FakeHttpSyncClient client = _FakeHttpSyncClient(
        helloResponse: const HelloResponseDto(
          device: DeviceInfo(
            deviceId: 'peer',
            deviceName: 'Peer',
            platform: 'android',
            address: '',
            port: 44888,
          ),
          directoryReady: false,
        ),
      );
      final ProviderContainer container = _container(client: client);
      addTearDown(container.dispose);

      await container
          .read(connectionControllerProvider.notifier)
          .connect(address: '192.168.1.2', port: 44888);

      final ConnectionState state = container.read(connectionControllerProvider);
      expect(state.status, ConnectionStatus.connected);
      expect(state.peer?.address, '192.168.1.2');
      expect(state.isRemoteDirectoryReady, isFalse);
      expect(state.remoteSnapshot, isNull);
    });

    test('refreshRemoteSnapshot updates remote snapshot over HTTP', () async {
      final _FakeHttpSyncClient client = _FakeHttpSyncClient(
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
        directoryStatusResponse: const DirectoryStatusResponseDto(
          directoryReady: true,
        ),
        scanResponse: ScanResponseDto(snapshot: _remoteSnapshot('Remote A')),
      );
      final ProviderContainer container = _container(client: client);
      addTearDown(container.dispose);

      await container
          .read(connectionControllerProvider.notifier)
          .connect(address: '192.168.1.2', port: 44888);

      final ScanSnapshot? refreshed = await container
          .read(connectionControllerProvider.notifier)
          .refreshRemoteSnapshot();

      expect(refreshed?.rootDisplayName, 'Remote A');
      expect(
        container.read(connectionControllerProvider).isRemoteDirectoryReady,
        isTrue,
      );
    });

    test('polling picks up remote directory after peer selects directory later',
        () async {
      final _FakeHttpSyncClient client = _FakeHttpSyncClient(
        helloResponse: const HelloResponseDto(
          device: DeviceInfo(
            deviceId: 'peer',
            deviceName: 'Peer',
            platform: 'android',
            address: '',
            port: 44888,
          ),
          directoryReady: false,
        ),
        directoryStatusSequence: <DirectoryStatusResponseDto>[
          const DirectoryStatusResponseDto(directoryReady: false),
          const DirectoryStatusResponseDto(directoryReady: true),
        ],
        scanResponse: ScanResponseDto(snapshot: _remoteSnapshot('Remote Later')),
      );
      final ProviderContainer container = _container(client: client);
      addTearDown(container.dispose);

      await container
          .read(connectionControllerProvider.notifier)
          .connect(address: '192.168.1.2', port: 44888);

      await Future<void>.delayed(const Duration(milliseconds: 2300));

      final ConnectionState state = container.read(connectionControllerProvider);
      expect(state.isRemoteDirectoryReady, isTrue);
      expect(state.remoteSnapshot?.rootDisplayName, 'Remote Later');
    });

    test('requestRemoteEntryDetail uses HTTP control plane', () async {
      final _FakeHttpSyncClient client = _FakeHttpSyncClient(
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
        entryDetailResponse: DiffEntryDetailViewData(
          entryId: 'entry-song',
          displayName: 'song.mp3',
          isDirectory: false,
          size: 123,
          modifiedTime: DateTime.fromMillisecondsSinceEpoch(5),
          audioMetadata: const AudioMetadataViewData(
            title: 'Remote Song',
            artist: 'Remote Artist',
            album: 'Remote Album',
          ),
        ),
      );
      final ProviderContainer container = _container(client: client);
      addTearDown(container.dispose);

      await container
          .read(connectionControllerProvider.notifier)
          .connect(address: '192.168.1.2', port: 44888);

      final DiffEntryDetailViewData? detail = await container
          .read(connectionControllerProvider.notifier)
          .requestRemoteEntryDetail('entry-song');

      expect(detail, isNotNull);
      expect(detail?.displayName, 'song.mp3');
      expect(detail?.audioMetadata?.artist, 'Remote Artist');
    });

    test('disconnect clears remote state but preserves listener', () async {
      final _FakeHttpSyncClient client = _FakeHttpSyncClient(
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
        scanResponse: ScanResponseDto(snapshot: _remoteSnapshot('Remote A')),
      );
      final ProviderContainer container = _container(client: client);
      addTearDown(container.dispose);

      await container
          .read(connectionControllerProvider.notifier)
          .startListening(port: 44888);
      await container
          .read(connectionControllerProvider.notifier)
          .connect(address: '192.168.1.2', port: 44888);

      container
          .read(executionControllerProvider.notifier)
          .setTargetRoot('local-target');

      await container.read(connectionControllerProvider.notifier).disconnect();

      final ConnectionState state = container.read(connectionControllerProvider);
      expect(state.status, ConnectionStatus.idle);
      expect(state.isListening, isTrue);
      expect(state.peer, isNull);
      expect(state.remoteSnapshot, isNull);
    });
  });
}

ProviderContainer _container({
  required _FakeHttpSyncClient client,
}) {
  return ProviderContainer(
    overrides: [
      httpSyncClientProvider.overrideWithValue(client),
      httpSyncServerServiceProvider.overrideWithValue(_FakeHttpSyncServerService()),
      discoveryServiceProvider.overrideWithValue(_FakeDiscoveryService()),
      recentItemsStoreProvider.overrideWithValue(_FakeRecentItemsStore()),
      fileAccessGatewayProvider.overrideWithValue(_FakeFileAccessGateway()),
    ],
  );
}

class _FakeHttpSyncClient extends HttpSyncClient {
  _FakeHttpSyncClient({
    required this.helloResponse,
    this.directoryStatusResponse = const DirectoryStatusResponseDto(
      directoryReady: true,
    ),
    this.directoryStatusSequence,
    this.scanResponse,
    this.entryDetailResponse,
  });

  final HelloResponseDto helloResponse;
  final DirectoryStatusResponseDto directoryStatusResponse;
  final List<DirectoryStatusResponseDto>? directoryStatusSequence;
  final ScanResponseDto? scanResponse;
  final DiffEntryDetailViewData? entryDetailResponse;
  int _directoryStatusIndex = 0;

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
    final List<DirectoryStatusResponseDto>? sequence = directoryStatusSequence;
    if (sequence == null || sequence.isEmpty) {
      return directoryStatusResponse;
    }
    final int index = _directoryStatusIndex < sequence.length
        ? _directoryStatusIndex
        : sequence.length - 1;
    _directoryStatusIndex++;
    return sequence[index];
  }

  @override
  Future<ScanResponseDto> scan({
    required String address,
    required int port,
  }) async {
    return scanResponse ?? ScanResponseDto(snapshot: _remoteSnapshot('Remote'));
  }

  @override
  Future<DiffEntryDetailViewData> entryDetail({
    required String address,
    required int port,
    required String entryId,
  }) async {
    return entryDetailResponse ??
        DiffEntryDetailViewData(
          entryId: entryId,
          displayName: entryId,
          isDirectory: false,
          size: 0,
          modifiedTime: DateTime.fromMillisecondsSinceEpoch(0),
        );
  }
}

class _FakeHttpSyncServerService extends HttpSyncServerService {
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

class _FakeDiscoveryService extends DiscoveryService {
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

class _FakeRecentItemsStore extends RecentItemsStore {
  final List<String> _addresses = <String>[];

  @override
  Future<List<String>> loadRecentAddresses() async => _addresses;

  @override
  Future<List<DirectoryHandle>> loadRecentDirectories() async =>
      const <DirectoryHandle>[];

  @override
  Future<void> saveRecentAddress(String address) async {
    _addresses
      ..remove(address)
      ..insert(0, address);
  }

  @override
  Future<void> saveRecentDirectory(DirectoryHandle handle) async {}
}

class _FakeFileAccessGateway implements FileAccessGateway {
  @override
  Future<String> createDirectory(String parentId, String name) async => '';

  @override
  Future<void> deleteEntry(String entryId) async {}

  @override
  Future<List<FileAccessEntry>> listChildren(String directoryId) async =>
      const <FileAccessEntry>[];

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
