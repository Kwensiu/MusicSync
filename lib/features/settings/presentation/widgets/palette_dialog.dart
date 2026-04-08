import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_sync/features/settings/presentation/widgets/settings_choice_dialog.dart';
import 'package:music_sync/features/settings/state/settings_controller.dart';
import 'package:music_sync/features/settings/state/settings_state.dart';
import 'package:music_sync/l10n/app_localizations_ext.dart';

Future<void> showPaletteDialog({
  required BuildContext context,
  required WidgetRef ref,
  required AppPaletteSetting initialValue,
}) {
  return showSettingsChoiceDialog<AppPaletteSetting>(
    context: context,
    title: context.l10n.settingsPaletteTitle,
    initialValue: initialValue,
    maxWidth: 380,
    maxHeight: 340,
    minHorizontalInset: 24,
    itemPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
    saveOnSelect: true,
    showConfirmButton: false,
    options: <SettingsChoiceItem<AppPaletteSetting>>[
      SettingsChoiceItem<AppPaletteSetting>(
        value: AppPaletteSetting.neutral,
        label: context.l10n.settingsPaletteNeutral,
      ),
      SettingsChoiceItem<AppPaletteSetting>(
        value: AppPaletteSetting.expressive,
        label: context.l10n.settingsPaletteExpressive,
      ),
      SettingsChoiceItem<AppPaletteSetting>(
        value: AppPaletteSetting.tonalSpot,
        label: context.l10n.settingsPaletteTonalSpot,
      ),
    ],
    onConfirm: (AppPaletteSetting value) {
      return ref.read(settingsControllerProvider.notifier).setPalette(value);
    },
  );
}
