import 'package:music_sync/core/errors/app_error_localizer.dart';
import 'package:music_sync/features/connection/state/discovered_device_entry.dart';
import 'package:music_sync/models/device_info.dart';
import 'package:music_sync/models/scan_snapshot.dart';

enum ConnectionStatus { idle, connecting, connected, disconnected, failed }

class ConnectionState {
  const ConnectionState({
    required this.status,
    this.peer,
    this.remoteSnapshot,
    this.isRemoteDirectoryReady = false,
    this.isIncomingSyncActive = false,
    this.isListening = false,
    this.discoveredDeviceMap = const <String, DiscoveredDeviceEntry>{},
    this.recentAddresses = const <String>[],
    this.recentLabels = const <String, String>{},
    this.listenPort,
    this.errorMessage,
  });

  final ConnectionStatus status;
  final DeviceInfo? peer;
  final ScanSnapshot? remoteSnapshot;
  final bool isRemoteDirectoryReady;
  final bool isIncomingSyncActive;
  final bool isListening;
  final Map<String, DiscoveredDeviceEntry> discoveredDeviceMap;
  final List<String> recentAddresses;
  final Map<String, String> recentLabels;
  final int? listenPort;
  final String? errorMessage;

  List<DeviceInfo> get discoveredDevices {
    final List<DiscoveredDeviceEntry> entries =
        discoveredDeviceMap.values.toList()..sort((a, b) {
          if (a.isConnectedPeer != b.isConnectedPeer) {
            return a.isConnectedPeer ? -1 : 1;
          }
          final int firstSeenCompare = a.firstSeenAt.compareTo(b.firstSeenAt);
          if (firstSeenCompare != 0) {
            return firstSeenCompare;
          }
          final int nameCompare = a.deviceName.toLowerCase().compareTo(
            b.deviceName.toLowerCase(),
          );
          if (nameCompare != 0) {
            return nameCompare;
          }
          return a.deviceId.compareTo(b.deviceId);
        });
    return entries.map((entry) => entry.toDeviceInfo()).toList();
  }

  static String localizeErrorMessage(String? value) {
    return AppErrorLocalizer.resolve(value);
  }

  factory ConnectionState.initial() {
    return const ConnectionState(status: ConnectionStatus.idle);
  }
}
