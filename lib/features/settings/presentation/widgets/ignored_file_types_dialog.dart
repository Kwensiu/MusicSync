import 'package:flutter/material.dart';
import 'package:music_sync/features/settings/presentation/widgets/settings_dialog_shell.dart';
import 'package:music_sync/l10n/app_localizations_ext.dart';

Future<void> showIgnoredFileTypesDialog({
  required BuildContext context,
  required List<String> initialValues,
  required Future<void> Function(List<String> values) onSave,
}) async {
  final TextEditingController controller = TextEditingController();
  List<String> values = List<String>.from(initialValues);
  String? inputError;

  const double gapS = 8;
  const double gapM = 10;
  const double gapL = 12;
  const double fieldRadius = 14;
  const double itemRadius = 16;
  final RegExp extensionPattern = RegExp(r'^[a-z0-9][a-z0-9_-]{0,15}$');

  await showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      final ColorScheme scheme = Theme.of(context).colorScheme;
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return SettingsDialogShell(
            title: Text(context.l10n.settingsIgnoredExtensionsTitle),
            maxWidth: 500,
            maxHeight: 430,
            minHorizontalInset: 18,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  context.l10n.settingsIgnoredExtensionsDescription,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: gapL),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          labelText: context.l10n.settingsIgnoredExtensionField,
                          hintText: context.l10n.settingsIgnoredExtensionHint,
                          errorText: inputError,
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(fieldRadius),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: gapS),
                    FilledButton(
                      onPressed: () {
                        final String normalized = controller.text
                            .trim()
                            .toLowerCase()
                            .replaceAll('.', '');
                        if (normalized.isEmpty) {
                          setState(() {
                            inputError =
                                context.l10n.settingsIgnoredExtensionRequired;
                          });
                          return;
                        }
                        if (!extensionPattern.hasMatch(normalized)) {
                          setState(() {
                            inputError =
                                context.l10n.settingsIgnoredExtensionInvalid;
                          });
                          return;
                        }
                        if (values.contains(normalized)) {
                          setState(() {
                            inputError =
                                context.l10n.settingsIgnoredExtensionDuplicate;
                          });
                          return;
                        }
                        setState(() {
                          values = <String>[...values, normalized]..sort();
                          inputError = null;
                          controller.clear();
                        });
                      },
                      child: Text(context.l10n.commonAdd),
                    ),
                  ],
                ),
                const SizedBox(height: gapL),
                Expanded(
                  child: values.isEmpty
                      ? Center(
                          child:
                              Text(context.l10n.settingsIgnoredExtensionsEmpty),
                        )
                      : ListView.separated(
                          itemCount: values.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: gapS),
                          itemBuilder: (BuildContext context, int index) {
                            final String value = values[index];
                            return DecoratedBox(
                              decoration: BoxDecoration(
                                color: scheme.surface,
                                borderRadius: BorderRadius.circular(itemRadius),
                                border: Border.all(
                                  color: scheme.outlineVariant,
                                ),
                              ),
                              child: ListTile(
                                dense: true,
                                visualDensity: VisualDensity.compact,
                                title: Text('.$value'),
                                trailing: IconButton(
                                  onPressed: () {
                                    setState(() {
                                      values.removeAt(index);
                                    });
                                  },
                                  icon:
                                      const Icon(Icons.delete_outline_rounded),
                                ),
                              ),
                            );
                          },
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
                onPressed: () async {
                  final List<String> nextValues = List<String>.from(values);
                  await onSave(nextValues);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                child: Text(context.l10n.commonConfirm),
              ),
            ],
            bottomActionPadding: gapM,
            topContentPadding: gapS,
          );
        },
      );
    },
  );

  controller.dispose();
}
