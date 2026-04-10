import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_tags/dart_tags.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_sync/features/connection/state/connection_controller.dart';
import 'package:music_sync/features/connection/state/connection_state.dart';
import 'package:music_sync/features/preview/models/diff_item_detail_view_data.dart';
import 'package:music_sync/features/directory/state/directory_controller.dart';
import 'package:music_sync/features/execution/state/execution_controller.dart';
import 'package:music_sync/features/execution/state/execution_state.dart';
import 'package:music_sync/features/preview/state/preview_controller.dart';
import 'package:music_sync/features/preview/state/preview_state.dart';
import 'package:music_sync/models/device_info.dart';
import 'package:music_sync/models/execution_result.dart';
import 'package:music_sync/models/file_entry.dart';
import 'package:music_sync/models/scan_snapshot.dart';
import 'package:music_sync/models/transfer_progress.dart';
import 'package:music_sync/services/file_access/file_access_entry.dart';
import 'package:music_sync/services/file_access/file_access_gateway.dart';
import 'package:music_sync/services/file_access/file_access_provider.dart';
import 'package:music_sync/services/network/connection_service.dart';
import 'package:music_sync/services/network/listener_service.dart';
import 'package:music_sync/services/network/peer_session.dart';
import 'package:music_sync/services/network/protocol/protocol_message.dart';
import 'package:music_sync/services/storage/recent_items_store.dart';

