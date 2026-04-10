import 'package:flutter/material.dart';
import 'package:music_sync/core/utils/path_display_format.dart';
import 'package:music_sync/features/directory/state/directory_state.dart';
import 'package:music_sync/l10n/app_localizations_ext.dart';
import 'package:music_sync/services/file_access/file_access_entry.dart';

class SourceDirectorySection extends StatelessWidget {
  const SourceDirectorySection({
    super.key,
    required this.directoryState,
    required this.isBusy,
    required this.hasRemoteDirectoryReady,
    required this.isCleaningSourceTemp,
    required this.onPickDirectory,
    required this.onClearDirectory,
    required this.onCleanupTempFiles,
    required this.onManageRecentDirectories,
    required this.onUseRecentDirectory,
    required this.localizePreflightReason,
  });

  final DirectoryState directoryState;
  final bool isBusy;
  final bool hasRemoteDirectoryReady;
  final bool isCleaningSourceTemp;
  final VoidCallback onPickDirectory;
  final VoidCallback onClearDirectory;
  final VoidCallback onCleanupTempFiles;
  final VoidCallback onManageRecentDirectories;
  final ValueChanged<DirectoryHandle> onUseRecentDirectory;
  final String Function(BuildContext context, String value)
  localizePreflightReason;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final DirectoryHandle? selectedHandle = directoryState.handle;
    final bool hasSelection = selectedHandle != null;
    final bool hasRisk = directoryState.preflight?.hasRisk == true;
    final String sourceLabel =
        selectedHandle?.displayName ?? context.l10n.homePickDirectory;
    final String? sourceDetail = selectedHandle == null
        ? null
        : selectedHandle.entryId == selectedHandle.displayName
        ? null
        : formatDisplayPath(selectedHandle.entryId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: hasRisk ? scheme.errorContainer : scheme.outlineVariant,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: hasSelection
                            ? scheme.primaryContainer
                            : scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.folder_outlined,
                        color: hasSelection
                            ? scheme.onPrimaryContainer
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            sourceLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (sourceDetail != null) ...<Widget>[
                            const SizedBox(height: 2),
                            Text(
                              sourceDetail,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: hasSelection
                          ? IconButton(
                              tooltip: context.l10n.homeClearSelection,
                              visualDensity: VisualDensity.compact,
                              onPressed: isBusy ? null : onClearDirectory,
                              icon: const Icon(Icons.close_rounded, size: 18),
                            )
                          : null,
                    ),
                  ],
                ),
                if (directoryState.errorMessage != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    directoryState.errorMessage!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: scheme.error),
                  ),
                ],
                if (hasRisk) ...<Widget>[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: scheme.errorContainer.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          context.l10n.directoryPreflightWarningTitle,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: scheme.onErrorContainer),
                        ),
                        const SizedBox(height: 6),
                        ...directoryState.preflight!.reasons
                            .take(2)
                            .map(
                              (String reason) => Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text(
                                  localizePreflightReason(context, reason),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: scheme.onErrorContainer,
                                      ),
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed: isBusy ? null : onPickDirectory,
                    child: Text(context.l10n.homePickDirectory),
                  ),
                ),
                if (directoryState.hasTempFiles) ...<Widget>[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton(
                      onPressed:
                          isBusy ||
                              selectedHandle == null ||
                              isCleaningSourceTemp
                          ? null
                          : onCleanupTempFiles,
                      child: Text(context.l10n.homeCleanupTempFiles),
                    ),
                  ),
                ],
                if (directoryState.recentHandles.isNotEmpty) ...<Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          context.l10n.homeRecentDirectories,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      IconButton(
                        tooltip: context.l10n.homeManageRecentItems,
                        onPressed: isBusy ? null : onManageRecentDirectories,
                        icon: const Icon(Icons.tune_rounded),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: directoryState.recentHandles.map((handle) {
                      final bool isCurrent =
                          directoryState.handle?.entryId == handle.entryId;
                      return ActionChip(
                        backgroundColor: isCurrent
                            ? scheme.secondaryContainer
                            : scheme.surface,
                        side: BorderSide(
                          color: isCurrent
                              ? scheme.secondary
                              : scheme.outlineVariant,
                        ),
                        avatar: isCurrent
                            ? Icon(
                                Icons.check_circle_outline,
                                size: 18,
                                color: scheme.onSecondaryContainer,
                              )
                            : null,
                        label: Text(
                          directoryState.recentLabels[handle.entryId] ??
                              handle.displayName,
                        ),
                        onPressed: isBusy || isCurrent
                            ? null
                            : () => onUseRecentDirectory(handle),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
