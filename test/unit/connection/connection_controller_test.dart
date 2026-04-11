import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_sync/features/connection/state/connection_controller.dart';
import 'package:music_sync/features/connection/state/connection_state.dart';
import 'package:music_sync/features/directory/state/directory_controller.dart';
import 'package:music_sync/features/execution/state/execution_controller.dart';
import 'package:music_sync/features/execution/state/execution_state.dart';
import 'package:music_sync/features/preview/models/diff_item_detail_view_data.dart';
import 'package:music_sync/features/settings/state/settings_controller.dart';
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
import 'package:music_sync/services/storage/settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  group('ConnectionController (HTTP)', () {
    test('connect succeeds even when remote shared directory is not selected yet', () async {
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
        directoryStatusResponse: const DirectoryStatusResponseDto(directoryReady: true),
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
      expect(container.read(connectionControllerProvider).isRemoteDirectoryReady, isTrue);
    });

    test('polling picks up remote directory after peer selects directory later', () async {
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

      await Future<void>.delayed(const Duration(milliseconds: 4600));

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

<<<<<<< HEAD
    test('connect records stream upload capability from hello response', () async {
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
          transferProtocols: <String>['chunk-rpc', 'stream-v1'],
        ),
        scanResponse: ScanResponseDto(snapshot: _remoteSnapshot('Remote A')),
      );
      final ProviderContainer container = _container(client: client);
      addTearDown(container.dispose);

      await container
          .read(connectionControllerProvider.notifier)
          .connect(address: '192.168.1.2', port: 44888);

      expect(
        container.read(connectionControllerProvider.notifier).peerSupportsStreamUpload,
        isTrue,
      );
    });
=======
    test(
      'connect records stream upload capability from hello response',
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
            directoryReady: true,
            transferProtocols: <String>['chunk-rpc', 'stream-v1'],
          ),
          scanResponse: ScanResponseDto(snapshot: _remoteSnapshot('Remote A')),
        );
        final ProviderContainer container = _container(client: client);
        addTearDown(container.dispose);

        await container
            .read(connectionControllerProvider.notifier)
            .connect(address: '192.168.1.2', port: 44888);

        expect(
          container
              .read(connectionControllerProvider.notifier)
              .peerSupportsStreamUpload,
          isTrue,
        );
      },
    );

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

      await container.read(connectionControllerProvider.notifier).startListening(port: 44888);
      await container
          .read(connectionControllerProvider.notifier)
          .connect(address: '192.168.1.2', port: 44888);

      container.read(executionControllerProvider.notifier).setTargetRoot('local-target');

      await container.read(connectionControllerProvider.notifier).disconnect();

      final ConnectionState state = container.read(connectionControllerProvider);
      expect(state.status, ConnectionStatus.idle);
      expect(state.isListening, isTrue);
      expect(state.peer, isNull);
      expect(state.remoteSnapshot, isNull);
    });

