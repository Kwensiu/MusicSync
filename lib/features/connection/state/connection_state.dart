import 'package:music_sync/models/device_info.dart';
import 'package:music_sync/models/scan_snapshot.dart';

enum ConnectionStatus {
  idle,
  listening,
  connecting,
  connected,
  disconnected,
  failed,
}

class ConnectionState {
  const ConnectionState({
    required this.status,
    this.peer,
    this.remoteSnapshot,
    this.discoveredDevices = const <DeviceInfo>[],
    this.recentAddresses = const <String>[],
    this.listenPort,
    this.errorMessage,
  });

  final ConnectionStatus status;
  final DeviceInfo? peer;
  final ScanSnapshot? remoteSnapshot;
  final List<DeviceInfo> discoveredDevices;
  final List<String> recentAddresses;
  final int? listenPort;
  final String? errorMessage;

  static String localizeErrorMessage(String? value) {
    if (value == null || value.isEmpty) {
      return '';
    }
    if (value.contains('No shared directory selected on peer')) {
      return '远端设备还没有选择共享目录。';
    }
    if (value.contains('Connection refused')) {
      return 'Connection was refused. Check the target address and ensure the remote listener is running.';
    }
    if (value.contains('timed out')) {
      return 'Connection timed out. Check that both devices are on the same LAN and try again.';
    }
    if (value.contains('Peer handshake failed') ||
        value.contains('Peer handshake payload invalid') ||
        value.contains('Peer scan response invalid') ||
        value.contains('Peer snapshot payload invalid')) {
      return 'Remote device responded with an incompatible or invalid protocol message.';
    }
    if (value.contains('Not connected to any peer')) {
      return '当前没有已连接的远端设备。';
    }
    if (value.contains('SocketException')) {
      return value.replaceFirst('SocketException: ', '');
    }
    return value;
  }

  factory ConnectionState.initial() {
    return const ConnectionState(status: ConnectionStatus.idle);
  }
}
