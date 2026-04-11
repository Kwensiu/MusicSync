import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:music_sync/app/routes/route_names.dart';
import 'package:music_sync/app/widgets/app_page_content.dart';
import 'package:music_sync/app/widgets/app_scaffold.dart';
import 'package:music_sync/app/widgets/section_card.dart';
import 'package:music_sync/core/errors/app_error_localizer.dart';
import 'package:music_sync/features/connection/state/connection_controller.dart';
import 'package:music_sync/features/connection/state/connection_state.dart'
    as peer_connection;
import 'package:music_sync/features/directory/state/directory_controller.dart';
import 'package:music_sync/features/directory/state/directory_state.dart';
import 'package:music_sync/features/execution/state/execution_controller.dart';
import 'package:music_sync/features/execution/state/execution_state.dart';
import 'package:music_sync/features/home/presentation/widgets/connection_section/connection_section.dart';
import 'package:music_sync/features/home/presentation/widgets/connection_section/connection_section_actions.dart';
import 'package:music_sync/features/home/presentation/widgets/action_chip_button.dart';
import 'package:music_sync/features/home/presentation/widgets/home_dialogs/home_dialogs.dart';
import 'package:music_sync/features/home/presentation/widgets/home_workspace_layout.dart';
import 'package:music_sync/features/home/presentation/widgets/preview_workbench_section/preview_workbench_actions.dart';
import 'package:music_sync/features/home/presentation/widgets/preview_workbench_section/preview_workbench_section.dart';
import 'package:music_sync/features/home/presentation/widgets/recent_record_managers/recent_record_managers.dart';
import 'package:music_sync/features/home/presentation/widgets/source_directory_section/source_directory_section.dart';
import 'package:music_sync/features/preview/state/preview_controller.dart';
import 'package:music_sync/features/preview/state/preview_state.dart';
import 'package:music_sync/features/settings/state/settings_controller.dart';
import 'package:music_sync/features/settings/state/settings_state.dart';
import 'package:music_sync/l10n/app_localizations_ext.dart';
import 'package:music_sync/models/device_info.dart';
import 'package:music_sync/services/file_access/file_access_entry.dart';
import 'package:music_sync/services/platform/android_background_runtime.dart';
import 'package:music_sync/services/scanning/temp_file_cleanup_service.dart';
import 'package:music_sync/services/storage/recent_items_store.dart';

class TransferPage extends ConsumerStatefulWidget {
  const TransferPage({super.key});

