enum AppThemeModeSetting { system, light, dark }

enum AppPaletteSetting { neutral, expressive, tonalSpot }

class SettingsState {
  const SettingsState({
    this.isLoading = false,
    this.autoStartListening = false,
    this.ignoredExtensions = const <String>[],
    this.themeMode = AppThemeModeSetting.system,
    this.palette = AppPaletteSetting.neutral,
  });

  final bool isLoading;
  final bool autoStartListening;
  final List<String> ignoredExtensions;
  final AppThemeModeSetting themeMode;
  final AppPaletteSetting palette;

  SettingsState copyWith({
    bool? isLoading,
    bool? autoStartListening,
    List<String>? ignoredExtensions,
    AppThemeModeSetting? themeMode,
    AppPaletteSetting? palette,
  }) {
    return SettingsState(
      isLoading: isLoading ?? this.isLoading,
      autoStartListening: autoStartListening ?? this.autoStartListening,
      ignoredExtensions: ignoredExtensions ?? this.ignoredExtensions,
      themeMode: themeMode ?? this.themeMode,
      palette: palette ?? this.palette,
    );
  }
}