void main() {
  group('ConnectionController', () {
    test(
        'disconnect clears remote state but preserves listener and local target',
        () async {
      final _FakeConnectionService connectionService = _FakeConnectionService(
        snapshots: <ScanSnapshot>[_remoteSnapshot('Remote A')],
      );
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          connectionServiceProvider.overrideWithValue(connectionService),
          listenerServiceProvider.overrideWithValue(_FakeListenerService()),
          recentItemsStoreProvider.overrideWithValue(_FakeRecentItemsStore()),
          fileAccessGatewayProvider.overrideWithValue(_FakeFileAccessGateway()),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(connectionControllerProvider.notifier)
          .startListening(port: 44888);
      await container.read(connectionControllerProvider.notifier).connect(
            address: '192.168.1.2',
            port: 44888,
          );

      container
          .read(executionControllerProvider.notifier)
          .setTargetRoot('local-target');
      container.read(directoryControllerProvider.notifier).setDirectory(
            const DirectoryHandle(entryId: 'root', displayName: 'Music'),
          );
      container.read(previewControllerProvider.notifier).loadPlan(
            source: _localSnapshot(),
            target: _remoteSnapshot('Remote A'),
            deleteEnabled: true,
          );

      await container.read(connectionControllerProvider.notifier).disconnect();

      final connectionState = container.read(connectionControllerProvider);
      final previewState = container.read(previewControllerProvider);
      final executionState = container.read(executionControllerProvider);

      expect(connectionState.status, ConnectionStatus.idle);
      expect(connectionState.isListening, isTrue);
      expect(connectionState.peer, isNull);
      expect(connectionState.remoteSnapshot, isNull);
      expect(previewState.status, PreviewStatus.idle);
      expect(executionState.status, ExecutionStatus.idle);
      expect(executionState.targetRoot, 'local-target');
      expect(connectionService.disconnectCalls, 1);
    });

    test('stop listening disconnects peer session and resets connection state',
        () async {
      final _FakeConnectionService connectionService = _FakeConnectionService(
        snapshots: <ScanSnapshot>[_remoteSnapshot('Remote A')],
      );
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          connectionServiceProvider.overrideWithValue(connectionService),
          listenerServiceProvider.overrideWithValue(_FakeListenerService()),
          recentItemsStoreProvider.overrideWithValue(_FakeRecentItemsStore()),
          fileAccessGatewayProvider.overrideWithValue(_FakeFileAccessGateway()),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(connectionControllerProvider.notifier)
          .startListening(port: 44888);
      await container.read(connectionControllerProvider.notifier).connect(
            address: '192.168.1.2',
            port: 44888,
          );

      await container
          .read(connectionControllerProvider.notifier)
          .stopListening();

      final ConnectionState connectionState =
          container.read(connectionControllerProvider);
      expect(connectionState.status, ConnectionStatus.idle);
      expect(connectionState.isListening, isFalse);
      expect(connectionState.listenPort, isNull);
      expect(connectionState.peer, isNull);
      expect(connectionState.remoteSnapshot, isNull);
      expect(connectionState.isRemoteDirectoryReady, isFalse);
      expect(connectionService.disconnectCalls, 1);
    });

    test(
        'connect succeeds even when remote shared directory is not selected yet',
        () async {
      final _FakeConnectionService connectionService = _FakeConnectionService(
        snapshots: <ScanSnapshot>[],
        scanErrorMessage: 'No shared directory selected on peer.',
      );
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          connectionServiceProvider.overrideWithValue(connectionService),
          listenerServiceProvider.overrideWithValue(_FakeListenerService()),
          recentItemsStoreProvider.overrideWithValue(_FakeRecentItemsStore()),
          fileAccessGatewayProvider.overrideWithValue(_FakeFileAccessGateway()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(connectionControllerProvider.notifier).connect(
            address: '192.168.1.2',
            port: 44888,
          );

      final ConnectionState connectionState =
          container.read(connectionControllerProvider);
      expect(connectionState.status, ConnectionStatus.connected);
      expect(connectionState.peer, isNotNull);
      expect(connectionState.remoteSnapshot, isNull);
      expect(connectionState.isRemoteDirectoryReady, isFalse);
      expect(connectionState.errorMessage, isNull);
    });

    test(
        'refreshRemoteSnapshot keeps connection and clears remote-ready state when remote directory is unavailable',
        () async {
      final _FakeConnectionService connectionService = _FakeConnectionService(
        snapshots: <ScanSnapshot>[_remoteSnapshot('Remote A')],
        refreshScanErrorMessage: 'No shared directory selected on peer.',
      );
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          connectionServiceProvider.overrideWithValue(connectionService),
          listenerServiceProvider.overrideWithValue(_FakeListenerService()),
          recentItemsStoreProvider.overrideWithValue(_FakeRecentItemsStore()),
          fileAccessGatewayProvider.overrideWithValue(_FakeFileAccessGateway()),
        ],
      );
      addTearDown(container.dispose);

      container.read(directoryControllerProvider.notifier).setDirectory(
            const DirectoryHandle(entryId: 'root', displayName: 'Music'),
          );
      await container.read(connectionControllerProvider.notifier).connect(
            address: '192.168.1.2',
            port: 44888,
          );
      container.read(previewControllerProvider.notifier).loadPlan(
            source: _localSnapshot(),
            target: _remoteSnapshot('Remote A'),
            deleteEnabled: true,
          );
      container
          .read(executionControllerProvider.notifier)
          .setTargetRoot('local-target');

      final ScanSnapshot? refreshed = await container
          .read(connectionControllerProvider.notifier)
          .refreshRemoteSnapshot();

      final ConnectionState connectionState =
          container.read(connectionControllerProvider);
      final PreviewState previewState =
          container.read(previewControllerProvider);
      final ExecutionState executionState =
          container.read(executionControllerProvider);

      expect(refreshed, isNull);
      expect(connectionState.status, ConnectionStatus.connected);
      expect(connectionState.peer, isNotNull);
      expect(connectionState.remoteSnapshot, isNull);
      expect(connectionState.isRemoteDirectoryReady, isFalse);
      expect(connectionState.errorMessage, isNotEmpty);
      expect(previewState.status, PreviewStatus.idle);
      expect(executionState.status, ExecutionStatus.idle);
      expect(executionState.targetRoot, 'local-target');
    });

    test(
        'remoteDirectoryChanged ready message refreshes remote snapshot automatically',
        () async {
      final _FakeConnectionService connectionService = _FakeConnectionService(
        snapshots: <ScanSnapshot>[_remoteSnapshot('Remote A')],
        scanErrorMessage: 'No shared directory selected on peer.',
      );
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          connectionServiceProvider.overrideWithValue(connectionService),
          listenerServiceProvider.overrideWithValue(_FakeListenerService()),
          recentItemsStoreProvider.overrideWithValue(_FakeRecentItemsStore()),
          fileAccessGatewayProvider.overrideWithValue(_FakeFileAccessGateway()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(connectionControllerProvider.notifier).connect(
            address: '192.168.1.2',
            port: 44888,
          );

      expect(
        container.read(connectionControllerProvider).remoteSnapshot,
        isNull,
      );
      expect(
        container.read(connectionControllerProvider).isRemoteDirectoryReady,
        isFalse,
      );

      await connectionService.onMessage?.call(
        const ProtocolMessage(
          type: 'remoteDirectoryChanged',
          requestId: 'dir-ready-1',
          payload: <String, Object?>{
            'isReady': true,
            'displayName': 'Remote Music',
          },
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final ConnectionState connectionState =
          container.read(connectionControllerProvider);
      expect(connectionState.isRemoteDirectoryReady, isTrue);
      expect(connectionState.remoteSnapshot?.rootDisplayName, 'Remote A');
    });

    test(
        'refreshRemoteSnapshot fails running remote execution when remote directory becomes unavailable',
        () async {
      final _FakeConnectionService connectionService = _FakeConnectionService(
        snapshots: <ScanSnapshot>[_remoteSnapshot('Remote A')],
        refreshScanErrorMessage:
            'The selected directory is not accessible anymore.',
      );
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          connectionServiceProvider.overrideWithValue(connectionService),
          listenerServiceProvider.overrideWithValue(_FakeListenerService()),
          recentItemsStoreProvider.overrideWithValue(_FakeRecentItemsStore()),
          fileAccessGatewayProvider.overrideWithValue(_FakeFileAccessGateway()),
        ],
      );
      addTearDown(container.dispose);

      container.read(directoryControllerProvider.notifier).setDirectory(
            const DirectoryHandle(entryId: 'root', displayName: 'Music'),
          );
      await container.read(connectionControllerProvider.notifier).connect(
            address: '192.168.1.2',
            port: 44888,
          );
      container.read(previewControllerProvider.notifier).loadPlan(
            source: _localSnapshot(),
            target: _remoteSnapshot('Remote A'),
            deleteEnabled: true,
          );
      container.read(executionControllerProvider.notifier).state =
          ExecutionState(
        status: ExecutionStatus.running,
        progress: container.read(executionControllerProvider).progress,
        result: const ExecutionResult(
          copiedCount: 0,
          deletedCount: 0,
          failedCount: 0,
          totalBytes: 0,
          targetRoot: 'remote-root',
        ),
        mode: ExecutionMode.remote,
        targetRoot: 'remote-root',
      );

      await container
          .read(connectionControllerProvider.notifier)
          .refreshRemoteSnapshot(clearTransientState: false);

      final ExecutionState executionState =
          container.read(executionControllerProvider);
      final ConnectionState connectionState =
          container.read(connectionControllerProvider);

      expect(connectionState.status, ConnectionStatus.connected);
      expect(connectionState.isRemoteDirectoryReady, isFalse);
      expect(executionState.status, ExecutionStatus.failed);
      expect(executionState.mode, ExecutionMode.remote);
      expect(executionState.errorMessage, isNotEmpty);
    });

    test(
        'refreshRemoteSnapshot marks connection disconnected when peer is no longer connected',
        () async {
      final _FakeConnectionService connectionService = _FakeConnectionService(
        snapshots: <ScanSnapshot>[_remoteSnapshot('Remote A')],
        refreshScanErrorMessage: 'Not connected to any peer.',
      );
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          connectionServiceProvider.overrideWithValue(connectionService),
          listenerServiceProvider.overrideWithValue(_FakeListenerService()),
          recentItemsStoreProvider.overrideWithValue(_FakeRecentItemsStore()),
          fileAccessGatewayProvider.overrideWithValue(_FakeFileAccessGateway()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(connectionControllerProvider.notifier).connect(
            address: '192.168.1.2',
            port: 44888,
          );

      final ScanSnapshot? refreshed = await container
          .read(connectionControllerProvider.notifier)
          .refreshRemoteSnapshot(clearTransientState: false);

      final ConnectionState connectionState =
          container.read(connectionControllerProvider);

      expect(refreshed, isNull);
      expect(connectionState.status, ConnectionStatus.disconnected);
      expect(connectionState.peer, isNull);
      expect(connectionState.remoteSnapshot, isNull);
      expect(connectionState.isRemoteDirectoryReady, isFalse);
      expect(connectionState.errorMessage, isNotEmpty);
    });

    test('passive disconnect clears remote state and keeps local target root',
        () async {
      final _FakeConnectionService connectionService = _FakeConnectionService(
        snapshots: <ScanSnapshot>[_remoteSnapshot('Remote A')],
      );
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          connectionServiceProvider.overrideWithValue(connectionService),
          listenerServiceProvider.overrideWithValue(_FakeListenerService()),
          recentItemsStoreProvider.overrideWithValue(_FakeRecentItemsStore()),
          fileAccessGatewayProvider.overrideWithValue(_FakeFileAccessGateway()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(connectionControllerProvider.notifier).connect(
            address: '192.168.1.2',
            port: 44888,
          );
      container
          .read(executionControllerProvider.notifier)
          .setTargetRoot('local-target');
      container.read(previewControllerProvider.notifier).loadPlan(
            source: _localSnapshot(),
            target: _remoteSnapshot('Remote A'),
            deleteEnabled: true,
          );

      connectionService.onDisconnected?.call(null);
      await Future<void>.delayed(Duration.zero);

      final ConnectionState connectionState =
          container.read(connectionControllerProvider);
      final PreviewState previewState =
          container.read(previewControllerProvider);
      final ExecutionState executionState =
          container.read(executionControllerProvider);

      expect(connectionState.status, ConnectionStatus.disconnected);
      expect(connectionState.peer, isNull);
      expect(connectionState.remoteSnapshot, isNull);
      expect(connectionState.isRemoteDirectoryReady, isFalse);
      expect(connectionState.errorMessage, isNotEmpty);
      expect(previewState.status, PreviewStatus.idle);
      expect(executionState.status, ExecutionStatus.idle);
      expect(executionState.targetRoot, 'local-target');
    });

    test('passive disconnect fails running remote execution', () async {
      final _FakeConnectionService connectionService = _FakeConnectionService(
        snapshots: <ScanSnapshot>[_remoteSnapshot('Remote A')],
      );
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          connectionServiceProvider.overrideWithValue(connectionService),
          listenerServiceProvider.overrideWithValue(_FakeListenerService()),
          recentItemsStoreProvider.overrideWithValue(_FakeRecentItemsStore()),
          fileAccessGatewayProvider.overrideWithValue(_FakeFileAccessGateway()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(connectionControllerProvider.notifier).connect(
            address: '192.168.1.2',
            port: 44888,
          );
      container.read(executionControllerProvider.notifier).state =
          const ExecutionState(
        status: ExecutionStatus.running,
        progress: TransferProgress(
          stage: SyncStage.copying,
          processedFiles: 1,
          totalFiles: 3,
          processedBytes: 64,
          totalBytes: 256,
          currentPath: 'Album/song.mp3',
        ),
        result: ExecutionResult.empty(),
        mode: ExecutionMode.remote,
        targetRoot: 'remote-root',
      );
      container.read(previewControllerProvider.notifier).loadPlan(
            source: _localSnapshot(),
            target: _remoteSnapshot('Remote A'),
            deleteEnabled: true,
          );

      connectionService.onDisconnected?.call(null);
      await Future<void>.delayed(Duration.zero);

      final ConnectionState connectionState =
          container.read(connectionControllerProvider);
      final PreviewState previewState =
          container.read(previewControllerProvider);
      final ExecutionState executionState =
          container.read(executionControllerProvider);

      expect(connectionState.status, ConnectionStatus.disconnected);
      expect(previewState.status, PreviewStatus.idle);
      expect(executionState.status, ExecutionStatus.failed);
      expect(executionState.mode, ExecutionMode.remote);
      expect(executionState.progress.stage, SyncStage.failed);
      expect(executionState.errorMessage, isNotEmpty);
    });

    test('incoming remote copy renames temp file on finish', () async {
      final _FakeListenerService listener = _FakeListenerService();
      final _TransferTrackingGateway gateway = _TransferTrackingGateway();
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          connectionServiceProvider.overrideWithValue(
            _FakeConnectionService(
                snapshots: <ScanSnapshot>[_remoteSnapshot('Remote A')]),
          ),
          listenerServiceProvider.overrideWithValue(listener),
          recentItemsStoreProvider.overrideWithValue(_FakeRecentItemsStore()),
          fileAccessGatewayProvider.overrideWithValue(gateway),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(connectionControllerProvider.notifier)
          .startListening(port: 44888);
      final _PeerPair pair = await _PeerPair.open(listener.onClient!);
      addTearDown(pair.close);

      await pair.client.sendRequest(
        type: 'beginCopy',
        requestId: 'req-1',
        payload: const <String, Object?>{
          'remoteRootId': 'root',
          'relativePath': 'Album/song.mp3',
          'transferId': 'transfer-1',
        },
      );
      await pair.client.sendRequest(
        type: 'writeChunk',
        requestId: 'req-2',
        payload: <String, Object?>{
          'transferId': 'transfer-1',
          'data': base64Encode(utf8.encode('hello')),
        },
      );
      await pair.client.sendRequest(
        type: 'finishCopy',
        requestId: 'req-3',
        payload: const <String, Object?>{
          'transferId': 'transfer-1',
        },
      );

      expect(gateway.entryNames, contains('song.mp3'));
      expect(gateway.entryNames, isNot(contains('song.mp3.music_sync_tmp')));
      expect(gateway.renameCalls, 1);
      expect(gateway.deletedEntries, isEmpty);
    });

    test(
        'incoming remote copy deletes temp file when peer disconnects mid-transfer',
        () async {
      final _FakeListenerService listener = _FakeListenerService();
      final _TransferTrackingGateway gateway = _TransferTrackingGateway();
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          connectionServiceProvider.overrideWithValue(
            _FakeConnectionService(
                snapshots: <ScanSnapshot>[_remoteSnapshot('Remote A')]),
          ),
          listenerServiceProvider.overrideWithValue(listener),
          recentItemsStoreProvider.overrideWithValue(_FakeRecentItemsStore()),
          fileAccessGatewayProvider.overrideWithValue(gateway),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(connectionControllerProvider.notifier)
          .startListening(port: 44888);
      final _PeerPair pair = await _PeerPair.open(listener.onClient!);
      addTearDown(pair.close);

      await pair.client.sendRequest(
        type: 'beginCopy',
        requestId: 'req-1',
        payload: const <String, Object?>{
          'remoteRootId': 'root',
          'relativePath': 'Album/song.mp3',
          'transferId': 'transfer-1',
        },
      );
      await pair.client.sendRequest(
        type: 'writeChunk',
        requestId: 'req-2',
        payload: <String, Object?>{
          'transferId': 'transfer-1',
          'data': base64Encode(utf8.encode('partial')),
        },
      );

      await pair.closeClientOnly();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(gateway.entryNames, isNot(contains('song.mp3.music_sync_tmp')));
      expect(gateway.deletedEntries, hasLength(1));
    });

    test('remote entry detail request can return audio metadata', () async {
      final ListenerService listener = ListenerService();
      final _MetadataGateway gateway = await _MetadataGateway.create();
      const int port = 44991;
      final ProviderContainer server = ProviderContainer(
        overrides: <Override>[
          connectionServiceProvider.overrideWithValue(
            _FakeConnectionService(
              snapshots: <ScanSnapshot>[_remoteSnapshot('Remote A')],
            ),
          ),
          listenerServiceProvider.overrideWithValue(listener),
          recentItemsStoreProvider.overrideWithValue(_FakeRecentItemsStore()),
          fileAccessGatewayProvider.overrideWithValue(gateway),
        ],
      );
      final ProviderContainer client = ProviderContainer(
        overrides: <Override>[
          connectionServiceProvider.overrideWithValue(ConnectionService()),
          listenerServiceProvider.overrideWithValue(_FakeListenerService()),
          recentItemsStoreProvider.overrideWithValue(_FakeRecentItemsStore()),
          fileAccessGatewayProvider.overrideWithValue(_FakeFileAccessGateway()),
        ],
      );
      addTearDown(server.dispose);
      addTearDown(client.dispose);
      addTearDown(() async {
        try {
          await client.read(connectionControllerProvider.notifier).disconnect();
        } catch (_) {
          // Ignore teardown disconnect failures in socket-bound tests.
        }
        try {
          await server
              .read(connectionControllerProvider.notifier)
              .stopListening();
        } catch (_) {
          // Ignore teardown listener failures in socket-bound tests.
        }
      });

      await server
          .read(connectionControllerProvider.notifier)
          .startListening(port: port);
      await client.read(connectionControllerProvider.notifier).connect(
            address: '127.0.0.1',
            port: port,
          );

      final DiffEntryDetailViewData? detail = await client
          .read(connectionControllerProvider.notifier)
          .requestRemoteEntryDetail('entry-song');

      expect(detail, isNotNull);
      expect(detail?.displayName, 'song.mp3');
      expect(detail?.audioMetadata?.title, 'Remote Song');
      expect(detail?.audioMetadata?.artist, 'Remote Artist');
      expect(detail?.audioMetadata?.album, 'Remote Album');
    });

    test('remote directory detail does not include audio metadata', () async {
      final ListenerService listener = ListenerService();
      final _MetadataGateway gateway = await _MetadataGateway.create();
      const int port = 44992;
      final ProviderContainer server = ProviderContainer(
        overrides: <Override>[
          connectionServiceProvider.overrideWithValue(
            _FakeConnectionService(
              snapshots: <ScanSnapshot>[_remoteSnapshot('Remote A')],
            ),
          ),
          listenerServiceProvider.overrideWithValue(listener),
          recentItemsStoreProvider.overrideWithValue(_FakeRecentItemsStore()),
          fileAccessGatewayProvider.overrideWithValue(gateway),
        ],
      );
      final ProviderContainer client = ProviderContainer(
        overrides: <Override>[
          connectionServiceProvider.overrideWithValue(ConnectionService()),
          listenerServiceProvider.overrideWithValue(_FakeListenerService()),
          recentItemsStoreProvider.overrideWithValue(_FakeRecentItemsStore()),
          fileAccessGatewayProvider.overrideWithValue(_FakeFileAccessGateway()),
        ],
      );
      addTearDown(server.dispose);
      addTearDown(client.dispose);
      addTearDown(() async {
        try {
          await client.read(connectionControllerProvider.notifier).disconnect();
        } catch (_) {}
        try {
          await server
              .read(connectionControllerProvider.notifier)
              .stopListening();
        } catch (_) {}
      });

      await server
          .read(connectionControllerProvider.notifier)
          .startListening(port: port);
      await client.read(connectionControllerProvider.notifier).connect(
            address: '127.0.0.1',
            port: port,
          );

      final DiffEntryDetailViewData? detail = await client
          .read(connectionControllerProvider.notifier)
          .requestRemoteEntryDetail('entry-dir');

      expect(detail, isNotNull);
      expect(detail?.isDirectory, isTrue);
      expect(detail?.audioMetadata, isNull);
    });

    test(
        'clearing local directory fails running remote execution instead of resetting to idle',
        () async {
      final _FakeConnectionService connectionService = _FakeConnectionService(
        snapshots: <ScanSnapshot>[_remoteSnapshot('Remote A')],
      );
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          connectionServiceProvider.overrideWithValue(connectionService),
          listenerServiceProvider.overrideWithValue(_FakeListenerService()),
          recentItemsStoreProvider.overrideWithValue(_FakeRecentItemsStore()),
          fileAccessGatewayProvider.overrideWithValue(_FakeFileAccessGateway()),
        ],
      );
      addTearDown(container.dispose);

      container.read(directoryControllerProvider.notifier).setDirectory(
            const DirectoryHandle(entryId: 'root', displayName: 'Music'),
          );
      await container.read(connectionControllerProvider.notifier).connect(
            address: '192.168.1.2',
            port: 44888,
          );
      container.read(executionControllerProvider.notifier).state =
          const ExecutionState(
        status: ExecutionStatus.running,
        progress: TransferProgress(
          stage: SyncStage.copying,
          processedFiles: 1,
          totalFiles: 3,
          processedBytes: 64,
          totalBytes: 256,
          currentPath: 'Album/song.mp3',
        ),
        result: ExecutionResult.empty(),
        mode: ExecutionMode.remote,
        targetRoot: 'remote-root',
      );

      await container
          .read(directoryControllerProvider.notifier)
          .clearDirectory();

      final ExecutionState executionState =
          container.read(executionControllerProvider);
      final PreviewState previewState =
          container.read(previewControllerProvider);

      expect(executionState.status, ExecutionStatus.failed);
      expect(executionState.mode, ExecutionMode.remote);
      expect(executionState.progress.stage, SyncStage.failed);
      expect(executionState.errorMessage, isNotEmpty);
      expect(previewState.status, PreviewStatus.idle);
    });

    test('passive incoming hello initializes remote directory ready state',
        () async {
      final _FakeListenerService listener = _FakeListenerService();
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          listenerServiceProvider.overrideWithValue(listener),
          recentItemsStoreProvider.overrideWithValue(_FakeRecentItemsStore()),
          fileAccessGatewayProvider.overrideWithValue(_FakeFileAccessGateway()),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(connectionControllerProvider.notifier)
          .startListening(port: 44888);

      final _PeerPair pair = await _PeerPair.open((PeerSession session) {
        listener.onClient?.call(session);
      });
      addTearDown(pair.close);

      final ProtocolMessage response = await pair.client.sendRequest(
        type: 'hello',
        requestId: 'hello-1',
        payload: <String, Object?>{
          'device': const DeviceInfo(
            deviceId: 'peer-device',
            deviceName: 'Peer Device',
            platform: 'android',
            address: '192.168.1.10',
            port: 44888,
          ).toJson(),
          'directoryReady': true,
          'directoryDisplayName': 'Peer Music',
        },
      );

      expect(response.type, 'helloAck');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final ConnectionState connectionState =
          container.read(connectionControllerProvider);
      expect(connectionState.status, ConnectionStatus.connected);
      expect(connectionState.peer?.deviceId, 'peer-device');
      expect(connectionState.isRemoteDirectoryReady, isTrue);
      expect(connectionState.remoteSnapshot, isNull);
    });

    test('passive incoming session applies remoteDirectoryChanged after hello',
        () async {
      final _FakeListenerService listener = _FakeListenerService();
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          listenerServiceProvider.overrideWithValue(listener),
          recentItemsStoreProvider.overrideWithValue(_FakeRecentItemsStore()),
          fileAccessGatewayProvider.overrideWithValue(_FakeFileAccessGateway()),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(connectionControllerProvider.notifier)
          .startListening(port: 44888);

      final _PeerPair pair = await _PeerPair.open((PeerSession session) {
        listener.onClient?.call(session);
      });
      addTearDown(pair.close);

      pair.client.onMessage = (ProtocolMessage message) {
        if (message.type != 'scanRequest') {
          return null;
        }
        return ProtocolMessage(
          type: 'scanResponse',
          requestId: message.requestId,
          payload: <String, Object?>{
            'snapshot': _remoteSnapshot('Remote Passive').toJson(),
          },
        );
      };

      await pair.client.sendRequest(
        type: 'hello',
        requestId: 'hello-passive-1',
        payload: <String, Object?>{
          'device': const DeviceInfo(
            deviceId: 'peer-device',
            deviceName: 'Peer Device',
            platform: 'android',
            address: '192.168.1.10',
            port: 44888,
          ).toJson(),
          'directoryReady': false,
        },
      );

      await pair.client.sendMessage(
        type: 'remoteDirectoryChanged',
        requestId: 'rdc-1',
        payload: const <String, Object?>{
          'isReady': true,
          'displayName': 'Peer Music',
        },
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));

      final ConnectionState connectionState =
          container.read(connectionControllerProvider);
      expect(connectionState.status, ConnectionStatus.connected);
      expect(connectionState.peer?.deviceId, 'peer-device');
      expect(connectionState.isRemoteDirectoryReady, isTrue);
      expect(connectionState.remoteSnapshot?.rootDisplayName, 'Remote Passive');
    });
  });
}

