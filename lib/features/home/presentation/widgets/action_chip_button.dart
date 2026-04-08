import 'package:flutter/material.dart';

enum ActionChipTone {
  neutral,
  active,
  success,
}

class ActionChipButton extends StatelessWidget {
  const ActionChipButton({
    required this.label,
    required this.onPressed,
    this.tone = ActionChipTone.neutral,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final ActionChipTone tone;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isEnabled = onPressed != null;
    final (Color background, Color foreground, Color border) = switch (tone) {
      ActionChipTone.neutral => (
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant,
          scheme.outlineVariant,
        ),
      ActionChipTone.active => (
          scheme.secondaryContainer,
          scheme.onSecondaryContainer,
          scheme.secondary,
        ),
      ActionChipTone.success => (
          scheme.tertiaryContainer,
          scheme.onTertiaryContainer,
          scheme.tertiary,
        ),
    };
    final Color resolvedBackground = isEnabled
        ? background
        : scheme.surfaceContainerHighest.withValues(alpha: 0.5);
    final Color resolvedForeground =
        isEnabled ? foreground : scheme.onSurface.withValues(alpha: 0.38);
    final Color resolvedBorder = isEnabled
        ? border.withValues(alpha: 0.5)
        : scheme.outlineVariant.withValues(alpha: 0.35);

    return Material(
      color: resolvedBackground,
      borderRadius: BorderRadius.circular(999),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: resolvedBorder),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: resolvedForeground,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
