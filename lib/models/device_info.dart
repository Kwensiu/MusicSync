class DeviceInfo {
  const DeviceInfo({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.address,
    required this.port,
    this.httpEncryptionEnabled = true,
    this.protocolVersion = 1,
  });

  final String deviceId;
  final String deviceName;
  final String platform;
  final String address;
  final int port;
  final bool httpEncryptionEnabled;

  /// Protocol version reported by this device during hello handshake.
  /// Used to determine feature availability (e.g. fingerprint support).
  final int protocolVersion;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'deviceId': deviceId,
      'deviceName': deviceName,
      'platform': platform,
      'address': address,
      'port': port,
      'httpEncryptionEnabled': httpEncryptionEnabled,
      'protocolVersion': protocolVersion,
    };
  }

  factory DeviceInfo.fromJson(Map<String, Object?> json) {
    return DeviceInfo(
      deviceId: json['deviceId'] as String? ?? '',
      deviceName: json['deviceName'] as String? ?? '',
      platform: json['platform'] as String? ?? 'unknown',
      address: json['address'] as String? ?? '',
      port: (json['port'] as num?)?.toInt() ?? 0,
      httpEncryptionEnabled:
          json['httpEncryptionEnabled'] as bool? ??
          json['https'] as bool? ??
          true,
      protocolVersion: (json['protocolVersion'] as num?)?.toInt() ?? 1,
    );
  }
}