class _FakeConnectionService extends ConnectionService {
  _FakeConnectionService({
    required this.snapshots,
    this.scanErrorMessage,
    this.refreshScanErrorMessage,
  });

  final List<ScanSnapshot> snapshots;
  final String? scanErrorMessage;
  final String? refreshScanErrorMessage;
  int disconnectCalls = 0;
  int _index = 0;

  @override
  Future<DeviceInfo> connect({
    required String address,
    required int port,
    required DeviceInfo localDevice,
    bool isDirectoryReady = false,
    String? directoryDisplayName,
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
    final bool isRefreshRequest = _index > 0;
    if (isRefreshRequest && refreshScanErrorMessage != null) {
      throw SocketException(refreshScanErrorMessage!);
    }
    if (!isRefreshRequest && scanErrorMessage != null) {
      _index++;
      throw SocketException(scanErrorMessage!);
    }
    final int current =
        _index < snapshots.length ? _index : snapshots.length - 1;
    _index++;
    return snapshots[current];
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls++;
  }
}

class _FakeListenerService extends ListenerService {
  bool started = false;
  void Function(PeerSession session)? onClient;

  @override
  Future<void> start({
    required int port,
    void Function(PeerSession session)? onClient,
  }) async {
    started = true;
    this.onClient = onClient;
  }

