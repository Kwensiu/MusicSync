import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:music_sync/app/routes/route_names.dart';
import 'package:music_sync/app/widgets/app_confirm_dialog.dart';
import 'package:music_sync/app/widgets/app_page_content.dart';
import 'package:music_sync/app/widgets/app_scaffold.dart';
import 'package:music_sync/app/widgets/section_card.dart';
import 'package:music_sync/core/errors/app_error_localizer.dart';
import 'package:music_sync/core/utils/byte_format.dart';
import 'package:music_sync/features/connection/state/connection_controller.dart';
import 'package:music_sync/features/connection/state/connection_state.dart'
    as peer_connection;
import 'package:music_sync/features/directory/state/directory_controller.dart';
import 'package:music_sync/features/directory/state/directory_state.dart';
import 'package:music_sync/features/execution/state/execution_controller.dart';
import 'package:music_sync/features/execution/state/execution_state.dart';
import 'package:music_sync/features/home/presentation/widgets/preview_workbench_section/preview_workbench_actions.dart';
import 'package:music_sync/features/home/presentation/widgets/preview_workbench_section/preview_workbench_section.dart';
import 'package:music_sync/features/preview/presentation/widgets/desktop/preview_desktop_workbench.dart';
import 'package:music_sync/features/preview/presentation/widgets/preview_result_list_section.dart';
import 'package:music_sync/features/preview/state/preview_controller.dart';
import 'package:music_sync/features/preview/state/preview_state.dart';
import 'package:music_sync/features/settings/state/settings_controller.dart';
import 'package:music_sync/features/settings/state/settings_state.dart';
import 'package:music_sync/l10n/app_localizations_ext.dart';
import 'package:music_sync/models/diff_item.dart';
import 'package:music_sync/models/sync_plan.dart';
import 'package:music_sync/services/file_access/file_access_provider.dart';
import 'package:music_sync/services/platform/android_background_runtime.dart';
import 'package:music_sync/services/scanning/temp_file_cleanup_service.dart';
import 'package:smooth_list_view/smooth_list_view.dart';

class PreviewPage extends ConsumerStatefulWidget {
  const PreviewPage({super.key});

