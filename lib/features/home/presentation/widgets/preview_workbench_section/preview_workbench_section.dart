import 'package:flutter/material.dart';
import 'package:music_sync/core/errors/app_error_localizer.dart';
import 'package:music_sync/core/utils/byte_format.dart';
import 'package:music_sync/features/connection/state/connection_state.dart'
    as peer_connection;
import 'package:music_sync/features/directory/state/directory_state.dart';
import 'package:music_sync/features/execution/state/execution_state.dart';
import 'package:music_sync/features/preview/state/preview_state.dart';
import 'package:music_sync/l10n/app_localizations_ext.dart';

class PreviewWorkbenchSection extends StatelessWidget {
  const PreviewWorkbenchSection({
    super.key,
    required this.directoryState,
    required this.connectionState,
    required this.previewState,
    required this.executionState,
    required this.scanWarnings,
    required this.isStalePlan,
    required this.isBusy,
    required this.isExecuting,
    required this.canStartRemoteSync,
    required this.showExecutionPanel,
    required this.hasRemoteDirectoryReady,
    required this.sourceDeviceLabel,
    required this.targetDeviceLabel,
    required this.isTransferConnected,
    required this.onBuildRemotePreview,
    required this.onStartRemoteSync,
    required this.onCancelSync,
    required this.localizeUiError,
    required this.localizedExecutionStatus,
    required this.isScanTimeoutError,
    this.sourceRiskMessage,
    this.showMetaStatus = true,
    this.showActionButtons = true,
    this.showBuildPreviewButton = true,
    this.showExecutionMetrics = true,
    this.conflictCount = 0,
    this.onViewConflicts,
  });

  final DirectoryState directoryState;
  final peer_connection.ConnectionState connectionState;
  final PreviewState previewState;
  final ExecutionState executionState;
  final List<String> scanWarnings;
  final bool isStalePlan;
  final bool isBusy;
  final bool isExecuting;
  final bool canStartRemoteSync;
  final bool showExecutionPanel;
  final bool hasRemoteDirectoryReady;
  final String sourceDeviceLabel;
  final String targetDeviceLabel;
  final bool isTransferConnected;
  final Future<void> Function() onBuildRemotePreview;
  final Future<void> Function() onStartRemoteSync;
  final VoidCallback onCancelSync;
  final String Function(BuildContext context, String value) localizeUiError;
  final String Function(BuildContext context, ExecutionStatus status)
  localizedExecutionStatus;
  final bool Function(String value) isScanTimeoutError;
  final String? sourceRiskMessage;
  final bool showMetaStatus;
  final bool showActionButtons;
  final bool showBuildPreviewButton;
  final bool showExecutionMetrics;
  final int conflictCount;
  final VoidCallback? onViewConflicts;

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
    final bool showExecutionProgress =
        executionState.status == ExecutionStatus.running;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (showMetaStatus)
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
            if (sourceRiskMessage != null) ...<Widget>[
              const SizedBox(height: 12),
              _CompactNotice(
                tone: _NoticeTone.warning,
                text: sourceRiskMessage!,
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
            if (conflictCount > 0) ...<Widget>[
              const SizedBox(height: 12),
              _ConflictEntryChip(count: conflictCount, onTap: onViewConflicts),
            ],
            if (showActionButtons) ...<Widget>[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  if (showBuildPreviewButton)
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
            ],
            if (showExecutionPanel) ...<Widget>[
              const SizedBox(height: 12),
              _ExecutionPanel(
                child: showExecutionProgress
                    ? Column(
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
                              text: localizeUiError(
                                context,
                                executionErrorMessage,
                              ),
                            ),
                          ],
                        ],
                      )
                    : _ExecutionResultPanel(
                        executionState: executionState,
                        localizedExecutionStatus: localizedExecutionStatus,
                        localizeUiError: localizeUiError,
                        showMetrics: showExecutionMetrics,
                      ),
              ),
            ],
          ],
        ),
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
        detail: isScanTimeoutError(errorMessage)
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

class _ExecutionResultPanel extends StatelessWidget {
  const _ExecutionResultPanel({
    required this.executionState,
    required this.localizedExecutionStatus,
    required this.localizeUiError,
    required this.showMetrics,
  });

  final ExecutionState executionState;
  final String Function(BuildContext context, ExecutionStatus status)
  localizedExecutionStatus;
  final String Function(BuildContext context, String value) localizeUiError;
  final bool showMetrics;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? errorMessage = executionState.errorMessage;
    final String? resolvedError = errorMessage == null
        ? null
        : AppErrorLocalizer.resolve(errorMessage);
    final bool isCancelledError = resolvedError == AppErrorCode.syncCancelled;
    final bool hasFailedItems = executionState.result.failedCount > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (showMetrics) ...<Widget>[
          Text(
            context.l10n.executionResultProcessed(
              executionState.progress.processedFiles,
              executionState.progress.totalFiles,
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _ResultMetricChip(
                icon: Icons.content_copy_rounded,
                label:
                    '${context.l10n.executionMetricCopy} ${executionState.result.copiedCount}',
              ),
              _ResultMetricChip(
                icon: Icons.delete_outline_rounded,
                label:
                    '${context.l10n.executionMetricDelete} ${executionState.result.deletedCount}',
              ),
              _ResultMetricChip(
                icon: Icons.error_outline_rounded,
                label:
                    '${context.l10n.executionMetricFailed} ${executionState.result.failedCount}',
              ),
              _ResultMetricChip(
                icon: Icons.data_usage_rounded,
                label: formatBytes(executionState.result.totalBytes),
              ),
              if (executionState.result.skippedConflictCount > 0)
                _ResultMetricChip(
                  icon: Icons.warning_amber_rounded,
                  label: context.l10n.executionSkippedConflict(
                    executionState.result.copiedCount +
                        executionState.result.deletedCount,
                    executionState.result.skippedConflictCount,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        if (executionState.status == ExecutionStatus.completed &&
            !hasFailedItems) ...<Widget>[
          _InlineMessage(
            tone: _InlineMessageTone.success,
            text: context.l10n.executionResultDone,
          ),
        ] else if (executionState.status == ExecutionStatus.completed &&
            hasFailedItems) ...<Widget>[
          _InlineMessage(
            tone: _InlineMessageTone.warning,
            text: errorMessage == null
                ? context.l10n.executionResultFailed
                : localizeUiError(context, errorMessage),
          ),
        ] else if (isCancelledError) ...<Widget>[
          _InlineMessage(
            tone: _InlineMessageTone.warning,
            text: localizeUiError(context, errorMessage!),
          ),
        ] else if (executionState.status == ExecutionStatus.failed) ...<Widget>[
          _InlineMessage(
            tone: _InlineMessageTone.error,
            text: errorMessage == null
                ? context.l10n.executionResultFailed
                : localizeUiError(context, errorMessage),
          ),
        ],
      ],
    );
  }
}

class _ResultMetricChip extends StatelessWidget {
  const _ResultMetricChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 14, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
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

class _ConflictEntryChip extends StatelessWidget {
  const _ConflictEntryChip({required this.count, this.onTap});

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
