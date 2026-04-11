import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_sync/features/settings/presentation/widgets/settings_dialog_shell.dart';
import 'package:music_sync/features/settings/state/settings_controller.dart';
import 'package:music_sync/l10n/app_localizations_ext.dart';

Future<void> showDeviceAliasDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String initialValue,
}) async {
  final String? nextAlias = await showDialog<String?>(
    context: context,
    builder: (BuildContext dialogContext) {
      return _DeviceAliasDialog(initialValue: initialValue);
    },
  );

  if (nextAlias == null) {
    return;
  }

  await ref.read(settingsControllerProvider.notifier).setDeviceAlias(nextAlias);
}

class _DeviceAliasDialog extends StatefulWidget {
  const _DeviceAliasDialog({required this.initialValue});

  final String initialValue;

  @override
  State<_DeviceAliasDialog> createState() => _DeviceAliasDialogState();
}

class _DeviceAliasDialogState extends State<_DeviceAliasDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return SettingsDialogShell(
      title: Text(context.l10n.settingsDeviceAliasTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            context.l10n.settingsDeviceAliasDescription,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: context.l10n.settingsDeviceAliasField,
              hintText: context.l10n.settingsDeviceAliasHint,
              helperText: context.l10n.settingsDeviceAliasDescription,
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(MaterialLocalizations.of(context).saveButtonLabel),
        ),
      ],
    );
  }
}
