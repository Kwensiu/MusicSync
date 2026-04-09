import 'dart:io';
import 'dart:math';
import 'dart:convert';

import 'package:music_sync/models/device_info.dart';
import 'package:music_sync/models/scan_snapshot.dart';
import 'package:music_sync/features/preview/models/diff_item_detail_view_data.dart';
import 'package:music_sync/services/file_access/file_access_entry.dart';
import 'package:music_sync/services/network/peer_session.dart';
import 'package:music_sync/services/network/protocol/protocol_message.dart';

class ConnectionService {
  PeerSession? _session;
  final Random _random = Random();
  void Function(Object? error)? onDisconnected;
  Future<void> Function(ProtocolMessage message)? onMessage;

  PeerSession? get session => _session;

  Future<DeviceInfo> connect({
    required String address,
    required int port,
    required DeviceInfo localDevice,
  }) async {
    await disconnect();
    final Socket socket = await Socket.connect(address, port);
    final PeerSession session = PeerSession(socket);
    final String requestId = _nextRequestId();
    final ProtocolMessage response = await session.sendRequest(
      type: 'hello',
      requestId: requestId,
      payload: <String, Object?>{
        'device': localDevice.toJson(),
      },
    );
    if (response.type != 'helloAck') {
      await session.close();
      throw const SocketException('Peer handshake failed.');
    }
    final Object? rawDevice = response.payload['device'];
    if (rawDevice is! Map<Object?, Object?>) {
      await session.close();
      throw const SocketException('Peer handshake payload invalid.');
    }
    _session = session;
    session.onMessage = _handleIncomingMessage;
    session.closed.then((_) {
      if (identical(_session, session)) {
        _session = null;
        onDisconnected?.call(null);
      }
    });

    return DeviceInfo(
      deviceId: rawDevice['deviceId'] as String? ?? '$address:$port',
      deviceName: _sanitizePeerName(
        rawDevice['deviceName'] as String?,
        fallbackPlatform: rawDevice['platform'] as String?,
        fallbackAddress: address,
      ),
      platform: rawDevice['platform'] as String? ?? 'network',
      address: address,
      port: port,
    );
  }

  Future<void> notifyRemoteDirectoryChanged({
    required bool isReady,
    String? displayName,
  }) async {
    final PeerSession session = _requireSession();
    await session.sendMessage(
      type: 'remoteDirectoryChanged',
      requestId: _nextRequestId(),
      payload: <String, Object?>{
        'isReady': isReady,
        if (displayName != null) 'displayName': displayName,
      },
    );
  }

  Future<void> notifySyncSessionState({
    required bool active,
  }) async {
    final PeerSession session = _requireSession();
    await session.sendMessage(
      type: active ? 'syncSessionStart' : 'syncSessionEnd',
      requestId: _nextRequestId(),
      payload: const <String, Object?>{},
    );
  }