  @override
  ConsumerState<PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends ConsumerState<PreviewPage>
    with WidgetsBindingObserver {
  Set<String> _selectedExtensions = <String>{'*'};
  bool _selectAllSections = true;
  Set<DiffType> _selectedSections = <DiffType>{DiffType.copy, DiffType.delete};
  bool _isCleaningTargetTemp = false;
  AppLifecycleState? _appLifecycleState;
  late final ScrollController _scrollController;
  static const Duration _scrollDuration = Duration(milliseconds: 140);

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appLifecycleState = state;
    _syncAndroidKeepAlive(
      connectionState: ref.read(connectionControllerProvider),
      executionState: ref.read(executionControllerProvider),
    );
    if (state != AppLifecycleState.resumed || !mounted) {
      return;
    }
    final peer_connection.ConnectionState connectionState = ref.read(
      connectionControllerProvider,
    );
    final ExecutionState executionState = ref.read(executionControllerProvider);
    if (connectionState.peer == null ||
        connectionState.status != peer_connection.ConnectionStatus.connected ||
        executionState.status == ExecutionStatus.running) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      await ref
          .read(connectionControllerProvider.notifier)
          .refreshRemoteSnapshot(clearTransientState: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<peer_connection.ConnectionState>(connectionControllerProvider, (
      _,
      peer_connection.ConnectionState next,
    ) {
      _syncAndroidKeepAlive(
        connectionState: next,
        executionState: ref.read(executionControllerProvider),
      );
    });
    ref.listen<ExecutionState>(executionControllerProvider, (
      _,
      ExecutionState next,
    ) {
      _syncAndroidKeepAlive(
        connectionState: ref.read(connectionControllerProvider),
        executionState: next,
      );
    });
    final DirectoryState directoryState = ref.watch(
      directoryControllerProvider,
    );
    final peer_connection.ConnectionState connectionState = ref.watch(
      connectionControllerProvider,
    );
    final PreviewState previewState = ref.watch(previewControllerProvider);
    final ExecutionState executionState = ref.watch(
      executionControllerProvider,
    );
    final settingsState = ref.watch(settingsControllerProvider);
    final List<String> ignoredExtensions = settingsState.ignoredExtensions;

    final bool isStalePlan =
        previewState.sourceRootId != null &&
        previewState.sourceRootId != directoryState.handle?.entryId;
    final List<String> extensionOptions = previewState.availableExtensions;
    final List<DiffItem> filteredCopyItems =
        PreviewWorkbenchActions.filterItemsByExtensions(
          previewState.plan.copyItems,
          _selectedExtensions,
        );
    final List<DiffItem> filteredDeleteItems =
        PreviewWorkbenchActions.filterItemsByExtensions(
          previewState.plan.deleteItems,
          _selectedExtensions,
        );
    final List<DiffItem> filteredConflictItems =
        PreviewWorkbenchActions.filterItemsByExtensions(
          previewState.plan.conflictItems,
          _selectedExtensions,
        );
    final bool isAllExtensionsSelected =
        _selectedExtensions.length == 1 && _selectedExtensions.contains('*');
    final List<DiffItem> activeItems = <DiffItem>[
      if (_selectAllSections || _selectedSections.contains(DiffType.copy))
        ...filteredCopyItems,
      if (_selectAllSections || _selectedSections.contains(DiffType.delete))
        ...filteredDeleteItems,
    ];
    final SyncPlanSummary planSummary = _buildVisibleSummary(
      filteredCopyItems: filteredCopyItems,
      filteredDeleteItems: filteredDeleteItems,
      filteredConflictItems: filteredConflictItems,
      selectAllSections: _selectAllSections,
      selectedSections: _selectedSections,
    );
    final bool hasExecutableItems =
        previewState.plan.copyItems.isNotEmpty ||
        previewState.plan.deleteItems.isNotEmpty;
    final bool isRemotePreview = previewState.mode == PreviewMode.remote;
    final bool isLocalPreview = previewState.mode == PreviewMode.local;
    final bool canRunRemote =
        connectionState.remoteSnapshot != null &&
        isRemotePreview &&
        previewState.targetSnapshot?.rootId ==
            connectionState.remoteSnapshot!.rootId;
    final bool isConnecting =
        connectionState.status == peer_connection.ConnectionStatus.connecting;
    final bool isPreviewLoading = previewState.status == PreviewStatus.loading;
    final bool isExecuting = executionState.status == ExecutionStatus.running;
    final bool isRemoteSyncRunning =
        executionState.status == ExecutionStatus.running &&
        executionState.mode == ExecutionMode.remote;
    final bool isBusy = isConnecting || isPreviewLoading || isExecuting;
    final bool hasRemoteSnapshot = connectionState.remoteSnapshot != null;
    final bool hasRemoteDirectoryReady =
        connectionState.isRemoteDirectoryReady || hasRemoteSnapshot;
    final bool canStartRemoteSync =
        canRunRemote && hasExecutableItems && !isBusy;
    final bool hasFinishedExecution =
        executionState.status == ExecutionStatus.completed ||
        executionState.status == ExecutionStatus.cancelled ||
        executionState.status == ExecutionStatus.failed;
    final bool showExecutionPanel = isExecuting || hasFinishedExecution;
    final List<String> scanWarnings = <String>{
      ...?previewState.sourceSnapshot?.warnings,
      ...?previewState.targetSnapshot?.warnings,
    }.toList();
    final bool showKeepAliveBadge =
        Platform.isAndroid &&
        connectionState.peer != null &&
        connectionState.status == peer_connection.ConnectionStatus.connected &&
        isRemoteSyncRunning;

    return AppScaffold(
      title: context.l10n.previewTitle,
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool isDesktop = constraints.maxWidth >= 900;

          if (isDesktop) {
            return Stack(
              children: <Widget>[
                AppPageContent(
                  child: Column(
                    children: <Widget>[
                      if (showExecutionPanel)
                        PreviewWorkbenchSection(
                          directoryState: directoryState,
                          connectionState: connectionState,
                          previewState: previewState,
                          executionState: executionState,
                          scanWarnings: scanWarnings,
                          isStalePlan: isStalePlan,
                          isBusy: isBusy,
                          isExecuting: isExecuting,
                          canStartRemoteSync: canStartRemoteSync,
                          showExecutionPanel: showExecutionPanel,
                          hasRemoteDirectoryReady: hasRemoteDirectoryReady,
                          sourceDeviceLabel: _localDeviceDisplayName(
                            settingsState,
                          ),
                          targetDeviceLabel: _targetDeviceDisplayName(
                            context,
                            connectionState: connectionState,
                            previewState: previewState,
                          ),
                          isTransferConnected:
                              connectionState.peer != null &&
                              connectionState.status ==
                                  peer_connection.ConnectionStatus.connected,
                          onBuildRemotePreview: directoryState.handle == null
                              ? () async {}
                              : () =>
                                    PreviewWorkbenchActions.buildRemotePreview(
                                      ref: ref,
                                      sourceRoot: directoryState.handle!,
                                      ignoredExtensions: ignoredExtensions,
                                    ),
                          onStartRemoteSync: () =>
                              PreviewWorkbenchActions.executeRemoteSyncFlow(
                                context: context,
                                ref: ref,
                                previewState: previewState,
                                directoryState: directoryState,
                                connectionState: connectionState,
                              ),
                          onCancelSync: () {
                            ref
                                .read(executionControllerProvider.notifier)
                                .cancel();
                          },
                          localizeUiError: _localizeUiError,
                          localizedExecutionStatus: _localizedExecutionStatus,
                          isScanTimeoutError: _isScanTimeoutError,
                          showMetaStatus: false,
                          showExecutionMetrics: false,
                          showActionButtons: false,
                          showBuildPreviewButton: false,
                        ),
                      if (previewState.status ==
                          PreviewStatus.loaded) ...<Widget>[
                        if (showExecutionPanel) const SizedBox(height: 16),
                        const Expanded(child: PreviewDesktopWorkbench()),
                      ],
                      if (isLocalPreview || executionState.targetRoot != null)
                        _buildLocalExecutionSection(
                          context: context,
                          executionState: executionState,
                          isBusy: isBusy,
                          hasExecutableItems: hasExecutableItems,
                          isLocalPreview: isLocalPreview,
                          previewState: previewState,
                          directoryState: directoryState,
                        ),
                    ],
                  ),
                ),
                if (showKeepAliveBadge)
                  Positioned(
                    left: 12,
                    top: 12,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          child: Text(
                            '🏷 后台保活已就绪',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onTertiaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          }

          return Stack(
            children: <Widget>[
              AppPageContent(
                child: Scrollbar(
                  controller: _scrollController,
                  child: SmoothListView(
                    duration: _scrollDuration,
                    curve: Curves.easeOutCubic,
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    children: <Widget>[
                      SectionCard(
                        title: context.l10n.previewSummaryTitle,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            _PlanSummaryWrap(
                              previewState: previewState,
                              summary: planSummary,
                            ),
                            const SizedBox(height: 16),
                            PreviewWorkbenchSection(
                              directoryState: directoryState,
                              connectionState: connectionState,
                              previewState: previewState,
                              executionState: executionState,
                              scanWarnings: scanWarnings,
                              isStalePlan: isStalePlan,
                              isBusy: isBusy,
                              isExecuting: isExecuting,
                              canStartRemoteSync: canStartRemoteSync,
                              showExecutionPanel: showExecutionPanel,
                              hasRemoteDirectoryReady: hasRemoteDirectoryReady,
                              sourceDeviceLabel: _localDeviceDisplayName(
                                settingsState,
                              ),
                              targetDeviceLabel: _targetDeviceDisplayName(
                                context,
                                connectionState: connectionState,
                                previewState: previewState,
                              ),
                              isTransferConnected:
                                  connectionState.peer != null &&
                                  connectionState.status ==
                                      peer_connection
                                          .ConnectionStatus
                                          .connected,
                              onBuildRemotePreview:
                                  directoryState.handle == null
                                  ? () async {}
                                  : () =>
                                        PreviewWorkbenchActions.buildRemotePreview(
                                          ref: ref,
                                          sourceRoot: directoryState.handle!,
                                          ignoredExtensions: ignoredExtensions,
                                        ),
                              onStartRemoteSync: () =>
                                  PreviewWorkbenchActions.executeRemoteSyncFlow(
                                    context: context,
                                    ref: ref,
                                    previewState: previewState,
                                    directoryState: directoryState,
                                    connectionState: connectionState,
                                  ),
                              onCancelSync: () {
                                ref
                                    .read(executionControllerProvider.notifier)
                                    .cancel();
                              },
                              localizeUiError: _localizeUiError,
                              localizedExecutionStatus:
                                  _localizedExecutionStatus,
                              isScanTimeoutError: _isScanTimeoutError,
                            ),
                          ],
                        ),
                      ),
                      if (previewState.status ==
                          PreviewStatus.loaded) ...<Widget>[
                        const SizedBox(height: 16),
                        SectionCard(
                          title: context.l10n.previewPlanItemsTitle,
                          child: PreviewResultListSection(
                            filteredCopyItems: filteredCopyItems,
                            filteredDeleteItems: filteredDeleteItems,
                            activeItems: activeItems,
                            extensionOptions: extensionOptions,
                            ignoredExtensions: ignoredExtensions,
                            excludedExtensions: previewState.excludedExtensions,
                            isAllExtensionsSelected: isAllExtensionsSelected,
                            selectAllSections: _selectAllSections,
                            selectedSections: _selectedSections,
                            selectedExtensions: _selectedExtensions,
                            isBusy: isBusy,
                            previewMode: previewState.mode,
                            onToggleSection: (DiffType? type) {
                              setState(() {
                                if (type == null) {
                                  _selectAllSections = true;
                                  _selectedSections = <DiffType>{
                                    DiffType.copy,
                                    DiffType.delete,
                                  };
                                  return;
                                }
                                final Set<DiffType> next = _selectAllSections
                                    ? <DiffType>{type}
                                    : <DiffType>{..._selectedSections};
                                _selectAllSections = false;
                                if (next.contains(type)) {
                                  next.remove(type);
                                } else {
                                  next.add(type);
                                }
                                if (next.isEmpty) {
                                  next.add(type);
                                }
                                _selectedSections = next;
                              });
                            },
                            onToggleExtension: (String extension) {
                              setState(() {
                                final bool selected = extension == '*'
                                    ? isAllExtensionsSelected
                                    : _selectedExtensions.contains(extension);
                                _selectedExtensions =
                                    PreviewWorkbenchActions.toggleExtensionSelection(
                                      current: _selectedExtensions,
                                      extension: extension,
                                      selected: !selected,
                                    );
                              });
                            },
                            onLongPressExtension: (String extension) {
                              HapticFeedback.mediumImpact();
                              final bool wasExcluded = previewState
                                  .excludedExtensions
                                  .contains(extension);
                              ref
                                  .read(previewControllerProvider.notifier)
                                  .toggleExcludedExtension(extension);
                              setState(() {
                                if (!wasExcluded) {
                                  _selectedExtensions = _selectedExtensions
                                    ..remove(extension);
                                  if (_selectedExtensions.isEmpty) {
                                    _selectedExtensions = <String>{'*'};
                                  }
                                }
                              });
                              if (!mounted) return;
                              final String message = wasExcluded
                                  ? context.l10n.previewExtensionRestored(
                                      extension,
                                    )
                                  : context.l10n.previewExtensionExcluded(
                                      extension,
                                    );
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text(message)));
                            },
                          ),
                        ),
                      ],
                      if (filteredConflictItems.isNotEmpty &&
                          previewState.status ==
                              PreviewStatus.loaded) ...<Widget>[
                        const SizedBox(height: 16),
                        _ConflictEntryCard(
                          conflictCount: filteredConflictItems.length,
                          onTap: () {
                            context.goNamed(RouteNames.previewConflicts);
                          },
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (isLocalPreview || executionState.targetRoot != null)
                        _buildLocalExecutionSection(
                          context: context,
                          executionState: executionState,
                          isBusy: isBusy,
                          hasExecutableItems: hasExecutableItems,
                          isLocalPreview: isLocalPreview,
                          previewState: previewState,
                          directoryState: directoryState,
                        ),
                    ],
                  ),
                ),
              ),
              if (showKeepAliveBadge)
                Positioned(
                  left: 12,
                  top: 12,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Text(
                          '🏷 后台保活已就绪',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onTertiaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  SyncPlanSummary _buildVisibleSummary({
    required List<DiffItem> filteredCopyItems,
    required List<DiffItem> filteredDeleteItems,
    required List<DiffItem> filteredConflictItems,
    required bool selectAllSections,
    required Set<DiffType> selectedSections,
  }) {
    final List<DiffItem> visibleCopyItems =
        selectAllSections || selectedSections.contains(DiffType.copy)
        ? filteredCopyItems
        : const <DiffItem>[];
    final List<DiffItem> visibleDeleteItems =
        selectAllSections || selectedSections.contains(DiffType.delete)
        ? filteredDeleteItems
        : const <DiffItem>[];

    return SyncPlanSummary(
      copyCount: visibleCopyItems.length,
      deleteCount: visibleDeleteItems.length,
      conflictCount: filteredConflictItems.length,
      copyBytes: visibleCopyItems.fold<int>(
        0,
        (int total, DiffItem item) => total + (item.source?.size ?? 0),
      ),
    );
  }

  Widget _buildLocalExecutionSection({
    required BuildContext context,
    required ExecutionState executionState,
    required bool isBusy,
    required bool hasExecutableItems,
    required bool isLocalPreview,
    required PreviewState previewState,
    required DirectoryState directoryState,
  }) {
    return ExpansionTile(
      title: Text(context.l10n.homeAdvancedTitle),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SectionCard(
            title: context.l10n.executionTargetTitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(context.l10n.executionTargetHint),
                const SizedBox(height: 8),
                Text(
                  executionState.targetRoot ?? context.l10n.executionNoTarget,
                ),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: isBusy
                      ? null
                      : () async {
                          final handle = await ref
                              .read(fileAccessGatewayProvider)
                              .pickDirectory();
                          ref
                              .read(executionControllerProvider.notifier)
                              .setTargetRoot(handle?.entryId);
                        },
                  child: Text(context.l10n.executionPickTarget),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed:
                      isBusy ||
                          executionState.targetRoot == null ||
                          _isCleaningTargetTemp
                      ? null
                      : () => _cleanupTempFiles(
                          rootId: executionState.targetRoot!,
                        ),
                  child: Text(context.l10n.homeCleanupTempFiles),
                ),
                const SizedBox(height: 8),
                FilledButton.tonal(
                  onPressed:
                      isBusy ||
                          executionState.targetRoot == null ||
                          !hasExecutableItems ||
                          !isLocalPreview
                      ? null
                      : () async {
                          if (previewState.plan.deleteItems.isNotEmpty) {
                            final bool? confirmed = await showDialog<bool>(
                              context: context,
                              builder: (BuildContext context) {
                                return AppConfirmDialog(
                                  title:
                                      context.l10n.executionConfirmDeleteTitle,
                                  message: context.l10n
                                      .executionConfirmDeleteBody(
                                        previewState.plan.deleteItems.length,
                                      ),
                                );
                              },
                            );
                            if (confirmed != true) {
                              return;
                            }
                          }
                          await ref
                              .read(executionControllerProvider.notifier)
                              .execute(
                                plan: previewState.plan,
                                targetRoot: executionState.targetRoot!,
                              );
                          await PreviewWorkbenchActions.refreshPreviewAfterExecution(
                            ref: ref,
                            previewState: previewState,
                            directoryState: directoryState,
                            executionState: ref.read(
                              executionControllerProvider,
                            ),
                          );
                        },
                  child: Text(context.l10n.executionRunLocalDebug),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _localizedExecutionStatus(
    BuildContext context,
    ExecutionStatus status,
  ) {
    switch (status) {
      case ExecutionStatus.idle:
        return context.l10n.statusIdle;
      case ExecutionStatus.running:
        return context.l10n.statusLoading;
      case ExecutionStatus.cancelled:
        return context.l10n.resultStatusCancelled;
      case ExecutionStatus.completed:
        return context.l10n.resultStatusCompleted;
      case ExecutionStatus.failed:
        return context.l10n.resultStatusFailed;
    }
  }

  bool _isScanTimeoutError(String value) {
    return AppErrorLocalizer.isScanTimeout(value);
  }

  String _localizeUiError(BuildContext context, String value) {
    return AppErrorLocalizer.localize(context, value);
  }

  String _targetDeviceDisplayName(
    BuildContext context, {
    required peer_connection.ConnectionState connectionState,
    required PreviewState previewState,
  }) {
    return switch (previewState.mode) {
      PreviewMode.remote =>
        connectionState.peer?.deviceName ?? context.l10n.previewDirectionRemote,
      PreviewMode.local => context.l10n.previewDirectionLocalTarget,
      PreviewMode.none =>
        connectionState.peer?.deviceName ?? context.l10n.previewDirectionRemote,
    };
  }

  String _localDeviceDisplayName(SettingsState settingsState) {
    final String displayName = settingsState.deviceDisplayName.trim();
    if (displayName.isNotEmpty) {
      return displayName;
    }
    final String alias = settingsState.deviceAlias.trim();
    if (alias.isNotEmpty) {
      return alias;
    }
    return Platform.isAndroid
        ? 'Android'
        : Platform.isWindows
        ? 'Windows'
        : Platform.operatingSystem;
  }

  void _syncAndroidKeepAlive({
    required peer_connection.ConnectionState connectionState,
    required ExecutionState executionState,
  }) {
    final bool isRemoteSyncRunning =
        executionState.status == ExecutionStatus.running &&
        executionState.mode == ExecutionMode.remote;
    final bool shouldEnable =
        Platform.isAndroid &&
        _appLifecycleState != null &&
        _appLifecycleState != AppLifecycleState.resumed &&
        connectionState.peer != null &&
        connectionState.status == peer_connection.ConnectionStatus.connected &&
        isRemoteSyncRunning;
    AndroidBackgroundRuntime.setKeepAliveEnabled(shouldEnable);
  }

  Future<void> _cleanupTempFiles({required String rootId}) async {
    setState(() {
      _isCleaningTargetTemp = true;
    });
    try {
      final result = await ref
          .read(tempFileCleanupServiceProvider)
          .cleanup(rootId: rootId);
      if (!mounted) {
        return;
      }
      final String message = result.failedPaths.isEmpty
          ? context.l10n.homeCleanupTempSuccess(result.deletedCount)
          : context.l10n.homeCleanupTempPartial(
              result.deletedCount,
              result.failedPaths.length,
            );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.homeCleanupTempFailed)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCleaningTargetTemp = false;
        });
      }
    }
  }
}

class _PlanSummaryWrap extends StatelessWidget {
  const _PlanSummaryWrap({required this.previewState, required this.summary});

  final PreviewState previewState;
  final SyncPlanSummary summary;

  @override
  Widget build(BuildContext context) {
    final List<Widget> chips = <Widget>[
      _SummaryChip(
        label: context.l10n.previewCopyCount(summary.copyCount),
        tone: _SummaryChipTone.neutral,
      ),
      _SummaryChip(
        label: context.l10n.previewDeleteCount(summary.deleteCount),
        tone: summary.deleteCount > 0
            ? _SummaryChipTone.warning
            : _SummaryChipTone.neutral,
      ),
      _SummaryChip(
        label: context.l10n.previewConflictCount(summary.conflictCount),
        tone: summary.conflictCount > 0
            ? _SummaryChipTone.danger
            : _SummaryChipTone.neutral,
      ),
    ];

    if (summary.copyBytes > 0) {
      chips.add(
        _SummaryChip(
          label: context.l10n.previewCopyBytes(formatBytes(summary.copyBytes)),
          tone: _SummaryChipTone.neutral,
        ),
      );
    }

    if (previewState.status == PreviewStatus.loaded &&
        summary.copyCount == 0 &&
        summary.deleteCount == 0 &&
        summary.conflictCount == 0) {
      chips.add(
        _SummaryChip(
          label: context.l10n.previewNoSyncItems,
          tone: _SummaryChipTone.success,
        ),
      );
    }

    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }
}

enum _SummaryChipTone { neutral, warning, danger, success }

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.tone});

  final String label;
  final _SummaryChipTone tone;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final (Color background, Color foreground) = switch (tone) {
      _SummaryChipTone.neutral => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
      _SummaryChipTone.warning => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      _SummaryChipTone.danger => (
        scheme.errorContainer,
        scheme.onErrorContainer,
      ),
      _SummaryChipTone.success => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: foreground),
        ),
      ),
    );
  }
}

class _ConflictEntryCard extends StatelessWidget {
  const _ConflictEntryCard({required this.conflictCount, required this.onTap});

  final int conflictCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final ThemeData theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: <Widget>[
              Icon(Icons.warning_amber_rounded, size: 20, color: scheme.error),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.l10n.previewConflictCount(conflictCount),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onErrorContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              FilledButton.tonal(
                onPressed: onTap,
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.errorContainer,
                  foregroundColor: scheme.onErrorContainer,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: Text(context.l10n.conflictViewConflicts),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
