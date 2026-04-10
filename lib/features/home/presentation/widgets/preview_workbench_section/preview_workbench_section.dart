import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:music_sync/app/routes/route_names.dart';
import 'package:music_sync/core/errors/app_error_localizer.dart';
import 'package:music_sync/core/utils/byte_format.dart';
import 'package:music_sync/features/connection/state/connection_state.dart'
    as peer_connection;
import 'package:music_sync/features/directory/state/directory_state.dart';
import 'package:music_sync/features/execution/state/execution_state.dart';
import 'package:music_sync/features/home/presentation/widgets/preview_workbench_section/preview_plan_section.dart';
import 'package:music_sync/features/preview/state/preview_state.dart';
import 'package:music_sync/l10n/app_localizations_ext.dart';
import 'package:music_sync/models/diff_item.dart';

class PreviewWorkbenchSection extends StatelessWidget {
  const PreviewWorkbenchSection({
    super.key,
    required this.directoryState,
    required this.connectionState,
    required this.previewState,
    required this.executionState,
    required this.ignoredExtensions,
    required this.filteredCopyItems,
    required this.filteredDeleteItems,
    required this.filteredConflictItems,
    required this.activeItems,
    required this.extensionOptions,
    required this.scanWarnings,
    required this.isStalePlan,
    required this.isBusy,
    required this.isExecuting,
    required this.canStartRemoteSync,
    required this.canOpenResult,
    required this.showExecutionPanel,
    required this.hasRemoteDirectoryReady,
    required this.isAllExtensionsSelected,
    required this.selectAllSections,
    required this.selectedSections,
    required this.selectedExtensions,
    required this.sourceDeviceLabel,
    required this.targetDeviceLabel,
    required this.isTransferConnected,
    required this.onBuildRemotePreview,
    required this.onStartRemoteSync,
    required this.onCancelSync,
    required this.onToggleSection,
    required this.onToggleExtension,
    required this.localizeUiError,
    required this.localizedExecutionStatus,
    required this.isScanTimeoutError,
  });

