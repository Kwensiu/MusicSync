import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:music_sync/app/routes/route_names.dart';
import 'package:music_sync/core/utils/byte_format.dart';
import 'package:music_sync/features/connection/state/connection_state.dart'
    as peer_connection;
import 'package:music_sync/features/directory/state/directory_state.dart';
import 'package:music_sync/features/execution/state/execution_state.dart';
import 'package:music_sync/features/preview/state/preview_state.dart';
import 'package:music_sync/l10n/app_localizations_ext.dart';
import 'package:music_sync/models/diff_item.dart';

typedef PreviewSectionBuilder = Widget Function(
  BuildContext context, {
  required List<DiffItem> items,
  required List<DiffItem> conflictItems,
  required bool targetIsRemote,
});

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
    required this.transferDirectionLabel,
    required this.onBuildRemotePreview,
    required this.onStartRemoteSync,
    required this.onCancelSync,
    required this.onToggleSection,
    required this.onToggleExtension,
    required this.buildSection,
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
  final String transferDirectionLabel;
  final Future<void> Function() onBuildRemotePreview;
  final Future<void> Function() onStartRemoteSync;
  final VoidCallback onCancelSync;
  final ValueChanged<DiffType?> onToggleSection;
  final ValueChanged<String> onToggleExtension;
  final PreviewSectionBuilder buildSection;
  final String Function(BuildContext context, String value) localizeUiError;
  final String Function(BuildContext context, ExecutionStatus status)
      localizedExecutionStatus;
  final bool Function(String value) isScanTimeoutError;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool hasPlanItems = previewState.plan.copyItems.isNotEmpty ||
        previewState.plan.deleteItems.isNotEmpty ||
        previewState.plan.conflictItems.isNotEmpty;
    final bool hasPreviewReady =
        previewState.status == PreviewStatus.loaded && hasPlanItems;
    final bool hasLocalDirectory = directoryState.handle != null;
    final bool hasRemoteDirectory = connectionState.isRemoteDirectoryReady ||
        connectionState.remoteSnapshot != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _InfoPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _MetaChipGroup(
                    label: context.l10n.previewTransferDirectionLabel,
                    chip: _MetaChip(
                      label: transferDirectionLabel,
                      maxWidth: MediaQuery.sizeOf(context).width * 0.42,
                    ),
                  ),
                  _MetaChipGroup(
                    label: context.l10n.previewDirectoryStatusLabel,
                    chip: _DirectoryStatusChip(
                      hasLocalDirectory: hasLocalDirectory,
                      hasRemoteDirectory: hasRemoteDirectory,
                    ),
                  ),
                ],
              ),
              if (previewState.errorMessage != null) ...<Widget>[
                const SizedBox(height: 12),
                _InlineMessage(
                  tone: _InlineMessageTone.error,
                  text: localizeUiError(context, previewState.errorMessage!),
                  detail: !isScanTimeoutError(previewState.errorMessage!)
                      ? context.l10n.previewScanTimeout
                      : null,
                ),
              ],
              if (scanWarnings.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                _InlineMessage(
                  tone: _InlineMessageTone.warning,
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
                _InlineMessage(
                  tone: _InlineMessageTone.warning,
                  text: context.l10n.previewStalePlan,
                ),
              ],
              if (directoryState.handle == null ||
                  !hasRemoteDirectoryReady) ...<Widget>[
                const SizedBox(height: 12),
                _InlineMessage(
                  tone: _InlineMessageTone.neutral,
                  text: directoryState.handle == null
                      ? context.l10n.previewDirectoryRequired
                      : context.l10n.previewRemoteDirectoryRequired,
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      FilledButton.tonalIcon(
                        onPressed: isBusy ||
                                directoryState.handle == null ||
                                !hasRemoteDirectoryReady
                            ? null
                            : onBuildRemotePreview,
                        style: FilledButton.styleFrom(
                          backgroundColor: scheme.tertiaryContainer,
                          foregroundColor: scheme.onTertiaryContainer,
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
                          onPressed:
                              canStartRemoteSync ? onStartRemoteSync : null,
                          icon: const Icon(Icons.sync_rounded),
                          label: Text(context.l10n.executionRunRemote),
                        ),
                    ],
                  ),
                ],
              ),
              if (showExecutionPanel) ...<Widget>[
                const SizedBox(height: 12),
                _InfoPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _MetaChip(
                        label: context.l10n.executionStateLabel(
                          localizedExecutionStatus(
                              context, executionState.status),
                        ),
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
                      const SizedBox(height: 4),
                      Text(
                        executionState.progress.currentPath != null
                            ? context.l10n.executionCurrentFile(
                                executionState.progress.currentPath!,
                              )
                            : context.l10n.executionProgressPlaceholder,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      if (executionState.errorMessage != null) ...<Widget>[
                        const SizedBox(height: 10),
                        _InlineMessage(
                          tone: _InlineMessageTone.error,
                          text: localizeUiError(
                            context,
                            executionState.errorMessage!,
                          ),
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
        const SizedBox(height: 12),
        if (hasPlanItems) ...<Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  context.l10n.previewSectionTitle,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <_SectionOption>[
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
              return FilterChip(
                label: Text(option.label),
                selected: selected,
                onSelected: (_) => onToggleSection(option.type),
              );
            }).toList(),
          ),
          if (extensionOptions.length > 1) ...<Widget>[
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Text(
                  context.l10n.previewFilterTitle,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (ignoredExtensions.isNotEmpty) ...<Widget>[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.l10n.previewIgnoredExtensions(
                        ignoredExtensions
                            .map((String value) => '.$value')
                            .join(', '),
                      ),
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
                if (ignoredExtensions.isEmpty) const Spacer(),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: extensionOptions.map((String extension) {
                final bool selected = extension == '*'
                    ? isAllExtensionsSelected
                    : selectedExtensions.contains(extension);
                return FilterChip(
                  label: Text(
                    extension == '*'
                        ? context.l10n.previewFilterAll
                        : extension,
                  ),
                  selected: selected,
                  onSelected:
                      isBusy ? null : (_) => onToggleExtension(extension),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 10),
          buildSection(
            context,
            items: activeItems,
            conflictItems: filteredConflictItems,
            targetIsRemote: previewState.mode == PreviewMode.remote,
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}

enum _InlineMessageTone {
  neutral,
  success,
  warning,
  error,
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.child,
  });

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
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: child,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.label,
    this.maxWidth,
  });

  final String label;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Widget text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: maxWidth == null
          ? text
          : ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth!),
              child: text,
            ),
    );
  }
}

