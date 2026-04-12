import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:music_sync/core/constants/app_constants.dart';
import 'package:music_sync/models/device_info.dart';

enum DiscoveryEventType { announce, goodbye }

class DiscoveryEvent {
  const DiscoveryEvent({required this.type, required this.device});

  final DiscoveryEventType type;
  final DeviceInfo device;
}

typedef DiscoveryCallback = void Function(DiscoveryEvent event);

class DiscoveryService {
  // TODO(http-fingerprint): include certificate fingerprint in discovery
  // packets. Protocol alone is not enough to authenticate an HTTPS peer.
  RawDatagramSocket? _receiver;
  final List<RawDatagramSocket> _senders = <RawDatagramSocket>[];
  Timer? _broadcastTimer;
  DiscoveryCallback? _onDevice;

  bool get isReceiving => _receiver != null;
  bool get isBroadcasting => _broadcastTimer != null;

  Future<void> startReceiving({required DiscoveryCallback onDevice}) async {
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
          'httpEncryptionEnabled': payload['httpEncryptionEnabled'],
          'protocolVersion': payload['protocolVersion'],
        });
        final DiscoveryEventType type = payload['action'] == 'goodbye'
            ? DiscoveryEventType.goodbye
            : DiscoveryEventType.announce;
        _onDevice?.call(DiscoveryEvent(type: type, device: device));
      } catch (_) {
        // Ignore malformed discovery packets.
      }
    });
    _receiver = socket;
  }

  Future<void> startBroadcasting(DeviceInfo device) async {
    await stopBroadcasting();
    _senders.addAll(await _createBroadcastSenders());

    void broadcastOnce() => _broadcastDeviceEvent(
      device: device,
      type: DiscoveryEventType.announce,
    );

    broadcastOnce();
    _broadcastTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => broadcastOnce(),
    );
  }

  Future<void> sendGoodbye(DeviceInfo device) async {
    if (_senders.isEmpty) {
      _senders.addAll(await _createBroadcastSenders());
    }
    _broadcastDeviceEvent(device: device, type: DiscoveryEventType.goodbye);
  }

  Future<void> stopBroadcasting() async {
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    for (final RawDatagramSocket sender in _senders) {
      sender.close();
    }
    _senders.clear();
  }

  Future<void> stopReceiving() async {
    _receiver?.close();
    _receiver = null;
  }

  Future<void> dispose() async {
    await stopBroadcasting();
    await stopReceiving();
  }

  void _broadcastDeviceEvent({
    required DeviceInfo device,
    required DiscoveryEventType type,
  }) {
    final List<int> data = utf8.encode(
      jsonEncode(<String, Object?>{
        'type': 'music_sync_discovery',
        'action': switch (type) {
          DiscoveryEventType.announce => 'announce',
          DiscoveryEventType.goodbye => 'goodbye',
        },
        'deviceId': device.deviceId,
        'deviceName': device.deviceName,
        'platform': device.platform,
        'port': device.port,
        'httpEncryptionEnabled': device.httpEncryptionEnabled,
        'protocolVersion': device.protocolVersion,
      }),
    );
    for (final RawDatagramSocket sender in _senders) {
      try {
        sender.send(
          data,
          InternetAddress('255.255.255.255'),
          AppConstants.discoveryPort,
        );
      } catch (_) {
        // Ignore per-interface send failures and continue broadcasting.
      }
    }
  }

  Future<List<RawDatagramSocket>> _createBroadcastSenders() async {
    final List<RawDatagramSocket> sockets = <RawDatagramSocket>[];
    final Set<String> boundAddresses = <String>{};

    try {
      final List<NetworkInterface> interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (final NetworkInterface interface in interfaces) {
        if (_shouldSkipInterface(interface)) {
          continue;
        }
        for (final InternetAddress address in interface.addresses) {
          if (!_isUsableBroadcastAddress(address)) {
            continue;
          }
          if (!boundAddresses.add(address.address)) {
            continue;
          }
          try {
            final RawDatagramSocket socket = await RawDatagramSocket.bind(
              address,
              0,
            );
            socket.broadcastEnabled = true;
            sockets.add(socket);
          } catch (_) {
            // Ignore interface-specific bind failures and keep probing.
          }
        }
      }
    } catch (_) {
      // Fall back to a generic sender below.
    }

    if (sockets.isEmpty) {
      final RawDatagramSocket fallback = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
      );
      fallback.broadcastEnabled = true;
      sockets.add(fallback);
      return sockets;
    }

    if (boundAddresses.add(InternetAddress.anyIPv4.address)) {
      try {
        final RawDatagramSocket fallback = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          0,
        );
        fallback.broadcastEnabled = true;
        sockets.add(fallback);
      } catch (_) {
        // Ignore fallback bind failures if interface-bound sockets already exist.
      }
    }
    return sockets;
  }

  bool _shouldSkipInterface(NetworkInterface interface) {
    final String name = interface.name.toLowerCase();
    return name.contains('loopback') ||
        name.contains('lo') ||
        name.contains('tun') ||
        name.contains('tap') ||
        name.contains('wintun') ||
        name.contains('clash') ||
        name.contains('vEthernet'.toLowerCase()) ||
        name.contains('virtual') ||
        name.contains('vpn');
  }

  bool _isUsableBroadcastAddress(InternetAddress address) {
    if (address.type != InternetAddressType.IPv4) {
      return false;
    }
    if (address.isLoopback) {
      return false;
    }
    final String value = address.address;
    return !value.startsWith('169.254.');
  }
}
