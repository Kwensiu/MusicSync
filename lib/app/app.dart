import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:music_sync/app/routes/app_router.dart';
import 'package:music_sync/app/theme/app_theme.dart';
import 'package:music_sync/features/connection/state/connection_controller.dart';
import 'package:music_sync/features/settings/state/settings_controller.dart';
import 'package:music_sync/features/settings/state/settings_state.dart';
import 'package:music_sync/l10n/generated/app_localizations.dart';

class MusicSyncApp extends ConsumerStatefulWidget {
  const MusicSyncApp({super.key});

  @override
  ConsumerState<MusicSyncApp> createState() => _MusicSyncAppState();
}

class _MusicSyncAppState extends ConsumerState<MusicSyncApp> {
  bool _startupListenerApplied = false;

  Future<void> _maybeStartListeningOnLaunch() async {
    if (_startupListenerApplied || !mounted) {
      return;
    }
    final settingsState = ref.read(settingsControllerProvider);
    if (settingsState.isLoading || !settingsState.autoStartListening) {
      return;
    }
    final connectionState = ref.read(connectionControllerProvider);
    if (connectionState.isListening) {
      _startupListenerApplied = true;
      return;
    }
    _startupListenerApplied = true;
    await ref.read(connectionControllerProvider.notifier).startListening();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeStartListeningOnLaunch();
    });
  }

  @override
  Widget build(BuildContext context) {
    final GoRouter router = ref.watch(appRouterProvider);
    final settingsState = ref.watch(settingsControllerProvider);
    final DynamicSchemeVariant schemeVariant = _schemeVariant(
      settingsState.palette,
    );
    final ThemeMode themeMode = _themeMode(settingsState.themeMode);

    if (!_startupListenerApplied &&
        !settingsState.isLoading &&
        settingsState.autoStartListening) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybeStartListeningOnLaunch();
      });
    }

    return MaterialApp.router(
      onGenerateTitle: (BuildContext context) =>
          AppLocalizations.of(context)!.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(variant: schemeVariant),
      darkTheme: AppTheme.dark(variant: schemeVariant),
      themeMode: themeMode,
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }

  ThemeMode _themeMode(AppThemeModeSetting mode) {
    return switch (mode) {
      AppThemeModeSetting.system => ThemeMode.system,
      AppThemeModeSetting.light => ThemeMode.light,
      AppThemeModeSetting.dark => ThemeMode.dark,
    };
  }

  DynamicSchemeVariant _schemeVariant(AppPaletteSetting palette) {
    return switch (palette) {
      AppPaletteSetting.neutral => DynamicSchemeVariant.neutral,
      AppPaletteSetting.expressive => DynamicSchemeVariant.expressive,
      AppPaletteSetting.tonalSpot => DynamicSchemeVariant.tonalSpot,
    };
  }
}
