import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_sync/core/constants/app_constants.dart';
import 'package:music_sync/core/errors/app_error_localizer.dart';
import 'package:music_sync/features/connection/state/connection_state.dart';
import 'package:music_sync/features/directory/state/directory_controller.dart';
import 'package:music_sync/features/execution/state/execution_controller.dart';
import 'package:music_sync/features/execution/state/execution_state.dart';
import 'package:music_sync/features/preview/models/diff_item_detail_view_data.dart';
import 'package:music_sync/features/preview/state/preview_controller.dart';
import 'package:music_sync/models/device_info.dart';
import 'package:music_sync/models/scan_snapshot.dart';
import 'package:music_sync/services/file_access/file_access_entry.dart';
import 'package:music_sync/services/file_access/file_access_gateway.dart';
import 'package:music_sync/services/file_access/file_access_provider.dart';
import 'package:music_sync/services/media/audio_metadata_reader.dart';
import 'package:music_sync/services/network/connection_service.dart';
import 'package:music_sync/services/network/discovery_service.dart';
import 'package:music_sync/services/network/listener_service.dart';
import 'package:music_sync/services/network/peer_session.dart';
import 'package:music_sync/services/network/protocol/protocol_message.dart';
import 'package:music_sync/services/storage/recent_items_store.dart';

final Provider<ConnectionService> connectionServiceProvider =
    Provider<ConnectionService>((Ref ref) => ConnectionService());

final Provider<ListenerService> listenerServiceProvider =
    Provider<ListenerService>((Ref ref) => ListenerService());
final Provider<DiscoveryService> discoveryServiceProvider =
    Provider<DiscoveryService>((Ref ref) => DiscoveryService());

