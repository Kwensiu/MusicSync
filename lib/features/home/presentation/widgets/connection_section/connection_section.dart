import 'package:flutter/material.dart';
import 'package:music_sync/features/connection/state/connection_state.dart'
    as peer_connection;
import 'package:music_sync/features/home/presentation/widgets/action_chip_button.dart';
import 'package:music_sync/l10n/app_localizations_ext.dart';

class ConnectionSection extends StatelessWidget {
  const ConnectionSection({
    super.key,
    required this.connectionState,
    required this.addressController,
    required this.isConnectUiBusy,
    required this.isConnecting,
    required this.hasConnectedPeer,
    required this.onConnectionStateChipTap,
    required this.onPortTap,
    required this.onShareTap,
    required this.onConnectTap,
    required this.onManageRecentAddresses,
    required this.onRecentAddressTap,
    required this.localizeUiError,
    required this.connectionStateChipLabel,
    required this.connectionStateChipTone,
  });

  final peer_connection.ConnectionState connectionState;
  final TextEditingController addressController;
  final bool isConnectUiBusy;
  final bool isConnecting;
  final bool hasConnectedPeer;
  final VoidCallback onConnectionStateChipTap;
  final VoidCallback onPortTap;
  final VoidCallback onShareTap;
  final VoidCallback onConnectTap;
  final VoidCallback onManageRecentAddresses;
  final ValueChanged<String> onRecentAddressTap;
  final String Function(BuildContext context, String value) localizeUiError;
  final String Function(
    BuildContext context,
    peer_connection.ConnectionState state,
  ) connectionStateChipLabel;
  final ActionChipTone Function(peer_connection.ConnectionState state)
      connectionStateChipTone;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool canStopConnection = hasConnectedPeer || isConnecting;
    final bool canShareAddress = connectionState.listenPort != null;
    final Color actionBackground =
        canStopConnection ? scheme.secondaryContainer : scheme.primary;
    final Color actionForeground =
        canStopConnection ? scheme.onSecondaryContainer : scheme.onPrimary;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(context.l10n.homeStepConnectionHint),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  ActionChipButton(
                    label: connectionStateChipLabel(context, connectionState),
                    tone: connectionStateChipTone(connectionState),
                    onPressed:
                        isConnectUiBusy ? null : onConnectionStateChipTap,
                  ),
                  const SizedBox(width: 8),
                  ActionChipButton(
                    label: context.l10n.homePortChipLabel(
                      connectionState.listenPort ?? 44888,
                    ),
                    tone: ActionChipTone.neutral,
                    onPressed: isConnectUiBusy ? null : onPortTap,
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: context.l10n.homeShareTooltip,
                    child: IconButton.filledTonal(
                      onPressed: canShareAddress ? onShareTap : null,
                      icon: const Icon(Icons.ios_share_outlined),
                    ),
                  ),
                ],
              ),
            ),
            if (connectionState.peer != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(context.l10n.homePeerName(connectionState.peer!.deviceName)),
            ],
            if (connectionState.errorMessage != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                localizeUiError(context, connectionState.errorMessage!),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: addressController,
              decoration: InputDecoration(
                filled: true,
                fillColor: scheme.surface,
                labelText: context.l10n.homePeerAddressLabel,
                hintText: context.l10n.homePeerAddressHint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: actionBackground,
                  foregroundColor: actionForeground,
                ),
                onPressed: isConnectUiBusy ? null : onConnectTap,
                child: Text(
                  canStopConnection
                      ? context.l10n.homeConnectStop
                      : context.l10n.homeConnect,
                ),
              ),
            ),
            if (connectionState.recentAddresses.isNotEmpty) ...<Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      context.l10n.homeRecentAddresses,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: context.l10n.homeManageRecentItems,
                    onPressed: isConnectUiBusy ? null : onManageRecentAddresses,
                    icon: const Icon(Icons.tune_rounded),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: connectionState.recentAddresses.map((String address) {
                  return ActionChip(
                    backgroundColor: scheme.surface,
                    side: BorderSide(color: scheme.outlineVariant),
                    label: Text(
                      connectionState.recentLabels[address] ?? address,
                    ),
                    onPressed: isConnectUiBusy
                        ? null
                        : () => onRecentAddressTap(address),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