  @override
  Future<void> stop() async {
    started = false;
  }
}

class _FakeRecentItemsStore extends RecentItemsStore {
  final List<String> _addresses = <String>[];
  final List<DirectoryHandle> _directories = <DirectoryHandle>[];

  @override
  Future<List<String>> loadRecentAddresses() async => _addresses;

  @override
  Future<List<DirectoryHandle>> loadRecentDirectories() async => _directories;

  @override
  Future<void> saveRecentAddress(String address) async {
    _addresses
      ..remove(address)
      ..insert(0, address);
  }

  @override
  Future<void> saveRecentDirectory(DirectoryHandle handle) async {
    _directories
      ..removeWhere((DirectoryHandle item) => item.entryId == handle.entryId)
      ..insert(0, handle);
  }
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

class _TransferTrackingGateway implements FileAccessGateway {
  final Map<String, List<FileAccessEntry>> _childrenById =
      <String, List<FileAccessEntry>>{
    'root': const <FileAccessEntry>[],
  };
  final Set<String> deletedEntries = <String>{};
  int renameCalls = 0;

  List<String> get entryNames => _childrenById.values
      .expand((List<FileAccessEntry> items) => items)
      .map((FileAccessEntry entry) => entry.name)
      .toList();

  @override
  Future<String> createDirectory(String parentId, String name) async {
    final String entryId = '$parentId/$name';
    final FileAccessEntry entry = FileAccessEntry(
      entryId: entryId,
      name: name,
      isDirectory: true,
      size: 0,
      modifiedTime: DateTime.fromMillisecondsSinceEpoch(0),
    );
    _childrenById[parentId] = <FileAccessEntry>[
      ...?_childrenById[parentId],
      entry,
    ];
    _childrenById.putIfAbsent(entryId, () => <FileAccessEntry>[]);
    return entryId;
  }

