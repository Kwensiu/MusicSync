import 'package:flutter/material.dart';
import 'package:music_sync/app/widgets/app_scaffold.dart';
import 'package:music_sync/app/widgets/section_card.dart';
import 'package:music_sync/l10n/app_localizations_x.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: context.l10n.settingsTitle,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SectionCard(
          title: context.l10n.settingsDefaultsTitle,
          child: Text(context.l10n.settingsDefaultsPlaceholder),
        ),
      ),
    );
  }
}
