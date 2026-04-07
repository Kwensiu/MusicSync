class DeviceInfo {
  const DeviceInfo({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.address,
    required this.port,
  });

  final String deviceId;
  final String deviceName;
  final String platform;
  final String address;
  final int port;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'deviceId': deviceId,
      'deviceName': deviceName,
      'platform': platform,
      'address': address,
      'port': port,
    };
  }

  factory DeviceInfo.fromJson(Map<String, Object?> json) {
    return DeviceInfo(
      deviceId: json['deviceId'] as String? ?? '',
      deviceName: json['deviceName'] as String? ?? '',
      platform: json['platform'] as String? ?? 'unknown',
      address: json['address'] as String? ?? '',
      port: (json['port'] as num?)?.toInt() ?? 0,
    );
  }
}
