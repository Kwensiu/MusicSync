import 'package:music_sync/models/device_info.dart';

class DiscoveredDeviceEntry {
  const DiscoveredDeviceEntry({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.primaryAddress,
    required this.port,
    required this.httpEncryptionEnabled,
    required this.firstSeenAt,
    required this.lastSeenAt,
    required this.seenAddresses,
    required this.isConnectedPeer,
  });

  final String deviceId;
  final String deviceName;
  final String platform;
  final String primaryAddress;
  final int port;
  final bool httpEncryptionEnabled;
  final DateTime firstSeenAt;
  final DateTime lastSeenAt;
  final Set<String> seenAddresses;
  final bool isConnectedPeer;

  DeviceInfo toDeviceInfo() {
    return DeviceInfo(
      deviceId: deviceId,
      deviceName: deviceName,
      platform: platform,
      address: primaryAddress,
      port: port,
      httpEncryptionEnabled: httpEncryptionEnabled,
    );
  }

  DiscoveredDeviceEntry copyWith({
    String? deviceId,
    String? deviceName,
    String? platform,
    String? primaryAddress,
    int? port,
    bool? httpEncryptionEnabled,
    DateTime? firstSeenAt,
    DateTime? lastSeenAt,
    Set<String>? seenAddresses,
    bool? isConnectedPeer,
  }) {
    return DiscoveredDeviceEntry(
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      platform: platform ?? this.platform,
      primaryAddress: primaryAddress ?? this.primaryAddress,
      port: port ?? this.port,
      httpEncryptionEnabled:
          httpEncryptionEnabled ?? this.httpEncryptionEnabled,
      firstSeenAt: firstSeenAt ?? this.firstSeenAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      seenAddresses: seenAddresses ?? this.seenAddresses,
      isConnectedPeer: isConnectedPeer ?? this.isConnectedPeer,
    );
  }

  factory DiscoveredDeviceEntry.fromDevice(
    DeviceInfo device, {
    required DateTime seenAt,
    required bool isConnectedPeer,
  }) {
    final Set<String> addresses = <String>{};
    if (device.address.isNotEmpty) {
      addresses.add(device.address);
    }
    return DiscoveredDeviceEntry(
      deviceId: device.deviceId,
      deviceName: device.deviceName,
      platform: device.platform,
      primaryAddress: device.address,
      port: device.port,
      httpEncryptionEnabled: device.httpEncryptionEnabled,
      firstSeenAt: seenAt,
      lastSeenAt: seenAt,
      seenAddresses: addresses,
      isConnectedPeer: isConnectedPeer,
    );
  }
}
