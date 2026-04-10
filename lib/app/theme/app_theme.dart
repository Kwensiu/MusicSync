import 'package:flutter/material.dart';
import 'package:music_sync/app/theme/app_colors.dart';

abstract final class AppTheme {
  static ThemeData light({
    DynamicSchemeVariant variant = DynamicSchemeVariant.neutral,
  }) {
    return _buildTheme(brightness: Brightness.light, variant: variant);
  }

  static ThemeData dark({
    DynamicSchemeVariant variant = DynamicSchemeVariant.neutral,
  }) {
    return _buildTheme(brightness: Brightness.dark, variant: variant);
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required DynamicSchemeVariant variant,
  }) {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: brightness,
      dynamicSchemeVariant: variant,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surfaceContainerLowest,
      appBarTheme: const AppBarTheme(centerTitle: false),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: colorScheme.surfaceContainerLow,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
          side: BorderSide.none,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
      ),
      switchTheme: SwitchThemeData(
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        thumbIcon: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) {
            return Icon(
              Icons.check_rounded,
              size: 14,
              color: colorScheme.primaryContainer,
            );
          }
          return const Icon(Icons.close_rounded, size: 14);
        }),
        thumbColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.onPrimaryContainer;
          }
          return colorScheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primaryContainer;
          }
          return colorScheme.surfaceContainerHighest;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((
          Set<WidgetState> states,
        ) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primaryContainer;
          }
          return colorScheme.outlineVariant;
        }),
        trackOutlineWidth: const WidgetStatePropertyAll<double>(1),
      ),
    );
  }
}
