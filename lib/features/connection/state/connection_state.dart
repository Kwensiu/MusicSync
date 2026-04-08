import 'package:music_sync/core/errors/app_error_localizer.dart';
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
    this.isRemoteDirectoryReady = false,
    this.discoveredDevices = const <DeviceInfo>[],
    this.recentAddresses = const <String>[],
    this.recentLabels = const <String, String>{},
    this.listenPort,
    this.errorMessage,
  });

  final ConnectionStatus status;
  final DeviceInfo? peer;
  final ScanSnapshot? remoteSnapshot;
  final bool isRemoteDirectoryReady;
  final List<DeviceInfo> discoveredDevices;
  final List<String> recentAddresses;
  final Map<String, String> recentLabels;
  final int? listenPort;
  final String? errorMessage;

  static String localizeErrorMessage(String? value) {
    return AppErrorLocalizer.resolve(value);
  }

  factory ConnectionState.initial() {
    return const ConnectionState(status: ConnectionStatus.idle);
  }
}