class _MetaChipGroup extends StatelessWidget {
  const _MetaChipGroup({
    required this.label,
    required this.chip,
  });

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
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
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
  const _DirectoryStatusItem({
    required this.active,
    required this.label,
  });

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
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
              ),
        ),
      ],
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({
    required this.tone,
    required this.text,
    this.detail,
    this.extraLines = const <String>[],
  });

  final _InlineMessageTone tone;
  final String text;
  final String? detail;
  final List<String> extraLines;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final (Color background, Color foreground, IconData icon) = switch (tone) {
      _InlineMessageTone.success => (
          scheme.tertiaryContainer.withValues(alpha: 0.8),
          scheme.onTertiaryContainer,
          Icons.check_circle_outline_rounded,
        ),
      _InlineMessageTone.warning => (
          scheme.secondaryContainer.withValues(alpha: 0.72),
          scheme.onSecondaryContainer,
          Icons.warning_amber_rounded,
        ),
      _InlineMessageTone.error => (
          scheme.errorContainer.withValues(alpha: 0.82),
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
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: foreground,
                      ),
                ),
                if (detail != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    detail!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: foreground.withValues(alpha: 0.88),
                        ),
                  ),
                ],
                if (extraLines.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  ...extraLines.map(
                    (String line) => Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        line,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: foreground.withValues(alpha: 0.88),
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
  const _SectionOption({
    required this.type,
    required this.label,
  });

  final DiffType? type;
  final String label;
}