  Future<ScanSnapshot> requestRemoteScan() async {
    final PeerSession? session = _session;
    if (session == null) {
      throw const SocketException('Not connected to any peer.');
    }
    final ProtocolMessage response = await session.sendRequest(
      type: 'scanRequest',
      requestId: _nextRequestId(),
      payload: const <String, Object?>{},
    );
    if (response.type == 'error') {
      throw SocketException(
          response.payload['message'] as String? ?? 'Peer error');
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

  Future<void> disconnect() async {
    final PeerSession? session = _session;
    _session = null;
    await session?.close();
  }

  Future<void> beginRemoteCopy({
    required String remoteRootId,
    required String relativePath,
    required String transferId,
  }) async {
    final PeerSession session = _requireSession();
    final ProtocolMessage response = await session.sendRequest(
      type: 'beginCopy',
      requestId: _nextRequestId(),
      payload: <String, Object?>{
        'remoteRootId': remoteRootId,
        'relativePath': relativePath,
        'transferId': transferId,
      },
    );
    _ensureOk(response, 'Remote begin copy failed.');
  }

  Future<void> writeRemoteChunk({
    required String transferId,
    required List<int> chunk,
  }) async {
    final PeerSession session = _requireSession();
    final ProtocolMessage response = await session.sendRequest(
      type: 'writeChunk',
      requestId: _nextRequestId(),
      payload: <String, Object?>{
        'transferId': transferId,
        'data': base64Encode(chunk),
      },
    );
    _ensureOk(response, 'Remote chunk write failed.');
  }

  Future<void> finishRemoteCopy({
    required String transferId,
  }) async {
    final PeerSession session = _requireSession();
    final ProtocolMessage response = await session.sendRequest(
      type: 'finishCopy',
      requestId: _nextRequestId(),
      payload: <String, Object?>{
        'transferId': transferId,
      },
    );
    _ensureOk(response, 'Remote copy finish failed.');
  }

  Future<void> abortRemoteCopy({
    required String transferId,
  }) async {
    final PeerSession session = _requireSession();
    final ProtocolMessage response = await session.sendRequest(
      type: 'abortCopy',
      requestId: _nextRequestId(),
      payload: <String, Object?>{
        'transferId': transferId,
      },
    );
    _ensureOk(response, 'Remote copy abort failed.');
  }

  Future<void> deleteRemoteEntry({
    required String remoteRootId,
    required String relativePath,
  }) async {
    final PeerSession session = _requireSession();
    final ProtocolMessage response = await session.sendRequest(
      type: 'deleteEntry',
      requestId: _nextRequestId(),
      payload: <String, Object?>{
        'remoteRootId': remoteRootId,
        'relativePath': relativePath,
      },
    );
    _ensureOk(response, 'Remote delete failed.');
  }

  Future<FileAccessEntry> requestRemoteEntryStat({
    required String entryId,
  }) async {
    final DiffEntryDetailViewData detail = await requestRemoteEntryDetail(
      entryId: entryId,
    );
    return FileAccessEntry(
      entryId: detail.entryId,
      name: detail.displayName,
      isDirectory: detail.isDirectory,
      size: detail.size,
      modifiedTime: detail.modifiedTime,
    );
  }

  Future<DiffEntryDetailViewData> requestRemoteEntryDetail({
    required String entryId,
  }) async {
    final PeerSession session = _requireSession();
    final ProtocolMessage response = await session.sendRequest(
      type: 'statEntry',
      requestId: _nextRequestId(),
      payload: <String, Object?>{
        'entryId': entryId,
      },
    );
    if (response.type == 'error') {
      throw SocketException(
        response.payload['message'] as String? ?? 'Remote stat failed.',
      );
    }
    if (response.type != 'statEntryResponse') {
      throw const SocketException('Remote stat response invalid.');
    }
    final Object? rawEntry = response.payload['entry'];
    if (rawEntry is! Map<Object?, Object?>) {
      throw const SocketException('Remote stat payload invalid.');
    }
    final Map<String, Object?> entry = rawEntry.map(
      (Object? key, Object? value) => MapEntry(key.toString(), value),
    );
    final Map<String, Object?>? audioMetadata =
        switch (response.payload['audioMetadata']) {
      final Map<Object?, Object?> raw => raw.map(
          (Object? key, Object? value) => MapEntry(key.toString(), value),
        ),
      _ => null,
    };
    return DiffEntryDetailViewData(
      entryId: entry['entryId'] as String? ?? '',
      displayName: entry['name'] as String? ?? '',
      isDirectory: entry['isDirectory'] as bool? ?? false,
      size: (entry['size'] as num?)?.toInt() ?? 0,
      modifiedTime: DateTime.fromMillisecondsSinceEpoch(
        (entry['modifiedTime'] as num?)?.toInt() ?? 0,
      ),
      audioMetadata: _parseAudioMetadata(audioMetadata),
    );
  }

  AudioMetadataViewData? _parseAudioMetadata(Map<String, Object?>? payload) {
    if (payload == null) {
      return null;
    }
    final AudioMetadataViewData metadata = AudioMetadataViewData(
      title: payload['title'] as String?,
      artist: payload['artist'] as String?,
      album: payload['album'] as String?,
      composer: payload['composer'] as String?,
      trackNumber: payload['trackNumber'] as String?,
      discNumber: payload['discNumber'] as String?,
      lyrics: payload['lyrics'] as String?,
    );
    return metadata.hasAnyValue ? metadata : null;
  }

  PeerSession _requireSession() {
    final PeerSession? session = _session;
    if (session == null) {
      throw const SocketException('Not connected to any peer.');
    }
    return session;
  }

  void _ensureOk(ProtocolMessage response, String fallbackMessage) {
    if (response.type == 'ok') {
      return;
    }
    if (response.type == 'error') {
      throw SocketException(
        response.payload['message'] as String? ?? fallbackMessage,
      );
    }
    throw SocketException(fallbackMessage);
  }

  String _nextRequestId() {
    return '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 32)}';
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

  Future<ProtocolMessage?> _handleIncomingMessage(
      ProtocolMessage message) async {
    await onMessage?.call(message);
    return null;
  }
}
