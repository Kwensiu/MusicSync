enum AppThemeModeSetting { system, light, dark }

enum AppPaletteSetting { neutral, expressive, tonalSpot }

class SettingsState {
  const SettingsState({
    this.isLoading = false,
    this.deviceAlias = '',
    this.deviceDisplayName = '',
    this.autoStartListening = false,
    this.httpEncryptionEnabled = true,
    this.ignoredExtensions = const <String>[],
    this.themeMode = AppThemeModeSetting.system,
    this.palette = AppPaletteSetting.neutral,
  });

  final bool isLoading;
  final String deviceAlias;
  final String deviceDisplayName;
  final bool autoStartListening;
  final bool httpEncryptionEnabled;
  final List<String> ignoredExtensions;
  final AppThemeModeSetting themeMode;
  final AppPaletteSetting palette;

  SettingsState copyWith({
    bool? isLoading,
    String? deviceAlias,
    String? deviceDisplayName,
    bool? autoStartListening,
    bool? httpEncryptionEnabled,
    List<String>? ignoredExtensions,
    AppThemeModeSetting? themeMode,
    AppPaletteSetting? palette,
  }) {
    return SettingsState(
      isLoading: isLoading ?? this.isLoading,
      deviceAlias: deviceAlias ?? this.deviceAlias,
      deviceDisplayName: deviceDisplayName ?? this.deviceDisplayName,
      autoStartListening: autoStartListening ?? this.autoStartListening,
      httpEncryptionEnabled:
          httpEncryptionEnabled ?? this.httpEncryptionEnabled,
      ignoredExtensions: ignoredExtensions ?? this.ignoredExtensions,
      themeMode: themeMode ?? this.themeMode,
      palette: palette ?? this.palette,
    );
  }
}