  final DirectoryState directoryState;
  final peer_connection.ConnectionState connectionState;
  final PreviewState previewState;
  final ExecutionState executionState;
  final List<String> ignoredExtensions;
  final List<DiffItem> filteredCopyItems;
  final List<DiffItem> filteredDeleteItems;
  final List<DiffItem> filteredConflictItems;
  final List<DiffItem> activeItems;
  final List<String> extensionOptions;
  final List<String> scanWarnings;
  final bool isStalePlan;
  final bool isBusy;
  final bool isExecuting;
  final bool canStartRemoteSync;
  final bool canOpenResult;
  final bool showExecutionPanel;
  final bool hasRemoteDirectoryReady;
  final bool isAllExtensionsSelected;
  final bool selectAllSections;
  final Set<DiffType> selectedSections;
  final Set<String> selectedExtensions;
  final String sourceDeviceLabel;
  final String targetDeviceLabel;
  final bool isTransferConnected;
  final Future<void> Function() onBuildRemotePreview;
  final Future<void> Function() onStartRemoteSync;
  final VoidCallback onCancelSync;
  final ValueChanged<DiffType?> onToggleSection;
  final ValueChanged<String> onToggleExtension;
  final String Function(BuildContext context, String value) localizeUiError;
  final String Function(BuildContext context, ExecutionStatus status)
  localizedExecutionStatus;
  final bool Function(String value) isScanTimeoutError;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool hasPlanItems =
        previewState.plan.copyItems.isNotEmpty ||
        previewState.plan.deleteItems.isNotEmpty ||
        previewState.plan.conflictItems.isNotEmpty;
    final bool hasPreviewReady =
        previewState.status == PreviewStatus.loaded && hasPlanItems;
    final bool hasLocalDirectory = directoryState.handle != null;
    final bool hasRemoteDirectory =
        connectionState.isRemoteDirectoryReady ||
        connectionState.remoteSnapshot != null;
    final _PrimaryStatus? primaryStatus = _buildPrimaryStatus(context);
    final String? executionErrorMessage = executionState.errorMessage;
    final String? resolvedExecutionError = executionErrorMessage == null
        ? null
        : AppErrorLocalizer.resolve(executionErrorMessage);
    final bool showExecutionInlineError =
        executionErrorMessage != null &&
        resolvedExecutionError != AppErrorCode.remoteDirectoryNotSelected &&
        resolvedExecutionError != AppErrorCode.remoteDeviceDisconnected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _InfoPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _MetaChipGroup(
                    label: context.l10n.previewTransferDirectionLabel,
                    chip: _TransferStatusChip(
                      sourceLabel: sourceDeviceLabel,
                      targetLabel: targetDeviceLabel,
                      connected: isTransferConnected,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _MetaChipGroup(
                    label: context.l10n.previewDirectoryStatusLabel,
                    chip: _DirectoryStatusChip(
                      hasLocalDirectory: hasLocalDirectory,
                      hasRemoteDirectory: hasRemoteDirectory,
                    ),
                  ),
                ],
              ),
              if (primaryStatus != null) ...<Widget>[
                const SizedBox(height: 12),
                _InlineMessage(
                  tone: primaryStatus.tone,
                  text: primaryStatus.text,
                  detail: primaryStatus.detail,
                ),
              ],
              if (scanWarnings.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                _CompactNotice(
                  tone: _NoticeTone.warning,
                  text: context.l10n.previewPartialScanWarning(
                    scanWarnings.length,
                  ),
                  detail: context.l10n.previewPartialScanAdvice,
                  extraLines: scanWarnings
                      .take(3)
                      .map(context.l10n.previewSkippedPath)
                      .toList(),
                ),
              ],
              if (isStalePlan) ...<Widget>[
                const SizedBox(height: 12),
                _CompactNotice(
                  tone: _NoticeTone.warning,
                  text: context.l10n.previewStalePlan,
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  FilledButton.tonalIcon(
                    onPressed:
                        isBusy ||
                            directoryState.handle == null ||
                            !hasRemoteDirectoryReady
                        ? null
                        : onBuildRemotePreview,
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
                  else if (hasPreviewReady)
                    FilledButton.icon(
                      onPressed: canStartRemoteSync ? onStartRemoteSync : null,
                      icon: const Icon(Icons.sync_rounded),
                      label: Text(context.l10n.executionRunRemote),
                    ),
                ],
              ),
              if (showExecutionPanel) ...<Widget>[
                const SizedBox(height: 12),
                _ExecutionPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        localizedExecutionStatus(
                          context,
                          executionState.status,
                        ),
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                        value: executionState.progress.totalBytes > 0
                            ? executionState.progress.processedBytes /
                                  executionState.progress.totalBytes
                            : null,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${context.l10n.executionProgressFiles(executionState.progress.processedFiles, executionState.progress.totalFiles)}  ·  ${formatBytes(executionState.progress.processedBytes)} / ${formatBytes(executionState.progress.totalBytes)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      if (executionState.progress.currentPath !=
                          null) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          context.l10n.executionCurrentFile(
                            executionState.progress.currentPath!,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (showExecutionInlineError) ...<Widget>[
                        const SizedBox(height: 10),
                        _InlineMessage(
                          tone: _InlineMessageTone.error,
                          text: localizeUiError(context, executionErrorMessage),
                        ),
                      ],
                      if (canOpenResult) ...<Widget>[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FilledButton.tonalIcon(
                            onPressed: () =>
                                context.pushNamed(RouteNames.result),
                            icon: const Icon(Icons.task_alt_rounded),
                            label: Text(context.l10n.executionOpenResult),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        if (hasPlanItems) ...<Widget>[
          const SizedBox(height: 12),
          PreviewPlanSection(
            header: _FilterPanel(
              sectionTitle: context.l10n.previewSectionTitle,
              sectionChild: Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    <_SectionOption>[
                      _SectionOption(
                        type: null,
                        label:
                            '${context.l10n.previewSectionAll} ${filteredCopyItems.length + filteredDeleteItems.length}',
                      ),
                      _SectionOption(
                        type: DiffType.copy,
                        label:
                            '${context.l10n.previewSectionCopy} ${filteredCopyItems.length}',
                      ),
                      _SectionOption(
                        type: DiffType.delete,
                        label:
                            '${context.l10n.previewSectionDelete} ${filteredDeleteItems.length}',
                      ),
                    ].map((option) {
                      final bool selected = option.type == null
                          ? selectAllSections
                          : (!selectAllSections &&
                                selectedSections.contains(option.type));
                      return _CompactFilterChip(
                        label: option.label,
                        selected: selected,
                        onSelected: (_) => onToggleSection(option.type),
                      );
                    }).toList(),
              ),
              filterTitle: extensionOptions.length > 1
                  ? context.l10n.previewFilterTitle
                  : null,
              filterSummary:
                  extensionOptions.length > 1 && ignoredExtensions.isNotEmpty
                  ? context.l10n.previewIgnoredExtensions(
                      ignoredExtensions
                          .map((String value) => '.$value')
                          .join(', '),
                    )
                  : null,
              filterChild: extensionOptions.length > 1
                  ? Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: extensionOptions.map((String extension) {
                        final bool selected = extension == '*'
                            ? isAllExtensionsSelected
                            : selectedExtensions.contains(extension);
                        return _CompactFilterChip(
                          label: extension == '*'
                              ? context.l10n.previewFilterAll
                              : extension,
                          selected: selected,
                          onSelected: isBusy
                              ? null
                              : (_) => onToggleExtension(extension),
                        );
                      }).toList(),
                    )
                  : null,
            ),
            items: activeItems,
            conflictItems: filteredConflictItems,
            targetIsRemote: previewState.mode == PreviewMode.remote,
          ),
        ],
      ],
    );
  }

  _PrimaryStatus? _buildPrimaryStatus(BuildContext context) {
    final String? errorMessage = previewState.errorMessage;
    if (errorMessage != null) {
      final String resolvedError = AppErrorLocalizer.resolve(errorMessage);
      if (resolvedError == AppErrorCode.remoteDirectoryNotSelected ||
          resolvedError == AppErrorCode.remoteDeviceDisconnected) {
        return null;
      }
      return _PrimaryStatus(
        tone: _InlineMessageTone.error,
        text: localizeUiError(context, errorMessage),
        detail: !isScanTimeoutError(errorMessage)
            ? context.l10n.previewScanTimeout
            : null,
      );
    }
    return null;
  }
}

class _PrimaryStatus {
  const _PrimaryStatus({required this.tone, required this.text, this.detail});