  @override
  Future<void> deleteEntry(String entryId) async {
    deletedEntries.add(entryId);
    _childrenById.remove(entryId);
    for (final String parentId in _childrenById.keys.toList()) {
      _childrenById[parentId] = _childrenById[parentId]!
          .where((FileAccessEntry entry) => entry.entryId != entryId)
          .toList();
    }
  }

  @override
  Future<List<FileAccessEntry>> listChildren(String directoryId) async =>
      List<FileAccessEntry>.from(
          _childrenById[directoryId] ?? const <FileAccessEntry>[]);

  @override
  Stream<List<int>> openRead(String entryId) async* {}

  @override
  Future<FileWriteSession> openWrite(String parentId, String name) async {
    final String entryId = '$parentId/$name';
    _childrenById[parentId] = <FileAccessEntry>[
      ...?_childrenById[parentId],
      FileAccessEntry(
        entryId: entryId,
        name: name,
        isDirectory: false,
        size: 0,
        modifiedTime: DateTime.fromMillisecondsSinceEpoch(0),
      ),
    ];
    return _MemoryWriteSession();
  }

  @override
  Future<DirectoryHandle?> pickDirectory() async => null;

  @override
  Future<String> renameEntry(String entryId, String newName) async {
    renameCalls++;
    final int slashIndex = entryId.lastIndexOf('/');
    final String parentId =
        slashIndex >= 0 ? entryId.substring(0, slashIndex) : '';
    final String nextEntryId =
        parentId.isEmpty ? newName : '$parentId/$newName';
    for (final String key in _childrenById.keys.toList()) {
      _childrenById[key] = _childrenById[key]!.map((FileAccessEntry entry) {
        if (entry.entryId != entryId) {
          return entry;
        }
        return FileAccessEntry(
          entryId: nextEntryId,
          name: newName,
          isDirectory: entry.isDirectory,
          size: entry.size,
          modifiedTime: entry.modifiedTime,
        );
      }).toList();
    }
    return nextEntryId;
  }

