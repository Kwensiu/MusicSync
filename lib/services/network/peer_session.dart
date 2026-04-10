import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:music_sync/services/network/protocol/protocol_codec.dart';
import 'package:music_sync/services/network/protocol/protocol_message.dart';

typedef MessageHandler =
    FutureOr<ProtocolMessage?> Function(ProtocolMessage message);

class PeerSession {
  PeerSession(this._socket, {ProtocolCodec codec = const ProtocolCodec()})
    : _codec = codec {
    _subscription = _socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_onLine, onDone: _handleClosed, onError: _handleError);
  }

  final Socket _socket;
  final ProtocolCodec _codec;
  final Map<String, Completer<ProtocolMessage>> _pending =
      <String, Completer<ProtocolMessage>>{};
  late final StreamSubscription<String> _subscription;

  MessageHandler? onMessage;

  bool get isConnected => !_closed.isCompleted;
  final Completer<void> _closed = Completer<void>();
  Future<void> get closed => _closed.future;

  Future<ProtocolMessage> sendRequest({
    required String type,
    required String requestId,
    required Map<String, Object?> payload,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final Completer<ProtocolMessage> completer = Completer<ProtocolMessage>();
    _pending[requestId] = completer;
    _socket.write(
      _codec.encode(
        ProtocolMessage(type: type, requestId: requestId, payload: payload),
      ),
    );
    return completer.future.timeout(
      timeout,
      onTimeout: () {
        _pending.remove(requestId);
        throw TimeoutException('Peer response timed out.', timeout);
      },
    );
  }

  Future<void> sendMessage({
    required String type,
    required String requestId,
    required Map<String, Object?> payload,
  }) async {
    _socket.write(
      _codec.encode(
        ProtocolMessage(type: type, requestId: requestId, payload: payload),
      ),
    );
    await _socket.flush();
  }

  void _onLine(String line) async {
    final ProtocolMessage message = _codec.decode(line);
    final Completer<ProtocolMessage>? pending = _pending.remove(
      message.requestId,
    );
    if (pending != null) {
      pending.complete(message);
      return;
    }

    final MessageHandler? handler = onMessage;
    if (handler == null) {
      return;
    }
    final ProtocolMessage? response = await handler(message);
    if (response != null) {
      await sendMessage(
        type: response.type,
        requestId: response.requestId,
        payload: response.payload,
      );
    }
  }

  void _handleClosed() {
    if (!_closed.isCompleted) {
      _closed.complete();
    }
    for (final Completer<ProtocolMessage> completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('Peer disconnected.'));
      }
    }
    _pending.clear();
  }

  void _handleError(Object error) {
    if (!_closed.isCompleted) {
      _closed.complete();
    }
    for (final Completer<ProtocolMessage> completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    }
    _pending.clear();
  }

  Future<void> close() async {
    await _subscription.cancel();
    await _socket.close();
    _handleClosed();
  }
}
