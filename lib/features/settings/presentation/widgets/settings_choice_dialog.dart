import 'package:flutter/material.dart';
import 'package:music_sync/features/settings/presentation/widgets/settings_dialog_shell.dart';
import 'package:music_sync/l10n/app_localizations_ext.dart';

class SettingsChoiceItem<T> {
  const SettingsChoiceItem({
    required this.value,
    required this.label,
    this.enabled = true,
  });

  final T value;
  final String label;
  final bool enabled;
}

Future<void> showSettingsChoiceDialog<T>({
  required BuildContext context,
  required String title,
  required T initialValue,
  required List<SettingsChoiceItem<T>> options,
  required Future<void> Function(T value) onConfirm,
  double maxWidth = 420,
  double maxHeight = 360,
  double minHorizontalInset = 20,
  double minVerticalInset = 24,
  EdgeInsets itemPadding =
      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
  bool showConfirmButton = true,
  bool saveOnSelect = false,
}) async {
  T selected = initialValue;
  bool isSubmitting = false;

  await showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return SettingsDialogShell(
            title: Text(title),
            maxWidth: maxWidth,
            maxHeight: maxHeight,
            minHorizontalInset: minHorizontalInset,
            minVerticalInset: minVerticalInset,
            content: ListView(
              shrinkWrap: true,
              children: options.map((SettingsChoiceItem<T> option) {
                final bool isSelected = option.value == selected;
                final ThemeData theme = Theme.of(context);
                final ColorScheme scheme = theme.colorScheme;

                return Padding(
                  padding: itemPadding,
                  child: Material(
                    color: isSelected
                        ? scheme.secondaryContainer
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: option.enabled
                          ? () async {
                              if (isSubmitting) return;
                              setState(() => selected = option.value);
                              if (!saveOnSelect) return;
                              isSubmitting = true;
                              await onConfirm(option.value);
                              if (context.mounted) {
                                Navigator.of(context).pop();
                              }
                            }
                          : null,
                      child: ListTile(
                        dense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        title: Text(
                          option.label,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: option.enabled
                                ? (isSelected
                                    ? scheme.onSecondaryContainer
                                    : scheme.onSurface)
                                : scheme.onSurfaceVariant
                                    .withValues(alpha: 0.6),
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(
                                Icons.check_rounded,
                                size: 18,
                                color: option.enabled
                                    ? scheme.primary
                                    : scheme.onSurfaceVariant
                                        .withValues(alpha: 0.5),
                              )
                            : null,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(context.l10n.commonCancel),
              ),
              if (showConfirmButton && !saveOnSelect)
                FilledButton(
                  onPressed: () async {
                    await onConfirm(selected);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: Text(context.l10n.commonConfirm),
                ),
            ],
          );
        },
      );
    },
  );
}
