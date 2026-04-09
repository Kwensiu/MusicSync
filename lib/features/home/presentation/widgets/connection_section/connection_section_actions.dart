import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_sync/features/connection/state/connection_controller.dart';
import 'package:music_sync/features/connection/state/connection_state.dart'
    as peer_connection;
import 'package:music_sync/features/home/presentation/widgets/action_chip_button.dart';
import 'package:music_sync/features/home/presentation/widgets/home_dialogs/home_dialogs.dart';
import 'package:music_sync/l10n/app_localizations_ext.dart';

class ConnectionSectionActions {
  const ConnectionSectionActions._();

  static String connectionStateChipLabel(
    BuildContext context,
    peer_connection.ConnectionState connectionState,
  ) {
    if (connectionState.peer != null &&
        connectionState.status == peer_connection.ConnectionStatus.connected) {
      if (connectionState.listenPort != null) {
        return context.l10n.homeConnectionStateConnectedListening;
      }
      return context.l10n.homeConnectionStateConnected;
    }
    if (connectionState.status == peer_connection.ConnectionStatus.connecting) {
      return context.l10n.homeConnectionStateConnecting;
    }
    if (connectionState.status == peer_connection.ConnectionStatus.listening) {
      return context.l10n.homeConnectionStateListening;
    }
    return context.l10n.homeConnectionStateIdle;
  }

  static ActionChipTone connectionStateChipTone(
    peer_connection.ConnectionState connectionState,
  ) {
    if (connectionState.peer != null &&
        connectionState.status == peer_connection.ConnectionStatus.connected) {
      return ActionChipTone.success;
    }
    if (connectionState.status == peer_connection.ConnectionStatus.listening ||
        connectionState.status == peer_connection.ConnectionStatus.connecting) {
      return ActionChipTone.active;
    }
    return ActionChipTone.neutral;
  }

  static Future<void> handleConnectionStateChipTap({
    required WidgetRef ref,
    required peer_connection.ConnectionState connectionState,
  }) async {
    if (connectionState.peer != null &&
        connectionState.status == peer_connection.ConnectionStatus.connected) {
      await ref.read(connectionControllerProvider.notifier).disconnect();
      return;
    }
    if (connectionState.status == peer_connection.ConnectionStatus.connecting) {
      await ref.read(connectionControllerProvider.notifier).disconnect();
      return;
    }
    if (connectionState.status == peer_connection.ConnectionStatus.listening) {
      await ref.read(connectionControllerProvider.notifier).stopListening();
      return;
    }
    await ref.read(connectionControllerProvider.notifier).startListening(
          port: connectionState.listenPort ?? 44888,
        );
  }

  static void connectFromInput({
    required WidgetRef ref,
    required TextEditingController addressController,
  }) {
    final String input = addressController.text.trim();
    if (input.isEmpty) {
      return;
    }
    final List<String> parts = input.split(':');
    final String host = parts.first;
    final int port = parts.length > 1 ? int.tryParse(parts[1]) ?? 44888 : 44888;
    ref.read(connectionControllerProvider.notifier).connect(
          address: host,
          port: port,
        );
  }

  static Future<void> handleConnectButton({
    required WidgetRef ref,
    required TextEditingController addressController,
    required peer_connection.ConnectionState connectionState,
  }) async {
    final bool hasConnectedPeer = connectionState.peer != null &&
        connectionState.status == peer_connection.ConnectionStatus.connected;
    if (hasConnectedPeer ||
        connectionState.status == peer_connection.ConnectionStatus.connecting) {
      await ref.read(connectionControllerProvider.notifier).disconnect();
      return;
    }
    connectFromInput(
      ref: ref,
      addressController: addressController,
    );
  }

  static Future<String> resolveLocalShareHost() async {
    try {
      final List<NetworkInterface> interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (final NetworkInterface interface in interfaces) {
        for (final InternetAddress address in interface.addresses) {
          final String host = address.address.trim();
          if (host.isEmpty) {
            continue;
          }
          if (host.startsWith('169.254.')) {
            continue;
          }
          return host;
        }
      }
    } catch (_) {}
    return InternetAddress.loopbackIPv4.address;
  }

  static Future<void> showPortDialog({
    required BuildContext context,
    required WidgetRef ref,
    required int currentPort,
  }) async {
    final int? port = await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return PortDialog(initialPort: currentPort);
      },
    );
    if (port == null || !context.mounted) {
      return;
    }
    final peer_connection.ConnectionState connectionState =
        ref.read(connectionControllerProvider);
    if (connectionState.status == peer_connection.ConnectionStatus.listening) {
      await ref.read(connectionControllerProvider.notifier).stopListening();
      await ref
          .read(connectionControllerProvider.notifier)
          .startListening(port: port);
      return;
    }
    await ref.read(connectionControllerProvider.notifier).startListening(
          port: port,
        );
  }

  static Future<void> showShareDialog({
    required BuildContext context,
    required peer_connection.ConnectionState connectionState,
  }) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String copyDoneText = context.l10n.homeShareCopyDone;
    final int port = connectionState.listenPort ?? 44888;
    final String host = await resolveLocalShareHost();
    final String address = '$host:$port';
    if (!context.mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return ShareAddressDialog(
          address: address,
          onCopy: () async {
            await Clipboard.setData(ClipboardData(text: address));
            if (!context.mounted) {
              return;
            }
            messenger.showSnackBar(
              SnackBar(content: Text(copyDoneText)),
            );
          },
        );
      },
    );
  }
}
