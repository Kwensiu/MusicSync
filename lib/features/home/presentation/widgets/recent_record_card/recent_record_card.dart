import 'package:flutter/material.dart';
import 'package:music_sync/l10n/app_localizations_ext.dart';

class RecentRecordCard extends StatelessWidget {
  const RecentRecordCard({
    super.key,
    required this.title,
    required this.onUse,
    required this.onEditRecord,
    required this.onDelete,
    this.subtitle,
    this.dragHandle,
  });

  final String title;
  final String? subtitle;
  final Widget? dragHandle;
  final VoidCallback onUse;
  final VoidCallback onEditRecord;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool hasSubtitle = subtitle != null && subtitle!.isNotEmpty;
    return Material(
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onUse,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              if (dragHandle != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 24,
                    child: Center(child: dragHandle!),
                  ),
                ),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Expanded(
                      child: hasSubtitle
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  subtitle!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                        height: 1.15,
                                      ),
                                ),
                              ],
                            )
                          : Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: context.l10n.homeRecentAlias,
                      visualDensity: VisualDensity.compact,
                      onPressed: onEditRecord,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: context.l10n.homeRecentDelete,
                      visualDensity: VisualDensity.compact,
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
