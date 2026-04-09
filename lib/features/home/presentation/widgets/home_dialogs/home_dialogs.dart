import 'package:flutter/material.dart';
import 'package:music_sync/l10n/app_localizations_ext.dart';
import 'package:music_sync/models/device_info.dart';
import 'package:qr_flutter/qr_flutter.dart';

class PortDialog extends StatefulWidget {
  const PortDialog({
    required this.initialPort,
    super.key,
  });

  final int initialPort;

  @override
  State<PortDialog> createState() => _PortDialogState();
}

class _PortDialogState extends State<PortDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialPort.toString(),
  );
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.homePortDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(context.l10n.homePortDialogBody),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: context.l10n.homePortDialogHint,
              errorText: _errorText,
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () {
            final int? value = int.tryParse(_controller.text.trim());
            if (value == null || value < 1 || value > 65535) {
              setState(() {
                _errorText = context.l10n.homePortDialogInvalid;
              });
              return;
            }
            Navigator.of(context).pop(value);
          },
          child: Text(context.l10n.commonConfirm),
        ),
      ],
    );
  }
}

class RecentAliasDialog extends StatefulWidget {
  const RecentAliasDialog({
    required this.title,
    required this.initialValue,
    super.key,
  });

  final String title;
  final String? initialValue;

  @override
  State<RecentAliasDialog> createState() => _RecentAliasDialogState();
}

class _RecentAliasDialogState extends State<RecentAliasDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                widget.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                decoration: InputDecoration(
                  labelText: context.l10n.homeRecentAlias,
                  hintText: context.l10n.homeRecentAliasHint,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                maxLength: 24,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.l10n.commonCancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () =>
                        Navigator.of(context).pop(_controller.text),
                    child: Text(context.l10n.commonConfirm),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RecentAddressDialog extends StatefulWidget {
  const RecentAddressDialog({
    required this.initialAddress,
    required this.initialAlias,
    super.key,
  });

  final String initialAddress;
  final String? initialAlias;

  @override
  State<RecentAddressDialog> createState() => _RecentAddressDialogState();
}

class _RecentAddressDialogState extends State<RecentAddressDialog> {
  late final TextEditingController _addressController =
      TextEditingController(text: widget.initialAddress);
  late final TextEditingController _aliasController =
      TextEditingController(text: widget.initialAlias ?? '');
  String? _addressError;

  @override
  void dispose() {
    _addressController.dispose();
    _aliasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                context.l10n.homeRecentEditAddress,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _addressController,
                decoration: InputDecoration(
                  labelText: context.l10n.homeRecentAddressField,
                  hintText: context.l10n.homePeerAddressHint,
                  errorText: _addressError,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _aliasController,
                decoration: InputDecoration(
                  labelText: context.l10n.homeRecentAlias,
                  hintText: context.l10n.homeRecentAliasHint,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                maxLength: 24,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.l10n.commonCancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      if (_addressController.text.trim().isEmpty) {
                        setState(() {
                          _addressError =
                              context.l10n.homeRecentAddressRequired;
                        });
                        return;
                      }
                      Navigator.of(context).pop((
                        address: _addressController.text,
                        alias: _aliasController.text,
                      ));
                    },
                    child: Text(context.l10n.commonConfirm),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ShareAddressDialog extends StatelessWidget {
  const ShareAddressDialog({
    required this.address,
    required this.onCopy,
    super.key,
  });

  final String address;
  final Future<void> Function() onCopy;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 228),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Text(
                context.l10n.homeShareDialogTitle,
                textAlign: TextAlign.center,
                style: textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              QrImageView(
                data: address,
                size: 180,
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: 180,
                child: Material(
                  color: scheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(color: scheme.outlineVariant),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: onCopy,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Expanded(
                            child: SelectableText(
                              address,
                              textAlign: TextAlign.center,
                              style: textTheme.bodyMedium?.copyWith(
                                fontFamily: 'monospace',
                                letterSpacing: 0.1,
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: scheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.content_copy_outlined,
                              size: 16,
                              color: scheme.onSecondaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ConnectionOptionsDialog extends StatelessWidget {
  const ConnectionOptionsDialog({
    required this.addressController,
    required this.recentAddresses,
    required this.recentLabels,
    required this.discoveredDevices,
    required this.onConnectTap,
    required this.onRecentAddressTap,
    required this.onDiscoveredDeviceTap,
    required this.onManageRecentAddresses,
    required this.onPortTap,
    required this.onShareTap,
    super.key,
  });

  final TextEditingController addressController;
  final List<String> recentAddresses;
  final Map<String, String> recentLabels;
  final List<DeviceInfo> discoveredDevices;
  final VoidCallback onConnectTap;
  final ValueChanged<String> onRecentAddressTap;
  final ValueChanged<DeviceInfo> onDiscoveredDeviceTap;
  final VoidCallback onManageRecentAddresses;
  final VoidCallback onPortTap;
  final VoidCallback onShareTap;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  context.l10n.homeOpenConnectionPanel,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: addressController,
                  decoration: InputDecoration(
                    filled: true,
                    labelText: context.l10n.homePeerAddressLabel,
                    hintText: context.l10n.homePeerAddressHint,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: onConnectTap,
                  child: Text(context.l10n.homeConnect),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed: onPortTap,
                      icon: const Icon(Icons.settings_ethernet_rounded),
                      label: Text(context.l10n.homeListenerTitle),
                    ),
                    OutlinedButton.icon(
                      onPressed: onShareTap,
                      icon: const Icon(Icons.ios_share_outlined),
                      label: Text(context.l10n.homeShareTooltip),
                    ),
                    OutlinedButton.icon(
                      onPressed: onManageRecentAddresses,
                      icon: const Icon(Icons.history_rounded),
                      label: Text(context.l10n.homeManageRecentItems),
                    ),
                  ],
                ),
                if (discoveredDevices.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 20),
                  Text(
                    context.l10n.homeDiscoveredDevices,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  ...discoveredDevices.map(
                    (DeviceInfo device) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(device.deviceName),
                      subtitle: Text('${device.address}:${device.port}'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => onDiscoveredDeviceTap(device),
                    ),
                  ),
                ],
                if (recentAddresses.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 20),
                  Text(
                    context.l10n.homeRecentAddresses,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: recentAddresses.map((String address) {
                      return ActionChip(
                        label: Text(recentLabels[address] ?? address),
                        onPressed: () => onRecentAddressTap(address),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
