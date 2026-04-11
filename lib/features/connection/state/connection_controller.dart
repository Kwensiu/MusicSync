import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_sync/core/constants/app_constants.dart';
import 'package:music_sync/core/errors/app_error_localizer.dart';
import 'package:music_sync/features/connection/state/discovered_device_entry.dart';
import 'package:music_sync/features/connection/state/connection_state.dart';
import 'package:music_sync/features/directory/state/directory_controller.dart';
import 'package:music_sync/features/execution/state/execution_controller.dart';
import 'package:music_sync/features/execution/state/execution_state.dart';
import 'package:music_sync/features/preview/models/diff_item_detail_view_data.dart';
import 'package:music_sync/features/preview/state/preview_controller.dart';
import 'package:music_sync/features/settings/state/settings_controller.dart';
import 'package:music_sync/models/device_info.dart';
import 'package:music_sync/models/scan_snapshot.dart';
import 'package:music_sync/services/file_access/file_access_entry.dart';
import 'package:music_sync/services/file_access/file_access_gateway.dart';
import 'package:music_sync/services/file_access/file_access_provider.dart';
import 'package:music_sync/services/media/audio_metadata_reader.dart';
import 'package:music_sync/services/network/discovery_service.dart';
import 'package:music_sync/services/network/http/http_sync_client.dart';
import 'package:music_sync/services/network/http/http_sync_dto.dart';
import 'package:music_sync/services/network/http/http_sync_server_service.dart';
import 'package:music_sync/services/platform/device_display_info_service.dart';
import 'package:music_sync/services/storage/recent_items_store.dart';
import 'package:music_sync/services/storage/settings_store.dart';

final Provider<DiscoveryService> discoveryServiceProvider =
    Provider<DiscoveryService>((Ref ref) => DiscoveryService());
final Provider<HttpSyncClient> httpSyncClientProvider =
    Provider<HttpSyncClient>((Ref ref) => HttpSyncClient());
final Provider<HttpSyncServerService> httpSyncServerServiceProvider =
    Provider<HttpSyncServerService>((Ref ref) => HttpSyncServerService());

class ConnectionController extends Notifier<ConnectionState> {
  Ref get _ref => ref;
  HttpSyncClient get _httpClient => ref.read(httpSyncClientProvider);
  HttpSyncServerService get _httpServer =>
      ref.read(httpSyncServerServiceProvider);
  RecentItemsStore get _store => ref.read(recentItemsStoreProvider);
  DiscoveryService get _discovery => ref.read(discoveryServiceProvider);
  SettingsStore get _settingsStore => ref.read(settingsStoreProvider);
  DeviceDisplayInfoService get _deviceDisplayInfo =>
      ref.read(deviceDisplayInfoServiceProvider);
  bool get _httpEncryptionEnabled =>
      ref.read(settingsControllerProvider).httpEncryptionEnabled;

  bool _isDisposed = false;
  String? _localDeviceIdentity;

  Map<String, DiscoveredDeviceEntry> _normalizedDiscoveredDeviceMap({
    DeviceInfo? peer,
    ConnectionStatus? status,
  }) {
    final String? connectedPeerId =
        (status ?? state.status) == ConnectionStatus.connected
        ? _deviceKey(peer)
        : null;
    return <String, DiscoveredDeviceEntry>{
      for (final MapEntry<String, DiscoveredDeviceEntry> entry
          in state.discoveredDeviceMap.entries)
        entry.key: entry.value.copyWith(
          isConnectedPeer:
              connectedPeerId != null && entry.key == connectedPeerId,
        ),
    };
  }

  Map<String, DiscoveredDeviceEntry> _discoveredDeviceMapWithConnectedPeer(
    DeviceInfo? peer, {
    ConnectionStatus? status,
  }) {
    final Map<String, DiscoveredDeviceEntry> normalizedMap =
        _normalizedDiscoveredDeviceMap(peer: peer, status: status);
    if ((status ?? state.status) != ConnectionStatus.connected ||
        peer == null) {
      return normalizedMap;
    }

    final DateTime now = DateTime.now();
    final String peerKey = _deviceKey(peer);
    final DiscoveredDeviceEntry? existing = normalizedMap[peerKey];
    final Set<String> seenAddresses = <String>{
      ...?existing?.seenAddresses,
      if (peer.address.isNotEmpty) peer.address,
    };

    return <String, DiscoveredDeviceEntry>{
      ...normalizedMap,
      peerKey: existing == null
          ? DiscoveredDeviceEntry.fromDevice(
              peer,
              seenAt: now,
              isConnectedPeer: true,
            )
          : existing.copyWith(
              deviceName: peer.deviceName,
              platform: peer.platform,
              primaryAddress: peer.address.isNotEmpty
                  ? peer.address
                  : existing.primaryAddress,
              port: peer.port,
              httpEncryptionEnabled: peer.httpEncryptionEnabled,
              lastSeenAt: now,
              seenAddresses: seenAddresses,
              isConnectedPeer: true,
            ),
    };
  }