  @override
  ConsumerState<TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends ConsumerState<TransferPage>
    with WidgetsBindingObserver {
  final TextEditingController _addressController = TextEditingController();
  bool _isCleaningSourceTemp = false;
  AppLifecycleState? _appLifecycleState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _addressController.dispose();
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
    final bool isConnecting =
        connectionState.status == peer_connection.ConnectionStatus.connecting;
    final bool isPreviewLoading = previewState.status == PreviewStatus.loading;
    final bool isExecuting = executionState.status == ExecutionStatus.running;
    final bool isRemoteSyncRunning =
        executionState.status == ExecutionStatus.running &&
        executionState.mode == ExecutionMode.remote;
    final bool isBusy = isConnecting || isPreviewLoading || isExecuting;
    final bool isConnectUiBusy = isPreviewLoading || isExecuting;
    final bool hasConnectedPeer =
        connectionState.peer != null &&
        connectionState.status == peer_connection.ConnectionStatus.connected;
    final bool hasRemoteSnapshot = connectionState.remoteSnapshot != null;
    final bool hasRemoteDirectoryReady =
        connectionState.isRemoteDirectoryReady || hasRemoteSnapshot;
    final bool hasExecutableItems =
        previewState.plan.copyItems.isNotEmpty ||
        previewState.plan.deleteItems.isNotEmpty;
    final bool isRemotePreview = previewState.mode == PreviewMode.remote;
    final bool canRunRemote =
        connectionState.remoteSnapshot != null &&
        isRemotePreview &&
        previewState.targetSnapshot?.rootId ==
            connectionState.remoteSnapshot!.rootId;
    final bool canStartRemoteSync =
        canRunRemote && hasExecutableItems && !isBusy;
    final bool hasPreviewLoaded = previewState.status == PreviewStatus.loaded;
    final bool canViewPreviewList =
        hasPreviewLoaded ||
        (directoryState.handle != null && hasRemoteDirectoryReady && !isBusy);
    final bool showExecutionPanel = isExecuting;
    final List<String> scanWarnings = <String>{
      ...?previewState.sourceSnapshot?.warnings,
      ...?previewState.targetSnapshot?.warnings,
    }.toList();
    final bool showKeepAliveBadge =
        Platform.isAndroid &&
        connectionState.peer != null &&
        connectionState.status == peer_connection.ConnectionStatus.connected &&
        isRemoteSyncRunning;
    final bool showIncomingSyncOverlay =
        connectionState.isIncomingSyncActive && hasConnectedPeer;
    final String sourceDeviceLabel = _localDeviceDisplayName(settingsState);
    // TODO(home-layout): Keep overview cards outside the workbench scroller so
    // the page always has a single obvious primary scroll target.
    final Widget connectionSectionCard = _buildConnectionSectionCard(
      context: context,
      connectionState: connectionState,
      isConnectUiBusy: isConnectUiBusy,
      hasConnectedPeer: hasConnectedPeer,
    );
    final Widget sourceSectionCard = _buildSourceSectionCard(
      context: context,
      directoryState: directoryState,
      isBusy: isBusy,
      hasRemoteDirectoryReady: hasRemoteDirectoryReady,
    );
    // TODO(home-layout): The preview workbench is now its own scroll region.
    // Any future expandable panels that can change height should live here.
    final Widget previewSectionCard = _buildPreviewSectionCard(
      context: context,
      directoryState: directoryState,
      connectionState: connectionState,
      previewState: previewState,
      executionState: executionState,
      ignoredExtensions: ignoredExtensions,
      scanWarnings: scanWarnings,
      isStalePlan: isStalePlan,
      isBusy: isBusy,
      isExecuting: isExecuting,
      canStartRemoteSync: canStartRemoteSync,
      showExecutionPanel: showExecutionPanel,
      hasRemoteDirectoryReady: hasRemoteDirectoryReady,
      canViewPreviewList: canViewPreviewList,
      sourceDeviceLabel: sourceDeviceLabel,
    );

    return AppScaffold(
      title: context.l10n.transferTitle,
      actions: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ActionChipButton(
                label: ConnectionSectionActions.listeningStateChipLabel(
                  context,
                  connectionState,
                ),
                tone: ConnectionSectionActions.listeningStateChipTone(
                  connectionState,
                ),
                compact: true,
                onPressed: isConnectUiBusy
                    ? null
                    : () =>
                          ConnectionSectionActions.showConnectionStateChipDialog(
                            context: context,
                            ref: ref,
                            connectionState: connectionState,
                          ),
              ),
              const SizedBox(width: 8),
              ActionChipButton(
                label: ConnectionSectionActions.peerConnectionChipLabel(
                  context,
                  connectionState,
                ),
                tone: ConnectionSectionActions.peerConnectionChipTone(
                  connectionState,
                ),
                compact: true,
                onPressed: isConnectUiBusy || !hasConnectedPeer
                    ? null
                    : () => ConnectionSectionActions.disconnectConnectedPeer(
                        ref: ref,
                      ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => context.pushNamed(RouteNames.settings),
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
      body: Stack(
        children: <Widget>[
          AppPageContent(
            child: HomeWorkspaceLayout(
              connectionSection: connectionSectionCard,
              sourceSection: sourceSectionCard,
              previewSection: previewSectionCard,
              advancedSection: const SizedBox.shrink(),
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
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
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
          if (showIncomingSyncOverlay)
            Positioned.fill(
              child: ColoredBox(
                color: Theme.of(
                  context,
                ).colorScheme.scrim.withValues(alpha: 0.54),
                child: Center(
                  child: AbsorbPointer(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 380),
                      child: Card(
                        margin: const EdgeInsets.all(24),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Icon(
                                    Icons.sync_lock_rounded,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      context.l10n.homeIncomingSyncTitle,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                context.l10n.homeIncomingSyncBody(
                                  connectionState.peer?.deviceName ??
                                      context.l10n.previewDirectionRemote,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                context.l10n.homeIncomingSyncHint,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 14),
                              const LinearProgressIndicator(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConnectionSectionCard({
    required BuildContext context,
    required peer_connection.ConnectionState connectionState,
    required bool isConnectUiBusy,
    required bool hasConnectedPeer,
  }) {
    return SectionCard(
      title: context.l10n.homeStepConnectionTitle,
      child: ConnectionSection(
        connectionState: connectionState,
        isConnectUiBusy: isConnectUiBusy,
        hasConnectedPeer: hasConnectedPeer,
        onRefreshPresence: () {
          ref.read(connectionControllerProvider.notifier).refreshPresence();
        },
        onOpenConnectionPanel: () =>
            _showConnectionOptionsPanel(connectionState),
        onDiscoveredDeviceTap: (DeviceInfo device) {
          _addressController.text = '${device.address}:${device.port}';
          ConnectionSectionActions.connectFromInput(
            ref: ref,
            addressController: _addressController,
          );
        },
        localizeUiError: _localizeUiError,
      ),
    );
  }

  Widget _buildSourceSectionCard({
    required BuildContext context,
    required DirectoryState directoryState,
    required bool isBusy,
    required bool hasRemoteDirectoryReady,
  }) {
    return SectionCard(
      title: context.l10n.homeStepSourceTitle,
      child: SourceDirectorySection(
        directoryState: directoryState,
        isBusy: isBusy,
        hasRemoteDirectoryReady: hasRemoteDirectoryReady,
        isCleaningSourceTemp: _isCleaningSourceTemp,
        onPickDirectory: () {
          ref.read(directoryControllerProvider.notifier).pickDirectory();
        },
        onClearDirectory: () {
          ref.read(directoryControllerProvider.notifier).clearDirectory();
        },
        onCleanupTempFiles: () => _cleanupTempFiles(
          rootId: directoryState.handle!.entryId,
          isSource: true,
        ),
        onManageRecentDirectories: _showRecentDirectoryManager,
        onUseRecentDirectory: (DirectoryHandle handle) {
          ref
              .read(directoryControllerProvider.notifier)
              .useRecentDirectory(handle);
        },
        localizePreflightReason: _localizePreflightReason,
      ),
    );
  }

  Widget _buildPreviewSectionCard({
    required BuildContext context,
    required DirectoryState directoryState,
    required peer_connection.ConnectionState connectionState,
    required PreviewState previewState,
    required ExecutionState executionState,
    required List<String> ignoredExtensions,
    required List<String> scanWarnings,
    required bool isStalePlan,
    required bool isBusy,
    required bool isExecuting,
    required bool canStartRemoteSync,
    required bool showExecutionPanel,
    required bool hasRemoteDirectoryReady,
    required bool canViewPreviewList,
    required String sourceDeviceLabel,
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool hasSourceRisk = directoryState.preflight?.hasRisk == true;
    return SectionCard(
      title: context.l10n.homeStepPreviewTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
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
            sourceDeviceLabel: sourceDeviceLabel,
            targetDeviceLabel: _targetDeviceDisplayName(
              context,
              connectionState: connectionState,
              previewState: previewState,
            ),
            isTransferConnected:
                connectionState.peer != null &&
                connectionState.status ==
                    peer_connection.ConnectionStatus.connected,
            onBuildRemotePreview: () =>
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
              ref.read(executionControllerProvider.notifier).cancel();
            },
            localizeUiError: _localizeUiError,
            localizedExecutionStatus: _localizedExecutionStatus,
            isScanTimeoutError: _isScanTimeoutError,
            sourceRiskMessage: hasSourceRisk
                ? context.l10n.directoryPreflightWarningTitle
                : null,
            showActionButtons: false,
            showBuildPreviewButton: false,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: canViewPreviewList
                  ? () => _openPreviewListFlow(
                      context,
                      directoryState: directoryState,
                      previewState: previewState,
                      hasRemoteDirectoryReady: hasRemoteDirectoryReady,
                      ignoredExtensions: ignoredExtensions,
                      isStalePlan: isStalePlan,
                    )
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: scheme.primaryContainer,
                foregroundColor: scheme.onPrimaryContainer,
              ),
              icon: const Icon(Icons.library_music_rounded),
              label: Text(context.l10n.homeViewPreviewList),
            ),
          ),
        ],
      ),
    );
  }

  String _localizeUiError(BuildContext context, String value) {
    return AppErrorLocalizer.localize(context, value);
  }

  void _openPreviewPage(BuildContext context) {
    context.pushNamed(RouteNames.preview);
  }

  void _openPreviewListFlow(
    BuildContext context, {
    required DirectoryState directoryState,
    required PreviewState previewState,
    required bool hasRemoteDirectoryReady,
    required List<String> ignoredExtensions,
    required bool isStalePlan,
  }) {
    _openPreviewPage(context);
    final DirectoryHandle? sourceRoot = directoryState.handle;
    final bool shouldBuildPreview =
        previewState.status != PreviewStatus.loaded || isStalePlan;
    if (!shouldBuildPreview ||
        sourceRoot == null ||
        !hasRemoteDirectoryReady ||
        previewState.status == PreviewStatus.loading) {
      return;
    }
    unawaited(
      PreviewWorkbenchActions.buildRemotePreview(
        ref: ref,
        sourceRoot: sourceRoot,
        ignoredExtensions: ignoredExtensions,
      ),
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

  String _localizePreflightReason(BuildContext context, String reason) {
    switch (reason) {
      case 'many_root_children':
        return context.l10n.directoryPreflightManyRootChildren;
      case 'dense_nested_directory':
        return context.l10n.directoryPreflightDenseNestedDirectory;
      case 'inaccessible_subdirectory':
        return context.l10n.directoryPreflightInaccessibleSubdirectory;
      case 'system_like_directory':
        return context.l10n.directoryPreflightSystemLikeDirectory;
      default:
        return reason;
    }
  }

  Future<void> _cleanupTempFiles({
    required String rootId,
    required bool isSource,
  }) async {
    setState(() {
      if (isSource) {
        _isCleaningSourceTemp = true;
      }
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
      if (isSource && result.deletedCount > 0 && result.failedPaths.isEmpty) {
        ref.read(directoryControllerProvider.notifier).setHasTempFiles(false);
      }
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
          if (isSource) {
            _isCleaningSourceTemp = false;
          }
        });
      }
    }
  }

  Future<void> _showRecentDirectoryManager() async {
    final RecentItemsStore store = ref.read(recentItemsStoreProvider);
    List<RecentDirectoryRecord> records = await store
        .loadRecentDirectoryRecords();
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return RecentDirectoryManagerDialog(
          initialRecords: records,
          onUse: (RecentDirectoryRecord record) async {
            ref
                .read(directoryControllerProvider.notifier)
                .useRecentDirectory(record.handle);
          },
          onReorder: (List<RecentDirectoryRecord> next) async {
            await store.reorderRecentDirectories(next);
            await ref.read(directoryControllerProvider.notifier).reloadRecent();
            return store.loadRecentDirectoryRecords();
          },
          onEdit: (RecentDirectoryRecord record) async {
            await _showRecentAliasDialog(
              initialValue: record.note,
              title: context.l10n.homeRecentEditAlias,
              onSave: (String? value) async {
                await store.updateRecentDirectoryNote(
                  record.handle.entryId,
                  value,
                );
                await ref
                    .read(directoryControllerProvider.notifier)
                    .reloadRecent();
              },
            );
            return store.loadRecentDirectoryRecords();
          },
          onDelete: (RecentDirectoryRecord record) async {
            await store.removeRecentDirectory(record.handle.entryId);
            await ref.read(directoryControllerProvider.notifier).reloadRecent();
            return store.loadRecentDirectoryRecords();
          },
        );
      },
    );
  }

  Future<void> _showRecentAddressManager() async {
    final RecentItemsStore store = ref.read(recentItemsStoreProvider);
    List<RecentAddressRecord> records = await store.loadRecentAddressRecords();
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return RecentAddressManagerDialog(
          initialRecords: records,
          onUse: (RecentAddressRecord record) async {
            _addressController.text = record.address;
            ConnectionSectionActions.connectFromInput(
              ref: ref,
              addressController: _addressController,
            );
          },
          onReorder: (List<RecentAddressRecord> next) async {
            await store.reorderRecentAddresses(next);
            await ref
                .read(connectionControllerProvider.notifier)
                .reloadRecent();
            return store.loadRecentAddressRecords();
          },
          onEdit: (RecentAddressRecord record) async {
            await _showRecentAddressDialog(
              initialAddress: record.address,
              initialAlias: record.note,
              onSave:
                  ({required String address, required String? alias}) async {
                    await store.updateRecentAddress(
                      oldAddress: record.address,
                      newAddress: address,
                      note: alias,
                    );
                    await ref
                        .read(connectionControllerProvider.notifier)
                        .reloadRecent();
                  },
            );
            return store.loadRecentAddressRecords();
          },
          onDelete: (RecentAddressRecord record) async {
            await store.removeRecentAddress(record.address);
            await ref
                .read(connectionControllerProvider.notifier)
                .reloadRecent();
            return store.loadRecentAddressRecords();
          },
        );
      },
    );
  }

  Future<void> _showRecentAliasDialog({
    required String title,
    required Future<void> Function(String? value) onSave,
    String? initialValue,
  }) async {
    final String? value = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return RecentAliasDialog(title: title, initialValue: initialValue);
      },
    );
    if (value != null) {
      await onSave(value);
    }
  }

  Future<void> _showRecentAddressDialog({
    required String initialAddress,
    required String? initialAlias,
    required Future<void> Function({
      required String address,
      required String? alias,
    })
    onSave,
  }) async {
    final ({String address, String alias})? result =
        await showDialog<({String address, String alias})>(
          context: context,
          builder: (BuildContext context) {
            return RecentAddressDialog(
              initialAddress: initialAddress,
              initialAlias: initialAlias,
            );
          },
        );
    if (result != null) {
      await onSave(address: result.address.trim(), alias: result.alias);
    }
  }

  Future<void> _showConnectionOptionsPanel(
    peer_connection.ConnectionState connectionState,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return ConnectionOptionsDialog(
          addressController: _addressController,
          recentAddresses: connectionState.recentAddresses,
          recentLabels: connectionState.recentLabels,
          discoveredDevices: connectionState.discoveredDevices,
          onConnectTap: () {
            Navigator.of(context).pop();
            ConnectionSectionActions.connectFromInput(
              ref: ref,
              addressController: _addressController,
            );
          },
          onRecentAddressTap: (String address) {
            _addressController.text = address;
            Navigator.of(context).pop();
            ConnectionSectionActions.connectFromInput(
              ref: ref,
              addressController: _addressController,
            );
          },
          onDiscoveredDeviceTap: (DeviceInfo device) {
            _addressController.text = '${device.address}:${device.port}';
            Navigator.of(context).pop();
            ConnectionSectionActions.connectFromInput(
              ref: ref,
              addressController: _addressController,
            );
          },
          onManageRecentAddresses: () {
            Navigator.of(context).pop();
            _showRecentAddressManager();
          },
          onPortTap: () {
            Navigator.of(context).pop();
            ConnectionSectionActions.showPortDialog(
              context: this.context,
              ref: ref,
              currentPort: connectionState.listenPort ?? 44888,
            );
          },
          onShareTap: () {
            Navigator.of(context).pop();
            ConnectionSectionActions.showShareDialog(
              context: this.context,
              connectionState: connectionState,
            );
          },
        );
      },
    );
  }
}