  @override
  Future<FileAccessEntry> stat(String entryId) async {
    for (final List<FileAccessEntry> children in _childrenById.values) {
      for (final FileAccessEntry entry in children) {
        if (entry.entryId == entryId) {
          return entry;
        }
      }
    }
    throw StateError('Missing entry: $entryId');
  }
}

class _MemoryWriteSession implements FileWriteSession {
  @override
  Future<void> close() async {}

  @override
  Future<void> write(List<int> chunk) async {}
}

class _MetadataGateway extends _FakeFileAccessGateway {
  _MetadataGateway(this._bytes);

  final Uint8List _bytes;

  static Future<_MetadataGateway> create() async {
    final Tag id3v2 = Tag()
      ..type = 'ID3'
      ..version = '2.4'
      ..tags = <String, dynamic>{
        'title': 'Remote Song',
        'artist': 'Remote Artist',
        'album': 'Remote Album',
      };
    final List<int> bytes = await TagProcessor().putTagsToByteArray(
      Future<List<int>?>.value(List<int>.filled(32, 0)),
      <Tag>[id3v2],
    );
    return _MetadataGateway(Uint8List.fromList(bytes));
  }

  @override
  Stream<List<int>> openRead(String entryId) async* {
    if (entryId == 'entry-song') {
      yield _bytes;
      return;
    }
    yield const <int>[];
  }