<<<<<<< HEAD
    test('failed incoming stream upload clears incoming sync active state', () async {
      final _CapturingHttpSyncServerService server = _CapturingHttpSyncServerService();
      final ProviderContainer container = ProviderContainer(
        overrides: [
          httpSyncClientProvider.overrideWithValue(
            _FakeHttpSyncClient(
              helloResponse: const HelloResponseDto(
                device: DeviceInfo(
                  deviceId: 'peer',
                  deviceName: 'Peer',
                  platform: 'android',
                  address: '',
                  port: 44888,
                ),
                directoryReady: false,
=======
    test(
      'failed incoming stream upload clears incoming sync active state',
      () async {
        final _CapturingHttpSyncServerService server =
            _CapturingHttpSyncServerService();
        final ProviderContainer container = ProviderContainer(
          overrides: [
            httpSyncClientProvider.overrideWithValue(
              _FakeHttpSyncClient(
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
              ),
            ),
            httpSyncServerServiceProvider.overrideWithValue(server),
            discoveryServiceProvider.overrideWithValue(_FakeDiscoveryService()),
            recentItemsStoreProvider.overrideWithValue(_FakeRecentItemsStore()),
            fileAccessGatewayProvider.overrideWithValue(
              _ThrowingFileAccessGateway(),
            ),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(connectionControllerProvider.notifier)
            .startListening(port: 44888);
        container
            .read(connectionControllerProvider.notifier)
            .state = const ConnectionState(
          status: ConnectionStatus.connected,
          isListening: true,
          isIncomingSyncActive: true,
        );

        final CopyFileStreamHandler handler =
            server.onCopyFileStream ??
            (throw StateError('Missing upload handler'));
        final Object? error = await _postToCopyHandler(
          handler: handler,
          remoteRootId: 'root',
          relativePath: 'song.mp3',
          expectedBytes: 4,
          body: <int>[1, 2, 3, 4],
        );

        expect(error, isA<FileSystemException>());

        expect(
          container.read(connectionControllerProvider).isIncomingSyncActive,
          isFalse,
        );
      },
    );

    test(
      'incoming upload restores original file when replacement rename fails',
      () async {
        final _CapturingHttpSyncServerService server =
            _CapturingHttpSyncServerService();
        final _RecoveringFileAccessGateway gateway =
            _RecoveringFileAccessGateway();
        final ProviderContainer container = ProviderContainer(
          overrides: [
            httpSyncClientProvider.overrideWithValue(
              _FakeHttpSyncClient(
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
              ),
            ),
            httpSyncServerServiceProvider.overrideWithValue(server),
            discoveryServiceProvider.overrideWithValue(_FakeDiscoveryService()),
            recentItemsStoreProvider.overrideWithValue(_FakeRecentItemsStore()),
            fileAccessGatewayProvider.overrideWithValue(gateway),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(connectionControllerProvider.notifier)
            .startListening(port: 44888);

        final CopyFileStreamHandler handler =
            server.onCopyFileStream ??
            (throw StateError('Missing upload handler'));
        final Object? error = await _postToCopyHandler(
          handler: handler,
          remoteRootId: 'root',
          relativePath: 'song.mp3',
          expectedBytes: 4,
          body: <int>[1, 2, 3, 4],
        );

        expect(error, isA<FileSystemException>());

        expect(gateway.restoreAttempted, isTrue);
        expect(gateway.deletedBackup, isFalse);
      },
    );

    test(
      'resetNetworkStateForProtocolChange rejects while connecting',
      () async {
        final ProviderContainer container = _container(
          client: _FakeHttpSyncClient(
            helloResponse: const HelloResponseDto(
              device: DeviceInfo(
                deviceId: 'peer',
                deviceName: 'Peer',
                platform: 'android',
                address: '',
                port: 44888,
>>>>>>> origin/main
              ),
            ),
          ),
          httpSyncServerServiceProvider.overrideWithValue(server),
          discoveryServiceProvider.overrideWithValue(_FakeDiscoveryService()),
          recentItemsStoreProvider.overrideWithValue(_FakeRecentItemsStore()),
          fileAccessGatewayProvider.overrideWithValue(_ThrowingFileAccessGateway()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(connectionControllerProvider.notifier).startListening(port: 44888);
      container.read(connectionControllerProvider.notifier).state = const ConnectionState(
        status: ConnectionStatus.connected,
        isListening: true,
        isIncomingSyncActive: true,
      );

      final CopyFileStreamHandler handler =
          server.onCopyFileStream ?? (throw StateError('Missing upload handler'));
      final Object? error = await _postToCopyHandler(
        handler: handler,
        remoteRootId: 'root',
        relativePath: 'song.mp3',
        expectedBytes: 4,
        body: <int>[1, 2, 3, 4],
      );

      expect(error, isA<FileSystemException>());

      expect(container.read(connectionControllerProvider).isIncomingSyncActive, isFalse);
    });

    test('incoming upload restores original file when replacement rename fails', () async {
      final _CapturingHttpSyncServerService server = _CapturingHttpSyncServerService();
      final _RecoveringFileAccessGateway gateway = _RecoveringFileAccessGateway();
      final ProviderContainer container = ProviderContainer(
        overrides: [
          httpSyncClientProvider.overrideWithValue(
            _FakeHttpSyncClient(
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
            ),
          ),
          httpSyncServerServiceProvider.overrideWithValue(server),
          discoveryServiceProvider.overrideWithValue(_FakeDiscoveryService()),
          recentItemsStoreProvider.overrideWithValue(_FakeRecentItemsStore()),
          fileAccessGatewayProvider.overrideWithValue(gateway),
        ],
      );
      addTearDown(container.dispose);

      await container.read(connectionControllerProvider.notifier).startListening(port: 44888);

      final CopyFileStreamHandler handler =
          server.onCopyFileStream ?? (throw StateError('Missing upload handler'));
      final Object? error = await _postToCopyHandler(
        handler: handler,
        remoteRootId: 'root',
        relativePath: 'song.mp3',
        expectedBytes: 4,
        body: <int>[1, 2, 3, 4],
      );

      expect(error, isA<FileSystemException>());

      expect(gateway.restoreAttempted, isTrue);
      expect(gateway.deletedBackup, isFalse);
    });

    test('resetNetworkStateForProtocolChange rejects while connecting', () async {
      final ProviderContainer container = _container(
        client: _FakeHttpSyncClient(
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
        ),
      );
      addTearDown(container.dispose);

      container.read(connectionControllerProvider.notifier).state = const ConnectionState(
        status: ConnectionStatus.connecting,
      );

      await expectLater(
        container.read(connectionControllerProvider.notifier).resetNetworkStateForProtocolChange(),
        throwsA(isA<StateError>()),
      );
    });

    test('resetNetworkStateForProtocolChange rejects while remote sync is running', () async {
      final ProviderContainer container = _container(
        client: _FakeHttpSyncClient(
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
        ),
      );
      addTearDown(container.dispose);

      container.read(executionControllerProvider.notifier).state = ExecutionState(
        status: ExecutionStatus.running,
        progress: container.read(executionControllerProvider).progress,
        result: const ExecutionResult.empty(),
        mode: ExecutionMode.remote,
        targetRoot: 'remote-root',
      );

      await expectLater(
        container.read(connectionControllerProvider.notifier).resetNetworkStateForProtocolChange(),
        throwsA(isA<StateError>()),
      );
    });

    test('discovery keeps multiple same-name devices as separate cards', () async {
      final _FakeDiscoveryService discovery = _FakeDiscoveryService();
      final ProviderContainer container = _container(
        client: _FakeHttpSyncClient(
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
        ),
        discovery: discovery,
      );
      addTearDown(container.dispose);

      container.read(connectionControllerProvider);
      await Future<void>.delayed(Duration.zero);
      discovery.emit(
        const DiscoveryEvent(
          type: DiscoveryEventType.announce,
          device: DeviceInfo(
            deviceId: 'stable-a',
            deviceName: 'Windows',
            platform: 'windows',
            address: '192.168.1.10',
            port: 44888,
          ),
        ),
      );
      discovery.emit(
        const DiscoveryEvent(
          type: DiscoveryEventType.announce,
          device: DeviceInfo(
            deviceId: 'stable-b',
            deviceName: 'Windows',
            platform: 'windows',
            address: '192.168.1.11',
            port: 44888,
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final List<DeviceInfo> devices = container
          .read(connectionControllerProvider)
          .discoveredDevices;
      expect(devices, hasLength(2));
      expect(devices.map((DeviceInfo device) => device.deviceId).toSet(), <String>{
        'stable-a',
        'stable-b',
      });
    });

    test('discovery keeps primary address stable for the same device', () async {
      final _FakeDiscoveryService discovery = _FakeDiscoveryService();
      final ProviderContainer container = _container(
        client: _FakeHttpSyncClient(
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
        ),
        discovery: discovery,
      );
      addTearDown(container.dispose);

      container.read(connectionControllerProvider);
      await Future<void>.delayed(Duration.zero);
      discovery.emit(
        const DiscoveryEvent(
          type: DiscoveryEventType.announce,
          device: DeviceInfo(
            deviceId: 'stable-peer',
            deviceName: 'Phone',
            platform: 'android',
            address: '192.168.1.20',
            port: 44888,
          ),
        ),
      );
      discovery.emit(
        const DiscoveryEvent(
          type: DiscoveryEventType.announce,
          device: DeviceInfo(
            deviceId: 'stable-peer',
            deviceName: 'Phone',
            platform: 'android',
            address: '192.168.1.21',
            port: 44888,
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final DeviceInfo device = container
          .read(connectionControllerProvider)
          .discoveredDevices
          .single;
      expect(device.address, '192.168.1.20');
    });

    test('discovery order stays stable when old devices broadcast again', () async {
      final _FakeDiscoveryService discovery = _FakeDiscoveryService();
      final ProviderContainer container = _container(
        client: _FakeHttpSyncClient(
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
        ),
        discovery: discovery,
      );
      addTearDown(container.dispose);

      container.read(connectionControllerProvider);
      await Future<void>.delayed(Duration.zero);

      discovery.emit(
        const DiscoveryEvent(
          type: DiscoveryEventType.announce,
          device: DeviceInfo(
            deviceId: 'stable-a',
            deviceName: 'Alpha',
            platform: 'windows',
            address: '192.168.1.10',
            port: 44888,
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 2));
      discovery.emit(
        const DiscoveryEvent(
          type: DiscoveryEventType.announce,
          device: DeviceInfo(
            deviceId: 'stable-b',
            deviceName: 'Beta',
            platform: 'windows',
            address: '192.168.1.11',
            port: 44888,
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      List<DeviceInfo> devices = container.read(connectionControllerProvider).discoveredDevices;
      expect(devices.map((DeviceInfo device) => device.deviceId).toList(), <String>[
        'stable-a',
        'stable-b',
      ]);

      discovery.emit(
        const DiscoveryEvent(
          type: DiscoveryEventType.announce,
          device: DeviceInfo(
            deviceId: 'stable-a',
            deviceName: 'Alpha',
            platform: 'windows',
            address: '192.168.1.12',
            port: 44888,
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      devices = container.read(connectionControllerProvider).discoveredDevices;
      expect(devices.map((DeviceInfo device) => device.deviceId).toList(), <String>[
        'stable-a',
        'stable-b',
      ]);
    });

    test('passive hello immediately moves connected peer card to the top', () async {
      final _FakeDiscoveryService discovery = _FakeDiscoveryService();
      final _FakeHttpSyncServerService server = _FakeHttpSyncServerService();
      final ProviderContainer container = _container(
        client: _FakeHttpSyncClient(
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
        ),
        discovery: discovery,
        server: server,
      );
      addTearDown(container.dispose);

      container.read(connectionControllerProvider);
      await container.read(connectionControllerProvider.notifier).startListening(port: 44888);
      await Future<void>.delayed(Duration.zero);

      discovery.emit(
        const DiscoveryEvent(
          type: DiscoveryEventType.announce,
          device: DeviceInfo(
            deviceId: 'stable-a',
            deviceName: 'Alpha',
            platform: 'windows',
            address: '192.168.1.10',
            port: 44888,
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 2));
      discovery.emit(
        const DiscoveryEvent(
          type: DiscoveryEventType.announce,
          device: DeviceInfo(
            deviceId: 'stable-b',
            deviceName: 'Beta',
            platform: 'windows',
            address: '192.168.1.11',
            port: 44888,
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      List<DeviceInfo> devices = container.read(connectionControllerProvider).discoveredDevices;
      expect(devices.map((DeviceInfo device) => device.deviceId).toList(), <String>[
        'stable-a',
        'stable-b',
      ]);

      await server.simulateHello(
        const HelloRequestDto(
          device: DeviceInfo(
            deviceId: 'stable-b',
            deviceName: 'Beta',
            platform: 'windows',
            address: '',
            port: 44888,
          ),
          directoryReady: false,
        ),
        remoteAddress: '192.168.1.11',
      );

      devices = container.read(connectionControllerProvider).discoveredDevices;
      expect(devices.map((DeviceInfo device) => device.deviceId).toList(), <String>[
        'stable-b',
        'stable-a',
      ]);
    });
  });
}

ProviderContainer _container({
  required _FakeHttpSyncClient client,
  _FakeDiscoveryService? discovery,
  _FakeHttpSyncServerService? server,
}) {
  return ProviderContainer(
    overrides: [
      httpSyncClientProvider.overrideWithValue(client),
      httpSyncServerServiceProvider.overrideWithValue(server ?? _FakeHttpSyncServerService()),
      discoveryServiceProvider.overrideWithValue(discovery ?? _FakeDiscoveryService()),
      recentItemsStoreProvider.overrideWithValue(_FakeRecentItemsStore()),
      fileAccessGatewayProvider.overrideWithValue(_FakeFileAccessGateway()),
      settingsStoreProvider.overrideWithValue(
        _FakeSettingsStore(deviceIdentity: 'local-stable-device'),
      ),
    ],
  );
}

class _FakeHttpSyncClient extends HttpSyncClient {
  _FakeHttpSyncClient({
    required this.helloResponse,
    this.directoryStatusResponse = const DirectoryStatusResponseDto(directoryReady: true),
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
    required bool httpEncryptionEnabled,
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
    required bool httpEncryptionEnabled,
  }) async {
    return scanResponse ?? ScanResponseDto(snapshot: _remoteSnapshot('Remote'));
  }

  @override
  Future<DiffEntryDetailViewData> entryDetail({
    required String address,
    required int port,
    required String entryId,
    required bool httpEncryptionEnabled,
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
  HelloHandler? _onHello;

  @override
  Future<void> start({
    required int port,
    required bool httpEncryptionEnabled,
    required HelloHandler onHello,
    required SessionCloseHandler onSessionClose,
    required DirectoryStatusHandler onDirectoryStatus,
    required ScanHandler onScan,
    required EntryDetailHandler onEntryDetail,
    required SyncSessionStateHandler onSyncSessionState,
    required CopyFileStreamHandler onCopyFileStream,
    required DeleteEntryHandler onDeleteEntry,
  }) async {
    _onHello = onHello;
  }

  @override
  Future<void> stop() async {}

  Future<HelloResponseDto> simulateHello(
    HelloRequestDto request, {
    required String remoteAddress,
  }) async {
    final HelloHandler handler = _onHello ?? (throw StateError('Hello handler not registered.'));
    return handler(request, remoteAddress);
  }
}

class _CapturingHttpSyncServerService extends HttpSyncServerService {
  CopyFileStreamHandler? onCopyFileStream;

  @override
  Future<void> start({
    required int port,
    required bool httpEncryptionEnabled,
    required HelloHandler onHello,
    required SessionCloseHandler onSessionClose,
    required DirectoryStatusHandler onDirectoryStatus,
    required ScanHandler onScan,
    required EntryDetailHandler onEntryDetail,
    required SyncSessionStateHandler onSyncSessionState,
    required CopyFileStreamHandler onCopyFileStream,
    required DeleteEntryHandler onDeleteEntry,
  }) async {
    this.onCopyFileStream = onCopyFileStream;
  }

  @override
  Future<void> stop() async {}
}

class _FakeDiscoveryService extends DiscoveryService {
  DiscoveryCallback? _callback;

  @override
  Future<void> startReceiving({required DiscoveryCallback onDevice}) async {
    _callback = onDevice;
  }

  @override
  Future<void> startBroadcasting(DeviceInfo device) async {}

  @override
  Future<void> sendGoodbye(DeviceInfo device) async {}

  @override
  Future<void> stopBroadcasting() async {}

  @override
  Future<void> dispose() async {}

  void emit(DiscoveryEvent event) {
    _callback?.call(event);
  }
}

class _FakeRecentItemsStore extends RecentItemsStore {
  final List<String> _addresses = <String>[];

  @override
  Future<List<String>> loadRecentAddresses() async => _addresses;

  @override
  Future<List<DirectoryHandle>> loadRecentDirectories() async => const <DirectoryHandle>[];

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
  Future<List<FileAccessEntry>> listChildren(String directoryId) async => const <FileAccessEntry>[];

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

class _FakeSettingsStore extends SettingsStore {
  _FakeSettingsStore({required this.deviceIdentity});

  final String deviceIdentity;

  @override
  Future<String> loadOrCreateDeviceIdentity() async => deviceIdentity;
}

class _ThrowingWriteSession implements FileWriteSession {
  @override
  Future<void> close() async {}

  @override
  Future<void> write(List<int> chunk) async {
    throw const FileSystemException('write failed');
  }
}

class _ThrowingFileAccessGateway extends _FakeFileAccessGateway {
  @override
  Future<List<FileAccessEntry>> listChildren(String directoryId) async {
    if (directoryId == 'root') {
      return <FileAccessEntry>[
        FileAccessEntry(
          entryId: 'temp-entry',
          name: 'song.mp3.music_sync_tmp',
          isDirectory: false,
          size: 1,
          modifiedTime: DateTime.fromMillisecondsSinceEpoch(0),
        ),
      ];
    }
    return const <FileAccessEntry>[];
  }

  @override
  Future<FileWriteSession> openWrite(String parentId, String name) async {
    return _ThrowingWriteSession();
  }
}

class _RecordingWriteSession implements FileWriteSession {
  @override
  Future<void> close() async {}

  @override
  Future<void> write(List<int> chunk) async {}
}

class _RecoveringFileAccessGateway extends _FakeFileAccessGateway {
  bool restoreAttempted = false;
  bool deletedBackup = false;
  int tempRenameAttempts = 0;

  @override
  Future<List<FileAccessEntry>> listChildren(String directoryId) async {
    if (directoryId == 'root') {
      return <FileAccessEntry>[
        FileAccessEntry(
          entryId: 'existing-entry',
          name: 'song.mp3',
          isDirectory: false,
          size: 1,
          modifiedTime: DateTime.fromMillisecondsSinceEpoch(0),
        ),
        FileAccessEntry(
          entryId: 'temp-entry',
          name: 'song.mp3.music_sync_tmp',
          isDirectory: false,
          size: 1,
          modifiedTime: DateTime.fromMillisecondsSinceEpoch(0),
        ),
      ];
    }
    return const <FileAccessEntry>[];
  }

  @override
  Future<FileWriteSession> openWrite(String parentId, String name) async {
    return _RecordingWriteSession();
  }

  @override
  Future<String> renameEntry(String entryId, String newName) async {
    if (entryId == 'temp-entry' && newName == 'song.mp3') {
      tempRenameAttempts++;
      if (tempRenameAttempts == 1) {
        throw const FileSystemException('target exists');
      }
      throw const FileSystemException('replacement failed');
    }
    if (entryId == 'existing-entry' &&
        newName.startsWith('song.mp3.music_sync_tmp.backup.')) {
      return 'backup-entry';
    }
    if (entryId == 'backup-entry' && newName == 'song.mp3') {
      restoreAttempted = true;
      return 'existing-entry';
    }
    if (entryId == 'temp-entry') {
      return 'temp-entry';
    }
    return entryId;
  }

  @override
  Future<void> deleteEntry(String entryId) async {
    if (entryId == 'backup-entry') {
      deletedBackup = true;
    }
  }
}

Future<Object?> _postToCopyHandler({
  required CopyFileStreamHandler handler,
  required String remoteRootId,
  required String relativePath,
  required int expectedBytes,
  required List<int> body,
}) async {
  final HttpServer server = await HttpServer.bind(
    InternetAddress.loopbackIPv4,
    0,
  );
  final Completer<Object?> completed = Completer<Object?>();
  server.listen((HttpRequest request) async {
    Object? error;
    try {
      await handler(request, remoteRootId, relativePath, expectedBytes);
      request.response.statusCode = HttpStatus.ok;
    } catch (caught) {
      error = caught;
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write(caught.toString());
    } finally {
      await request.response.close();
      if (!completed.isCompleted) {
        completed.complete(error);
      }
    }
  });
  final Socket socket = await Socket.connect(
    InternetAddress.loopbackIPv4,
    server.port,
  );
  final List<String> headerLines = <String>[
    'POST /test HTTP/1.1',
    'Host: ${InternetAddress.loopbackIPv4.host}:${server.port}',
    'x-remote-root-id: $remoteRootId',
    'x-relative-path: ${Uri.encodeComponent(relativePath)}',
    'x-file-size: $expectedBytes',
    'Content-Length: ${body.length}',
    '',
    '',
  ];
  socket.add(utf8.encode(headerLines.join('\r\n')));
  socket.add(body);
  await socket.flush();
  await socket.close();
  final Object? error = await completed.future;
  addTearDown(() async {
    await server.close(force: true);
  });
  return error;
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
