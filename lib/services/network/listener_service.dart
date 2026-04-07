import 'dart:io';

import 'package:music_sync/services/network/peer_session.dart';

class ListenerService {
  ServerSocket? _serverSocket;
  final List<PeerSession> _sessions = <PeerSession>[];

  bool get isListening => _serverSocket != null;

  Future<void> start({
    required int port,
    void Function(PeerSession session)? onClient,
  }) async {
    await stop();
    _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, port);
    _serverSocket!.listen((Socket socket) {
      final PeerSession session = PeerSession(socket);
      _sessions.add(session);
      session.closed.whenComplete(() {
        _sessions.remove(session);
      });
      onClient?.call(session);
    });
  }

  Future<void> stop() async {
    for (final PeerSession session in List<PeerSession>.from(_sessions)) {
      await session.close();
    }
    _sessions.clear();
    await _serverSocket?.close();
    _serverSocket = null;
  }
}
