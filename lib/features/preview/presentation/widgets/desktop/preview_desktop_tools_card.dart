import 'package:flutter/material.dart';
import 'package:music_sync/core/utils/byte_format.dart';
import 'package:music_sync/l10n/app_localizations_ext.dart';
import 'package:music_sync/models/sync_plan.dart';

class PreviewDesktopToolsCard extends StatelessWidget {
  const PreviewDesktopToolsCard({
    required this.sourceDeviceLabel,
    required this.targetDeviceLabel,
    required this.isTransferConnected,
    required this.hasLocalDirectory,
    required this.hasRemoteDirectory,
    required this.showActionButtons,
    required this.showBuildPreviewButton,
    required this.conflictCount,
    required this.canBuildPreview,
    required this.canStartSync,
    required this.isExecuting,
    required this.onBuildPreview,
    required this.onStartSync,
    required this.onCancelSync,
    this.onViewConflicts,
    required this.extensionOptions,
    required this.selectedExtensions,
    required this.excludedExtensions,
    required this.ignoredExtensions,
    required this.isAllExtensionsSelected,
    required this.isBusy,
    required this.onToggleExtension,
    required this.onLongPressExtension,
    required this.summary,
    required this.previewStatusLoaded,
    super.key,
  });

  final String sourceDeviceLabel;
  final String targetDeviceLabel;
  final bool isTransferConnected;
  final bool hasLocalDirectory;
  final bool hasRemoteDirectory;
  final bool showActionButtons;
  final bool showBuildPreviewButton;
  final int conflictCount;
  final bool canBuildPreview;
  final bool canStartSync;
  final bool isExecuting;
  final Future<void> Function() onBuildPreview;
  final Future<void> Function() onStartSync;
  final VoidCallback onCancelSync;
  final VoidCallback? onViewConflicts;
  final List<String> extensionOptions;
  final Set<String> selectedExtensions;
  final Set<String> excludedExtensions;
  final List<String> ignoredExtensions;
  final bool isAllExtensionsSelected;
  final bool isBusy;
  final ValueChanged<String> onToggleExtension;
  final ValueChanged<String> onLongPressExtension;
  final SyncPlanSummary summary;
  final bool previewStatusLoaded;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              context.l10n.previewDesktopToolsTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            _EnvironmentStatusBlock(
              sourceDeviceLabel: sourceDeviceLabel,
              targetDeviceLabel: targetDeviceLabel,
              isTransferConnected: isTransferConnected,
              hasLocalDirectory: hasLocalDirectory,
              hasRemoteDirectory: hasRemoteDirectory,
            ),
            if (showActionButtons) ...<Widget>[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  if (showBuildPreviewButton)
                    FilledButton.tonalIcon(
                      onPressed: canBuildPreview ? onBuildPreview : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.secondaryContainer,
                        foregroundColor: scheme.onSecondaryContainer,
                      ),
                      icon: const Icon(Icons.file_download_rounded),
                      label: Text(context.l10n.previewBuildRemotePlan),
                    ),
                  if (isExecuting)
                    FilledButton.icon(
                      onPressed: onCancelSync,
                      icon: const Icon(Icons.stop_rounded),
                      label: Text(context.l10n.executionStop),
                    )
                  else
                    FilledButton.icon(
                      onPressed: canStartSync ? onStartSync : null,
                      icon: const Icon(Icons.sync_rounded),
                      label: Text(context.l10n.executionRunRemote),
                    ),
                ],
              ),
            ],
            if (conflictCount > 0) ...<Widget>[
              const SizedBox(height: 12),
              _ConflictActionChip(count: conflictCount, onTap: onViewConflicts),
            ],
            const SizedBox(height: 12),
            _SummaryChips(
              summary: summary,
              previewStatusLoaded: previewStatusLoaded,
            ),
            if (extensionOptions.length > 1) ...<Widget>[
              const SizedBox(height: 12),
              Divider(height: 1, color: scheme.outlineVariant),
              const SizedBox(height: 12),
              Text(
                context.l10n.previewFilterTitle,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
              if (ignoredExtensions.isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  context.l10n.previewIgnoredExtensions(
                    ignoredExtensions.map((String v) => '.$v').join(', '),
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: extensionOptions.map((String extension) {
                  final bool excluded = excludedExtensions.contains(extension);
                  final bool selected = extension == '*'
                      ? isAllExtensionsSelected
                      : (!excluded && selectedExtensions.contains(extension));
                  return _DesktopFilterChip(
                    label: extension == '*'
                        ? context.l10n.previewFilterAll
                        : extension,
                    selected: selected,
                    excluded: excluded,
                    onSelected: isBusy || excluded
                        ? null
                        : (_) => onToggleExtension(extension),
                    onLongPress: extension == '*' || isBusy
                        ? null
                        : () => onLongPressExtension(extension),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConflictActionChip extends StatelessWidget {
  const _ConflictActionChip({required this.count, this.onTap});

  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.errorContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.errorContainer),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.warning_amber_rounded,
              size: 18,
              color: scheme.onErrorContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.l10n.previewConflictCount(count),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onErrorContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: scheme.onErrorContainer,
              ),
          ],
        ),
      ),
    );
  }
}

