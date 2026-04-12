import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:music_sync/app/routes/route_names.dart';
import 'package:music_sync/features/connection/state/connection_controller.dart';
import 'package:music_sync/features/connection/state/connection_state.dart'
    as peer_connection;
import 'package:music_sync/features/directory/state/directory_controller.dart';
import 'package:music_sync/features/directory/state/directory_state.dart';
import 'package:music_sync/features/execution/state/execution_controller.dart';
import 'package:music_sync/features/execution/state/execution_state.dart';
import 'package:music_sync/features/home/presentation/widgets/preview_workbench_section/preview_workbench_actions.dart';
import 'package:music_sync/features/preview/models/diff_item_detail_view_data.dart';
import 'package:music_sync/features/preview/presentation/widgets/desktop/preview_desktop_list_pane.dart';
import 'package:music_sync/features/preview/presentation/widgets/desktop/preview_desktop_sidebar.dart';
import 'package:music_sync/features/preview/presentation/widgets/diff_item_detail_viewer.dart';
import 'package:music_sync/features/preview/state/preview_controller.dart';
import 'package:music_sync/features/preview/state/preview_state.dart';
import 'package:music_sync/features/settings/state/settings_controller.dart';
import 'package:music_sync/l10n/app_localizations_ext.dart';
import 'package:music_sync/models/diff_item.dart';
import 'package:music_sync/models/sync_plan.dart';

class PreviewDesktopWorkbench extends ConsumerStatefulWidget {
  const PreviewDesktopWorkbench({super.key});

  @override
  ConsumerState<PreviewDesktopWorkbench> createState() =>
      _PreviewDesktopWorkbenchState();
}