class ConnectionController extends StateNotifier<ConnectionState> {
  ConnectionController(
    this._ref,
    this._service,
    this._listener,
    this._store,
    this._discovery,
  ) : super(ConnectionState.initial()) {
    _service.onDisconnected = _handleDisconnected;
    _service.onMessage = _handleServiceMessage;
    _loadRecent();
    _discoveryCleanupTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _pruneDiscoveredDevices(),
    );
    unawaited(
      _discovery.startReceiving(
        onDevice: _handleDiscoveryEvent,
      ),
    );
  }

  @override
  void dispose() {
    _discoveryCleanupTimer?.cancel();
    unawaited(_discovery.dispose());
    super.dispose();
  }

  final Ref _ref;
  final ConnectionService _service;
  final ListenerService _listener;
  final RecentItemsStore _store;
  final DiscoveryService _discovery;
  Timer? _discoveryCleanupTimer;
  final Map<String, DateTime> _discoveredAt = <String, DateTime>{};
  final Map<String, FileWriteSession> _incomingWriteSessions =
      <String, FileWriteSession>{};
  final Map<String, _IncomingWriteTarget> _incomingWriteTargets =
      <String, _IncomingWriteTarget>{};
  PeerSession? _activeIncomingSession;
  int _connectAttemptId = 0;

  Future<void> startListening({int port = AppConstants.defaultPort}) async {
    try {
      await _listener.start(
        port: port,
        onClient: _handleIncomingSession,
      );
      await _discovery.startBroadcasting(_buildLocalDevice(port: port));
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
        discoveredDevices: state.discoveredDevices,
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
        discoveredDevices: state.discoveredDevices,
        recentAddresses: state.recentAddresses,
        recentLabels: state.recentLabels,
        errorMessage: ConnectionState.localizeErrorMessage(error.toString()),
      );
    }
  }

  Future<void> stopListening() async {
    _connectAttemptId++;
    final int? listenPort = state.listenPort;
    if (listenPort != null) {
      try {
        await _discovery.sendGoodbye(_buildLocalDevice(port: listenPort));
      } catch (_) {
        // Best effort only.
      }
    }
    final PeerSession? incomingSession = _activeIncomingSession;
    _activeIncomingSession = null;
    await _service.disconnect();
    if (incomingSession != null && incomingSession.isConnected) {
      try {
        await incomingSession.close();
      } catch (_) {
        // Best effort only.
      }
    }
    await _listener.stop();
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
      discoveredDevices: state.discoveredDevices,
      recentAddresses: state.recentAddresses,
      recentLabels: state.recentLabels,
    );
  }

  Future<void> refreshPresence() async {
    final int? listenPort = state.listenPort;
    if (listenPort != null) {
      try {
        await _discovery.startBroadcasting(_buildLocalDevice(port: listenPort));
      } catch (_) {
        // Best effort only.
      }
    }
    _ensureConnectedPeerVisible();
    if (state.peer != null && state.status == ConnectionStatus.connected) {
      await refreshRemoteSnapshot(clearTransientState: false);
    }
  }

  Future<void> connect({
    required String address,
    required int port,
  }) async {
    final int attemptId = ++_connectAttemptId;
    final DirectoryHandle? localHandle =
        _ref.read(directoryControllerProvider).handle;
    _clearPlanAndExecution();
    state = ConnectionState(
      status: ConnectionStatus.connecting,
      isListening: state.isListening,
      listenPort: state.listenPort,
      peer: null,
      remoteSnapshot: null,
      isRemoteDirectoryReady: false,
      isIncomingSyncActive: false,
      discoveredDevices: state.discoveredDevices,
      recentAddresses: state.recentAddresses,
      recentLabels: state.recentLabels,
    );

    try {
      final peer = await _service.connect(
        address: address,
        port: port,
        localDevice: _buildLocalDevice(
            port: state.listenPort ?? AppConstants.defaultPort),
        isDirectoryReady: localHandle != null,
        directoryDisplayName: localHandle?.displayName,
      );
      await _store.saveRecentAddress('$address:$port');
      ScanSnapshot? remoteSnapshot;
      bool isRemoteDirectoryReady = false;
      try {
        remoteSnapshot = await _service.requestRemoteScan();
        isRemoteDirectoryReady = true;
      } catch (error) {
        final String message = error.toString();
        if (!message.contains('No shared directory selected on peer')) {
          rethrow;
        }
      }
      if (attemptId != _connectAttemptId) {
        await _service.disconnect();
        return;
      }
      state = ConnectionState(
        status: ConnectionStatus.connected,
        isListening: state.isListening,
        peer: peer,
        remoteSnapshot: remoteSnapshot,
        isRemoteDirectoryReady: isRemoteDirectoryReady,
        listenPort: state.listenPort,
        discoveredDevices: state.discoveredDevices,
        recentAddresses: await _store.loadRecentAddresses(),
        recentLabels: await _store.loadRecentAddressLabels(),
      );
      await handleLocalDirectoryChanged(localHandle);
    } catch (error) {
      if (attemptId != _connectAttemptId) {
        return;
      }
      state = ConnectionState(
        status: ConnectionStatus.failed,
        isListening: state.isListening,
        listenPort: state.listenPort,
        discoveredDevices: state.discoveredDevices,
        recentAddresses: state.recentAddresses,
        recentLabels: state.recentLabels,
        errorMessage: ConnectionState.localizeErrorMessage(error.toString()),
      );
    }
  }

  void _handleDisconnected(Object? error) {
    unawaited(_cleanupIncomingTransfers());
    final ExecutionState executionState =
        _ref.read(executionControllerProvider);
    _ref.read(previewControllerProvider.notifier).clear();
    if (executionState.status == ExecutionStatus.running &&
        executionState.mode == ExecutionMode.remote) {
      _ref.read(executionControllerProvider.notifier).failActiveExecution(
            'Remote device disconnected. Keep the target device in foreground and reconnect.',
          );
    } else {
      _ref.read(executionControllerProvider.notifier).clearTransient();
    }
    state = ConnectionState(
      status: ConnectionStatus.disconnected,
      isListening: state.isListening,
      listenPort: state.listenPort,
      discoveredDevices: state.discoveredDevices,
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
      final ScanSnapshot remoteSnapshot = await _requestRemoteSnapshot();
      state = ConnectionState(
        status: ConnectionStatus.connected,
        isListening: state.isListening,
        peer: peer,
        remoteSnapshot: remoteSnapshot,
        isRemoteDirectoryReady: true,
        isIncomingSyncActive: state.isIncomingSyncActive,
        listenPort: state.listenPort,
        discoveredDevices: state.discoveredDevices,
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
        remoteSnapshot:
            remoteDirectoryUnavailable ? null : state.remoteSnapshot,
        isRemoteDirectoryReady:
            remoteDirectoryUnavailable ? false : state.isRemoteDirectoryReady,
        isIncomingSyncActive: state.isIncomingSyncActive,
        listenPort: state.listenPort,
        discoveredDevices: state.discoveredDevices,
        recentAddresses: state.recentAddresses,
        recentLabels: state.recentLabels,
        errorMessage: ConnectionState.localizeErrorMessage(message),
      );
      return null;
    }
  }

  Future<ScanSnapshot> _requestRemoteSnapshot() async {
    final PeerSession? incomingSession = _activeIncomingSession;
    if (incomingSession != null && incomingSession.isConnected) {
      final ProtocolMessage response = await incomingSession.sendRequest(
        type: 'scanRequest',
        requestId: '${DateTime.now().microsecondsSinceEpoch}',
        payload: const <String, Object?>{},
      );
      if (response.type == 'error') {
        throw SocketException(
          response.payload['message'] as String? ?? 'Peer error',
        );
      }
      if (response.type != 'scanResponse') {
        throw const SocketException('Peer scan response invalid.');
      }
      final Object? rawSnapshot = response.payload['snapshot'];
      if (rawSnapshot is! Map<Object?, Object?>) {
        throw const SocketException('Peer snapshot payload invalid.');
      }
      return ScanSnapshot.fromJson(
        rawSnapshot.map(
          (Object? key, Object? value) => MapEntry(key.toString(), value),
        ),
      );
    }
    return _service.requestRemoteScan();
  }

  Future<void> disconnect() async {
    _connectAttemptId++;
    await _service.disconnect();
    _clearPlanAndExecution();
    state = ConnectionState(
      status: ConnectionStatus.idle,
      isListening: state.isListening,
      listenPort: state.listenPort,
      discoveredDevices: state.discoveredDevices,
      recentAddresses: state.recentAddresses,
      recentLabels: state.recentLabels,
      peer: null,
      remoteSnapshot: null,
      isRemoteDirectoryReady: false,
      isIncomingSyncActive: false,
    );
  }

  Future<FileAccessEntry?> requestRemoteEntryStat(String entryId) async {
    if (entryId.isEmpty || state.peer == null) {
      return null;
    }
    try {
      return await _service.requestRemoteEntryStat(entryId: entryId);
    } catch (_) {
      return null;
    }
  }

  Future<DiffEntryDetailViewData?> requestRemoteEntryDetail(
      String entryId) async {
    if (entryId.isEmpty || state.peer == null) {
      return null;
    }
    try {
      return await _service.requestRemoteEntryDetail(entryId: entryId);
    } catch (_) {
      return null;
    }
  }

  void _clearPlanAndExecution() {
    _ref.read(previewControllerProvider.notifier).clear();
    _ref.read(executionControllerProvider.notifier).clearTransient();
  }

  void _handleRemoteDirectoryUnavailable() {
    final ExecutionState executionState =
        _ref.read(executionControllerProvider);
    _ref.read(previewControllerProvider.notifier).clear();
    if (executionState.status == ExecutionStatus.running &&
        executionState.mode == ExecutionMode.remote) {
      _ref.read(executionControllerProvider.notifier).failRemoteExecution(
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

  Future<void> saveRecentAddress(String value) async {
    await _store.saveRecentAddress(value);
    state = ConnectionState(
      status: state.status,
      isListening: state.isListening,
      peer: state.peer,
      remoteSnapshot: state.remoteSnapshot,
      isRemoteDirectoryReady: state.isRemoteDirectoryReady,
      isIncomingSyncActive: state.isIncomingSyncActive,
      discoveredDevices: state.discoveredDevices,
      recentAddresses: await _store.loadRecentAddresses(),
      recentLabels: await _store.loadRecentAddressLabels(),
      listenPort: state.listenPort,
      errorMessage: state.errorMessage,
    );
  }

  Future<void> _handleIncomingSession(PeerSession session) async {
    _activeIncomingSession = session;
    session.closed.then((_) {
      if (identical(_activeIncomingSession, session)) {
        _activeIncomingSession = null;
      }
      unawaited(_cleanupIncomingTransfers());
    });
    session.onMessage = (ProtocolMessage message) async {
      switch (message.type) {
        case 'hello':
          final DirectoryHandle? handle =
              _ref.read(directoryControllerProvider).handle;
          final Object? rawDevice = message.payload['device'];
          final bool isRemoteDirectoryReady =
              message.payload['directoryReady'] as bool? ?? false;
          if (rawDevice is Map<Object?, Object?>) {
            state = ConnectionState(
              status: ConnectionStatus.connected,
              isListening: state.isListening,
              peer: DeviceInfo(
                deviceId: rawDevice['deviceId'] as String? ?? 'peer',
                deviceName: _sanitizePeerName(
                  rawDevice['deviceName'] as String?,
                  fallbackPlatform: rawDevice['platform'] as String?,
                  fallbackAddress: rawDevice['address'] as String?,
                ),
                platform: rawDevice['platform'] as String? ?? 'network',
                address: rawDevice['address'] as String? ?? '',
                port: rawDevice['port'] as int? ?? AppConstants.defaultPort,
              ),
              remoteSnapshot:
                  isRemoteDirectoryReady ? state.remoteSnapshot : null,
              isRemoteDirectoryReady: isRemoteDirectoryReady,
              isIncomingSyncActive: false,
              listenPort: state.listenPort,
              discoveredDevices: state.discoveredDevices,
              recentAddresses: state.recentAddresses,
              recentLabels: state.recentLabels,
            );
            if (!isRemoteDirectoryReady) {
              _handleRemoteDirectoryUnavailable();
            }
          }
          return ProtocolMessage(
            type: 'helloAck',
            requestId: message.requestId,
            payload: <String, Object?>{
              'device': _buildLocalDevice(
                port: state.listenPort ?? AppConstants.defaultPort,
              ).toJson(),
              'directoryReady': handle != null,
              'directoryDisplayName': handle?.displayName,
            },
          );
        case 'scanRequest':
          final DirectoryHandle? handle =
              _ref.read(directoryControllerProvider).handle;
          if (handle == null) {
            return ProtocolMessage(
              type: 'error',
              requestId: message.requestId,
              payload: const <String, Object?>{
                'message': 'No shared directory selected on peer.',
              },
            );
          }
          final ScanSnapshot snapshot = await _ref
              .read(directoryScannerProvider)
              .scan(
                  root: handle,
                  deviceId: _buildLocalDevice(
                          port: state.listenPort ?? AppConstants.defaultPort)
                      .deviceId);
          return ProtocolMessage(
            type: 'scanResponse',
            requestId: message.requestId,
            payload: <String, Object?>{
              'snapshot': snapshot.toJson(),
            },
          );
        case 'beginCopy':
          return _handleBeginCopy(message);
        case 'writeChunk':
          return _handleWriteChunk(message);
        case 'finishCopy':
          return _handleFinishCopy(message);
        case 'abortCopy':
          return _handleAbortCopy(message);
        case 'deleteEntry':
          return _handleDeleteEntry(message);
        case 'statEntry':
          return _handleStatEntry(message);
        case 'syncSessionStart':
          _setIncomingSyncActive(true);
          return ProtocolMessage(
            type: 'ok',
            requestId: message.requestId,
            payload: const <String, Object?>{},
          );
        case 'syncSessionEnd':
          _setIncomingSyncActive(false);
          return ProtocolMessage(
            type: 'ok',
            requestId: message.requestId,
            payload: const <String, Object?>{},
          );
        case 'remoteDirectoryChanged':
          _handleRemoteDirectoryChangedMessage(message);
          return null;
        default:
          return ProtocolMessage(
            type: 'error',
            requestId: message.requestId,
            payload: <String, Object?>{
              'message': 'Unsupported message type: ${message.type}',
            },
          );
      }
    };
  }

  DeviceInfo _buildLocalDevice({required int port}) {
    final String hostName = Platform.localHostname;
    final String fallbackName = Platform.environment['COMPUTERNAME'] ??
        Platform.environment['HOSTNAME'] ??
        (Platform.isAndroid
            ? 'Android'
            : Platform.isWindows
                ? 'Windows'
                : Platform.operatingSystem);
    final String deviceName =
        hostName.toLowerCase() == 'localhost' ? fallbackName : hostName;
    return DeviceInfo(
      deviceId: '$deviceName:$port',
      deviceName: deviceName,
      platform: Platform.operatingSystem,
      address: '',
      port: port,
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
    final Map<String, String> recentLabels =
        await _store.loadRecentAddressLabels();
    if (!mounted) {
      return;
    }
    state = ConnectionState(
      status: state.status,
      isListening: state.isListening,
      peer: state.peer,
      remoteSnapshot: state.remoteSnapshot,
      isRemoteDirectoryReady: state.isRemoteDirectoryReady,
      isIncomingSyncActive: state.isIncomingSyncActive,
      discoveredDevices: state.discoveredDevices,
      recentAddresses: recentAddresses,
      recentLabels: recentLabels,
      listenPort: state.listenPort,
      errorMessage: state.errorMessage,
    );
  }

  Future<void> reloadRecent() => _loadRecent();

  void _handleDiscoveryEvent(DiscoveryEvent event) {
    switch (event.type) {
      case DiscoveryEventType.announce:
        _handleDiscoveredDevice(event.device);
      case DiscoveryEventType.goodbye:
        _handleRemovedDevice(event.device);
    }
  }

  void _handleDiscoveredDevice(DeviceInfo device) {
    final DeviceInfo local = _buildLocalDevice(
      port: state.listenPort ?? AppConstants.defaultPort,
    );
    if (device.deviceId == local.deviceId) {
      return;
    }
    _discoveredAt[device.deviceId] = DateTime.now();
    final List<DeviceInfo> next = <DeviceInfo>[
      device,
      ...state.discoveredDevices.where(
        (DeviceInfo item) => item.deviceId != device.deviceId,
      ),
    ];
    state = ConnectionState(
      status: state.status,
      isListening: state.isListening,
      peer: state.peer,
      remoteSnapshot: state.remoteSnapshot,
      isRemoteDirectoryReady: state.isRemoteDirectoryReady,
      isIncomingSyncActive: state.isIncomingSyncActive,
      discoveredDevices: next.take(12).toList(),
      recentAddresses: state.recentAddresses,
      recentLabels: state.recentLabels,
      listenPort: state.listenPort,
      errorMessage: state.errorMessage,
    );
  }

  void _handleRemovedDevice(DeviceInfo device) {
    if (_isConnectedPeer(device)) {
      return;
    }
    _discoveredAt.remove(device.deviceId);
    final List<DeviceInfo> next = state.discoveredDevices
        .where((DeviceInfo item) => item.deviceId != device.deviceId)
        .toList();
    if (next.length == state.discoveredDevices.length) {
      return;
    }
    state = ConnectionState(
      status: state.status,
      isListening: state.isListening,
      peer: state.peer,
      remoteSnapshot: state.remoteSnapshot,
      isRemoteDirectoryReady: state.isRemoteDirectoryReady,
      isIncomingSyncActive: state.isIncomingSyncActive,
      discoveredDevices: next,
      recentAddresses: state.recentAddresses,
      recentLabels: state.recentLabels,
      listenPort: state.listenPort,
      errorMessage: state.errorMessage,
    );
  }

  void _pruneDiscoveredDevices() {
    final DateTime cutoff = DateTime.now().subtract(const Duration(seconds: 8));
    _discoveredAt
        .removeWhere((String _, DateTime seenAt) => seenAt.isBefore(cutoff));
    final List<DeviceInfo> next =
        state.discoveredDevices.where((DeviceInfo device) {
      if (_isConnectedPeer(device)) {
        return true;
      }
      final DateTime? seenAt = _discoveredAt[device.deviceId];
      return seenAt != null && !seenAt.isBefore(cutoff);
    }).toList();
    if (next.length == state.discoveredDevices.length) {
      return;
    }
    state = ConnectionState(
      status: state.status,
      isListening: state.isListening,
      peer: state.peer,
      remoteSnapshot: state.remoteSnapshot,
      isRemoteDirectoryReady: state.isRemoteDirectoryReady,
      isIncomingSyncActive: state.isIncomingSyncActive,
      discoveredDevices: next,
      recentAddresses: state.recentAddresses,
      recentLabels: state.recentLabels,
      listenPort: state.listenPort,
      errorMessage: state.errorMessage,
    );
  }

  bool _isConnectedPeer(DeviceInfo device) {
    return state.status == ConnectionStatus.connected &&
        state.peer?.deviceId == device.deviceId;
  }

  void _ensureConnectedPeerVisible() {
    final DeviceInfo? peer = state.peer;
    if (peer == null || state.status != ConnectionStatus.connected) {
      return;
    }
    final bool alreadyVisible = state.discoveredDevices.any(
      (DeviceInfo device) => device.deviceId == peer.deviceId,
    );
    if (alreadyVisible) {
      return;
    }
    state = ConnectionState(
      status: state.status,
      isListening: state.isListening,
      peer: state.peer,
      remoteSnapshot: state.remoteSnapshot,
      isRemoteDirectoryReady: state.isRemoteDirectoryReady,
      isIncomingSyncActive: state.isIncomingSyncActive,
      discoveredDevices: <DeviceInfo>[
        peer,
        ...state.discoveredDevices,
      ].take(12).toList(),
      recentAddresses: state.recentAddresses,
      recentLabels: state.recentLabels,
      listenPort: state.listenPort,
      errorMessage: state.errorMessage,
    );
  }

  Future<ProtocolMessage> _handleBeginCopy(ProtocolMessage message) async {
    try {
      _setIncomingSyncActive(true);
      final String remoteRootId =
          message.payload['remoteRootId'] as String? ?? '';
      final String relativePath =
          message.payload['relativePath'] as String? ?? '';
      final String transferId = message.payload['transferId'] as String? ?? '';
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
      final FileWriteSession session =
          await gateway.openWrite(parentId, tempFileName);
      _incomingWriteSessions[transferId] = session;
      final String? tempEntryId = await _resolveRemoteEntryId(
        gateway: gateway,
        rootId: remoteRootId,
        relativePath: _replaceFileName(relativePath, tempFileName),
      );
      if (tempEntryId == null) {
        await session.close();
        throw const FileSystemException(
            'Temporary target file could not be resolved.');
      }
      _incomingWriteTargets[transferId] = _IncomingWriteTarget(
        tempEntryId: tempEntryId,
        finalName: fileName,
      );
      return ProtocolMessage(
        type: 'ok',
        requestId: message.requestId,
        payload: const <String, Object?>{},
      );
    } catch (error) {
      return ProtocolMessage(
        type: 'error',
        requestId: message.requestId,
        payload: <String, Object?>{
          'message': error.toString(),
        },
      );
    }
  }

  Future<ProtocolMessage> _handleWriteChunk(ProtocolMessage message) async {
    try {
      final String transferId = message.payload['transferId'] as String? ?? '';
      final String data = message.payload['data'] as String? ?? '';
      final FileWriteSession session = _incomingWriteSessions[transferId] ??
          (throw const FormatException('Transfer session not found.'));
      await session.write(base64Decode(data));
      return ProtocolMessage(
        type: 'ok',
        requestId: message.requestId,
        payload: const <String, Object?>{},
      );
    } catch (error) {
      return ProtocolMessage(
        type: 'error',
        requestId: message.requestId,
        payload: <String, Object?>{
          'message': error.toString(),
        },
      );
    }
  }

  Future<ProtocolMessage> _handleFinishCopy(ProtocolMessage message) async {
    try {
      final String transferId = message.payload['transferId'] as String? ?? '';
      final FileWriteSession session =
          _incomingWriteSessions.remove(transferId) ??
              (throw const FormatException('Transfer session not found.'));
      final _IncomingWriteTarget? target =
          _incomingWriteTargets.remove(transferId);
      await session.close();
      if (target != null) {
        final FileAccessGateway gateway = _ref.read(fileAccessGatewayProvider);
        await gateway.renameEntry(target.tempEntryId, target.finalName);
      }
      return ProtocolMessage(
        type: 'ok',
        requestId: message.requestId,
        payload: const <String, Object?>{},
      );
    } catch (error) {
      return ProtocolMessage(
        type: 'error',
        requestId: message.requestId,
        payload: <String, Object?>{
          'message': error.toString(),
        },
      );
    }
  }

  Future<ProtocolMessage> _handleAbortCopy(ProtocolMessage message) async {
    try {
      final String transferId = message.payload['transferId'] as String? ?? '';
      final FileWriteSession session =
          _incomingWriteSessions.remove(transferId) ??
              (throw const FormatException('Transfer session not found.'));
      final _IncomingWriteTarget? target =
          _incomingWriteTargets.remove(transferId);
      await session.close();
      if (target != null) {
        final FileAccessGateway gateway = _ref.read(fileAccessGatewayProvider);
        await gateway.deleteEntry(target.tempEntryId);
      }
      return ProtocolMessage(
        type: 'ok',
        requestId: message.requestId,
        payload: const <String, Object?>{},
      );
    } catch (error) {
      return ProtocolMessage(
        type: 'error',
        requestId: message.requestId,
        payload: <String, Object?>{
          'message': error.toString(),
        },
      );
    }
  }

  Future<ProtocolMessage> _handleDeleteEntry(ProtocolMessage message) async {
    try {
      final String remoteRootId =
          message.payload['remoteRootId'] as String? ?? '';
      final String relativePath =
          message.payload['relativePath'] as String? ?? '';
      final FileAccessGateway gateway = _ref.read(fileAccessGatewayProvider);
      final String? entryId = await _resolveRemoteEntryId(
        gateway: gateway,
        rootId: remoteRootId,
        relativePath: relativePath,
      );
      if (entryId != null) {
        await gateway.deleteEntry(entryId);
      }
      return ProtocolMessage(
        type: 'ok',
        requestId: message.requestId,
        payload: const <String, Object?>{},
      );
    } catch (error) {
      return ProtocolMessage(
        type: 'error',
        requestId: message.requestId,
        payload: <String, Object?>{
          'message': error.toString(),
        },
      );
    }
  }

  Future<ProtocolMessage> _handleStatEntry(ProtocolMessage message) async {
    try {
      final String entryId = message.payload['entryId'] as String? ?? '';
      if (entryId.isEmpty) {
        throw const FormatException('Stat entry payload invalid.');
      }
      final FileAccessGateway gateway = _ref.read(fileAccessGatewayProvider);
      final FileAccessEntry entry = await gateway.stat(entryId);
      final AudioMetadataViewData? metadata = entry.isDirectory
          ? null
          : await AudioMetadataReader(gateway).read(entryId);
      return ProtocolMessage(
        type: 'statEntryResponse',
        requestId: message.requestId,
        payload: <String, Object?>{
          'entry': <String, Object?>{
            'entryId': entry.entryId,
            'name': entry.name,
            'isDirectory': entry.isDirectory,
            'size': entry.size,
            'modifiedTime': entry.modifiedTime.millisecondsSinceEpoch,
          },
          if (metadata != null)
            'audioMetadata': <String, Object?>{
              if (metadata.title case final String title) 'title': title,
              if (metadata.artist case final String artist) 'artist': artist,
              if (metadata.album case final String album) 'album': album,
              if (metadata.composer case final String composer)
                'composer': composer,
              if (metadata.trackNumber case final String trackNumber)
                'trackNumber': trackNumber,
              if (metadata.discNumber case final String discNumber)
                'discNumber': discNumber,
              if (metadata.lyrics case final String lyrics) 'lyrics': lyrics,
            },
        },
      );
    } catch (error) {
      return ProtocolMessage(
        type: 'error',
        requestId: message.requestId,
        payload: <String, Object?>{
          'message': error.toString(),
        },
      );
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
      final List<FileAccessEntry> children =
          await gateway.listChildren(currentId);
      final FileAccessEntry? existing =
          children.cast<FileAccessEntry?>().firstWhere(
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
      final List<FileAccessEntry> children =
          await gateway.listChildren(currentId);
      final FileAccessEntry? match =
          children.cast<FileAccessEntry?>().firstWhere(
                (FileAccessEntry? child) =>
                    child != null && child.name == segment,
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
    if (state.peer == null) {
      return;
    }
    try {
      final PeerSession? incomingSession = _activeIncomingSession;
      if (incomingSession != null && incomingSession.isConnected) {
        await incomingSession.sendMessage(
          type: 'remoteDirectoryChanged',
          requestId: '${DateTime.now().microsecondsSinceEpoch}',
          payload: <String, Object?>{
            'isReady': handle != null,
            if (handle != null) 'displayName': handle.displayName,
          },
        );
      } else {
        await _service.notifyRemoteDirectoryChanged(
          isReady: handle != null,
          displayName: handle?.displayName,
        );
      }
    } catch (_) {
      // Best effort only.
    }
  }

  Future<void> _handleServiceMessage(ProtocolMessage message) async {
    if (message.type == 'syncSessionStart') {
      _setIncomingSyncActive(true);
      return;
    }
    if (message.type == 'syncSessionEnd') {
      _setIncomingSyncActive(false);
      return;
    }
    if (message.type != 'remoteDirectoryChanged') {
      return;
    }
    _handleRemoteDirectoryChangedMessage(message);
  }

  void _handleRemoteDirectoryChangedMessage(ProtocolMessage message) {
    final DeviceInfo? peer = state.peer;
    if (peer == null) {
      return;
    }
    final bool isReady = message.payload['isReady'] as bool? ?? false;
    if (!isReady) {
      _handleRemoteDirectoryUnavailable();
      state = ConnectionState(
        status: ConnectionStatus.connected,
        isListening: state.isListening,
        peer: peer,
        remoteSnapshot: null,
        isRemoteDirectoryReady: false,
        isIncomingSyncActive: state.isIncomingSyncActive,
        listenPort: state.listenPort,
        discoveredDevices: state.discoveredDevices,
        recentAddresses: state.recentAddresses,
        recentLabels: state.recentLabels,
      );
      return;
    }
    state = ConnectionState(
      status: ConnectionStatus.connected,
      isListening: state.isListening,
      peer: peer,
      remoteSnapshot: state.remoteSnapshot,
      isRemoteDirectoryReady: true,
      isIncomingSyncActive: state.isIncomingSyncActive,
      listenPort: state.listenPort,
      discoveredDevices: state.discoveredDevices,
      recentAddresses: state.recentAddresses,
      recentLabels: state.recentLabels,
    );
    unawaited(_refreshRemoteSnapshotAfterRemoteDirectoryReady(peer));
  }

  Future<void> _refreshRemoteSnapshotAfterRemoteDirectoryReady(
    DeviceInfo expectedPeer,
  ) async {
    final DeviceInfo? currentPeer = state.peer;
    if (currentPeer == null ||
        currentPeer.deviceId != expectedPeer.deviceId ||
        state.status != ConnectionStatus.connected) {
      return;
    }
    await refreshRemoteSnapshot(clearTransientState: false);
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
      discoveredDevices: state.discoveredDevices,
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

final StateNotifierProvider<ConnectionController, ConnectionState>
    connectionControllerProvider =
    StateNotifierProvider<ConnectionController, ConnectionState>(
  (Ref ref) => ConnectionController(
    ref,
    ref.watch(connectionServiceProvider),
    ref.watch(listenerServiceProvider),
    ref.watch(recentItemsStoreProvider),
    ref.watch(discoveryServiceProvider),
  ),
);
