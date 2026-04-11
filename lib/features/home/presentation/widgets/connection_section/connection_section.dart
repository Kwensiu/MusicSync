import 'package:flutter/material.dart';
import 'package:music_sync/features/connection/state/connection_state.dart'
    as peer_connection;
import 'package:music_sync/l10n/app_localizations_ext.dart';
import 'package:music_sync/models/device_info.dart';

class ConnectionSection extends StatelessWidget {
  const ConnectionSection({
    super.key,
    required this.connectionState,
    required this.isConnectUiBusy,
    required this.hasConnectedPeer,
    required this.onRefreshPresence,
    required this.onOpenConnectionPanel,
    required this.onDiscoveredDeviceTap,
    required this.localizeUiError,
  });

  final peer_connection.ConnectionState connectionState;
  final bool isConnectUiBusy;
  final bool hasConnectedPeer;
  final VoidCallback onRefreshPresence;
  final VoidCallback onOpenConnectionPanel;
  final ValueChanged<DeviceInfo> onDiscoveredDeviceTap;
  final String Function(BuildContext context, String value) localizeUiError;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                context.l10n.homeDiscoveredDevices,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            IconButton(
              tooltip: context.l10n.homeRefreshConnectionState,
              visualDensity: VisualDensity.compact,
              onPressed: isConnectUiBusy ? null : onRefreshPresence,
              icon: const Icon(Icons.refresh_rounded, size: 20),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeOutCubic,
          child: connectionState.discoveredDevices.isNotEmpty
              ? Column(
                  key: const ValueKey<String>('device-list'),
                  children: List<Widget>.generate(
                    connectionState.discoveredDevices.length,
                    (int index) {
                      final DeviceInfo device =
                          connectionState.discoveredDevices[index];
                      final bool isLast =
                          index == connectionState.discoveredDevices.length - 1;
                      return Padding(
                        key: ValueKey<String>('device-${device.deviceId}'),
                        padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
                        child: _DiscoveredDeviceCard(
                          device: device,
                          enabled: !isConnectUiBusy,
                          connected:
                              connectionState.peer?.deviceId ==
                                  device.deviceId &&
                              hasConnectedPeer,
                          onTap: () => onDiscoveredDeviceTap(device),
                        ),
                      );
                    },
                  ),
                )
              : const _EmptyDeviceSkeleton(
                  key: ValueKey<String>('empty-skeleton'),
                ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onOpenConnectionPanel,
            icon: const Icon(Icons.tune_rounded),
            label: Text(context.l10n.homeOpenConnectionPanel),
          ),
        ),
      ],
    );
  }
}

class _EmptyDeviceSkeleton extends StatefulWidget {
  const _EmptyDeviceSkeleton({super.key});

  @override
  State<_EmptyDeviceSkeleton> createState() => _EmptyDeviceSkeletonState();
}

class _EmptyDeviceSkeletonState extends State<_EmptyDeviceSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
    lowerBound: 0.48,
    upperBound: 1,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return FadeTransition(
      opacity: _controller,
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      height: 16,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FractionallySizedBox(
                      widthFactor: 0.72,
                      child: Container(
                        height: 14,
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscoveredDeviceCard extends StatelessWidget {
  const _DiscoveredDeviceCard({
    required this.device,
    required this.enabled,
    required this.connected,
    required this.onTap,
  });

  final DeviceInfo device;
  final bool enabled;
  final bool connected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Material(
      color: connected ? scheme.tertiaryContainer : scheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      device.deviceName,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${device.platform} | ${device.address}:${device.port}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (connected)
                Icon(Icons.check_circle_rounded, color: scheme.primary)
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: scheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
