import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_sync/features/settings/presentation/widgets/settings_choice_dialog.dart';
import 'package:music_sync/features/settings/state/settings_controller.dart';
import 'package:music_sync/features/settings/state/settings_state.dart';
import 'package:music_sync/l10n/app_localizations_ext.dart';

Future<void> showThemeModeDialog({
  required BuildContext context,
  required WidgetRef ref,
  required AppThemeModeSetting initialValue,
}) {
  return showSettingsChoiceDialog<AppThemeModeSetting>(
    context: context,
    title: context.l10n.settingsThemeModeTitle,
    initialValue: initialValue,
    maxWidth: 380,
    maxHeight: 320,
    minHorizontalInset: 24,
    itemPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
    saveOnSelect: true,
    showConfirmButton: false,
    options: <SettingsChoiceItem<AppThemeModeSetting>>[
      SettingsChoiceItem<AppThemeModeSetting>(
        value: AppThemeModeSetting.light,
        label: context.l10n.settingsThemeModeLight,
      ),
      SettingsChoiceItem<AppThemeModeSetting>(
        value: AppThemeModeSetting.dark,
        label: context.l10n.settingsThemeModeDark,
      ),
      SettingsChoiceItem<AppThemeModeSetting>(
        value: AppThemeModeSetting.system,
        label: context.l10n.settingsThemeModeSystem,
      ),
    ],
    onConfirm: (AppThemeModeSetting value) {
      return ref.read(settingsControllerProvider.notifier).setThemeMode(value);
    },
  );
}