class _PreviewDesktopWorkbenchState
    extends ConsumerState<PreviewDesktopWorkbench> {
  Set<String> _selectedExtensions = <String>{'*'};
  bool _selectAllSections = true;
  Set<DiffType> _selectedSections = <DiffType>{DiffType.copy, DiffType.delete};
  String _searchQuery = '';
  DiffItem? _selectedItem;

  @override
  Widget build(BuildContext context) {
    final PreviewState previewState = ref.watch(previewControllerProvider);
    final DirectoryState directoryState = ref.watch(
      directoryControllerProvider,
    );
    final peer_connection.ConnectionState connectionState = ref.watch(
      connectionControllerProvider,
    );
    final ExecutionState executionState = ref.watch(
      executionControllerProvider,
    );
    final List<String> ignoredExtensions = ref
        .watch(settingsControllerProvider)
        .ignoredExtensions;
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

    final List<DiffItem> searchedCopyItems = _applySearchFilter(
      filteredCopyItems,
    );
    final List<DiffItem> searchedDeleteItems = _applySearchFilter(
      filteredDeleteItems,
    );
    final List<DiffItem> searchedConflictItems = _applySearchFilter(
      filteredConflictItems,
    );

    final List<DiffItem> activeItems = <DiffItem>[
      if (_selectAllSections || _selectedSections.contains(DiffType.copy))
        ...searchedCopyItems,
      if (_selectAllSections || _selectedSections.contains(DiffType.delete))
        ...searchedDeleteItems,
    ];

    final SyncPlanSummary summary = _buildVisibleSummary(
      filteredCopyItems: searchedCopyItems,
      filteredDeleteItems: searchedDeleteItems,
      filteredConflictItems: searchedConflictItems,
    );

    final bool isBusy = previewState.status == PreviewStatus.loading;
    final bool hasRemoteDirectoryReady =
        connectionState.isRemoteDirectoryReady ||
        connectionState.remoteSnapshot != null;
    final bool canBuildPreview =
        !isBusy &&
        directoryState.handle != null &&
        hasRemoteDirectoryReady &&
        previewState.mode != PreviewMode.local;
    final bool hasExecutableItems =
        previewState.plan.copyItems.isNotEmpty ||
        previewState.plan.deleteItems.isNotEmpty;
    final bool canStartSync =
        previewState.mode == PreviewMode.remote &&
        connectionState.remoteSnapshot != null &&
        previewState.targetSnapshot?.rootId ==
            connectionState.remoteSnapshot!.rootId &&
        hasExecutableItems &&
        !isBusy;
    final bool isExecuting = executionState.status == ExecutionStatus.running;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          flex: 7,
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: PreviewDesktopListPane(
              items: activeItems,
              selectedItemPath: _selectedItem?.relativePath,
              onSelectItem: _onSelectItem,
              searchQuery: _searchQuery,
              onSearchChanged: _onSearchChanged,
              selectAllSections: _selectAllSections,
              selectedSections: _selectedSections,
              onToggleSection: _onToggleSection,
              activeItemCount: activeItems.length,
              filteredCopyCount: searchedCopyItems.length,
              filteredDeleteCount: searchedDeleteItems.length,
              filteredConflictCount: 0,
              targetIsRemote: previewState.mode == PreviewMode.remote,
            ),
          ),
        ),
        SizedBox(
          width: _sidebarWidth(context),
          child: PreviewDesktopSidebar(
            showActionButtons: previewState.mode == PreviewMode.remote,
            showBuildPreviewButton: previewState.mode != PreviewMode.local,
            conflictCount: previewState.plan.conflictItems.length,
            canBuildPreview: canBuildPreview,
            canStartSync: canStartSync,
            isExecuting: isExecuting,
            onBuildPreview: directoryState.handle == null
                ? () async {}
                : () => PreviewWorkbenchActions.buildRemotePreview(
                    ref: ref,
                    sourceRoot: directoryState.handle!,
                    ignoredExtensions: ignoredExtensions,
                  ),
            onStartSync: () => PreviewWorkbenchActions.executeRemoteSyncFlow(
              context: context,
              ref: ref,
              previewState: previewState,
              directoryState: directoryState,
              connectionState: connectionState,
            ),
            onCancelSync: () {
              ref.read(executionControllerProvider.notifier).cancel();
            },
            onViewConflicts: previewState.plan.conflictItems.isNotEmpty
                ? () {
                    context.goNamed(RouteNames.previewConflicts);
                  }
                : null,
            sourceDeviceLabel: _localDeviceDisplayName(),
            targetDeviceLabel: _targetDeviceLabel(
              previewState,
              connectionState,
            ),
            isTransferConnected:
                connectionState.peer != null &&
                connectionState.status ==
                    peer_connection.ConnectionStatus.connected,
            hasLocalDirectory: directoryState.handle != null,
            hasRemoteDirectory: hasRemoteDirectoryReady,
            extensionOptions: extensionOptions,
            selectedExtensions: _selectedExtensions,
            excludedExtensions: previewState.excludedExtensions,
            ignoredExtensions: ignoredExtensions,
            isAllExtensionsSelected: isAllExtensionsSelected,
            isBusy: isBusy,
            onToggleExtension: _onToggleExtension,
            onLongPressExtension: (String extension) =>
                _onLongPressExtension(extension, previewState),
            summary: summary,
            previewStatusLoaded: previewState.status == PreviewStatus.loaded,
          ),
        ),
      ],
    );
  }

  String _targetDeviceLabel(
    PreviewState previewState,
    peer_connection.ConnectionState connectionState,
  ) {
    return switch (previewState.mode) {
      PreviewMode.remote => connectionState.peer?.deviceName ?? 'Remote',
      PreviewMode.local => 'Local target',
      PreviewMode.none => connectionState.peer?.deviceName ?? 'Remote',
    };
  }

  String _localDeviceNameFallback() {
    return 'Local';
  }

  String _localDeviceDisplayName() {
    final settingsState = ref.read(settingsControllerProvider);
    final String displayName = settingsState.deviceDisplayName.trim();
    if (displayName.isNotEmpty) {
      return displayName;
    }
    final String alias = settingsState.deviceAlias.trim();
    if (alias.isNotEmpty) {
      return alias;
    }
    return _localDeviceNameFallback();
  }

  double _sidebarWidth(BuildContext context) {
    final double totalWidth = MediaQuery.sizeOf(context).width;
    const double maxSidebar = 420;
    const double minLeft = 640;
    final double sidebarFromRatio = (totalWidth * 0.35).clamp(
      280.0,
      maxSidebar,
    );
    final double leftRemaining = totalWidth - sidebarFromRatio;
    if (leftRemaining < minLeft) {
      return (totalWidth - minLeft).clamp(280.0, maxSidebar);
    }
    return sidebarFromRatio;
  }

  void _onSelectItem(DiffItem item) {
    setState(() {
      _selectedItem = item;
    });
    final PreviewState ps = ref.read(previewControllerProvider);
    final DiffItemDetailViewData detail = DiffItemDetailViewData.fromDiffItem(
      item,
      sourceIsRemote: false,
      targetIsRemote: ps.mode == PreviewMode.remote,
    );
    showDiffItemDetailViewer(context, data: detail);
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
    });
  }

  List<DiffItem> _applySearchFilter(List<DiffItem> items) {
    if (_searchQuery.isEmpty) return items;
    final String query = _searchQuery.toLowerCase();
    return items
        .where(
          (DiffItem item) => item.relativePath.toLowerCase().contains(query),
        )
        .toList();
  }

  void _onToggleSection(DiffType? type) {
    setState(() {
      if (type == null) {
        _selectAllSections = true;
        _selectedSections = <DiffType>{DiffType.copy, DiffType.delete};
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
  }

  void _onToggleExtension(String extension) {
    setState(() {
      final bool selected = extension == '*'
          ? (_selectedExtensions.length == 1 &&
                _selectedExtensions.contains('*'))
          : _selectedExtensions.contains(extension);
      _selectedExtensions = PreviewWorkbenchActions.toggleExtensionSelection(
        current: _selectedExtensions,
        extension: extension,
        selected: !selected,
      );
    });
  }

  void _onLongPressExtension(String extension, PreviewState previewState) {
    HapticFeedback.mediumImpact();
    final bool wasExcluded = previewState.excludedExtensions.contains(
      extension,
    );
    ref
        .read(previewControllerProvider.notifier)
        .toggleExcludedExtension(extension);
    setState(() {
      if (!wasExcluded) {
        _selectedExtensions = _selectedExtensions..remove(extension);
        if (_selectedExtensions.isEmpty) {
          _selectedExtensions = <String>{'*'};
        }
      }
    });
    if (!mounted) return;
    final String message = wasExcluded
        ? context.l10n.previewExtensionRestored(extension)
        : context.l10n.previewExtensionExcluded(extension);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  SyncPlanSummary _buildVisibleSummary({
    required List<DiffItem> filteredCopyItems,
    required List<DiffItem> filteredDeleteItems,
    required List<DiffItem> filteredConflictItems,
  }) {
    final List<DiffItem> visibleCopyItems =
        _selectAllSections || _selectedSections.contains(DiffType.copy)
        ? filteredCopyItems
        : const <DiffItem>[];
    final List<DiffItem> visibleDeleteItems =
        _selectAllSections || _selectedSections.contains(DiffType.delete)
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
}
