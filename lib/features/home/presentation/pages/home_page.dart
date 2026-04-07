import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:music_sync/app/routes/route_names.dart';
import 'package:music_sync/app/widgets/app_scaffold.dart';
import 'package:music_sync/app/widgets/section_card.dart';
import 'package:music_sync/core/utils/byte_format.dart';
import 'package:music_sync/features/connection/state/connection_controller.dart';
import 'package:music_sync/features/connection/state/connection_state.dart'
    as peer_connection;
import 'package:music_sync/features/directory/state/directory_controller.dart';
import 'package:music_sync/features/directory/state/directory_state.dart';
import 'package:music_sync/features/execution/state/execution_controller.dart';
import 'package:music_sync/features/execution/state/execution_state.dart';
import 'package:music_sync/features/preview/presentation/widgets/plan_item_list.dart';
import 'package:music_sync/features/preview/state/preview_controller.dart';
import 'package:music_sync/features/preview/state/preview_state.dart';
import 'package:music_sync/l10n/app_localizations_x.dart';
import 'package:music_sync/models/device_info.dart';
import 'package:music_sync/models/diff_item.dart';
import 'package:music_sync/models/scan_snapshot.dart';
import 'package:music_sync/services/file_access/file_access_entry.dart';
import 'package:music_sync/services/file_access/file_access_provider.dart';
import 'package:music_sync/services/scanning/temp_file_cleanup_service.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final TextEditingController _addressController = TextEditingController();
  String _selectedExtension = '*';
  DiffType _selectedSection = DiffType.copy;
  bool _isCleaningSourceTemp = false;
  bool _isCleaningTargetTemp = false;

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DirectoryState directoryState = ref.watch(directoryControllerProvider);
    final peer_connection.ConnectionState connectionState =
        ref.watch(connectionControllerProvider);
    final PreviewState previewState = ref.watch(previewControllerProvider);
    final ExecutionState executionState = ref.watch(executionControllerProvider);

    final bool isStalePlan = previewState.sourceRootId != null &&
        previewState.sourceRootId != directoryState.handle?.entryId;
    final List<String> extensionOptions = previewState.availableExtensions;
    final List<DiffItem> filteredCopyItems = _filterItems(
      previewState.plan.copyItems,
      _selectedExtension,
    );
    final List<DiffItem> filteredDeleteItems = _filterItems(
      previewState.plan.deleteItems,
      _selectedExtension,
    );
    final List<DiffItem> filteredConflictItems = _filterItems(
      previewState.plan.conflictItems,
      _selectedExtension,
    );

    final List<DiffItem> activeItems = switch (_selectedSection) {
      DiffType.copy => filteredCopyItems,
      DiffType.delete => filteredDeleteItems,
      DiffType.conflict => filteredConflictItems,
      DiffType.skip => const <DiffItem>[],
    };
    final bool hasExecutableItems = previewState.plan.copyItems.isNotEmpty ||
        previewState.plan.deleteItems.isNotEmpty;
    final bool isRemotePreview = previewState.mode == PreviewMode.remote;
    final bool isLocalPreview = previewState.mode == PreviewMode.local;
    final bool canRunRemote = connectionState.remoteSnapshot != null &&
        isRemotePreview &&
        previewState.targetSnapshot?.rootId == connectionState.remoteSnapshot!.rootId;
    final bool isConnecting =
        connectionState.status == peer_connection.ConnectionStatus.connecting;
    final bool isPreviewLoading = previewState.status == PreviewStatus.loading;
    final bool isExecuting = executionState.status == ExecutionStatus.running;
    final bool isBusy = isConnecting || isPreviewLoading || isExecuting;
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
            title: context.l10n.homeModeTitle,
            child: Text(context.l10n.homeModeDescription),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: context.l10n.homeSyncDirectionTitle,
            child: Text(context.l10n.homeSyncDirectionDescription),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: context.l10n.homeLocalLibraryTitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(context.l10n.homeLocalSourceHint),
                const SizedBox(height: 8),
                Text(
                  directoryState.handle?.displayName ??
                      context.l10n.homeNoDirectorySelected,
                ),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: isBusy
                      ? null
                      : () {
                    ref.read(directoryControllerProvider.notifier).pickDirectory();
                  },
                  child: Text(context.l10n.homePickDirectory),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: isBusy ||
                          directoryState.handle == null ||
                          _isCleaningSourceTemp
                      ? null
                      : () => _cleanupTempFiles(
                            rootId: directoryState.handle!.entryId,
                            isSource: true,
                          ),
                  child: Text(context.l10n.homeCleanupTempFiles),
                ),
                if (directoryState.recentHandles.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.homeRecentDirectories,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: directoryState.recentHandles.map((handle) {
                      return ActionChip(
                        label: Text(handle.displayName),
                        onPressed: isBusy
                            ? null
                            : () {
                          ref
                              .read(directoryControllerProvider.notifier)
                              .useRecentDirectory(handle);
                        },
                      );
                    }).toList(),
                  ),
                ],
                if (directoryState.errorMessage != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(directoryState.errorMessage!),
                ],
                if (directoryState.preflight?.hasRisk == true) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(context.l10n.directoryPreflightWarningTitle),
                  Text(
                    context.l10n.directoryPreflightSampleSummary(
                      directoryState.preflight!.sampledChildren,
                      directoryState.preflight!.sampledDirectories,
                      directoryState.preflight!.sampledFiles,
                    ),
                  ),
                  ...directoryState.preflight!.reasons.map(
                    (String reason) => Text(_localizePreflightReason(context, reason)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: context.l10n.executionTargetTitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(context.l10n.executionTargetHint),
                const SizedBox(height: 8),
                Text(executionState.targetRoot ?? context.l10n.executionNoTarget),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: isBusy
                      ? null
                      : () async {
                    final handle =
                        await ref.read(fileAccessGatewayProvider).pickDirectory();
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
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: context.l10n.homeRemoteTargetTitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(context.l10n.homeRemoteTargetHint),
                const SizedBox(height: 8),
                Text(
                  connectionState.remoteSnapshot != null
                      ? context.l10n.homeRemoteDirectoryReady
                      : context.l10n.homeRemoteDirectoryMissing,
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.homeConnectionStatus(
                    _localizedConnectionStatus(context, connectionState.status),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  context.l10n.homeListenerTitle,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                if (connectionState.listenPort != null)
                  Text(context.l10n.homeListenerPort(connectionState.listenPort!)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: <Widget>[
                    FilledButton.tonal(
                      onPressed: isBusy ||
                              connectionState.status ==
                                  peer_connection.ConnectionStatus.listening
                          ? null
                          : () {
                              ref
                                  .read(connectionControllerProvider.notifier)
                                  .startListening();
                            },
                      child: Text(context.l10n.homeListenerStart),
                    ),
                    OutlinedButton(
                      onPressed: isBusy ||
                              connectionState.status !=
                                  peer_connection.ConnectionStatus.listening
                          ? null
                          : () {
                              ref
                                  .read(connectionControllerProvider.notifier)
                                  .stopListening();
                            },
                      child: Text(context.l10n.homeListenerStop),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _addressController,
                  decoration: InputDecoration(
                    labelText: context.l10n.homePeerAddressLabel,
                    hintText: context.l10n.homePeerAddressHint,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: isBusy
                      ? null
                      : () {
                    final String input = _addressController.text.trim();
                    if (input.isEmpty) {
                      return;
                    }
                    final List<String> parts = input.split(':');
                    final String host = parts.first;
                    final int port =
                        parts.length > 1 ? int.tryParse(parts[1]) ?? 44888 : 44888;
                    ref.read(connectionControllerProvider.notifier).connect(
                          address: host,
                          port: port,
                        );
                  },
                  child: Text(context.l10n.homeConnect),
                ),
                if (connectionState.peer != null) ...<Widget>[
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: isBusy
                        ? null
                        : () {
                      ref.read(connectionControllerProvider.notifier).disconnect();
                    },
                    child: Text(context.l10n.homeDisconnect),
                  ),
                ],
                if (connectionState.recentAddresses.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.homeRecentAddresses,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: connectionState.recentAddresses.map((String address) {
                      return ActionChip(
                        label: Text(address),
                        onPressed: isBusy
                            ? null
                            : () {
                          _addressController.text = address;
                        },
                      );
                    }).toList(),
                  ),
                ],
                if (connectionState.discoveredDevices.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.homeDiscoveredDevices,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: connectionState.discoveredDevices
                        .map<Widget>((DeviceInfo device) {
                      return ActionChip(
                        label: Text('${device.deviceName} (${device.address}:${device.port})'),
                        onPressed: isBusy
                            ? null
                            : () {
                                _addressController.text = '${device.address}:${device.port}';
                              },
                      );
                    }).toList(),
                  ),
                ],
                if (connectionState.peer != null) ...<Widget>[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: isBusy
                        ? null
                        : () {
                      ref
                          .read(connectionControllerProvider.notifier)
                          .refreshRemoteSnapshot();
                    },
                    child: Text(context.l10n.homeRefreshRemoteIndex),
                  ),
                ],
                const SizedBox(height: 12),
                if (connectionState.peer != null)
                  Text(context.l10n.homePeerName(connectionState.peer!.deviceName)),
                if (connectionState.remoteSnapshot != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    context.l10n.homeRemoteRoot(
                      connectionState.remoteSnapshot!.rootDisplayName,
                    ),
                  ),
                  Text(
                    context.l10n.homeRemoteFiles(
                      connectionState.remoteSnapshot!.asPathMap().length,
                    ),
                  ),
                ],
                if (connectionState.errorMessage != null)
                  Text(
                    _localizeUiError(
                      context,
                      connectionState.errorMessage!,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: context.l10n.previewSummaryTitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  switch (previewState.mode) {
                    PreviewMode.local => context.l10n.previewScopeLocal,
                    PreviewMode.remote => context.l10n.previewScopeRemote,
                    PreviewMode.none => context.l10n.previewScopeLocal,
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.previewStatus(
                    _localizedPreviewStatus(context, previewState.status),
                  ),
                ),
                Text(context.l10n.previewCopyCount(previewState.plan.summary.copyCount)),
                Text(
                  context.l10n.previewDeleteCount(
                    previewState.plan.summary.deleteCount,
                  ),
                ),
                Text(
                  context.l10n.previewConflictCount(
                    previewState.plan.summary.conflictCount,
                  ),
                ),
                Text(
                  context.l10n.previewCopyBytes(
                    formatBytes(previewState.plan.summary.copyBytes),
                  ),
                ),
                if (previewState.errorMessage != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(_localizeUiError(context, previewState.errorMessage!)),
                  if (!_isScanTimeoutError(previewState.errorMessage!)) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(context.l10n.previewScanTimeout),
                  ],
                ],
                if (scanWarnings.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.previewPartialScanWarning(scanWarnings.length),
                  ),
                  Text(context.l10n.previewPartialScanAdvice),
                  const SizedBox(height: 4),
                  ...scanWarnings.take(3).map(
                        (String path) => Text(
                          context.l10n.previewSkippedPath(path),
                        ),
                      ),
                ],
                if (isStalePlan) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(context.l10n.previewStalePlan),
                ],
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: isBusy ||
                          directoryState.handle == null ||
                          executionState.targetRoot == null
                      ? null
                      : () {
                          final DirectoryHandle targetRoot = DirectoryHandle(
                            entryId: executionState.targetRoot!,
                            displayName: executionState.targetRoot!,
                          );
                          ref.read(previewControllerProvider.notifier).buildLocalPreview(
                                sourceRoot: directoryState.handle!,
                                targetRoot: targetRoot,
                                deleteEnabled: true,
                                extensionFilter: _selectedExtension,
                              );
                        },
                  child: Text(context.l10n.previewBuildPlan),
                ),
                const SizedBox(height: 8),
                FilledButton.tonal(
                  onPressed: isBusy ||
                          directoryState.handle == null ||
                          connectionState.remoteSnapshot == null
                      ? null
                      : () async {
                          final ScanSnapshot? remoteSnapshot = await ref
                              .read(connectionControllerProvider.notifier)
                              .refreshRemoteSnapshot();
                          if (remoteSnapshot == null) {
                            return;
                          }
                          final ScanSnapshot localSnapshot = await ref
                              .read(directoryScannerProvider)
                              .scan(
                                root: directoryState.handle!,
                                deviceId: 'local-device',
                              );
                          await ref
                              .read(previewControllerProvider.notifier)
                              .buildPreviewFromSnapshots(
                                source: localSnapshot,
                                target: remoteSnapshot,
                                deleteEnabled: true,
                                extensionFilter: _selectedExtension,
                                sourceRootId: directoryState.handle!.entryId,
                              );
                        },
                  child: Text(context.l10n.previewBuildRemotePlan),
                ),
                if (directoryState.handle == null ||
                    executionState.targetRoot == null) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(context.l10n.previewDirectoryRequired),
                ],
                if (directoryState.handle == null ||
                    connectionState.remoteSnapshot == null) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(context.l10n.previewRemoteDirectoryRequired),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: context.l10n.previewPlanItemsTitle,
            child: previewState.plan.copyItems.isEmpty &&
                    previewState.plan.deleteItems.isEmpty &&
                    previewState.plan.conflictItems.isEmpty
                ? Text(context.l10n.previewEmptyPlan)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        context.l10n.previewSectionTitle,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <MapEntry<DiffType, String>>[
                          MapEntry(DiffType.copy, context.l10n.previewSectionCopy),
                          MapEntry(DiffType.delete, context.l10n.previewSectionDelete),
                          MapEntry(
                            DiffType.conflict,
                            context.l10n.previewSectionConflict,
                          ),
                        ].map((entry) {
                          return ChoiceChip(
                            label: Text(entry.value),
                            selected: _selectedSection == entry.key,
                            onSelected: (bool selected) {
                              if (!selected) {
                                return;
                              }
                              setState(() {
                                _selectedSection = entry.key;
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        context.l10n.previewFilterTitle,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: extensionOptions.map((String extension) {
                          return ChoiceChip(
                            label: Text(
                              extension == '*'
                                  ? context.l10n.previewFilterAll
                                  : extension,
                            ),
                            selected: _selectedExtension == extension,
                            onSelected: isBusy
                                ? null
                                : (bool selected) async {
                              if (!selected) {
                                return;
                              }
                              setState(() {
                                _selectedExtension = extension;
                              });
                              ref
                                  .read(previewControllerProvider.notifier)
                                  .applyExtensionFilter(extension);
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      _buildSection(
                        context,
                        title: switch (_selectedSection) {
                          DiffType.copy => context.l10n.previewSectionCopy,
                          DiffType.delete => context.l10n.previewSectionDelete,
                          DiffType.conflict => context.l10n.previewSectionConflict,
                          DiffType.skip => context.l10n.previewSectionCopy,
                        },
                        items: activeItems,
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: context.l10n.executionProgressTitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  canRunRemote
                      ? context.l10n.executionRemoteReady
                      : context.l10n.executionRemotePending,
                ),
                const SizedBox(height: 8),
                Text(context.l10n.executionKeepForeground),
                const SizedBox(height: 8),
                Text(context.l10n.executionLocalPending),
                const SizedBox(height: 8),
                Text(
                  context.l10n.executionWillCopy(
                    previewState.plan.copyItems.length,
                  ),
                ),
                Text(
                  context.l10n.executionWillDelete(
                    previewState.plan.deleteItems.length,
                  ),
                ),
                Text(
                  context.l10n.executionWillSkipConflict(
                    previewState.plan.conflictItems.length,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  context.l10n.executionProgressFiles(
                    executionState.progress.processedFiles,
                    executionState.progress.totalFiles,
                  ),
                ),
                Text(
                  '${formatBytes(executionState.progress.processedBytes)} / '
                  '${formatBytes(executionState.progress.totalBytes)}',
                ),
                if (executionState.progress.currentPath != null)
                  Text(
                    context.l10n.executionCurrentFile(
                      executionState.progress.currentPath!,
                    ),
                  )
                else
                  Text(context.l10n.executionProgressPlaceholder),
                if (executionState.errorMessage != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(executionState.errorMessage!),
                ],
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: FilledButton(
                        onPressed: canRunRemote && hasExecutableItems
                                && !isBusy
                            ? () async {
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
                            : null,
                        child: Text(context.l10n.executionRunRemote),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: isExecuting
                          ? () {
                              ref.read(executionControllerProvider.notifier).cancel();
                            }
                          : null,
                      child: Text(context.l10n.executionStop),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: FilledButton(
                        onPressed: isBusy ||
                                executionState.targetRoot == null ||
                                !hasExecutableItems ||
                                !isLocalPreview
                            ? null
                            : () async {
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
                                await ref.read(executionControllerProvider.notifier).execute(
                                      plan: previewState.plan,
                                      targetRoot: executionState.targetRoot!,
                                    );
                                await _refreshPreviewAfterExecution(
                                  previewState: previewState,
                                  directoryState: directoryState,
                                  executionState: ref.read(executionControllerProvider),
                                );
                              },
                        child: Text(context.l10n.executionRunLocalDebug),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: isExecuting
                          ? () {
                              ref.read(executionControllerProvider.notifier).cancel();
                            }
                          : null,
                      child: Text(context.l10n.executionStop),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: executionState.targetRoot == null
                      ? null
                      : () => context.pushNamed(RouteNames.result),
                  child: Text(context.l10n.executionOpenResult),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<DiffItem> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Text(context.l10n.previewNoItemsInSection)
        else
          PlanItemList(items: items),
      ],
    );
  }

  String _localizedConnectionStatus(
    BuildContext context,
    peer_connection.ConnectionStatus status,
  ) {
    switch (status) {
      case peer_connection.ConnectionStatus.idle:
        return context.l10n.statusIdle;
      case peer_connection.ConnectionStatus.listening:
        return context.l10n.statusListening;
      case peer_connection.ConnectionStatus.connecting:
        return context.l10n.statusConnecting;
      case peer_connection.ConnectionStatus.connected:
        return context.l10n.statusConnected;
      case peer_connection.ConnectionStatus.disconnected:
        return context.l10n.statusDisconnected;
      case peer_connection.ConnectionStatus.failed:
        return context.l10n.statusFailed;
    }
  }

  String _localizedPreviewStatus(BuildContext context, PreviewStatus status) {
    switch (status) {
      case PreviewStatus.idle:
        return context.l10n.statusIdle;
      case PreviewStatus.loading:
        return context.l10n.statusLoading;
      case PreviewStatus.loaded:
        return context.l10n.statusLoaded;
      case PreviewStatus.failed:
        return context.l10n.statusFailed;
    }
  }

  bool _isScanTimeoutError(String value) {
    return value.contains('Scanning timed out');
  }

  String _localizeUiError(BuildContext context, String value) {
    if (value.contains('Remote device has not selected a shared directory yet.')) {
      return context.l10n.errorRemoteDirectoryNotSelected;
    }
    if (value.contains('Remote device disconnected. Keep the target device in foreground and reconnect.')) {
      return context.l10n.errorRemoteDeviceDisconnected;
    }
    if (value.contains('Connection was refused.')) {
      return context.l10n.errorConnectionRefused;
    }
    if (value.contains('Connection timed out.')) {
      return context.l10n.errorConnectionTimedOut;
    }
    if (value.contains('Remote device responded with an incompatible or invalid protocol message.')) {
      return context.l10n.errorRemoteProtocolInvalid;
    }
    if (value.contains('No remote device is connected.')) {
      return context.l10n.errorNoRemoteDeviceConnected;
    }
    if (value.contains('Scanning timed out.')) {
      return context.l10n.errorScanTimedOut;
    }
    if (value.contains('Unable to access the selected directory.')) {
      return context.l10n.errorDirectoryUnavailable;
    }
    if (value.contains('Scanning failed because part of the directory tree is not accessible.')) {
      return context.l10n.errorDirectoryTreeAccessDenied;
    }
    if (value.contains('Directory access was denied.')) {
      return context.l10n.errorDirectoryAccessDenied;
    }
    if (value.contains('The selected directory is no longer accessible.')) {
      return context.l10n.errorDirectoryUnavailable;
    }
    return value;
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

  List<DiffItem> _filterItems(List<DiffItem> items, String extension) {
    if (extension == '*') {
      return items;
    }
    return items
        .where((DiffItem item) => _extensionOf(item.relativePath) == extension)
        .toList();
  }

  String _extensionOf(String path) {
    final int dotIndex = path.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex == path.length - 1) {
      return '';
    }
    return path.substring(dotIndex + 1).toLowerCase();
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
          );
      return;
    }

    if (previewState.mode == PreviewMode.remote) {
      final ScanSnapshot? remoteSnapshot =
          await ref.read(connectionControllerProvider.notifier).refreshRemoteSnapshot(
                clearTransientState: false,
              );
      if (remoteSnapshot == null) {
        ref.read(previewControllerProvider.notifier).clear();
        return;
      }
      final ScanSnapshot localSnapshot = await ref.read(directoryScannerProvider).scan(
            root: sourceRoot,
            deviceId: 'local-device',
          );
      await ref.read(previewControllerProvider.notifier).buildPreviewFromSnapshots(
            source: localSnapshot,
            target: remoteSnapshot,
            deleteEnabled: previewState.deleteEnabled,
            extensionFilter: previewState.activeExtension,
            sourceRootId: sourceRoot.entryId,
          );
      return;
    }

    ref.read(previewControllerProvider.notifier).clear();
  }
}
