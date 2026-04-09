import 'package:flutter/material.dart';
import 'package:music_sync/app/widgets/app_dialog_shell.dart';
import 'package:music_sync/l10n/app_localizations_ext.dart';

class AppConfirmDialog extends StatelessWidget {
  const AppConfirmDialog({
    required this.title,
    required this.message,
    this.confirmLabel,
    this.cancelLabel,
    super.key,
  });

  final String title;
  final String message;
  final String? confirmLabel;
  final String? cancelLabel;

  @override
  Widget build(BuildContext context) {
    return AppDialogShell(
      size: AppDialogSize.form,
      title: Text(title),
      content: Text(message),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel ?? context.l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel ?? context.l10n.commonConfirm),
        ),
      ],
    );
  }
}
