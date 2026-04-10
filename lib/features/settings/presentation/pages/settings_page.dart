import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_sync/features/settings/presentation/widgets/ignored_file_types_dialog.dart';
import 'package:music_sync/features/settings/presentation/widgets/palette_dialog.dart';
import 'package:music_sync/features/settings/presentation/widgets/settings_group.dart';
import 'package:music_sync/features/settings/presentation/widgets/theme_mode_dialog.dart';
import 'package:music_sync/features/settings/state/settings_controller.dart';
import 'package:music_sync/features/settings/state/settings_state.dart';
import 'package:music_sync/l10n/app_localizations_ext.dart';
import 'package:smooth_list_view/smooth_list_view.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  static const double _pageHorizontal = 20;
  static const double _pageTop = 20;
  static const double _pageBottom = 20;
  static const double _headerGap = 12;
  static const double _titleToSectionGap = 16;
  static const double _sectionLabelIndent = 16;
  static const double _sectionLabelFontSize = 18;
  static const double _sectionToGroupGap = 8;
  static const double _groupToGroupGap = 16;
  static const double _backButtonPadding = 12;
  static const bool _compactSwitch = true;
  static const Duration _scrollDuration = Duration(milliseconds: 140);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SettingsState settingsState = ref.watch(settingsControllerProvider);
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: SafeArea(
        child: SmoothListView(
          duration: _scrollDuration,
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.fromLTRB(
            _pageHorizontal,
            _pageTop,
            _pageHorizontal,
            _pageBottom,
          ),
          children: <Widget>[
            Row(
              children: <Widget>[
                Material(
                  color: scheme.surfaceContainerHigh,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    visualDensity: VisualDensity.compact,
                    iconSize: 22,
                    padding: const EdgeInsets.all(_backButtonPadding),
                    splashRadius: 22,
                  ),
                ),
                const SizedBox(width: _headerGap),
                Expanded(
                  child: Text(
                    context.l10n.settingsTitle,
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 30,
                      color: scheme.onSurface,
                      letterSpacing: -0.8,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: _titleToSectionGap),
            Padding(
              padding: const EdgeInsets.only(left: _sectionLabelIndent),
              child: Text(
                context.l10n.settingsGeneralTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: _sectionLabelFontSize,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: _sectionToGroupGap),
            SettingsJoinedGroup(
              children: <Widget>[
                SettingsActionRow(
                  icon: Icons.wifi_tethering_rounded,
                  title: context.l10n.settingsAutoStartListeningTitle,
                  subtitle: context.l10n.settingsAutoStartListeningDescription,
                  trailing: Switch(
                    value: settingsState.autoStartListening,
                    materialTapTargetSize: _compactSwitch
                        ? MaterialTapTargetSize.shrinkWrap
                        : MaterialTapTargetSize.padded,
                    onChanged: settingsState.isLoading
                        ? null
                        : (bool value) {
                            ref
                                .read(settingsControllerProvider.notifier)
                                .setAutoStartListening(value);
                          },
                  ),
                ),
                SettingsGroupDivider(color: scheme.outlineVariant),
                SettingsActionRow(
                  icon: Icons.filter_alt_outlined,
                  title: context.l10n.settingsIgnoredExtensionsTitle,
                  subtitle: settingsState.ignoredExtensions.isEmpty
                      ? context.l10n.settingsIgnoredExtensionsEmpty
                      : context.l10n.settingsIgnoredExtensionsSummary(
                          settingsState.ignoredExtensions.length,
                        ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: settingsState.isLoading
                      ? null
                      : () => showIgnoredFileTypesDialog(
                          context: context,
                          initialValues: settingsState.ignoredExtensions,
                          onSave: (List<String> values) {
                            return ref
                                .read(settingsControllerProvider.notifier)
                                .saveIgnoredExtensions(values);
                          },
                        ),
                ),
                SettingsGroupDivider(color: scheme.outlineVariant),
                SettingsActionRow(
                  icon: Icons.lock_outline_rounded,
                  title: context.l10n.settingsHttpEncryptionTitle,
                  subtitle: context.l10n.settingsHttpEncryptionDescription,
                  trailing: Switch(
                    value: settingsState.httpEncryptionEnabled,
                    materialTapTargetSize: _compactSwitch
                        ? MaterialTapTargetSize.shrinkWrap
                        : MaterialTapTargetSize.padded,
                    onChanged: settingsState.isLoading
                        ? null
                        : (bool value) {
                            ref
                                .read(settingsControllerProvider.notifier)
                                .setHttpEncryptionEnabled(value);
                          },
                  ),
                ),
              ],
            ),
            const SizedBox(height: _groupToGroupGap),
            Padding(
              padding: const EdgeInsets.only(left: _sectionLabelIndent),
              child: Text(
                context.l10n.settingsAppearanceTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: _sectionLabelFontSize,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: _sectionToGroupGap),
            SettingsJoinedGroup(
              children: <Widget>[
                SettingsActionRow(
                  icon: Icons.dark_mode_outlined,
                  title: context.l10n.settingsThemeModeTitle,
                  subtitle: _themeModeLabel(context, settingsState.themeMode),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: settingsState.isLoading
                      ? null
                      : () => showThemeModeDialog(
                          context: context,
                          ref: ref,
                          initialValue: settingsState.themeMode,
                        ),
                ),
                SettingsGroupDivider(color: scheme.outlineVariant),
                SettingsActionRow(
                  icon: Icons.palette_outlined,
                  title: context.l10n.settingsPaletteTitle,
                  subtitle: _paletteLabel(context, settingsState.palette),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: settingsState.isLoading
                      ? null
                      : () => showPaletteDialog(
                          context: context,
                          ref: ref,
                          initialValue: settingsState.palette,
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _themeModeLabel(BuildContext context, AppThemeModeSetting mode) {
    return switch (mode) {
      AppThemeModeSetting.light => context.l10n.settingsThemeModeLight,
      AppThemeModeSetting.dark => context.l10n.settingsThemeModeDark,
      AppThemeModeSetting.system => context.l10n.settingsThemeModeSystem,
    };
  }

  String _paletteLabel(BuildContext context, AppPaletteSetting palette) {
    return switch (palette) {
      AppPaletteSetting.neutral => context.l10n.settingsPaletteNeutral,
      AppPaletteSetting.expressive => context.l10n.settingsPaletteExpressive,
      AppPaletteSetting.tonalSpot => context.l10n.settingsPaletteTonalSpot,
    };
  }
}
