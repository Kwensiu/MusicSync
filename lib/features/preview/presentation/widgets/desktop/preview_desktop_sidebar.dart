import 'package:flutter/material.dart';
import 'package:music_sync/features/preview/presentation/widgets/desktop/preview_desktop_tools_card.dart';
import 'package:music_sync/models/sync_plan.dart';

class PreviewDesktopSidebar extends StatelessWidget {
  const PreviewDesktopSidebar({
    required this.sourceDeviceLabel,
    required this.targetDeviceLabel,
    required this.isTransferConnected,
    required this.hasLocalDirectory,
    required this.hasRemoteDirectory,
    required this.showActionButtons,
    required this.showBuildPreviewButton,
    required this.conflictCount,
    required this.canBuildPreview,
    required this.canStartSync,
    required this.isExecuting,
    required this.onBuildPreview,
    required this.onStartSync,
    required this.onCancelSync,
    this.onViewConflicts,
    required this.extensionOptions,
    required this.selectedExtensions,
    required this.excludedExtensions,
    required this.ignoredExtensions,
    required this.isAllExtensionsSelected,
    required this.isBusy,
    required this.onToggleExtension,
    required this.onLongPressExtension,
    required this.summary,
    required this.previewStatusLoaded,
    super.key,
  });

  final String sourceDeviceLabel;
  final String targetDeviceLabel;
  final bool isTransferConnected;
  final bool hasLocalDirectory;
  final bool hasRemoteDirectory;
  final bool showActionButtons;
  final bool showBuildPreviewButton;
  final int conflictCount;
  final bool canBuildPreview;
  final bool canStartSync;
  final bool isExecuting;
  final Future<void> Function() onBuildPreview;
  final Future<void> Function() onStartSync;
  final VoidCallback onCancelSync;
  final VoidCallback? onViewConflicts;
  final List<String> extensionOptions;
  final Set<String> selectedExtensions;
  final Set<String> excludedExtensions;
  final List<String> ignoredExtensions;
  final bool isAllExtensionsSelected;
  final bool isBusy;
  final ValueChanged<String> onToggleExtension;
  final ValueChanged<String> onLongPressExtension;
  final SyncPlanSummary summary;
  final bool previewStatusLoaded;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: PreviewDesktopToolsCard(
        sourceDeviceLabel: sourceDeviceLabel,
        targetDeviceLabel: targetDeviceLabel,
        isTransferConnected: isTransferConnected,
        hasLocalDirectory: hasLocalDirectory,
        hasRemoteDirectory: hasRemoteDirectory,
        showActionButtons: showActionButtons,
        showBuildPreviewButton: showBuildPreviewButton,
        conflictCount: conflictCount,
        canBuildPreview: canBuildPreview,
        canStartSync: canStartSync,
        isExecuting: isExecuting,
        onBuildPreview: onBuildPreview,
        onStartSync: onStartSync,
        onCancelSync: onCancelSync,
        onViewConflicts: onViewConflicts,
        extensionOptions: extensionOptions,
        selectedExtensions: selectedExtensions,
        excludedExtensions: excludedExtensions,
        ignoredExtensions: ignoredExtensions,
        isAllExtensionsSelected: isAllExtensionsSelected,
        isBusy: isBusy,
        onToggleExtension: onToggleExtension,
        onLongPressExtension: onLongPressExtension,
        summary: summary,
        previewStatusLoaded: previewStatusLoaded,
      ),
    );
  }
}
