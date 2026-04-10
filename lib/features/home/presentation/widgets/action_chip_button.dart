import 'package:flutter/material.dart';

enum ActionChipTone { neutral, active, success }

class ActionChipButton extends StatelessWidget {
  const ActionChipButton({
    required this.label,
    required this.onPressed,
    this.tone = ActionChipTone.neutral,
    this.compact = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final ActionChipTone tone;
  final bool compact;

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
        : scheme.surfaceContainerHigh;
    final Color resolvedForeground = isEnabled
        ? foreground
        : scheme.onSurfaceVariant;
    final Color resolvedBorder = isEnabled ? border : scheme.outlineVariant;

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
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 14,
              vertical: compact ? 7 : 10,
            ),
            child: Text(
              label,
              style:
                  (compact
                          ? Theme.of(context).textTheme.labelMedium
                          : Theme.of(context).textTheme.labelLarge)
                      ?.copyWith(
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