  final _InlineMessageTone tone;
  final String text;
  final String? detail;
}

enum _InlineMessageTone { neutral, success, warning, error }

enum _NoticeTone { warning }

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Padding(padding: const EdgeInsets.all(14), child: child),
      ),
    );
  }
}

class _ExecutionPanel extends StatelessWidget {
  const _ExecutionPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Padding(padding: const EdgeInsets.all(12), child: child),
      ),
    );
  }
}

class _TransferStatusChip extends StatelessWidget {
  const _TransferStatusChip({
    required this.sourceLabel,
    required this.targetLabel,
    required this.connected,
  });

  final String sourceLabel;
  final String targetLabel;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color iconColor = connected
        ? scheme.primary
        : scheme.onSurfaceVariant;
    final IconData icon = connected
        ? Icons.arrow_forward_rounded
        : Icons.link_off_rounded;
    final Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Flexible(
          child: Text(
            sourceLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        Flexible(
          child: Text(
            targetLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: content,
    );
  }
}

class _MetaChipGroup extends StatelessWidget {
  const _MetaChipGroup({required this.label, required this.chip});

  final String label;
  final Widget chip;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        chip,
      ],
    );
  }
}

class _DirectoryStatusChip extends StatelessWidget {
  const _DirectoryStatusChip({
    required this.hasLocalDirectory,
    required this.hasRemoteDirectory,
  });

  final bool hasLocalDirectory;
  final bool hasRemoteDirectory;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _DirectoryStatusItem(
            active: hasLocalDirectory,
            label: context.l10n.previewDirectoryStatusLocal,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '|',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          _DirectoryStatusItem(
            active: hasRemoteDirectory,
            label: context.l10n.previewDirectoryStatusRemote,
          ),
        ],
      ),
    );
  }
}

class _DirectoryStatusItem extends StatelessWidget {
  const _DirectoryStatusItem({required this.active, required this.label});

  final bool active;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color color = active ? scheme.primary : scheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          active ? Icons.check_circle_rounded : Icons.close_rounded,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: color),
        ),
      ],
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.tone, required this.text, this.detail});

  final _InlineMessageTone tone;
  final String text;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final (Color background, Color foreground, IconData icon) = switch (tone) {
      _InlineMessageTone.success => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
        Icons.check_circle_outline_rounded,
      ),
      _InlineMessageTone.warning => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
        Icons.warning_amber_rounded,
      ),
      _InlineMessageTone.error => (
        scheme.errorContainer,
        scheme.onErrorContainer,
        Icons.error_outline_rounded,
      ),
      _InlineMessageTone.neutral => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
        Icons.info_outline_rounded,
      ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  text,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: foreground),
                ),
                if (detail != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    detail!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: foreground),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactNotice extends StatelessWidget {
  const _CompactNotice({
    required this.tone,
    required this.text,
    this.detail,
    this.extraLines = const <String>[],
  });

  final _NoticeTone tone;
  final String text;
  final String? detail;
  final List<String> extraLines;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final (Color foreground, IconData icon) = switch (tone) {
      _NoticeTone.warning => (
        scheme.onSurfaceVariant,
        Icons.info_outline_rounded,
      ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  text,
                  style: theme.textTheme.bodySmall?.copyWith(color: foreground),
                ),
                if (detail != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    detail!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: foreground,
                    ),
                  ),
                ],
                if (extraLines.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  ...extraLines.map(
                    (String line) => Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        line,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: foreground,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionOption {
  const _SectionOption({required this.type, required this.label});

  final DiffType? type;
  final String label;
}

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.sectionTitle,
    required this.sectionChild,
    this.filterTitle,
    this.filterSummary,
    this.filterChild,
  });

  final String sectionTitle;
  final Widget sectionChild;
  final String? filterTitle;
  final String? filterSummary;
  final Widget? filterChild;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _FilterHeader(title: sectionTitle),
          const SizedBox(height: 8),
          sectionChild,
          if (filterChild != null && filterTitle != null) ...<Widget>[
            const SizedBox(height: 10),
            _FilterHeader(
              title: filterTitle!,
              trailing: filterSummary == null
                  ? null
                  : Text(
                      filterSummary!,
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            filterChild!,
          ],
        ],
      ),
    );
  }
}

class _FilterHeader extends StatelessWidget {
  const _FilterHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Row(
      children: <Widget>[
        Text(
          title,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
          ),
        ),
        if (trailing != null) ...<Widget>[
          const SizedBox(width: 12),
          Expanded(child: trailing!),
        ],
      ],
    );
  }
}

class _CompactFilterChip extends StatelessWidget {
  const _CompactFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelPadding: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}
