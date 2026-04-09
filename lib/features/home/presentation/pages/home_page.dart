import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:music_sync/app/routes/route_names.dart';
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
import 'package:music_sync/features/home/presentation/widgets/preview_workbench_section/preview_workbench_actions.dart';
import 'package:music_sync/features/home/presentation/widgets/preview_workbench_section/preview_workbench_section.dart';
import 'package:music_sync/features/home/presentation/widgets/recent_record_managers/recent_record_managers.dart';
import 'package:music_sync/features/home/presentation/widgets/source_directory_section/source_directory_section.dart';
import 'package:music_sync/features/preview/state/preview_controller.dart';
import 'package:music_sync/features/preview/state/preview_state.dart';
import 'package:music_sync/features/settings/state/settings_controller.dart';
import 'package:music_sync/l10n/app_localizations_ext.dart';
import 'package:music_sync/models/device_info.dart';
import 'package:music_sync/models/diff_item.dart';
import 'package:music_sync/models/scan_snapshot.dart';
import 'package:music_sync/services/file_access/file_access_entry.dart';
import 'package:music_sync/services/file_access/file_access_provider.dart';
import 'package:music_sync/services/platform/android_background_runtime.dart';
import 'package:music_sync/services/scanning/temp_file_cleanup_service.dart';
import 'package:music_sync/services/storage/recent_items_store.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with WidgetsBindingObserver {
  final TextEditingController _addressController = TextEditingController();
  Set<String> _selectedExtensions = <String>{'*'};
  bool _selectAllSections = true;
  Set<DiffType> _selectedSections = <DiffType>{
    DiffType.copy,
    DiffType.delete,
  };
  bool _isCleaningSourceTemp = false;
  bool _isCleaningTargetTemp = false;
  String? _lastAutoPreviewSignature;
  bool _isAutoPreviewQueued = false;
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
    final peer_connection.ConnectionState connectionState =
        ref.read(connectionControllerProvider);
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
    ref.listen<DirectoryState>(directoryControllerProvider,
        (_, DirectoryState next) {
      _maybeScheduleAutoRemotePreview(
        directoryState: next,
        connectionState: ref.read(connectionControllerProvider),
        previewState: ref.read(previewControllerProvider),
        executionState: ref.read(executionControllerProvider),
        ignoredExtensions:
            ref.read(settingsControllerProvider).ignoredExtensions,
      );
    });
    ref.listen<peer_connection.ConnectionState>(
      connectionControllerProvider,
      (_, peer_connection.ConnectionState next) {
        _syncAndroidKeepAlive(
          connectionState: next,
          executionState: ref.read(executionControllerProvider),
        );
        _maybeScheduleAutoRemotePreview(
          directoryState: ref.read(directoryControllerProvider),
          connectionState: next,
          previewState: ref.read(previewControllerProvider),
          executionState: ref.read(executionControllerProvider),
          ignoredExtensions:
              ref.read(settingsControllerProvider).ignoredExtensions,
        );
      },
    );
    ref.listen<ExecutionState>(
      executionControllerProvider,
      (_, ExecutionState next) {
        _syncAndroidKeepAlive(
          connectionState: ref.read(connectionControllerProvider),
          executionState: next,
        );
      },
    );
    final DirectoryState directoryState =
        ref.watch(directoryControllerProvider);
    final peer_connection.ConnectionState connectionState =
        ref.watch(connectionControllerProvider);
    final PreviewState previewState = ref.watch(previewControllerProvider);
    final ExecutionState executionState =
        ref.watch(executionControllerProvider);
    final List<String> ignoredExtensions =
        ref.watch(settingsControllerProvider).ignoredExtensions;

    final bool isStalePlan = previewState.sourceRootId != null &&
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
    final bool hasExecutableItems = previewState.plan.copyItems.isNotEmpty ||
        previewState.plan.deleteItems.isNotEmpty;
    final bool isRemotePreview = previewState.mode == PreviewMode.remote;
    final bool isLocalPreview = previewState.mode == PreviewMode.local;
    final bool canRunRemote = connectionState.remoteSnapshot != null &&
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
    final bool hasFinishedExecution =
        executionState.status == ExecutionStatus.completed ||
            executionState.status == ExecutionStatus.cancelled ||
            executionState.status == ExecutionStatus.failed;
    final bool isBusy = isConnecting || isPreviewLoading || isExecuting;
    final bool isConnectUiBusy = isPreviewLoading || isExecuting;
    final bool hasConnectedPeer = connectionState.peer != null &&
        connectionState.status == peer_connection.ConnectionStatus.connected;
    final bool hasRemoteSnapshot = connectionState.remoteSnapshot != null;
    final bool hasRemoteDirectoryReady =
        connectionState.isRemoteDirectoryReady || hasRemoteSnapshot;
    final bool canStartRemoteSync =
        canRunRemote && hasExecutableItems && !isBusy;
    final bool canOpenResult = hasFinishedExecution &&
        executionState.targetRoot != null &&
        executionState.targetRoot!.isNotEmpty;
    final bool showExecutionPanel = isExecuting ||
        executionState.errorMessage != null ||
        executionState.status != ExecutionStatus.idle ||
        executionState.progress.totalFiles > 0 ||
        executionState.progress.totalBytes > 0;
    final List<String> scanWarnings = <String>{
      ...?previewState.sourceSnapshot?.warnings,
      ...?previewState.targetSnapshot?.warnings,
    }.toList();
    final bool showKeepAliveBadge = Platform.isAndroid &&
        connectionState.peer != null &&
        connectionState.status == peer_connection.ConnectionStatus.connected &&
        isRemoteSyncRunning;
    final bool showIncomingSyncOverlay =
        connectionState.isIncomingSyncActive && hasConnectedPeer;

    return AppScaffold(
      title: context.l10n.appTitle,
      showBackButton: false,
      actions: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: ActionChipButton(
            label: ConnectionSectionActions.connectionStateChipLabel(
              context,
              connectionState,
            ),
            tone: ConnectionSectionActions.connectionStateChipTone(
              connectionState,
            ),
            compact: true,
            onPressed: isConnectUiBusy
                ? null
                : () => ConnectionSectionActions.showConnectionStateChipDialog(
                      context: context,
                      ref: ref,
                      connectionState: connectionState,
                    ),
          ),
        ),
        IconButton(
          onPressed: () => context.pushNamed(RouteNames.settings),
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
      body: Stack(
        children: <Widget>[
          ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              SectionCard(
                title: context.l10n.homeStepConnectionTitle,
                child: ConnectionSection(
                  connectionState: connectionState,
                  isConnectUiBusy: isConnectUiBusy,
                  hasConnectedPeer: hasConnectedPeer,
                  onRefreshPresence: () {
                    ref
                        .read(connectionControllerProvider.notifier)
                        .refreshPresence();
                  },
                  onOpenConnectionPanel: () =>
                      _showConnectionOptionsPanel(connectionState),
                  onDiscoveredDeviceTap: (DeviceInfo device) {
                    _addressController.text =
                        '${device.address}:${device.port}';
                    ConnectionSectionActions.connectFromInput(
                      ref: ref,
                      addressController: _addressController,
                    );
                  },
                  localizeUiError: _localizeUiError,
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: context.l10n.homeStepSourceTitle,
                child: SourceDirectorySection(
                  directoryState: directoryState,
                  isBusy: isBusy,
                  hasRemoteDirectoryReady: hasRemoteDirectoryReady,
                  isCleaningSourceTemp: _isCleaningSourceTemp,
                  onPickDirectory: () {
                    ref
                        .read(directoryControllerProvider.notifier)
                        .pickDirectory();
                  },
                  onClearDirectory: () {
                    ref
                        .read(directoryControllerProvider.notifier)
                        .clearDirectory();
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
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: context.l10n.homeStepPreviewTitle,
                child: PreviewWorkbenchSection(
                  directoryState: directoryState,
                  connectionState: connectionState,
                  previewState: previewState,
                  executionState: executionState,
                  ignoredExtensions: ignoredExtensions,
                  filteredCopyItems: filteredCopyItems,
                  filteredDeleteItems: filteredDeleteItems,
                  filteredConflictItems: filteredConflictItems,
                  activeItems: activeItems,
                  extensionOptions: extensionOptions,
                  scanWarnings: scanWarnings,
                  isStalePlan: isStalePlan,
                  isBusy: isBusy,
                  isExecuting: isExecuting,
                  canStartRemoteSync: canStartRemoteSync,
                  canOpenResult: canOpenResult,
                  showExecutionPanel: showExecutionPanel,
                  hasRemoteDirectoryReady: hasRemoteDirectoryReady,
                  isAllExtensionsSelected: isAllExtensionsSelected,
                  selectAllSections: _selectAllSections,
                  selectedSections: _selectedSections,
                  selectedExtensions: _selectedExtensions,
                  sourceDeviceLabel: _localDeviceDisplayName(),
                  targetDeviceLabel: _targetDeviceDisplayName(
                    context,
                    connectionState: connectionState,
                    previewState: previewState,
                  ),
                  isTransferConnected: connectionState.peer != null &&
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
                  localizeUiError: _localizeUiError,
                  localizedExecutionStatus: _localizedExecutionStatus,
                  isScanTimeoutError: _isScanTimeoutError,
                ),
              ),
              const SizedBox(height: 16),
              ExpansionTile(
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
                          Text(executionState.targetRoot ??
                              context.l10n.executionNoTarget),
                          const SizedBox(height: 12),
                          FilledButton.tonal(
                            onPressed: isBusy
                                ? null
                                : () async {
                                    final handle = await ref
                                        .read(fileAccessGatewayProvider)
                                        .pickDirectory();
                                    ref
                                        .read(executionControllerProvider
                                            .notifier)
                                        .setTargetRoot(handle?.entryId);
                                  },
                            child: Text(context.l10n.executionPickTarget),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: isBusy ||
                                    executionState.targetRoot == null ||
                                    _isCleaningTargetTemp
                                ? null
                                : () => _cleanupTempFiles(
                                      rootId: executionState.targetRoot!,
                                      isSource: false,
                                    ),
                            child: Text(context.l10n.homeCleanupTempFiles),
                          ),
                          const SizedBox(height: 8),
                          FilledButton.tonal(
                            onPressed: isBusy ||
                                    executionState.targetRoot == null ||
                                    !hasExecutableItems ||
                                    !isLocalPreview
                                ? null
                                : () async {
                                    if (previewState
                                        .plan.deleteItems.isNotEmpty) {
                                      final bool? confirmed =
                                          await showDialog<bool>(
                                        context: context,
                                        builder: (BuildContext context) {
                                          return AlertDialog(
                                            title: Text(context.l10n
                                                .executionConfirmDeleteTitle),
                                            content: Text(
                                              context.l10n
                                                  .executionConfirmDeleteBody(
                                                previewState
                                                    .plan.deleteItems.length,
                                              ),
                                            ),
                                            actions: <Widget>[
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.of(context)
                                                        .pop(false),
                                                child: Text(
                                                    context.l10n.commonCancel),
                                              ),
                                              FilledButton(
                                                onPressed: () =>
                                                    Navigator.of(context)
                                                        .pop(true),
                                                child: Text(
                                                    context.l10n.commonConfirm),
                                              ),
                                            ],
                                          );
                                        },
                                      );

                                      if (confirmed != true) {
                                        return;
                                      }
                                    }
                                    await ref
                                        .read(executionControllerProvider
                                            .notifier)
                                        .execute(
                                          plan: previewState.plan,
                                          targetRoot:
                                              executionState.targetRoot!,
                                        );
                                    await PreviewWorkbenchActions
                                        .refreshPreviewAfterExecution(
                                      ref: ref,
                                      previewState: previewState,
                                      directoryState: directoryState,
                                      executionState:
                                          ref.read(executionControllerProvider),
                                    );
                                  },
                            child: Text(context.l10n.executionRunLocalDebug),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Text(
                      '🏷 后台保活已就绪',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onTertiaryContainer,
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
                color: Colors.black54,
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
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      context.l10n.homeIncomingSyncTitle,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
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
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
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

  String _localDeviceDisplayName() {
    final String hostName = Platform.localHostname.trim();
    final String fallbackName = Platform.environment['COMPUTERNAME'] ??
        Platform.environment['HOSTNAME'] ??
        (Platform.isAndroid
            ? 'Android'
            : Platform.isWindows
                ? 'Windows'
                : Platform.operatingSystem);
    if (hostName.isEmpty || hostName.toLowerCase() == 'localhost') {
      return fallbackName;
    }
    return hostName;
  }

  void _syncAndroidKeepAlive({
    required peer_connection.ConnectionState connectionState,
    required ExecutionState executionState,
  }) {
    final bool isRemoteSyncRunning =
        executionState.status == ExecutionStatus.running &&
            executionState.mode == ExecutionMode.remote;
    final bool shouldEnable = Platform.isAndroid &&
        _appLifecycleState != null &&
        _appLifecycleState != AppLifecycleState.resumed &&
        connectionState.peer != null &&
        connectionState.status == peer_connection.ConnectionStatus.connected &&
        isRemoteSyncRunning;
    AndroidBackgroundRuntime.setKeepAliveEnabled(shouldEnable);
  }

  void _maybeScheduleAutoRemotePreview({
    required DirectoryState directoryState,
    required peer_connection.ConnectionState connectionState,
    required PreviewState previewState,
    required ExecutionState executionState,
    required List<String> ignoredExtensions,
  }) {
    if (!mounted || _isAutoPreviewQueued) {
      return;
    }
    final DirectoryHandle? sourceRoot = directoryState.handle;
    final ScanSnapshot? remoteSnapshot = connectionState.remoteSnapshot;
    final bool remoteReady =
        connectionState.isRemoteDirectoryReady || remoteSnapshot != null;
    if (sourceRoot == null || !remoteReady) {
      return;
    }
    if (executionState.status == ExecutionStatus.running) {
      return;
    }
    final String signature = remoteSnapshot == null
        ? '${sourceRoot.entryId}|pending-remote|${ignoredExtensions.join(",")}'
        : '${sourceRoot.entryId}|${remoteSnapshot.rootId}|${remoteSnapshot.scannedAt.microsecondsSinceEpoch}|${ignoredExtensions.join(",")}';
    final bool alreadyCurrent = remoteSnapshot != null &&
        previewState.mode == PreviewMode.remote &&
        previewState.sourceRootId == sourceRoot.entryId &&
        previewState.targetSnapshot?.rootId == remoteSnapshot.rootId &&
        previewState.targetSnapshot?.scannedAt == remoteSnapshot.scannedAt &&
        PreviewWorkbenchActions.listEquals(
          previewState.ignoredExtensions,
          ignoredExtensions,
        );
    if (alreadyCurrent || _lastAutoPreviewSignature == signature) {
      return;
    }
    _isAutoPreviewQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await PreviewWorkbenchActions.buildRemotePreview(
          ref: ref,
          sourceRoot: sourceRoot,
          remoteSnapshot: remoteSnapshot,
          ignoredExtensions: ignoredExtensions,
        );
        _lastAutoPreviewSignature = signature;
      } finally {
        if (mounted) {
          setState(() {
            _isAutoPreviewQueued = false;
          });
        } else {
          _isAutoPreviewQueued = false;
        }
      }
    });
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
      } else {
        _isCleaningTargetTemp = true;
      }
    });
    try {
      final result = await ref.read(tempFileCleanupServiceProvider).cleanup(
            rootId: rootId,
          );
      if (!mounted) {
        return;
      }
      final String message = result.failedPaths.isEmpty
          ? context.l10n.homeCleanupTempSuccess(result.deletedCount)
          : context.l10n.homeCleanupTempPartial(
              result.deletedCount,
              result.failedPaths.length,
            );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
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
          } else {
            _isCleaningTargetTemp = false;
          }
        });
      }
    }
  }

  Future<void> _showRecentDirectoryManager() async {
    final RecentItemsStore store = ref.read(recentItemsStoreProvider);
    List<RecentDirectoryRecord> records =
        await store.loadRecentDirectoryRecords();
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
              onSave: ({
                required String address,
                required String? alias,
              }) async {
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
        return RecentAliasDialog(
          title: title,
          initialValue: initialValue,
        );
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
    }) onSave,
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
      await onSave(
        address: result.address.trim(),
        alias: result.alias,
      );
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
