import 'package:flutter/material.dart';

/// Shared spacing/radius scale for settings UI (4dp grid).
abstract final class SettingsUiScale {
  static const double radiusGroup = 20;
  static const double rowHorizontal = 16;
  static const double rowVertical = 16;
  static const double rowMinHeight = 60;
  static const double iconSize = 24;
  static const double iconToText = 16;
  static const double trailingGap = 8;
  static const double trailingSlotHeight = 32;
  static const double dividerStart = 20;
  static const double dividerEnd = 20;
}

class SettingsJoinedGroup extends StatelessWidget {
  const SettingsJoinedGroup({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(SettingsUiScale.radiusGroup),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(SettingsUiScale.radiusGroup),
        child: Column(children: children),
      ),
    );
  }
}

class SettingsActionRow extends StatelessWidget {
  const SettingsActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: SettingsUiScale.rowMinHeight,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SettingsUiScale.rowHorizontal,
              vertical: SettingsUiScale.rowVertical,
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  icon,
                  color: scheme.onSurfaceVariant,
                  size: SettingsUiScale.iconSize,
                ),
                const SizedBox(width: SettingsUiScale.iconToText),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                        ),
                        strutStyle: const StrutStyle(
                          height: 1.15,
                          forceStrutHeight: true,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.2,
                        ),
                        strutStyle: const StrutStyle(
                          height: 1.2,
                          forceStrutHeight: true,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: SettingsUiScale.trailingGap),
                SizedBox(
                  height: SettingsUiScale.trailingSlotHeight,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: trailing,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsGroupDivider extends StatelessWidget {
  const SettingsGroupDivider({required this.color, super.key});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: SettingsUiScale.dividerStart,
        right: SettingsUiScale.dividerEnd,
      ),
      child: Divider(
        height: 1,
        thickness: 1,
        color: color.withValues(alpha: 0.3),
      ),
    );
  }
}
