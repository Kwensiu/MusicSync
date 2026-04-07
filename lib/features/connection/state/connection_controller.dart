import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_sync/core/constants/app_constants.dart';
import 'package:music_sync/features/directory/state/directory_controller.dart';
import 'package:music_sync/features/connection/state/connection_state.dart';
import 'package:music_sync/features/execution/state/execution_controller.dart';
import 'package:music_sync/models/device_info.dart';
import 'package:music_sync/models/scan_snapshot.dart';
import 'package:music_sync/services/file_access/file_access_entry.dart';
import 'package:music_sync/services/file_access/file_access_provider.dart';
import 'package:music_sync/services/network/connection_service.dart';
import 'package:music_sync/services/network/discovery_service.dart';
import 'package:music_sync/services/network/listener_service.dart';
import 'package:music_sync/services/network/peer_session.dart';
import 'package:music_sync/services/network/protocol/protocol_message.dart';
import 'package:music_sync/features/preview/state/preview_controller.dart';
import 'package:music_sync/services/file_access/file_access_gateway.dart';
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
  )
      : super(ConnectionState.initial()) {
    _service.onDisconnected = _handleDisconnected;
    _loadRecent();
    _discoveryCleanupTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _pruneDiscoveredDevices(),
    );
    unawaited(
      _discovery.startReceiving(
        onDevice: _handleDiscoveredDevice,
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

  Future<void> startListening({int port = AppConstants.defaultPort}) async {
    try {
      await _listener.start(
        port: port,
        onClient: _handleIncomingSession,
      );
      await _discovery.startBroadcasting(_buildLocalDevice(port: port));
      state = ConnectionState(
        status: ConnectionStatus.listening,
        listenPort: port,
        peer: state.peer,
        remoteSnapshot: state.remoteSnapshot,
        discoveredDevices: state.discoveredDevices,
        recentAddresses: state.recentAddresses,
      );
    } catch (error) {
      state = ConnectionState(
        status: ConnectionStatus.failed,
        listenPort: state.listenPort,
        peer: state.peer,
        remoteSnapshot: state.remoteSnapshot,
        discoveredDevices: state.discoveredDevices,
        recentAddresses: state.recentAddresses,
        errorMessage: ConnectionState.localizeErrorMessage(error.toString()),
      );
    }
  }

  Future<void> stopListening() async {
    await _listener.stop();
    await _discovery.stopBroadcasting();
    state = ConnectionState(
      status: state.peer == null ? ConnectionStatus.idle : ConnectionStatus.connected,
      peer: state.peer,
      remoteSnapshot: state.remoteSnapshot,
      discoveredDevices: state.discoveredDevices,
      recentAddresses: state.recentAddresses,
    );
  }

  Future<void> connect({
    required String address,
    required int port,
  }) async {
    _clearPlanAndExecution();
    state = ConnectionState(
      status: ConnectionStatus.connecting,
      listenPort: state.listenPort,
      discoveredDevices: state.discoveredDevices,
      recentAddresses: state.recentAddresses,
    );

    try {
      final peer = await _service.connect(
        address: address,
        port: port,
        localDevice: _buildLocalDevice(port: state.listenPort ?? AppConstants.defaultPort),
      );
      final ScanSnapshot remoteSnapshot = await _service.requestRemoteScan();
      await _store.saveRecentAddress('$address:$port');
      state = ConnectionState(
        status: ConnectionStatus.connected,
        peer: peer,
        remoteSnapshot: remoteSnapshot,
        listenPort: state.listenPort,
        discoveredDevices: state.discoveredDevices,
        recentAddresses: await _store.loadRecentAddresses(),
      );
    } catch (error) {
      state = ConnectionState(
        status: ConnectionStatus.failed,
        listenPort: state.listenPort,
        discoveredDevices: state.discoveredDevices,
        recentAddresses: state.recentAddresses,
        errorMessage: ConnectionState.localizeErrorMessage(error.toString()),
      );
    }
  }

  void _handleDisconnected(Object? error) {
    unawaited(_cleanupIncomingTransfers());
    _clearPlanAndExecution();
    state = ConnectionState(
      status: ConnectionStatus.disconnected,
      listenPort: state.listenPort,
      discoveredDevices: state.discoveredDevices,
      recentAddresses: state.recentAddresses,
      peer: null,
      remoteSnapshot: null,
      errorMessage:
          'Remote device disconnected. Keep the target device in foreground and reconnect.',
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
      final ScanSnapshot remoteSnapshot = await _service.requestRemoteScan();
      state = ConnectionState(
        status: ConnectionStatus.connected,
        peer: peer,
        remoteSnapshot: remoteSnapshot,
        listenPort: state.listenPort,
        discoveredDevices: state.discoveredDevices,
        recentAddresses: state.recentAddresses,
      );
      return remoteSnapshot;
    } catch (error) {
      state = ConnectionState(
        status: ConnectionStatus.failed,
        peer: peer,
        remoteSnapshot: state.remoteSnapshot,
        listenPort: state.listenPort,
        discoveredDevices: state.discoveredDevices,
        recentAddresses: state.recentAddresses,
        errorMessage: ConnectionState.localizeErrorMessage(error.toString()),
      );
      return null;
    }
  }

  Future<void> disconnect() async {
    await _service.disconnect();
    _clearPlanAndExecution();
    state = ConnectionState(
      status: state.listenPort == null ? ConnectionStatus.idle : ConnectionStatus.listening,
      listenPort: state.listenPort,
      discoveredDevices: state.discoveredDevices,
      recentAddresses: state.recentAddresses,
      peer: null,
      remoteSnapshot: null,
    );
  }

  void _clearPlanAndExecution() {
    _ref.read(previewControllerProvider.notifier).clear();
    _ref.read(executionControllerProvider.notifier).clearTransient();
  }

  Future<void> saveRecentAddress(String value) async {
    await _store.saveRecentAddress(value);
    state = ConnectionState(
      status: state.status,
      peer: state.peer,
      remoteSnapshot: state.remoteSnapshot,
      discoveredDevices: state.discoveredDevices,
      recentAddresses: await _store.loadRecentAddresses(),
      listenPort: state.listenPort,
      errorMessage: state.errorMessage,
    );
  }

  Future<void> _handleIncomingSession(PeerSession session) async {
    session.closed.then((_) {
      unawaited(_cleanupIncomingTransfers());
    });
    session.onMessage = (ProtocolMessage message) async {
      switch (message.type) {
        case 'hello':
          return ProtocolMessage(
            type: 'helloAck',
            requestId: message.requestId,
            payload: <String, Object?>{
              'device': _buildLocalDevice(
                port: state.listenPort ?? AppConstants.defaultPort,
              ).toJson(),
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
              .scan(root: handle, deviceId: _buildLocalDevice(port: state.listenPort ?? AppConstants.defaultPort).deviceId);
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
        hostName;
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

  Future<void> _loadRecent() async {
    state = ConnectionState(
      status: state.status,
      peer: state.peer,
      remoteSnapshot: state.remoteSnapshot,
      discoveredDevices: state.discoveredDevices,
      recentAddresses: await _store.loadRecentAddresses(),
      listenPort: state.listenPort,
      errorMessage: state.errorMessage,
    );
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
      peer: state.peer,
      remoteSnapshot: state.remoteSnapshot,
      discoveredDevices: next.take(12).toList(),
      recentAddresses: state.recentAddresses,
      listenPort: state.listenPort,
      errorMessage: state.errorMessage,
    );
  }

  void _pruneDiscoveredDevices() {
    final DateTime cutoff = DateTime.now().subtract(const Duration(seconds: 8));
    _discoveredAt.removeWhere((String _, DateTime seenAt) => seenAt.isBefore(cutoff));
    final List<DeviceInfo> next = state.discoveredDevices.where((DeviceInfo device) {
      final DateTime? seenAt = _discoveredAt[device.deviceId];
      return seenAt != null && !seenAt.isBefore(cutoff);
    }).toList();
    if (next.length == state.discoveredDevices.length) {
      return;
    }
    state = ConnectionState(
      status: state.status,
      peer: state.peer,
      remoteSnapshot: state.remoteSnapshot,
      discoveredDevices: next,
      recentAddresses: state.recentAddresses,
      listenPort: state.listenPort,
      errorMessage: state.errorMessage,
    );
  }

  Future<ProtocolMessage> _handleBeginCopy(ProtocolMessage message) async {
    try {
      final String remoteRootId = message.payload['remoteRootId'] as String? ?? '';
      final String relativePath = message.payload['relativePath'] as String? ?? '';
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
      final FileWriteSession session = await gateway.openWrite(parentId, tempFileName);
      _incomingWriteSessions[transferId] = session;
      final String? tempEntryId = await _resolveRemoteEntryId(
        gateway: gateway,
        rootId: remoteRootId,
        relativePath: _replaceFileName(relativePath, tempFileName),
      );
      if (tempEntryId == null) {
        await session.close();
        throw const FileSystemException('Temporary target file could not be resolved.');
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
      final FileWriteSession session = _incomingWriteSessions.remove(transferId) ??
          (throw const FormatException('Transfer session not found.'));
      final _IncomingWriteTarget? target = _incomingWriteTargets.remove(transferId);
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
      final FileWriteSession session = _incomingWriteSessions.remove(transferId) ??
          (throw const FormatException('Transfer session not found.'));
      final _IncomingWriteTarget? target = _incomingWriteTargets.remove(transferId);
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
      final String remoteRootId = message.payload['remoteRootId'] as String? ?? '';
      final String relativePath = message.payload['relativePath'] as String? ?? '';
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
      final List<FileAccessEntry> children = await gateway.listChildren(currentId);
      final FileAccessEntry? existing = children.cast<FileAccessEntry?>().firstWhere(
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
      final List<FileAccessEntry> children = await gateway.listChildren(currentId);
      final FileAccessEntry? match = children.cast<FileAccessEntry?>().firstWhere(
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
