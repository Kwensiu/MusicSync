import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:music_sync/app/routes/route_names.dart';
import 'package:music_sync/app/widgets/app_scaffold.dart';
import 'package:music_sync/app/widgets/section_card.dart';
import 'package:music_sync/core/errors/app_error_localizer.dart';
import 'package:music_sync/core/utils/byte_format.dart';
import 'package:music_sync/core/utils/path_display_format.dart';
import 'package:music_sync/features/connection/state/connection_controller.dart';
import 'package:music_sync/features/connection/state/connection_state.dart'
    as peer_connection;
import 'package:music_sync/features/directory/state/directory_controller.dart';
import 'package:music_sync/features/directory/state/directory_state.dart';
import 'package:music_sync/features/execution/state/execution_controller.dart';
import 'package:music_sync/features/execution/state/execution_state.dart';
import 'package:music_sync/features/home/presentation/widgets/action_chip_button.dart';
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
    final bool isBusy = isConnecting || isPreviewLoading || isExecuting;
    final bool isConnectUiBusy = isPreviewLoading || isExecuting;
    final bool hasConnectedPeer = connectionState.peer != null &&
        connectionState.status == peer_connection.ConnectionStatus.connected;
    final bool hasRemoteSnapshot = connectionState.remoteSnapshot != null;
    final bool hasRemoteDirectoryReady =
        connectionState.isRemoteDirectoryReady || hasRemoteSnapshot;
    final bool canStartRemoteSync =
        canRunRemote && hasExecutableItems && !isBusy;
    final bool canOpenResult = executionState.targetRoot != null;
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
            child: Builder(
              builder: (BuildContext context) {
                final ColorScheme scheme = Theme.of(context).colorScheme;
                final bool canStopConnection = hasConnectedPeer || isConnecting;
                final bool canShareAddress = connectionState.listenPort != null;
                final Color actionBackground = canStopConnection
                    ? scheme.secondaryContainer
                    : scheme.primary;
                final Color actionForeground = canStopConnection
                    ? scheme.onSecondaryContainer
                    : scheme.onPrimary;

                return DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(context.l10n.homeStepConnectionHint),
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: <Widget>[
                              ActionChipButton(
                                label: _connectionStateChipLabel(
                                    context, connectionState),
                                tone: _connectionStateChipTone(connectionState),
                                onPressed: isConnectUiBusy
                                    ? null
                                    : () => _handleConnectionStateChipTap(
                                        connectionState),
                              ),
                              const SizedBox(width: 8),
                              ActionChipButton(
                                label: context.l10n.homePortChipLabel(
                                  connectionState.listenPort ?? 44888,
                                ),
                                tone: ActionChipTone.neutral,
                                onPressed: isConnectUiBusy
                                    ? null
                                    : () => _showPortDialog(
                                        connectionState.listenPort ?? 44888),
                              ),
                              const SizedBox(width: 8),
                              Tooltip(
                                message: context.l10n.homeShareTooltip,
                                child: IconButton.filledTonal(
                                  onPressed: canShareAddress
                                      ? () => _showShareDialog(connectionState)
                                      : null,
                                  icon: const Icon(Icons.ios_share_outlined),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (connectionState.peer != null) ...<Widget>[
                          const SizedBox(height: 12),
                          Text(context.l10n
                              .homePeerName(connectionState.peer!.deviceName)),
                        ],
                        if (connectionState.errorMessage != null) ...<Widget>[
                          const SizedBox(height: 8),
                          Text(
                            _localizeUiError(
                              context,
                              connectionState.errorMessage!,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        TextField(
                          controller: _addressController,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: scheme.surface,
                            labelText: context.l10n.homePeerAddressLabel,
                            hintText: context.l10n.homePeerAddressHint,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: actionBackground,
                              foregroundColor: actionForeground,
                            ),
                            onPressed: isConnectUiBusy
                                ? null
                                : () => _handleConnectButton(connectionState),
                            child: Text(
                              canStopConnection
                                  ? context.l10n.homeConnectStop
                                  : context.l10n.homeConnect,
                            ),
                          ),
                        ),
                        if (connectionState
                            .recentAddresses.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 12),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  context.l10n.homeRecentAddresses,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                              ),
                              IconButton(
                                tooltip: context.l10n.homeManageRecentItems,
                                onPressed: isConnectUiBusy
                                    ? null
                                    : () => _showRecentAddressManager(),
                                icon: const Icon(Icons.tune_rounded),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: connectionState.recentAddresses
                                .map((String address) {
                              return ActionChip(
                                backgroundColor: scheme.surface,
                                side: BorderSide(color: scheme.outlineVariant),
                                label: Text(
                                  connectionState.recentLabels[address] ??
                                      address,
                                ),
                                onPressed: isConnectUiBusy
                                    ? null
                                    : () {
                                        _addressController.text = address;
                                        _connectFromInput();
                                      },
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: context.l10n.homeStepSourceTitle,
            child: Builder(
              builder: (BuildContext context) {
                final ColorScheme scheme = Theme.of(context).colorScheme;
                final DirectoryHandle? selectedHandle = directoryState.handle;
                final bool hasSelection = selectedHandle != null;
                final bool hasRisk = directoryState.preflight?.hasRisk == true;
                final String sourceLabel = selectedHandle?.displayName ??
                    context.l10n.homeNoDirectorySelected;
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
                          color: hasRisk
                              ? scheme.errorContainer
                              : scheme.outlineVariant,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        sourceLabel,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      if (sourceDetail != null) ...<Widget>[
                                        const SizedBox(height: 2),
                                        Text(
                                          sourceDetail,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: scheme.onSurfaceVariant,
                                              ),
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
                                          tooltip:
                                              context.l10n.homeClearSelection,
                                          visualDensity: VisualDensity.compact,
                                          onPressed: isBusy
                                              ? null
                                              : () {
                                                  ref
                                                      .read(
                                                          directoryControllerProvider
                                                              .notifier)
                                                      .clearDirectory();
                                                },
                                          icon: const Icon(Icons.close_rounded,
                                              size: 18),
                                        )
                                      : null,
                                ),
                              ],
                            ),
                            if (directoryState.errorMessage !=
                                null) ...<Widget>[
                              const SizedBox(height: 12),
                              Text(
                                directoryState.errorMessage!,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: scheme.error,
                                    ),
                              ),
                            ] else if (!hasSelection &&
                                hasRemoteDirectoryReady) ...<Widget>[
                              const SizedBox(height: 12),
                              Text(
                                context
                                    .l10n.homeSourcePendingBecauseRemoteReady,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                            if (hasRisk) ...<Widget>[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: scheme.errorContainer
                                      .withValues(alpha: 0.55),
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
                                      context
                                          .l10n.directoryPreflightWarningTitle,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                            color: scheme.onErrorContainer,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    ...directoryState.preflight!.reasons
                                        .take(2)
                                        .map(
                                          (String reason) => Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 2),
                                            child: Text(
                                              _localizePreflightReason(
                                                  context, reason),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color:
                                                        scheme.onErrorContainer,
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
                                onPressed: isBusy
                                    ? null
                                    : () {
                                        ref
                                            .read(directoryControllerProvider
                                                .notifier)
                                            .pickDirectory();
                                      },
                                child: Text(context.l10n.homePickDirectory),
                              ),
                            ),
                            if (directoryState.hasTempFiles) ...<Widget>[
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: OutlinedButton(
                                  onPressed: isBusy ||
                                          directoryState.handle == null ||
                                          _isCleaningSourceTemp
                                      ? null
                                      : () => _cleanupTempFiles(
                                            rootId:
                                                directoryState.handle!.entryId,
                                            isSource: true,
                                          ),
                                  child:
                                      Text(context.l10n.homeCleanupTempFiles),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (directoryState.recentHandles.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 12),
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
                            onPressed: isBusy
                                ? null
                                : () => _showRecentDirectoryManager(),
                            icon: const Icon(Icons.tune_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
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
                                : () {
                                    ref
                                        .read(directoryControllerProvider
                                            .notifier)
                                        .useRecentDirectory(handle);
                                  },
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: context.l10n.homeStepPreviewTitle,
            child: Builder(
              builder: (BuildContext context) {
                final ThemeData theme = Theme.of(context);
                final ColorScheme scheme = theme.colorScheme;
                final bool hasPlanItems =
                    previewState.plan.copyItems.isNotEmpty ||
                        previewState.plan.deleteItems.isNotEmpty ||
                        previewState.plan.conflictItems.isNotEmpty;
                final String transferDirectionLabel = _transferDirectionValue(
                  context,
                  connectionState: connectionState,
                  previewState: previewState,
                );
                final bool hasLocalDirectory = directoryState.handle != null;
                final bool hasRemoteDirectory =
                    connectionState.isRemoteDirectoryReady ||
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
                                label:
                                    context.l10n.previewTransferDirectionLabel,
                                chip: _MetaChip(
                                  label: transferDirectionLabel,
                                  maxWidth:
                                      MediaQuery.sizeOf(context).width * 0.42,
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
                              text: _localizeUiError(
                                  context, previewState.errorMessage!),
                              detail: !_isScanTimeoutError(
                                      previewState.errorMessage!)
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
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              FilledButton(
                                onPressed: isExecuting
                                    ? () {
                                        ref
                                            .read(executionControllerProvider
                                                .notifier)
                                            .cancel();
                                      }
                                    : canStartRemoteSync
                                        ? () async {
                                            if (previewState
                                                .plan.deleteItems.isNotEmpty) {
                                              final bool? confirmed =
                                                  await showDialog<bool>(
                                                context: context,
                                                builder:
                                                    (BuildContext context) {
                                                  return AlertDialog(
                                                    title: Text(
                                                      context.l10n
                                                          .executionConfirmDeleteTitle,
                                                    ),
                                                    content: Text(
                                                      context.l10n
                                                          .executionConfirmDeleteBody(
                                                        previewState.plan
                                                            .deleteItems.length,
                                                      ),
                                                    ),
                                                    actions: <Widget>[
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.of(
                                                                    context)
                                                                .pop(false),
                                                        child: Text(
                                                          context.l10n
                                                              .commonCancel,
                                                        ),
                                                      ),
                                                      FilledButton(
                                                        onPressed: () =>
                                                            Navigator.of(
                                                                    context)
                                                                .pop(true),
                                                        child: Text(
                                                          context.l10n
                                                              .commonConfirm,
                                                        ),
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
                                                .read(
                                                    executionControllerProvider
                                                        .notifier)
                                                .executeRemote(
                                                  plan: previewState.plan,
                                                  remoteRootId: connectionState
                                                      .remoteSnapshot!.rootId,
                                                );
                                            await _refreshPreviewAfterExecution(
                                              previewState: previewState,
                                              directoryState: directoryState,
                                              executionState: ref.read(
                                                executionControllerProvider,
                                              ),
                                            );
                                          }
                                        : null,
                                child: Text(
                                  isExecuting
                                      ? context.l10n.executionStop
                                      : context.l10n.executionRunRemote,
                                ),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: isBusy ||
                                        directoryState.handle == null ||
                                        !hasRemoteDirectoryReady
                                    ? null
                                    : () async {
                                        final ScanSnapshot? remoteSnapshot =
                                            await ref
                                                .read(
                                                    connectionControllerProvider
                                                        .notifier)
                                                .refreshRemoteSnapshot();
                                        if (remoteSnapshot == null) {
                                          return;
                                        }
                                        final ScanSnapshot localSnapshot =
                                            await ref
                                                .read(directoryScannerProvider)
                                                .scan(
                                                  root: directoryState.handle!,
                                                  deviceId: 'local-device',
                                                );
                                        await ref
                                            .read(previewControllerProvider
                                                .notifier)
                                            .buildPreviewFromSnapshots(
                                              source: localSnapshot,
                                              target: remoteSnapshot,
                                              deleteEnabled: true,
                                              extensionFilter: '*',
                                              ignoredExtensions:
                                                  ignoredExtensions,
                                              sourceRootId: directoryState
                                                  .handle!.entryId,
                                            );
                                      },
                                style: FilledButton.styleFrom(
                                  backgroundColor: scheme.tertiaryContainer,
                                  foregroundColor: scheme.onTertiaryContainer,
                                ),
                                icon: const Icon(Icons.sync_rounded),
                                label:
                                    Text(context.l10n.previewBuildRemotePlan),
                              ),
                              FilledButton.tonal(
                                onPressed: canOpenResult
                                    ? () => context.pushNamed(RouteNames.result)
                                    : null,
                                child: Text(context.l10n.executionOpenResult),
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
                                      _localizedExecutionStatus(
                                        context,
                                        executionState.status,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  LinearProgressIndicator(
                                    value: executionState.progress.totalBytes >
                                            0
                                        ? executionState
                                                .progress.processedBytes /
                                            executionState.progress.totalBytes
                                        : null,
                                    minHeight: 8,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${context.l10n.executionProgressFiles(
                                      executionState.progress.processedFiles,
                                      executionState.progress.totalFiles,
                                    )}  ·  ${formatBytes(executionState.progress.processedBytes)} / ${formatBytes(executionState.progress.totalBytes)}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    executionState.progress.currentPath != null
                                        ? context.l10n.executionCurrentFile(
                                            executionState
                                                .progress.currentPath!,
                                          )
                                        : context
                                            .l10n.executionProgressPlaceholder,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                  if (executionState.errorMessage !=
                                      null) ...<Widget>[
                                    const SizedBox(height: 10),
                                    _InlineMessage(
                                      tone: _InlineMessageTone.error,
                                      text: _localizeUiError(
                                        context,
                                        executionState.errorMessage!,
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
                              ? _selectAllSections
                              : (!_selectAllSections &&
                                  _selectedSections.contains(option.type));
                          return FilterChip(
                            label: Text(option.label),
                            selected: selected,
                            onSelected: (bool nextSelected) {
                              setState(() {
                                if (option.type == null) {
                                  _selectAllSections = true;
                                  _selectedSections = <DiffType>{
                                    DiffType.copy,
                                    DiffType.delete,
                                  };
                                  return;
                                }
                                final DiffType type = option.type!;
                                final Set<DiffType> next = _selectAllSections
                                    ? <DiffType>{type}
                                    : <DiffType>{..._selectedSections};
                                _selectAllSections = false;
                                if (nextSelected) {
                                  next.add(type);
                                } else {
                                  next.remove(type);
                                }
                                if (next.isEmpty) {
                                  next.add(type);
                                }
                                _selectedSections = next;
                              });
                            },
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
                                : _selectedExtensions.contains(extension);
                            return FilterChip(
                              label: Text(
                                extension == '*'
                                    ? context.l10n.previewFilterAll
                                    : extension,
                              ),
                              selected: selected,
                              onSelected: isBusy
                                  ? null
                                  : (bool nextSelected) {
                                      setState(() {
                                        _selectedExtensions =
                                            _toggleExtensionSelection(
                                          current: _selectedExtensions,
                                          extension: extension,
                                          selected: nextSelected,
                                        );
                                      });
                                    },
                            );
                          }).toList(),
                        ),
                      ],
                      const SizedBox(height: 10),
                      _buildSection(
                        context,
                        items: activeItems,
                        conflictItems: filteredConflictItems,
                        targetIsRemote: previewState.mode == PreviewMode.remote,
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],
                );
              },
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
                                    child: _RecentRecordCard(
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
                                    child: _RecentRecordCard(
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

class _RecentRecordCard extends StatelessWidget {
  const _RecentRecordCard({
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