  @override
  Future<FileAccessEntry> stat(String entryId) async {
    if (entryId == 'entry-song') {
      return FileAccessEntry(
        entryId: 'entry-song',
        name: 'song.mp3',
        isDirectory: false,
        size: 123,
        modifiedTime: DateTime.fromMillisecondsSinceEpoch(5),
      );
    }
    if (entryId == 'entry-dir') {
      return FileAccessEntry(
        entryId: 'entry-dir',
        name: 'Album',
        isDirectory: true,
        size: 0,
        modifiedTime: DateTime.fromMillisecondsSinceEpoch(6),
      );
    }
    return super.stat(entryId);
  }
}

class _PeerPair {
  _PeerPair({
    required this.client,
    required this.clientSocket,
    required this.serverSession,
    required this.serverSocket,
  });

  final PeerSession client;
  final Socket clientSocket;
  final PeerSession serverSession;
  final ServerSocket serverSocket;
  bool _clientClosed = false;
  bool _closed = false;

  static Future<_PeerPair> open(
    FutureOr<void> Function(PeerSession session) onServerSession,
  ) async {
    final ServerSocket server =
        await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final Future<Socket> accepted = server.first;
    final Socket clientSocket =
        await Socket.connect(InternetAddress.loopbackIPv4, server.port);
    final Socket serverSocket = await accepted;
    final PeerSession serverSession = PeerSession(serverSocket);
    await onServerSession(serverSession);
    return _PeerPair(
      client: PeerSession(clientSocket),
      clientSocket: clientSocket,
      serverSession: serverSession,
      serverSocket: server,
    );
  }

  Future<void> closeClientOnly() async {
    if (_clientClosed) {
      return;
    }
    _clientClosed = true;
    try {
      await client.close();
    } catch (_) {
      try {
        await clientSocket.close();
      } catch (_) {
        // Ignore test socket cleanup failures.
      }
    }
  }

  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    await closeClientOnly();
    try {
      await serverSession.close();
    } catch (_) {
      // Ignore test socket cleanup failures.
    }
    try {
      await serverSocket.close();
    } catch (_) {
      // Ignore test socket cleanup failures.
    }
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

ScanSnapshot _localSnapshot() {
  return ScanSnapshot(
    rootId: 'local-root',
    rootDisplayName: 'Local',
    deviceId: 'local-device',
    scannedAt: DateTime.fromMillisecondsSinceEpoch(0),
    entries: const <FileEntry>[],
    cacheVersion: 1,
  );
}