class _SummaryChips extends StatelessWidget {
  const _SummaryChips({
    required this.summary,
    required this.previewStatusLoaded,
  });

  final SyncPlanSummary summary;
  final bool previewStatusLoaded;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    final List<Widget> chips = <Widget>[
      _SummaryChip(
        icon: Icons.content_copy_rounded,
        label: '${summary.copyCount}',
        background: scheme.surfaceContainerHighest,
        foreground: scheme.onSurfaceVariant,
      ),
      _SummaryChip(
        icon: Icons.delete_outline_rounded,
        label: '${summary.deleteCount}',
        background: summary.deleteCount > 0
            ? scheme.secondaryContainer
            : scheme.surfaceContainerHighest,
        foreground: summary.deleteCount > 0
            ? scheme.onSecondaryContainer
            : scheme.onSurfaceVariant,
      ),
    ];

    if (summary.copyBytes > 0) {
      chips.add(
        _SummaryChip(
          icon: Icons.data_usage_rounded,
          label: formatBytes(summary.copyBytes),
          background: scheme.surfaceContainerHighest,
          foreground: scheme.onSurfaceVariant,
        ),
      );
    }

    if (previewStatusLoaded &&
        summary.copyCount == 0 &&
        summary.deleteCount == 0 &&
        summary.conflictCount == 0) {
      chips.add(
        _SummaryChip(
          icon: Icons.check_circle_outline_rounded,
          label: context.l10n.previewNoSyncItems,
          background: scheme.tertiaryContainer,
          foreground: scheme.onTertiaryContainer,
        ),
      );
    }

    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: foreground),
            ),
          ],
        ),
      ),
    );
  }
}

class _EnvironmentStatusBlock extends StatelessWidget {
  const _EnvironmentStatusBlock({
    required this.sourceDeviceLabel,
    required this.targetDeviceLabel,
    required this.isTransferConnected,
    required this.hasLocalDirectory,
    required this.hasRemoteDirectory,
  });

  final String sourceDeviceLabel;
  final String targetDeviceLabel;
  final bool isTransferConnected;
  final bool hasLocalDirectory;
  final bool hasRemoteDirectory;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final String transferText = isTransferConnected
        ? '$sourceDeviceLabel -> $targetDeviceLabel'
        : '$sourceDeviceLabel / $targetDeviceLabel';
    final String directoryText =
        '${context.l10n.previewDirectoryStatusLocal} ${hasLocalDirectory ? "OK" : "--"} · ${context.l10n.previewDirectoryStatusRemote} ${hasRemoteDirectory ? "OK" : "--"}';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.compare_arrows_rounded,
                  size: 14,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    transferText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                Icon(
                  Icons.folder_outlined,
                  size: 14,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    directoryText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopFilterChip extends StatelessWidget {
  const _DesktopFilterChip({
    required this.label,
    required this.selected,
    this.excluded = false,
    required this.onSelected,
    this.onLongPress,
  });

  final String label;
  final bool selected;
  final bool excluded;
  final ValueChanged<bool>? onSelected;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    if (excluded) {
      return GestureDetector(
        onLongPress: onLongPress,
        child: InputChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.block, size: 14, color: scheme.error),
              const SizedBox(width: 4),
              Text(label),
            ],
          ),
          selected: false,
          onPressed: null,
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          labelPadding: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          side: BorderSide(color: scheme.error),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          labelStyle: TextStyle(color: scheme.error),
          disabledColor: scheme.surfaceContainerHighest,
        ),
      );
    }

    return GestureDetector(
      onLongPress: onLongPress,
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: onSelected,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        labelPadding: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
