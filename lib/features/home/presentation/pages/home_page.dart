import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:music_sync/app/routes/route_names.dart';
import 'package:music_sync/app/widgets/app_scaffold.dart';
import 'package:music_sync/app/widgets/section_card.dart';
import 'package:music_sync/core/errors/app_error_localizer.dart';
import 'package:music_sync/core/utils/path_display_format.dart';
import 'package:music_sync/features/connection/state/connection_controller.dart';
import 'package:music_sync/features/connection/state/connection_state.dart'
    as peer_connection;
import 'package:music_sync/features/directory/state/directory_controller.dart';
import 'package:music_sync/features/directory/state/directory_state.dart';
import 'package:music_sync/features/execution/state/execution_controller.dart';
import 'package:music_sync/features/execution/state/execution_state.dart';
import 'package:music_sync/features/home/presentation/widgets/action_chip_button.dart';
import 'package:music_sync/features/home/presentation/widgets/connection_section/connection_section.dart';
import 'package:music_sync/features/home/presentation/widgets/preview_workbench_section/preview_workbench_section.dart';
import 'package:music_sync/features/home/presentation/widgets/recent_record_card/recent_record_card.dart';
import 'package:music_sync/features/home/presentation/widgets/source_directory_section/source_directory_section.dart';
import 'package:music_sync/features/preview/presentation/widgets/plan_item_list.dart';
import 'package:music_sync/features/preview/state/preview_controller.dart';
import 'package:music_sync/features/preview/state/preview_state.dart';
import 'package:music_sync/features/settings/state/settings_controller.dart';
import 'package:music_sync/l10n/app_localizations_ext.dart';
import 'package:music_sync/models/diff_item.dart';
import 'package:music_sync/models/scan_snapshot.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:music_sync/services/file_access/file_access_entry.dart';
import 'package:music_sync/services/file_access/file_access_provider.dart';
import 'package:music_sync/services/scanning/temp_file_cleanup_service.dart';
import 'package:music_sync/services/storage/recent_items_store.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final TextEditingController _addressController = TextEditingController();
  Set<String> _selectedExtensions = <String>{'*'};
  bool _selectAllSections = true;
  Set<DiffType> _selectedSections = <DiffType>{
    DiffType.copy,
    DiffType.delete,
  };
  bool _isCleaningSourceTemp = false;
  bool _isCleaningTargetTemp = false;
  bool _showConflictItems = false;
  String? _lastAutoPreviewSignature;
  bool _isAutoPreviewQueued = false;

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
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
    final List<DiffItem> filteredCopyItems = _filterItemsByExtensions(
      previewState.plan.copyItems,
      _selectedExtensions,
    );
    final List<DiffItem> filteredDeleteItems = _filterItemsByExtensions(
      previewState.plan.deleteItems,
      _selectedExtensions,
    );
    final List<DiffItem> filteredConflictItems = _filterItemsByExtensions(
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

    return AppScaffold(
      title: context.l10n.appTitle,
      showBackButton: false,
      actions: <Widget>[
        IconButton(
          onPressed: () => context.pushNamed(RouteNames.settings),
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          SectionCard(
            title: context.l10n.homeStepConnectionTitle,
            child: ConnectionSection(
              connectionState: connectionState,
              addressController: _addressController,
              isConnectUiBusy: isConnectUiBusy,
              isConnecting: isConnecting,
              hasConnectedPeer: hasConnectedPeer,
              onConnectionStateChipTap: () =>
                  _handleConnectionStateChipTap(connectionState),
              onPortTap: () =>
                  _showPortDialog(connectionState.listenPort ?? 44888),
              onShareTap: () => _showShareDialog(connectionState),
              onConnectTap: () => _handleConnectButton(connectionState),
              onManageRecentAddresses: _showRecentAddressManager,
              onRecentAddressTap: (String address) {
                _addressController.text = address;
                _connectFromInput();
              },
              localizeUiError: _localizeUiError,
              connectionStateChipLabel: _connectionStateChipLabel,
              connectionStateChipTone: _connectionStateChipTone,
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
              transferDirectionLabel: _transferDirectionValue(
                context,
                connectionState: connectionState,
                previewState: previewState,
              ),
              onBuildRemotePreview: () => _buildRemotePreview(
                sourceRoot: directoryState.handle!,
                ignoredExtensions: ignoredExtensions,
              ),
              onStartRemoteSync: () => _executeRemoteSyncFlow(
                context: context,
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
                  _selectedExtensions = _toggleExtensionSelection(
                    current: _selectedExtensions,
                    extension: extension,
                    selected: !selected,
                  );
                });
              },
              buildSection: _buildSection,
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
                                    .read(executionControllerProvider.notifier)
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
                      if (executionState.targetRoot == null) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(context.l10n.executionTargetRequired),
                      ],
                      const SizedBox(height: 8),
                      FilledButton.tonal(
                        onPressed: isBusy ||
                                executionState.targetRoot == null ||
                                !hasExecutableItems ||
                                !isLocalPreview
                            ? null
                            : () async {
                                if (previewState.plan.deleteItems.isNotEmpty) {
                                  final bool? confirmed =
                                      await showDialog<bool>(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        title: Text(context
                                            .l10n.executionConfirmDeleteTitle),
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
                                            child:
                                                Text(context.l10n.commonCancel),
                                          ),
                                          FilledButton(
                                            onPressed: () =>
                                                Navigator.of(context).pop(true),
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
                                    .read(executionControllerProvider.notifier)
                                    .execute(
                                      plan: previewState.plan,
                                      targetRoot: executionState.targetRoot!,
                                    );
                                await _refreshPreviewAfterExecution(
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
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required List<DiffItem> items,
    required List<DiffItem> conflictItems,
    required bool targetIsRemote,
  }) {
    if (items.isEmpty && conflictItems.isEmpty) {
      return PlanItemEmptyState(
        message: context.l10n.previewNoItemsInSection,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (items.isNotEmpty) ...<Widget>[
          PlanItemList(
            items: items,
            sourceIsRemote: false,
            targetIsRemote: targetIsRemote,
          ),
        ],
        if (conflictItems.isNotEmpty) ...<Widget>[
          if (items.isNotEmpty) const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              setState(() {
                _showConflictItems = !_showConflictItems;
              });
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: _showConflictItems
                    ? const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      )
                    : BorderRadius.circular(12),
                border: _showConflictItems
                    ? Border(
                        top: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        left: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        right: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        bottom: BorderSide.none,
                      )
                    : Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${context.l10n.previewSectionConflict} ${conflictItems.length}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _showConflictItems ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    child: Icon(
                      Icons.expand_more_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: _showConflictItems ? 1 : 0,
                child: PlanItemList(
                  items: conflictItems,
                  maxHeight: 220,
                  sourceIsRemote: false,
                  targetIsRemote: targetIsRemote,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                  showTopBorder: false,
                ),
              ),
            ),
          ),
        ],
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

  String _transferDirectionValue(
    BuildContext context, {
    required peer_connection.ConnectionState connectionState,
    required PreviewState previewState,
  }) {
    final String localName = _localDeviceDisplayName();
    final String targetName = switch (previewState.mode) {
      PreviewMode.remote =>
        connectionState.peer?.deviceName ?? context.l10n.previewDirectionRemote,
      PreviewMode.local => context.l10n.previewDirectionLocalTarget,
      PreviewMode.none =>
        connectionState.peer?.deviceName ?? context.l10n.previewDirectionRemote,
    };
    return '$localName -> $targetName';
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

  String _connectionStateChipLabel(
    BuildContext context,
    peer_connection.ConnectionState connectionState,
  ) {
    if (connectionState.peer != null &&
        connectionState.status == peer_connection.ConnectionStatus.connected) {
      return context.l10n.homeConnectionStateConnected;
    }
    if (connectionState.status == peer_connection.ConnectionStatus.connecting) {
      return context.l10n.homeConnectionStateConnecting;
    }
    if (connectionState.status == peer_connection.ConnectionStatus.listening) {
      return context.l10n.homeConnectionStateListening;
    }
    return context.l10n.homeConnectionStateIdle;
  }

  ActionChipTone _connectionStateChipTone(
    peer_connection.ConnectionState connectionState,
  ) {
    if (connectionState.peer != null &&
        connectionState.status == peer_connection.ConnectionStatus.connected) {
      return ActionChipTone.success;
    }
    if (connectionState.status == peer_connection.ConnectionStatus.listening ||
        connectionState.status == peer_connection.ConnectionStatus.connecting) {
      return ActionChipTone.active;
    }
    return ActionChipTone.neutral;
  }

  Future<void> _handleConnectionStateChipTap(
    peer_connection.ConnectionState connectionState,
  ) async {
    if (connectionState.peer != null &&
        connectionState.status == peer_connection.ConnectionStatus.connected) {
      await ref.read(connectionControllerProvider.notifier).disconnect();
      return;
    }
    if (connectionState.status == peer_connection.ConnectionStatus.connecting) {
      await ref.read(connectionControllerProvider.notifier).disconnect();
      return;
    }
    if (connectionState.status == peer_connection.ConnectionStatus.listening) {
      await ref.read(connectionControllerProvider.notifier).stopListening();
      return;
    }
    await ref.read(connectionControllerProvider.notifier).startListening(
          port: connectionState.listenPort ?? 44888,
        );
  }

  void _connectFromInput() {
    final String input = _addressController.text.trim();
    if (input.isEmpty) {
      return;
    }
    final List<String> parts = input.split(':');
    final String host = parts.first;
    final int port = parts.length > 1 ? int.tryParse(parts[1]) ?? 44888 : 44888;
    ref.read(connectionControllerProvider.notifier).connect(
          address: host,
          port: port,
        );
  }

  Future<void> _handleConnectButton(
    peer_connection.ConnectionState connectionState,
  ) async {
    final bool hasConnectedPeer = connectionState.peer != null &&
        connectionState.status == peer_connection.ConnectionStatus.connected;
    if (hasConnectedPeer ||
        connectionState.status == peer_connection.ConnectionStatus.connecting) {
      await ref.read(connectionControllerProvider.notifier).disconnect();
      return;
    }
    _connectFromInput();
  }

  Future<void> _showPortDialog(int currentPort) async {
    final TextEditingController controller = TextEditingController(
      text: currentPort.toString(),
    );
    final int? port = await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        String? errorText;
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Text(context.l10n.homePortDialogTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(context.l10n.homePortDialogBody),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: context.l10n.homePortDialogHint,
                      errorText: errorText,
                    ),
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(context.l10n.commonCancel),
                ),
                FilledButton(
                  onPressed: () {
                    final int? value = int.tryParse(controller.text.trim());
                    if (value == null || value < 1 || value > 65535) {
                      setState(() {
                        errorText = context.l10n.homePortDialogInvalid;
                      });
                      return;
                    }
                    Navigator.of(context).pop(value);
                  },
                  child: Text(context.l10n.commonConfirm),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
    if (port == null || !mounted) {
      return;
    }
    final peer_connection.ConnectionState connectionState =
        ref.read(connectionControllerProvider);
    if (connectionState.status == peer_connection.ConnectionStatus.listening) {
      await ref.read(connectionControllerProvider.notifier).stopListening();
      await ref
          .read(connectionControllerProvider.notifier)
          .startListening(port: port);
    } else {
      await ref
          .read(connectionControllerProvider.notifier)
          .startListening(port: port);
    }
  }

  Future<void> _showShareDialog(
    peer_connection.ConnectionState connectionState,
  ) async {
    final BuildContext pageContext = context;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(pageContext);
    final String copyDoneText = pageContext.l10n.homeShareCopyDone;
    final int port = connectionState.listenPort ?? 44888;
    final String host = await _resolveLocalShareHost();
    final String address = '$host:$port';
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        final ColorScheme scheme = Theme.of(context).colorScheme;
        final TextTheme textTheme = Theme.of(context).textTheme;
        return Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 228),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Text(
                    context.l10n.homeShareDialogTitle,
                    textAlign: TextAlign.center,
                    style: textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  QrImageView(
                    data: address,
                    size: 180,
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: 180,
                    child: Material(
                      color: scheme.surfaceContainerLow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(color: scheme.outlineVariant),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () async {
                          await Clipboard.setData(ClipboardData(text: address));
                          if (!mounted) {
                            return;
                          }
                          messenger.showSnackBar(
                            SnackBar(content: Text(copyDoneText)),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Expanded(
                                child: SelectableText(
                                  address,
                                  textAlign: TextAlign.center,
                                  style: textTheme.bodyMedium?.copyWith(
                                    fontFamily: 'monospace',
                                    letterSpacing: 0.1,
                                    color: scheme.onSurface,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: scheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.content_copy_outlined,
                                  size: 16,
                                  color: scheme.onSecondaryContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<String> _resolveLocalShareHost() async {
    try {
      final List<NetworkInterface> interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (final NetworkInterface interface in interfaces) {
        for (final InternetAddress address in interface.addresses) {
          final String host = address.address.trim();
          if (host.isEmpty) {
            continue;
          }
          if (host.startsWith('169.254.')) {
            continue;
          }
          return host;
        }
      }
    } catch (_) {
      // Fallback below.
    }
    return InternetAddress.loopbackIPv4.address;
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
        _listEquals(previewState.ignoredExtensions, ignoredExtensions);
    if (alreadyCurrent || _lastAutoPreviewSignature == signature) {
      return;
    }
    _isAutoPreviewQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _buildRemotePreview(
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

  Future<void> _buildRemotePreview({
    required DirectoryHandle sourceRoot,
    ScanSnapshot? remoteSnapshot,
    List<String> ignoredExtensions = const <String>[],
  }) async {
    final ScanSnapshot? targetSnapshot = remoteSnapshot ??
        await ref
            .read(connectionControllerProvider.notifier)
            .refreshRemoteSnapshot();
    if (targetSnapshot == null) {
      return;
    }
    final ScanSnapshot localSnapshot =
        await ref.read(directoryScannerProvider).scan(
              root: sourceRoot,
              deviceId: 'local-device',
            );
    await ref
        .read(previewControllerProvider.notifier)
        .buildPreviewFromSnapshots(
          source: localSnapshot,
          target: targetSnapshot,
          deleteEnabled: true,
          extensionFilter: '*',
          ignoredExtensions: ignoredExtensions,
          sourceRootId: sourceRoot.entryId,
        );
  }

  Future<void> _executeRemoteSyncFlow({
    required BuildContext context,
    required PreviewState previewState,
    required DirectoryState directoryState,
    required peer_connection.ConnectionState connectionState,
  }) async {
    if (previewState.plan.deleteItems.isNotEmpty) {
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(context.l10n.executionConfirmDeleteTitle),
            content: Text(
              context.l10n.executionConfirmDeleteBody(
                previewState.plan.deleteItems.length,
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(context.l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(context.l10n.commonConfirm),
              ),
            ],
          );
        },
      );
      if (confirmed != true) {
        return;
      }
    }

    await ref.read(executionControllerProvider.notifier).executeRemote(
          plan: previewState.plan,
          remoteRootId: connectionState.remoteSnapshot!.rootId,
        );
    await _refreshPreviewAfterExecution(
      previewState: previewState,
      directoryState: directoryState,
      executionState: ref.read(executionControllerProvider),
    );
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

  List<DiffItem> _filterItemsByExtensions(
    List<DiffItem> items,
    Set<String> extensions,
  ) {
    if (extensions.contains('*')) {
      return items;
    }
    return items
        .where((DiffItem item) =>
            extensions.contains(_extensionOf(item.relativePath)))
        .toList();
  }

  String _extensionOf(String path) {
    final int dotIndex = path.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex == path.length - 1) {
      return '';
    }
    return path.substring(dotIndex + 1).toLowerCase();
  }

  Set<String> _toggleExtensionSelection({
    required Set<String> current,
    required String extension,
    required bool selected,
  }) {
    if (extension == '*') {
      return <String>{'*'};
    }
    final Set<String> next = <String>{...current}..remove('*');
    if (selected) {
      next.add(extension);
    } else {
      next.remove(extension);
    }
    if (next.isEmpty) {
      return <String>{'*'};
    }
    return next;
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) {
      return false;
    }
    for (int index = 0; index < a.length; index += 1) {
      if (a[index] != b[index]) {
        return false;
      }
    }
    return true;
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
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Dialog(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 520, maxHeight: 560),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              context.l10n.homeRecentDirectories,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: records.isEmpty
                            ? Center(child: Text(context.l10n.homeRecentEmpty))
                            : ReorderableListView.builder(
                                buildDefaultDragHandles: false,
                                proxyDecorator: (
                                  Widget child,
                                  int index,
                                  Animation<double> animation,
                                ) {
                                  return child;
                                },
                                itemCount: records.length,
                                onReorder: (int oldIndex, int newIndex) async {
                                  if (newIndex > oldIndex) {
                                    newIndex -= 1;
                                  }
                                  final RecentDirectoryRecord item =
                                      records.removeAt(oldIndex);
                                  records.insert(newIndex, item);
                                  setModalState(() {});
                                  await store.reorderRecentDirectories(records);
                                  await ref
                                      .read(
                                          directoryControllerProvider.notifier)
                                      .reloadRecent();
                                },
                                itemBuilder: (BuildContext context, int index) {
                                  final RecentDirectoryRecord record =
                                      records[index];
                                  return Padding(
                                    key:
                                        ValueKey<String>(record.handle.entryId),
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: RecentRecordCard(
                                      title: record.label,
                                      subtitle: record.note == null ||
                                              record.note!.trim().isEmpty
                                          ? null
                                          : record.handle.displayName ==
                                                  record.label
                                              ? formatDisplayPath(
                                                  record.handle.entryId,
                                                )
                                              : formatDisplayPath(
                                                  record.handle.displayName,
                                                ),
                                      dragHandle: ReorderableDragStartListener(
                                        index: index,
                                        child: Icon(
                                          Icons.drag_indicator_rounded,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ),
                                      onUse: () {
                                        Navigator.of(context).pop();
                                        ref
                                            .read(directoryControllerProvider
                                                .notifier)
                                            .useRecentDirectory(record.handle);
                                      },
                                      onEditRecord: () async {
                                        await _showRecentAliasDialog(
                                          initialValue: record.note,
                                          title:
                                              context.l10n.homeRecentEditAlias,
                                          onSave: (String? value) async {
                                            await store
                                                .updateRecentDirectoryNote(
                                              record.handle.entryId,
                                              value,
                                            );
                                            records = await store
                                                .loadRecentDirectoryRecords();
                                            await ref
                                                .read(
                                                    directoryControllerProvider
                                                        .notifier)
                                                .reloadRecent();
                                          },
                                        );
                                        setModalState(() {});
                                      },
                                      onDelete: () async {
                                        await store.removeRecentDirectory(
                                            record.handle.entryId);
                                        records = await store
                                            .loadRecentDirectoryRecords();
                                        await ref
                                            .read(directoryControllerProvider
                                                .notifier)
                                            .reloadRecent();
                                        setModalState(() {});
                                      },
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
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
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Dialog(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 520, maxHeight: 560),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              context.l10n.homeRecentAddresses,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: records.isEmpty
                            ? Center(child: Text(context.l10n.homeRecentEmpty))
                            : ReorderableListView.builder(
                                buildDefaultDragHandles: false,
                                proxyDecorator: (
                                  Widget child,
                                  int index,
                                  Animation<double> animation,
                                ) {
                                  return child;
                                },
                                itemCount: records.length,
                                onReorder: (int oldIndex, int newIndex) async {
                                  if (newIndex > oldIndex) {
                                    newIndex -= 1;
                                  }
                                  final RecentAddressRecord item =
                                      records.removeAt(oldIndex);
                                  records.insert(newIndex, item);
                                  setModalState(() {});
                                  await store.reorderRecentAddresses(records);
                                  await ref
                                      .read(
                                          connectionControllerProvider.notifier)
                                      .reloadRecent();
                                },
                                itemBuilder: (BuildContext context, int index) {
                                  final RecentAddressRecord record =
                                      records[index];
                                  return Padding(
                                    key: ValueKey<String>(record.address),
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: RecentRecordCard(
                                      title: record.label,
                                      subtitle: record.address == record.label
                                          ? null
                                          : record.address,
                                      dragHandle: ReorderableDragStartListener(
                                        index: index,
                                        child: Icon(
                                          Icons.drag_indicator_rounded,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ),
                                      onUse: () {
                                        Navigator.of(context).pop();
                                        _addressController.text =
                                            record.address;
                                        _connectFromInput();
                                      },
                                      onEditRecord: () async {
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
                                            records = await store
                                                .loadRecentAddressRecords();
                                            await ref
                                                .read(
                                                    connectionControllerProvider
                                                        .notifier)
                                                .reloadRecent();
                                          },
                                        );
                                        setModalState(() {});
                                      },
                                      onDelete: () async {
                                        await store.removeRecentAddress(
                                            record.address);
                                        records = await store
                                            .loadRecentAddressRecords();
                                        await ref
                                            .read(connectionControllerProvider
                                                .notifier)
                                            .reloadRecent();
                                        setModalState(() {});
                                      },
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
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
    final TextEditingController controller =
        TextEditingController(text: initialValue ?? '');
    final bool? shouldSave = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: context.l10n.homeRecentAlias,
                      hintText: context.l10n.homeRecentAliasHint,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    maxLength: 24,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(context.l10n.commonCancel),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: Text(context.l10n.commonConfirm),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (shouldSave == true) {
      await onSave(controller.text);
    }
    controller.dispose();
  }

  Future<void> _showRecentAddressDialog({
    required String initialAddress,
    required String? initialAlias,
    required Future<void> Function({
      required String address,
      required String? alias,
    }) onSave,
  }) async {
    final TextEditingController addressController =
        TextEditingController(text: initialAddress);
    final TextEditingController aliasController =
        TextEditingController(text: initialAlias ?? '');
    String? addressError;
    final bool? shouldSave = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Dialog(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        context.l10n.homeRecentEditAddress,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: addressController,
                        decoration: InputDecoration(
                          labelText: context.l10n.homeRecentAddressField,
                          hintText: context.l10n.homePeerAddressHint,
                          errorText: addressError,
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: aliasController,
                        decoration: InputDecoration(
                          labelText: context.l10n.homeRecentAlias,
                          hintText: context.l10n.homeRecentAliasHint,
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        maxLength: 24,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: Text(context.l10n.commonCancel),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () {
                              if (addressController.text.trim().isEmpty) {
                                setState(() {
                                  addressError =
                                      context.l10n.homeRecentAddressRequired;
                                });
                                return;
                              }
                              Navigator.of(context).pop(true);
                            },
                            child: Text(context.l10n.commonConfirm),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    if (shouldSave == true) {
      await onSave(
        address: addressController.text.trim(),
        alias: aliasController.text,
      );
    }
    addressController.dispose();
    aliasController.dispose();
  }

  Future<void> _refreshPreviewAfterExecution({
    required PreviewState previewState,
    required DirectoryState directoryState,
    required ExecutionState executionState,
  }) async {
    final ExecutionStatus status = executionState.status;
    if (status != ExecutionStatus.completed &&
        status != ExecutionStatus.cancelled) {
      return;
    }

    final DirectoryHandle? sourceRoot = directoryState.handle;
    if (sourceRoot == null) {
      ref.read(previewControllerProvider.notifier).clear();
      return;
    }

    if (previewState.mode == PreviewMode.local) {
      final String? targetRootId = executionState.targetRoot;
      if (targetRootId == null || targetRootId.isEmpty) {
        ref.read(previewControllerProvider.notifier).clear();
        return;
      }
      await ref.read(previewControllerProvider.notifier).buildLocalPreview(
            sourceRoot: sourceRoot,
            targetRoot: DirectoryHandle(
              entryId: targetRootId,
              displayName: targetRootId,
            ),
            deleteEnabled: previewState.deleteEnabled,
            extensionFilter: previewState.activeExtension,
            ignoredExtensions:
                ref.read(settingsControllerProvider).ignoredExtensions,
          );
      return;
    }

    if (previewState.mode == PreviewMode.remote) {
      final ScanSnapshot? remoteSnapshot = await ref
          .read(connectionControllerProvider.notifier)
          .refreshRemoteSnapshot(
            clearTransientState: false,
          );
      if (remoteSnapshot == null) {
        ref.read(previewControllerProvider.notifier).clear();
        return;
      }
      final ScanSnapshot localSnapshot =
          await ref.read(directoryScannerProvider).scan(
                root: sourceRoot,
                deviceId: 'local-device',
              );
      await ref
          .read(previewControllerProvider.notifier)
          .buildPreviewFromSnapshots(
            source: localSnapshot,
            target: remoteSnapshot,
            deleteEnabled: previewState.deleteEnabled,
            extensionFilter: previewState.activeExtension,
            ignoredExtensions:
                ref.read(settingsControllerProvider).ignoredExtensions,
            sourceRootId: sourceRoot.entryId,
          );
      return;
    }

    ref.read(previewControllerProvider.notifier).clear();
  }
}