  @override
  ConnectionState build() {
    _isDisposed = false;
    final DiscoveryService discovery = _discovery;
    unawaited(_loadRecent());
    unawaited(_primeLocalDeviceIdentity());
    _discoveryCleanupTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _pruneDiscoveredDevices(),
    );
    _remoteDirectorySyncTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(_pollRemoteDirectoryState()),
    );
    unawaited(discovery.startReceiving(onDevice: _handleDiscoveryEvent));
    ref.onDispose(() {
      _isDisposed = true;
      _discoveryCleanupTimer?.cancel();
      _remoteDirectorySyncTimer?.cancel();
      unawaited(discovery.dispose());
    });
    return ConnectionState.initial();
  }

  Timer? _discoveryCleanupTimer;
  Timer? _remoteDirectorySyncTimer;
  final Map<String, DateTime> _discoveredAt = <String, DateTime>{};
  final Map<String, FileWriteSession> _incomingWriteSessions =
      <String, FileWriteSession>{};
  final Map<String, _IncomingWriteTarget> _incomingWriteTargets =
      <String, _IncomingWriteTarget>{};
  int _connectAttemptId = 0;

  Future<void> startListening({int port = AppConstants.defaultPort}) async {
    try {
      await _httpServer.start(
        port: port,
        httpEncryptionEnabled: _httpEncryptionEnabled,
        onHello: _handleHttpHello,
        onSessionClose: _handleHttpSessionClose,
        onDirectoryStatus: _handleHttpDirectoryStatus,
        onScan: _handleHttpScan,
        onEntryDetail: _handleHttpEntryDetail,
        onSyncSessionState: _handleHttpSyncSessionState,
        onBeginCopy: _handleHttpBeginCopy,
        onWriteChunk: _handleHttpWriteChunk,
        onFinishCopy: _handleHttpFinishCopy,
        onAbortCopy: _handleHttpAbortCopy,
        onDeleteEntry: _handleHttpDeleteEntry,
      );
      await _discovery.startBroadcasting(await _buildLocalDevice(port: port));
      state = ConnectionState(
        status: state.peer == null
            ? ConnectionStatus.idle
            : ConnectionStatus.connected,
        isListening: true,
        listenPort: port,
        peer: state.peer,
        remoteSnapshot: state.remoteSnapshot,
        isRemoteDirectoryReady: state.isRemoteDirectoryReady,
        isIncomingSyncActive: state.isIncomingSyncActive,
        discoveredDeviceMap: state.discoveredDeviceMap,
        recentAddresses: state.recentAddresses,
        recentLabels: state.recentLabels,
      );
    } catch (error) {
      state = ConnectionState(
        status: ConnectionStatus.failed,
        isListening: state.isListening,
        listenPort: state.listenPort,
        peer: state.peer,
        remoteSnapshot: state.remoteSnapshot,
        isRemoteDirectoryReady: state.isRemoteDirectoryReady,
        isIncomingSyncActive: state.isIncomingSyncActive,
        discoveredDeviceMap: state.discoveredDeviceMap,
        recentAddresses: state.recentAddresses,
        recentLabels: state.recentLabels,
        errorMessage: _localizeListenStartError(error.toString(), port: port),
      );
    }
  }

  Future<void> stopListening() async {
    _connectAttemptId++;
    final int? listenPort = state.listenPort;
    final DeviceInfo? peer = state.peer;
    if (listenPort != null) {
      try {
        await _discovery.sendGoodbye(await _buildLocalDevice(port: listenPort));
      } catch (_) {
        // Best effort only.
      }
    }
    if (peer != null && peer.address.isNotEmpty) {
      try {
        await _httpClient.closeSession(
          address: peer.address,
          port: peer.port,
          deviceId: (await _buildLocalDevice(
            port: state.listenPort ?? AppConstants.defaultPort,
          )).deviceId,
          httpEncryptionEnabled: peer.httpEncryptionEnabled,
        );
      } catch (_) {
        // Best effort only.
      }
    }
    await _httpServer.stop();
    await _discovery.stopBroadcasting();
    _clearPlanAndExecution();
    state = ConnectionState(
      status: ConnectionStatus.idle,
      isListening: false,
      peer: null,
      remoteSnapshot: null,
      isIncomingSyncActive: false,
      isRemoteDirectoryReady: false,
      listenPort: null,
      discoveredDeviceMap: _normalizedDiscoveredDeviceMap(
        peer: null,
        status: ConnectionStatus.idle,
      ),
      recentAddresses: state.recentAddresses,
      recentLabels: state.recentLabels,
    );
  }

  Future<void> refreshPresence() async {
    final int? listenPort = state.listenPort;
    if (listenPort != null) {
      try {
        await _discovery.startBroadcasting(
          await _buildLocalDevice(port: listenPort),
        );
      } catch (_) {
        // Best effort only.
      }
    }
    _ensureConnectedPeerVisible();
    if (state.peer != null && state.status == ConnectionStatus.connected) {
      await refreshRemoteDirectoryStatus();
      await refreshRemoteSnapshot(clearTransientState: false);
    }
  }

  Future<void> connect({required String address, required int port}) async {
    // TODO(http-fingerprint): manual connections currently learn only address
    // and port. To fully pin HTTPS peers, extend this flow so a known
    // fingerprint can be supplied/resolved before trusting the certificate.
    final int attemptId = ++_connectAttemptId;
    final DirectoryHandle? localHandle = _ref
        .read(directoryControllerProvider)
        .handle;
    _clearPlanAndExecution();
    state = ConnectionState(
      status: ConnectionStatus.connecting,
      isListening: state.isListening,
      listenPort: state.listenPort,
      peer: null,
      remoteSnapshot: null,
      isRemoteDirectoryReady: false,
      isIncomingSyncActive: false,
      discoveredDeviceMap: _normalizedDiscoveredDeviceMap(
        peer: null,
        status: ConnectionStatus.connecting,
      ),
      recentAddresses: state.recentAddresses,
      recentLabels: state.recentLabels,
    );

    try {
      final HelloResponseDto response = await _httpClient.hello(
        address: address,
        port: port,
        localDevice: await _buildLocalDevice(
          port: state.listenPort ?? AppConstants.defaultPort,
        ),
        directoryReady: localHandle != null,
        directoryDisplayName: localHandle?.displayName,
      );
      final DeviceInfo peer = DeviceInfo(
        deviceId: response.device.deviceId,
        deviceName: _sanitizePeerName(
          response.device.deviceName,
          fallbackPlatform: response.device.platform,
          fallbackAddress: address,
        ),
        platform: response.device.platform,
        address: address,
        port: port,
        httpEncryptionEnabled: response.device.httpEncryptionEnabled,
      );
      await _store.saveRecentAddress('$address:$port');
      final bool isRemoteDirectoryReady = response.directoryReady;
      state = ConnectionState(
        status: ConnectionStatus.connecting,
        isListening: state.isListening,
        peer: peer,
        remoteSnapshot: null,
        isRemoteDirectoryReady: isRemoteDirectoryReady,
        isIncomingSyncActive: false,
        listenPort: state.listenPort,
        discoveredDeviceMap: state.discoveredDeviceMap,
        recentAddresses: state.recentAddresses,
        recentLabels: state.recentLabels,
      );
      ScanSnapshot? remoteSnapshot;
      try {
        if (isRemoteDirectoryReady) {
          remoteSnapshot = await _requestRemoteSnapshot();
        } else {
          throw const SocketException('No shared directory selected on peer.');
        }
      } catch (error) {
        final String message = error.toString();
        if (!message.contains('No shared directory selected on peer')) {
          rethrow;
        }
      }
      if (attemptId != _connectAttemptId) {
        return;
      }
      state = ConnectionState(
        status: ConnectionStatus.connected,
        isListening: state.isListening,
        peer: peer,
        remoteSnapshot: remoteSnapshot,
        isRemoteDirectoryReady: isRemoteDirectoryReady,
        listenPort: state.listenPort,
        discoveredDeviceMap: _discoveredDeviceMapWithConnectedPeer(
          peer,
          status: ConnectionStatus.connected,
        ),
        recentAddresses: await _store.loadRecentAddresses(),
        recentLabels: await _store.loadRecentAddressLabels(),
      );
    } catch (error) {
      if (attemptId != _connectAttemptId) {
        return;
      }
      state = ConnectionState(
        status: ConnectionStatus.failed,
        isListening: state.isListening,
        listenPort: state.listenPort,
        discoveredDeviceMap: state.discoveredDeviceMap,
        recentAddresses: state.recentAddresses,
        recentLabels: state.recentLabels,
        errorMessage: ConnectionState.localizeErrorMessage(error.toString()),
      );
    }
  }

  Future<bool> refreshRemoteDirectoryStatus() async {
    final DeviceInfo? peer = state.peer;
    if (peer == null || peer.address.isEmpty) {
      return false;
    }
    try {
      final DirectoryStatusResponseDto response = await _httpClient
          .directoryStatus(
            address: peer.address,
            port: peer.port,
            httpEncryptionEnabled: peer.httpEncryptionEnabled,
          );
      state = ConnectionState(
        status: ConnectionStatus.connected,
        isListening: state.isListening,
        peer: peer,
        remoteSnapshot: response.directoryReady ? state.remoteSnapshot : null,
        isRemoteDirectoryReady: response.directoryReady,
        isIncomingSyncActive: state.isIncomingSyncActive,
        listenPort: state.listenPort,
        discoveredDeviceMap: _discoveredDeviceMapWithConnectedPeer(
          peer,
          status: ConnectionStatus.connected,
        ),
        recentAddresses: state.recentAddresses,
        recentLabels: state.recentLabels,
      );
      return response.directoryReady;
    } catch (error) {
      final String message = error.toString();
      if (_isPeerDisconnectedError(message)) {
        _handleDisconnected(error);
      }
      return false;
    }
  }

  Future<void> _pollRemoteDirectoryState() async {
    if (_isDisposed) {
      return;
    }
    final DeviceInfo? peer = state.peer;
    if (peer == null || state.status != ConnectionStatus.connected) {
      return;
    }
    final bool previousReady = state.isRemoteDirectoryReady;
    final String? previousRootId = state.remoteSnapshot?.rootId;
    final bool ready = await refreshRemoteDirectoryStatus();
    if (!ready) {
      return;
    }
    if (!previousReady || previousRootId == null) {
      await refreshRemoteSnapshot(clearTransientState: false);
    }
  }

  void _handleDisconnected(Object? error) {
    unawaited(_cleanupIncomingTransfers());
    final ExecutionState executionState = _ref.read(
      executionControllerProvider,
    );
    _ref.read(previewControllerProvider.notifier).clear();
    if (executionState.status == ExecutionStatus.running &&
        executionState.mode == ExecutionMode.remote) {
      _ref
          .read(executionControllerProvider.notifier)
          .failActiveExecution(
            'Remote device disconnected. Keep the target device in foreground and reconnect.',
          );
    } else {
      _ref.read(executionControllerProvider.notifier).clearTransient();
    }
    state = ConnectionState(
      status: ConnectionStatus.disconnected,
      isListening: state.isListening,
      listenPort: state.listenPort,
      discoveredDeviceMap: _normalizedDiscoveredDeviceMap(
        peer: null,
        status: ConnectionStatus.disconnected,
      ),
      recentAddresses: state.recentAddresses,
      recentLabels: state.recentLabels,
      peer: null,
      remoteSnapshot: null,
      isRemoteDirectoryReady: false,
      errorMessage: AppErrorLocalizer.resolve(
        'Remote device disconnected. Keep the target device in foreground and reconnect.',
      ),
    );
  }

  Future<ScanSnapshot?> refreshRemoteSnapshot({
    bool clearTransientState = true,
  }) async {
    final DeviceInfo? peer = state.peer;
    if (peer == null) {
      return null;
    }
    if (clearTransientState) {
      _clearPlanAndExecution();
    }
    try {
      final bool ready = await refreshRemoteDirectoryStatus();
      if (!ready) {
        _handleRemoteDirectoryUnavailable();
        state = ConnectionState(
          status: ConnectionStatus.connected,
          isListening: state.isListening,
          peer: peer,
          remoteSnapshot: null,
          isRemoteDirectoryReady: false,
          isIncomingSyncActive: state.isIncomingSyncActive,
          listenPort: state.listenPort,
          discoveredDeviceMap: state.discoveredDeviceMap,
          recentAddresses: state.recentAddresses,
          recentLabels: state.recentLabels,
        );
        return null;
      }
      final ScanSnapshot remoteSnapshot = await _requestRemoteSnapshot();
      state = ConnectionState(
        status: ConnectionStatus.connected,
        isListening: state.isListening,
        peer: peer,
        remoteSnapshot: remoteSnapshot,
        isRemoteDirectoryReady: true,
        isIncomingSyncActive: state.isIncomingSyncActive,
        listenPort: state.listenPort,
        discoveredDeviceMap: _discoveredDeviceMapWithConnectedPeer(
          peer,
          status: ConnectionStatus.connected,
        ),
        recentAddresses: state.recentAddresses,
        recentLabels: state.recentLabels,
      );
      return remoteSnapshot;
    } catch (error) {
      final String message = error.toString();
      if (_isPeerDisconnectedError(message)) {
        _handleDisconnected(error);
        return null;
      }
      final bool remoteDirectoryUnavailable =
          _isRemoteDirectoryUnavailableError(message);
      if (remoteDirectoryUnavailable) {
        _handleRemoteDirectoryUnavailable();
      }
      state = ConnectionState(
        status: ConnectionStatus.connected,
        isListening: state.isListening,
        peer: peer,
        remoteSnapshot: remoteDirectoryUnavailable
            ? null
            : state.remoteSnapshot,
        isRemoteDirectoryReady: remoteDirectoryUnavailable
            ? false
            : state.isRemoteDirectoryReady,
        isIncomingSyncActive: state.isIncomingSyncActive,
        listenPort: state.listenPort,
        discoveredDeviceMap: state.discoveredDeviceMap,
        recentAddresses: state.recentAddresses,
        recentLabels: state.recentLabels,
        errorMessage: ConnectionState.localizeErrorMessage(message),
      );
      return null;
    }
  }

  Future<ScanSnapshot> _requestRemoteSnapshot() async {
    final DeviceInfo? peer = state.peer;
    if (peer == null || peer.address.isEmpty) {
      throw const SocketException('Not connected to any peer.');
    }
    final ScanResponseDto response = await _httpClient.scan(
      address: peer.address,
      port: peer.port,
      httpEncryptionEnabled: peer.httpEncryptionEnabled,
    );
    return response.snapshot;
  }

  Future<HelloResponseDto> _handleHttpHello(
    HelloRequestDto request,
    String remoteAddress,
  ) async {
    final DirectoryHandle? handle = _ref
        .read(directoryControllerProvider)
        .handle;
    state = ConnectionState(
      status: ConnectionStatus.connected,
      isListening: state.isListening,
      peer: DeviceInfo(
        deviceId: request.device.deviceId,
        deviceName: _sanitizePeerName(
          request.device.deviceName,
          fallbackPlatform: request.device.platform,
          fallbackAddress: remoteAddress,
        ),
        platform: request.device.platform,
        address: remoteAddress,
        port: request.device.port,
        httpEncryptionEnabled: request.device.httpEncryptionEnabled,
      ),
      remoteSnapshot: request.directoryReady ? state.remoteSnapshot : null,
      isRemoteDirectoryReady: request.directoryReady,
      isIncomingSyncActive: state.isIncomingSyncActive,
      listenPort: state.listenPort,
      discoveredDeviceMap: _discoveredDeviceMapWithConnectedPeer(
        DeviceInfo(
          deviceId: request.device.deviceId,
          deviceName: _sanitizePeerName(
            request.device.deviceName,
            fallbackPlatform: request.device.platform,
            fallbackAddress: remoteAddress,
          ),
          platform: request.device.platform,
          address: remoteAddress,
          port: request.device.port,
          httpEncryptionEnabled: request.device.httpEncryptionEnabled,
        ),
        status: ConnectionStatus.connected,
      ),
      recentAddresses: state.recentAddresses,
      recentLabels: state.recentLabels,
    );
    return HelloResponseDto(
      device: await _buildLocalDevice(
        port: state.listenPort ?? AppConstants.defaultPort,
      ),
      directoryReady: handle != null,
      directoryDisplayName: handle?.displayName,
    );
  }

  Future<void> _handleHttpSessionClose(SessionCloseRequestDto request) async {
    if (state.peer?.deviceId != request.deviceId) {
      return;
    }
    _clearPlanAndExecution();
    state = ConnectionState(
      status: state.isListening
          ? ConnectionStatus.idle
          : ConnectionStatus.disconnected,
      isListening: state.isListening,
      listenPort: state.listenPort,
      discoveredDeviceMap: _normalizedDiscoveredDeviceMap(
        peer: null,
        status: state.isListening
            ? ConnectionStatus.idle
            : ConnectionStatus.disconnected,
      ),
      recentAddresses: state.recentAddresses,
      recentLabels: state.recentLabels,
      peer: null,
      remoteSnapshot: null,
      isRemoteDirectoryReady: false,
      isIncomingSyncActive: false,
    );
  }

  Future<DirectoryStatusResponseDto> _handleHttpDirectoryStatus() async {
    final DirectoryHandle? handle = _ref
        .read(directoryControllerProvider)
        .handle;
    return DirectoryStatusResponseDto(
      directoryReady: handle != null,
      directoryDisplayName: handle?.displayName,
    );
  }

  Future<ScanResponseDto> _handleHttpScan() async {
    final DirectoryHandle? handle = _ref
        .read(directoryControllerProvider)
        .handle;
    if (handle == null) {
      throw const SocketException('No shared directory selected on peer.');
    }
    final ScanSnapshot snapshot = await _ref
        .read(directoryScannerProvider)
        .scan(
          root: handle,
          deviceId: (await _buildLocalDevice(
            port: state.listenPort ?? AppConstants.defaultPort,
          )).deviceId,
        );
    return ScanResponseDto(snapshot: snapshot);
  }

  Future<DiffEntryDetailViewData> _handleHttpEntryDetail(String entryId) async {
    final FileAccessGateway gateway = _ref.read(fileAccessGatewayProvider);
    final FileAccessEntry entry = await gateway.stat(entryId);
    final AudioMetadataViewData? metadata = entry.isDirectory
        ? null
        : await AudioMetadataReader(gateway).read(entryId);
    return DiffEntryDetailViewData(
      entryId: entry.entryId,
      displayName: entry.name,
      isDirectory: entry.isDirectory,
      size: entry.size,
      modifiedTime: entry.modifiedTime,
      audioMetadata: metadata,
    );
  }

  Future<void> _handleHttpSyncSessionState(
    SyncSessionStateRequestDto request,
  ) async {
    _setIncomingSyncActive(request.active);
  }

  Future<void> _handleHttpBeginCopy(BeginCopyRequestDto request) async {
    await _beginCopy(
      remoteRootId: request.remoteRootId,
      relativePath: request.relativePath,
      transferId: request.transferId,
    );
  }

  Future<void> _handleHttpWriteChunk(WriteChunkRequestDto request) async {
    await _writeChunk(transferId: request.transferId, data: request.data);
  }

  Future<void> _handleHttpFinishCopy(FinishCopyRequestDto request) async {
    await _finishCopy(transferId: request.transferId);
  }

  Future<void> _handleHttpAbortCopy(AbortCopyRequestDto request) async {
    await _abortCopy(transferId: request.transferId);
  }

  Future<void> _handleHttpDeleteEntry(DeleteEntryRequestDto request) async {
    await _deleteEntry(
      remoteRootId: request.remoteRootId,
      relativePath: request.relativePath,
    );
  }

  Future<void> disconnect() async {
    _connectAttemptId++;
    final DeviceInfo? peer = state.peer;
    if (peer != null && peer.address.isNotEmpty) {
      try {
        await _httpClient.closeSession(
          address: peer.address,
          port: peer.port,
          deviceId: (await _buildLocalDevice(
            port: state.listenPort ?? AppConstants.defaultPort,
          )).deviceId,
          httpEncryptionEnabled: peer.httpEncryptionEnabled,
        );
      } catch (_) {
        // Best effort only.
      }
    }
    _clearPlanAndExecution();
    state = ConnectionState(
      status: ConnectionStatus.idle,
      isListening: state.isListening,
      listenPort: state.listenPort,
      discoveredDeviceMap: _normalizedDiscoveredDeviceMap(
        peer: null,
        status: ConnectionStatus.idle,
      ),
      recentAddresses: state.recentAddresses,
      recentLabels: state.recentLabels,
      peer: null,
      remoteSnapshot: null,
      isRemoteDirectoryReady: false,
      isIncomingSyncActive: false,
    );
  }

  Future<void> resetNetworkStateForProtocolChange() async {
    final ExecutionState executionState = _ref.read(
      executionControllerProvider,
    );
    if (state.status == ConnectionStatus.connecting) {
      throw StateError(
        'Cannot change HTTP encryption while a device connection is in progress.',
      );
    }
    if (state.isIncomingSyncActive) {
      throw StateError(
        'Cannot change HTTP encryption while this device is receiving a sync.',
      );
    }
    if (executionState.status == ExecutionStatus.running) {
      throw StateError(
        'Cannot change HTTP encryption while a sync task is running.',
      );
    }

    final bool wasListening = state.isListening;
    final int restartPort = state.listenPort ?? AppConstants.defaultPort;
    final DeviceInfo? peer = state.peer;

    if (wasListening) {
      await stopListening();
    } else if (peer != null) {
      await disconnect();
    }

    if (wasListening) {
      await startListening(port: restartPort);
    }
  }

  Future<FileAccessEntry?> requestRemoteEntryStat(String entryId) async {
    if (entryId.isEmpty || state.peer == null) {
      return null;
    }
    try {
      final DiffEntryDetailViewData detail =
          await requestRemoteEntryDetail(entryId) ??
          (throw const SocketException('Remote stat failed.'));
      return FileAccessEntry(
        entryId: detail.entryId,
        name: detail.displayName,
        isDirectory: detail.isDirectory,
        size: detail.size,
        modifiedTime: detail.modifiedTime,
      );
    } catch (_) {
      return null;
    }
  }

  Future<DiffEntryDetailViewData?> requestRemoteEntryDetail(
    String entryId,
  ) async {
    final DeviceInfo? peer = state.peer;
    if (entryId.isEmpty || peer == null || peer.address.isEmpty) {
      return null;
    }
    try {
      return await _httpClient.entryDetail(
        address: peer.address,
        port: peer.port,
        entryId: entryId,
        httpEncryptionEnabled: peer.httpEncryptionEnabled,
      );
    } catch (_) {
      return null;
    }
  }

  void _clearPlanAndExecution() {
    _ref.read(previewControllerProvider.notifier).clear();
    _ref.read(executionControllerProvider.notifier).clearTransient();
  }

  void _handleRemoteDirectoryUnavailable() {
    final ExecutionState executionState = _ref.read(
      executionControllerProvider,
    );
    _ref.read(previewControllerProvider.notifier).clear();
    if (executionState.status == ExecutionStatus.running &&
        executionState.mode == ExecutionMode.remote) {
      _ref
          .read(executionControllerProvider.notifier)
          .failRemoteExecution(
            'The selected directory is not accessible anymore.',
          );
      return;
    }
    _ref.read(executionControllerProvider.notifier).clearTransient();
  }

  bool _isRemoteDirectoryUnavailableError(String value) {
    return value.contains('No shared directory selected on peer') ||
        value.contains('not accessible anymore');
  }

  bool _isPeerDisconnectedError(String value) {
    return value.contains('Not connected to any peer') ||
        value.contains('Peer disconnected') ||
        value.contains('Remote device disconnected') ||
        value.contains('Peer response timed out');
  }

  String _localizeListenStartError(String rawError, {required int port}) {
    if (rawError.contains('Address already in use')) {
      return AppErrorLocalizer.resolve(
        'Listen port $port is already in use. Close the old app process or choose another port.',
      );
    }
    return ConnectionState.localizeErrorMessage(rawError);
  }

  Future<void> saveRecentAddress(String value) async {
    await _store.saveRecentAddress(value);
    state = ConnectionState(
      status: state.status,
      isListening: state.isListening,
      peer: state.peer,
      remoteSnapshot: state.remoteSnapshot,
      isRemoteDirectoryReady: state.isRemoteDirectoryReady,
      isIncomingSyncActive: state.isIncomingSyncActive,
      discoveredDeviceMap: state.discoveredDeviceMap,
      recentAddresses: await _store.loadRecentAddresses(),
      recentLabels: await _store.loadRecentAddressLabels(),
      listenPort: state.listenPort,
      errorMessage: state.errorMessage,
    );
  }

  Future<DeviceInfo> _buildLocalDevice({required int port}) async {
    final String deviceId = await _ensureLocalDeviceIdentity();
    final String deviceAlias = await _settingsStore.loadDeviceAlias();
    final String deviceName = deviceAlias.isNotEmpty
        ? deviceAlias
        : await _deviceDisplayInfo.defaultAlias();
    return DeviceInfo(
      deviceId: deviceId,
      deviceName: deviceName,
      platform: Platform.operatingSystem,
      address: '',
      port: port,
      httpEncryptionEnabled: _httpEncryptionEnabled,
    );
  }

  String _sanitizePeerName(
    String? rawName, {
    String? fallbackPlatform,
    String? fallbackAddress,
  }) {
    final String? normalized = rawName?.trim();
    if (normalized != null &&
        normalized.isNotEmpty &&
        normalized.toLowerCase() != 'localhost') {
      return normalized;
    }
    final String? platform = fallbackPlatform?.trim();
    if (platform != null && platform.isNotEmpty) {
      if (platform.toLowerCase() == 'android') {
        return 'Android';
      }
      if (platform.toLowerCase() == 'windows') {
        return 'Windows';
      }
      return platform;
    }
    final String? address = fallbackAddress?.trim();
    if (address != null && address.isNotEmpty) {
      return address;
    }
    return 'Peer';
  }

  Future<void> _loadRecent() async {
    final List<String> recentAddresses = await _store.loadRecentAddresses();
    final Map<String, String> recentLabels = await _store
        .loadRecentAddressLabels();
    if (_isDisposed) {
      return;
    }
    state = ConnectionState(
      status: state.status,
      isListening: state.isListening,
      peer: state.peer,
      remoteSnapshot: state.remoteSnapshot,
      isRemoteDirectoryReady: state.isRemoteDirectoryReady,
      isIncomingSyncActive: state.isIncomingSyncActive,
      discoveredDeviceMap: state.discoveredDeviceMap,
      recentAddresses: recentAddresses,
      recentLabels: recentLabels,
      listenPort: state.listenPort,
      errorMessage: state.errorMessage,
    );
  }

  Future<void> reloadRecent() => _loadRecent();

  void _handleDiscoveryEvent(DiscoveryEvent event) {
    unawaited(_handleDiscoveryEventAsync(event));
  }

  Future<void> _handleDiscoveryEventAsync(DiscoveryEvent event) async {
    await _ensureLocalDeviceIdentity();
    switch (event.type) {
      case DiscoveryEventType.announce:
        await _handleDiscoveredDevice(event.device);
        return;
      case DiscoveryEventType.goodbye:
        await _handleRemovedDevice(event.device);
        return;
    }
  }

  Future<void> _handleDiscoveredDevice(DeviceInfo device) async {
    if (_isLocalDevice(device)) {
      return;
    }
    final String deviceKey = _deviceKey(device);
    final DateTime now = DateTime.now();
    _discoveredAt[deviceKey] = now;
    final DiscoveredDeviceEntry? existing =
        state.discoveredDeviceMap[deviceKey];
    final String nextPrimaryAddress;
    if (existing == null ||
        existing.primaryAddress.isEmpty ||
        existing.isConnectedPeer ||
        existing.primaryAddress == device.address) {
      nextPrimaryAddress = device.address;
    } else {
      nextPrimaryAddress = existing.primaryAddress;
    }
    final Set<String> seenAddresses = <String>{
      ...?existing?.seenAddresses,
      if (device.address.isNotEmpty) device.address,
    };
    final DiscoveredDeviceEntry nextEntry = existing == null
        ? DiscoveredDeviceEntry.fromDevice(
            device,
            seenAt: now,
            isConnectedPeer: _isConnectedPeer(device),
          )
        : existing.copyWith(
            deviceName: device.deviceName,
            platform: device.platform,
            port: device.port,
            httpEncryptionEnabled: device.httpEncryptionEnabled,
            primaryAddress: nextPrimaryAddress,
            lastSeenAt: now,
            seenAddresses: seenAddresses,
            isConnectedPeer: _isConnectedPeer(device),
          );
    final Map<String, DiscoveredDeviceEntry> nextMap =
        <String, DiscoveredDeviceEntry>{
          ...state.discoveredDeviceMap,
          deviceKey: nextEntry,
        };
    state = ConnectionState(
      status: state.status,
      isListening: state.isListening,
      peer: state.peer,
      remoteSnapshot: state.remoteSnapshot,
      isRemoteDirectoryReady: state.isRemoteDirectoryReady,
      isIncomingSyncActive: state.isIncomingSyncActive,
      discoveredDeviceMap: nextMap,
      recentAddresses: state.recentAddresses,
      recentLabels: state.recentLabels,
      listenPort: state.listenPort,
      errorMessage: state.errorMessage,
    );
  }

  Future<void> _handleRemovedDevice(DeviceInfo device) async {
    if (_isConnectedPeer(device)) {
      return;
    }
    final String deviceKey = _deviceKey(device);
    _discoveredAt.remove(deviceKey);
    if (!state.discoveredDeviceMap.containsKey(deviceKey)) {
      return;
    }
    final Map<String, DiscoveredDeviceEntry> nextMap =
        <String, DiscoveredDeviceEntry>{...state.discoveredDeviceMap}
          ..remove(deviceKey);
    state = ConnectionState(
      status: state.status,
      isListening: state.isListening,
      peer: state.peer,
      remoteSnapshot: state.remoteSnapshot,
      isRemoteDirectoryReady: state.isRemoteDirectoryReady,
      isIncomingSyncActive: state.isIncomingSyncActive,
      discoveredDeviceMap: nextMap,
      recentAddresses: state.recentAddresses,
      recentLabels: state.recentLabels,
      listenPort: state.listenPort,
      errorMessage: state.errorMessage,
    );
  }

  void _pruneDiscoveredDevices() {
    final DateTime cutoff = DateTime.now().subtract(
      const Duration(seconds: 24),
    );
    _discoveredAt.removeWhere(
      (String _, DateTime seenAt) => seenAt.isBefore(cutoff),
    );
    final Map<String, DiscoveredDeviceEntry> nextMap =
        <String, DiscoveredDeviceEntry>{
          for (final MapEntry<String, DiscoveredDeviceEntry> entry
              in state.discoveredDeviceMap.entries)
            if (entry.value.isConnectedPeer ||
                (_discoveredAt[entry.key] != null &&
                    !_discoveredAt[entry.key]!.isBefore(cutoff)))
              entry.key: entry.value,
        };
    if (nextMap.length == state.discoveredDeviceMap.length) {
      return;
    }
    state = ConnectionState(
      status: state.status,
      isListening: state.isListening,
      peer: state.peer,
      remoteSnapshot: state.remoteSnapshot,
      isRemoteDirectoryReady: state.isRemoteDirectoryReady,
      isIncomingSyncActive: state.isIncomingSyncActive,
      discoveredDeviceMap: nextMap,
      recentAddresses: state.recentAddresses,
      recentLabels: state.recentLabels,
      listenPort: state.listenPort,
      errorMessage: state.errorMessage,
    );
  }

  bool _isConnectedPeer(DeviceInfo device) {
    return state.status == ConnectionStatus.connected &&
        _deviceKey(state.peer) == _deviceKey(device);
  }

  void _ensureConnectedPeerVisible() {
    final DeviceInfo? peer = state.peer;
    if (peer == null || state.status != ConnectionStatus.connected) {
      return;
    }
    state = ConnectionState(
      status: state.status,
      isListening: state.isListening,
      peer: state.peer,
      remoteSnapshot: state.remoteSnapshot,
      isRemoteDirectoryReady: state.isRemoteDirectoryReady,
      isIncomingSyncActive: state.isIncomingSyncActive,
      discoveredDeviceMap: _discoveredDeviceMapWithConnectedPeer(
        peer,
        status: ConnectionStatus.connected,
      ),
      recentAddresses: state.recentAddresses,
      recentLabels: state.recentLabels,
      listenPort: state.listenPort,
      errorMessage: state.errorMessage,
    );
  }

  Future<void> _primeLocalDeviceIdentity() async {
    await _ensureLocalDeviceIdentity();
  }

  Future<String> _ensureLocalDeviceIdentity() async {
    final String? cached = _localDeviceIdentity;
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    final String deviceIdentity = await _settingsStore
        .loadOrCreateDeviceIdentity();
    _localDeviceIdentity = deviceIdentity;
    return deviceIdentity;
  }

  bool _isLocalDevice(DeviceInfo device) {
    final String? localIdentity = _localDeviceIdentity;
    return localIdentity != null &&
        localIdentity.isNotEmpty &&
        device.deviceId == localIdentity;
  }

  String _deviceKey(DeviceInfo? device) {
    if (device == null) {
      return '';
    }
    final String stableId = device.deviceId.trim();
    if (stableId.isNotEmpty) {
      return stableId;
    }
    return [
      device.deviceName.trim(),
      device.platform.trim(),
      device.address.trim(),
      device.port.toString(),
    ].join('|');
  }

  Future<void> _beginCopy({
    required String remoteRootId,
    required String relativePath,
    required String transferId,
  }) async {
    _setIncomingSyncActive(true);
    if (remoteRootId.isEmpty || relativePath.isEmpty || transferId.isEmpty) {
      throw const FormatException('Copy request payload invalid.');
    }
    final FileAccessGateway gateway = _ref.read(fileAccessGatewayProvider);
    final String parentId = await _ensureRemoteParentDirectory(
      gateway: gateway,
      remoteRootId: remoteRootId,
      relativePath: relativePath,
    );
    final String fileName = _fileNameOf(relativePath);
    final String tempFileName = _tempFileName(fileName);
    final FileWriteSession session = await gateway.openWrite(
      parentId,
      tempFileName,
    );
    _incomingWriteSessions[transferId] = session;
    final String? tempEntryId = await _resolveRemoteEntryId(
      gateway: gateway,
      rootId: remoteRootId,
      relativePath: _replaceFileName(relativePath, tempFileName),
    );
    if (tempEntryId == null) {
      await session.close();
      throw const FileSystemException(
        'Temporary target file could not be resolved.',
      );
    }
    _incomingWriteTargets[transferId] = _IncomingWriteTarget(
      tempEntryId: tempEntryId,
      finalName: fileName,
    );
  }

  Future<void> _writeChunk({
    required String transferId,
    required String data,
  }) async {
    final FileWriteSession session =
        _incomingWriteSessions[transferId] ??
        (throw const FormatException('Transfer session not found.'));
    await session.write(base64Decode(data));
  }

  Future<void> _finishCopy({required String transferId}) async {
    final FileWriteSession session =
        _incomingWriteSessions.remove(transferId) ??
        (throw const FormatException('Transfer session not found.'));
    final _IncomingWriteTarget? target = _incomingWriteTargets.remove(
      transferId,
    );
    await session.close();
    if (target != null) {
      final FileAccessGateway gateway = _ref.read(fileAccessGatewayProvider);
      await gateway.renameEntry(target.tempEntryId, target.finalName);
    }
  }

  Future<void> _abortCopy({required String transferId}) async {
    final FileWriteSession session =
        _incomingWriteSessions.remove(transferId) ??
        (throw const FormatException('Transfer session not found.'));
    final _IncomingWriteTarget? target = _incomingWriteTargets.remove(
      transferId,
    );
    await session.close();
    if (target != null) {
      final FileAccessGateway gateway = _ref.read(fileAccessGatewayProvider);
      await gateway.deleteEntry(target.tempEntryId);
    }
  }

  Future<void> _deleteEntry({
    required String remoteRootId,
    required String relativePath,
  }) async {
    final FileAccessGateway gateway = _ref.read(fileAccessGatewayProvider);
    final String? entryId = await _resolveRemoteEntryId(
      gateway: gateway,
      rootId: remoteRootId,
      relativePath: relativePath,
    );
    if (entryId != null) {
      await gateway.deleteEntry(entryId);
    }
  }

  Future<String> _ensureRemoteParentDirectory({
    required FileAccessGateway gateway,
    required String remoteRootId,
    required String relativePath,
  }) async {
    final List<String> segments = relativePath.split(RegExp(r'[\\/]'));
    if (segments.length <= 1) {
      return remoteRootId;
    }
    String currentId = remoteRootId;
    for (final String segment in segments.take(segments.length - 1)) {
      final List<FileAccessEntry> children = await gateway.listChildren(
        currentId,
      );
      final FileAccessEntry? existing = children
          .cast<FileAccessEntry?>()
          .firstWhere(
            (FileAccessEntry? child) =>
                child != null && child.isDirectory && child.name == segment,
            orElse: () => null,
          );
      if (existing != null) {
        currentId = existing.entryId;
        continue;
      }
      currentId = await gateway.createDirectory(currentId, segment);
    }
    return currentId;
  }

  Future<String?> _resolveRemoteEntryId({
    required FileAccessGateway gateway,
    required String rootId,
    required String relativePath,
  }) async {
    String currentId = rootId;
    final List<String> segments = relativePath.split(RegExp(r'[\\/]'));
    for (final String segment in segments) {
      final List<FileAccessEntry> children = await gateway.listChildren(
        currentId,
      );
      final FileAccessEntry? match = children
          .cast<FileAccessEntry?>()
          .firstWhere(
            (FileAccessEntry? child) => child != null && child.name == segment,
            orElse: () => null,
          );
      if (match == null) {
        return null;
      }
      currentId = match.entryId;
    }
    return currentId;
  }

  String _fileNameOf(String relativePath) {
    final List<String> segments = relativePath.split(RegExp(r'[\\/]'));
    return segments.isEmpty ? relativePath : segments.last;
  }

  String _replaceFileName(String relativePath, String fileName) {
    final List<String> segments = relativePath.split(RegExp(r'[\\/]'));
    if (segments.isEmpty) {
      return fileName;
    }
    segments[segments.length - 1] = fileName;
    return segments.join('/');
  }

  String _tempFileName(String fileName) =>
      '$fileName${AppConstants.tempFileSuffix}';

  Future<void> _cleanupIncomingTransfers() async {
    if (_incomingWriteSessions.isEmpty && _incomingWriteTargets.isEmpty) {
      _setIncomingSyncActive(false);
      return;
    }
    final FileAccessGateway gateway = _ref.read(fileAccessGatewayProvider);
    final Map<String, FileWriteSession> sessions =
        Map<String, FileWriteSession>.from(_incomingWriteSessions);
    final Map<String, _IncomingWriteTarget> targets =
        Map<String, _IncomingWriteTarget>.from(_incomingWriteTargets);
    _incomingWriteSessions.clear();
    _incomingWriteTargets.clear();
    for (final FileWriteSession session in sessions.values) {
      try {
        await session.close();
      } catch (_) {
        // Ignore close failures during cleanup.
      }
    }
    for (final _IncomingWriteTarget target in targets.values) {
      try {
        await gateway.deleteEntry(target.tempEntryId);
      } catch (_) {
        // Ignore cleanup failures during disconnect recovery.
      }
    }
    _setIncomingSyncActive(false);
  }

  Future<void> handleLocalDirectoryChanged(DirectoryHandle? handle) async {
    // Directory readiness is now queried over HTTP control endpoints.
  }

  void _setIncomingSyncActive(bool value) {
    if (state.isIncomingSyncActive == value) {
      return;
    }
    state = ConnectionState(
      status: state.status,
      isListening: state.isListening,
      peer: state.peer,
      remoteSnapshot: state.remoteSnapshot,
      isRemoteDirectoryReady: state.isRemoteDirectoryReady,
      isIncomingSyncActive: value,
      discoveredDeviceMap: state.discoveredDeviceMap,
      recentAddresses: state.recentAddresses,
      recentLabels: state.recentLabels,
      listenPort: state.listenPort,
      errorMessage: state.errorMessage,
    );
  }
}

class _IncomingWriteTarget {
  const _IncomingWriteTarget({
    required this.tempEntryId,
    required this.finalName,
  });

  final String tempEntryId;
  final String finalName;
}

final NotifierProvider<ConnectionController, ConnectionState>
connectionControllerProvider =
    NotifierProvider<ConnectionController, ConnectionState>(
      ConnectionController.new,
    );
