import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:music_sync/core/constants/app_constants.dart';
import 'package:music_sync/models/device_info.dart';

typedef DiscoveryCallback = void Function(DeviceInfo device);

class DiscoveryService {
  RawDatagramSocket? _receiver;
  RawDatagramSocket? _sender;
  Timer? _broadcastTimer;
  DiscoveryCallback? _onDevice;

  bool get isReceiving => _receiver != null;
  bool get isBroadcasting => _broadcastTimer != null;

  Future<void> startReceiving({
    required DiscoveryCallback onDevice,
  }) async {
    _onDevice = onDevice;
    if (_receiver != null) {
      return;
    }
    final RawDatagramSocket socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      AppConstants.discoveryPort,
      reuseAddress: true,
      reusePort: false,
    );
    socket.broadcastEnabled = true;
    socket.listen((RawSocketEvent event) {
      if (event != RawSocketEvent.read) {
        return;
      }
      final Datagram? datagram = socket.receive();
      if (datagram == null) {
        return;
      }
      try {
        final Map<String, Object?> payload =
            jsonDecode(utf8.decode(datagram.data)) as Map<String, Object?>;
        if (payload['type'] != 'music_sync_discovery') {
          return;
        }
        final DeviceInfo device = DeviceInfo.fromJson(<String, Object?>{
          'deviceId': payload['deviceId'],
          'deviceName': payload['deviceName'],
          'platform': payload['platform'],
          'address': datagram.address.address,
          'port': payload['port'],
        });
        _onDevice?.call(device);
      } catch (_) {
        // Ignore malformed discovery packets.
      }
    });
    _receiver = socket;
  }

  Future<void> startBroadcasting(DeviceInfo device) async {
    await stopBroadcasting();
    final RawDatagramSocket socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      0,
    );
    socket.broadcastEnabled = true;
    _sender = socket;

    void broadcastOnce() {
      final List<int> data = utf8.encode(
        jsonEncode(<String, Object?>{
          'type': 'music_sync_discovery',
          'deviceId': device.deviceId,
          'deviceName': device.deviceName,
          'platform': device.platform,
          'port': device.port,
        }),
      );
      socket.send(
        data,
        InternetAddress('255.255.255.255'),
        AppConstants.discoveryPort,
      );
    }

    broadcastOnce();
    _broadcastTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => broadcastOnce(),
    );
  }

  Future<void> stopBroadcasting() async {
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    _sender?.close();
    _sender = null;
  }

  Future<void> stopReceiving() async {
    _receiver?.close();
    _receiver = null;
  }

  Future<void> dispose() async {
    await stopBroadcasting();
    await stopReceiving();
  }
}
