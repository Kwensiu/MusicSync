import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_sync/features/connection/state/connection_controller.dart';
import 'package:music_sync/features/connection/state/connection_state.dart'
    as peer_connection;
import 'package:music_sync/features/directory/state/directory_state.dart';
import 'package:music_sync/features/execution/state/execution_controller.dart';
import 'package:music_sync/features/execution/state/execution_state.dart';
import 'package:music_sync/features/preview/state/preview_controller.dart';
import 'package:music_sync/features/preview/state/preview_state.dart';
import 'package:music_sync/features/settings/state/settings_controller.dart';
import 'package:music_sync/l10n/app_localizations_ext.dart';
import 'package:music_sync/models/diff_item.dart';
import 'package:music_sync/models/scan_snapshot.dart';
import 'package:music_sync/services/file_access/file_access_entry.dart';

class PreviewWorkbenchActions {
  const PreviewWorkbenchActions._();

  static List<DiffItem> filterItemsByExtensions(
    List<DiffItem> items,
    Set<String> extensions,
  ) {
    if (extensions.contains('*')) {
      return items;
    }
    return items
        .where(
          (DiffItem item) =>
              extensions.contains(extensionOf(item.relativePath)),
        )
        .toList();
  }

  static String extensionOf(String path) {
    final int dotIndex = path.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex == path.length - 1) {
      return '';
    }
    return path.substring(dotIndex + 1).toLowerCase();
  }

  static Set<String> toggleExtensionSelection({
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

  static bool listEquals(List<String> a, List<String> b) {
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

  static Future<void> buildRemotePreview({
    required WidgetRef ref,
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

  static Future<void> executeRemoteSyncFlow({
    required BuildContext context,
    required WidgetRef ref,
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
    await refreshPreviewAfterExecution(
      ref: ref,
      previewState: previewState,
      directoryState: directoryState,
      executionState: ref.read(executionControllerProvider),
    );
  }

  static Future<void> refreshPreviewAfterExecution({
    required WidgetRef ref,
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
