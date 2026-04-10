import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_sync/features/connection/state/connection_controller.dart';
import 'package:music_sync/features/directory/state/directory_state.dart';
import 'package:music_sync/features/execution/state/execution_controller.dart';
import 'package:music_sync/features/execution/state/execution_state.dart';
import 'package:music_sync/features/preview/state/preview_controller.dart';
import 'package:music_sync/services/file_access/file_access_entry.dart';
import 'package:music_sync/services/file_access/file_access_gateway.dart';
import 'package:music_sync/services/file_access/file_access_provider.dart';
import 'package:music_sync/services/scanning/directory_preflight_service.dart';
import 'package:music_sync/services/scanning/temp_file_cleanup_service.dart';
import 'package:music_sync/services/storage/recent_items_store.dart';

class DirectoryController extends Notifier<DirectoryState> {
  FileAccessGateway get _gateway => ref.read(fileAccessGatewayProvider);
  Future<DirectoryHandle?> Function() get _pickDirectory =>
      ref.read(fileAccessGatewayProvider).pickDirectory;
  void Function({required bool hadDirectorySelected}) get _onDirectoryChanged =>
      ({required bool hadDirectorySelected}) {
        ref.read(previewControllerProvider.notifier).clear();
        final ExecutionController executionController = ref.read(
          executionControllerProvider.notifier,
        );
        final bool isExecutionRunning =
            ref.read(executionControllerProvider).status ==
            ExecutionStatus.running;
        if (hadDirectorySelected && isExecutionRunning) {
          executionController.failActiveExecution(
            'The selected directory is not accessible anymore.',
          );
          return;
        }
        executionController.clearTransient();
      };
  Future<void> Function(DirectoryHandle? handle) get _onHandleUpdated =>
      (DirectoryHandle? handle) async {
        await ref
            .read(connectionControllerProvider.notifier)
            .handleLocalDirectoryChanged(handle);
      };
  RecentItemsStore get _store => ref.read(recentItemsStoreProvider);
  DirectoryPreflightService get _preflightService =>
      DirectoryPreflightService(ref.read(fileAccessGatewayProvider));
  TempFileCleanupService get _tempFileCleanupService =>
      ref.read(tempFileCleanupServiceProvider);
  bool _isDisposed = false;

  @override
  DirectoryState build() {
    _isDisposed = false;
    ref.onDispose(() {
      _isDisposed = true;
    });
    unawaited(_loadRecent());
    return const DirectoryState();
  }

  Future<void> pickDirectory() async {
    try {
      final DirectoryHandle? handle = await _pickDirectory();
      if (handle == null) {
        return;
      }
      await _validateHandle(handle);
      final DirectoryPreflightResult preflight = await _preflightService
          .inspect(handle);
      final bool hasTempFiles = await _tempFileCleanupService.hasTempFiles(
        rootId: handle.entryId,
      );
      _onDirectoryChanged(hadDirectorySelected: state.handle != null);
      await _onHandleUpdated(handle);
      await _store.saveRecentDirectory(handle);
      state = DirectoryState(
        handle: handle,
        recentHandles: await _store.loadRecentDirectories(),
        recentLabels: await _store.loadRecentDirectoryLabels(),
        preflight: DirectoryPreflightView(
          sampledDirectories: preflight.sampledDirectories,
          sampledFiles: preflight.sampledFiles,
          sampledChildren: preflight.sampledChildren,
          reasons: preflight.reasons,
        ),
        hasTempFiles: hasTempFiles,
      );
    } catch (error) {
      state = DirectoryState(
        handle: state.handle,
        recentHandles: state.recentHandles,
        recentLabels: state.recentLabels,
        errorMessage: DirectoryState.localizeErrorMessage(error.toString()),
        preflight: state.preflight,
        hasTempFiles: state.hasTempFiles,
      );
    }
  }

  Future<void> clearDirectory() async {
    _onDirectoryChanged(hadDirectorySelected: state.handle != null);
    await _onHandleUpdated(null);
    state = DirectoryState(
      recentHandles: state.recentHandles,
      recentLabels: state.recentLabels,
    );
  }

  void setDirectory(DirectoryHandle handle) {
    _onDirectoryChanged(hadDirectorySelected: state.handle != null);
    _onHandleUpdated(handle);
    state = DirectoryState(
      handle: handle,
      recentHandles: state.recentHandles,
      recentLabels: state.recentLabels,
      preflight: state.preflight,
      hasTempFiles: state.hasTempFiles,
    );
  }

  void setError(String message) {
    state = DirectoryState(
      handle: state.handle,
      recentHandles: state.recentHandles,
      recentLabels: state.recentLabels,
      errorMessage: DirectoryState.localizeErrorMessage(message),
      preflight: state.preflight,
      hasTempFiles: state.hasTempFiles,
    );
  }

  void setHasTempFiles(bool value) {
    state = DirectoryState(
      handle: state.handle,
      recentHandles: state.recentHandles,
      recentLabels: state.recentLabels,
      errorMessage: state.errorMessage,
      preflight: state.preflight,
      hasTempFiles: value,
    );
  }

  Future<void> useRecentDirectory(DirectoryHandle handle) async {
    try {
      await _validateHandle(handle);
      final DirectoryPreflightResult preflight = await _preflightService
          .inspect(handle);
      final bool hasTempFiles = await _tempFileCleanupService.hasTempFiles(
        rootId: handle.entryId,
      );
      _onDirectoryChanged(hadDirectorySelected: state.handle != null);
      await _onHandleUpdated(handle);
      await _store.saveRecentDirectory(handle);
      state = DirectoryState(
        handle: handle,
        recentHandles: await _store.loadRecentDirectories(),
        recentLabels: await _store.loadRecentDirectoryLabels(),
        preflight: DirectoryPreflightView(
          sampledDirectories: preflight.sampledDirectories,
          sampledFiles: preflight.sampledFiles,
          sampledChildren: preflight.sampledChildren,
          reasons: preflight.reasons,
        ),
        hasTempFiles: hasTempFiles,
      );
    } catch (error) {
      state = DirectoryState(
        handle: state.handle,
        recentHandles: state.recentHandles,
        recentLabels: state.recentLabels,
        errorMessage: DirectoryState.localizeErrorMessage(error.toString()),
        preflight: state.preflight,
        hasTempFiles: state.hasTempFiles,
      );
    }
  }

  Future<void> _loadRecent() async {
    final List<DirectoryHandle> recentHandles = await _store
        .loadRecentDirectories();
    final Map<String, String> recentLabels = await _store
        .loadRecentDirectoryLabels();
    if (_isDisposed) {
      return;
    }
    state = DirectoryState(
      handle: state.handle,
      recentHandles: recentHandles,
      recentLabels: recentLabels,
      errorMessage: state.errorMessage,
      preflight: state.preflight,
      hasTempFiles: state.hasTempFiles,
    );
  }

  Future<void> reloadRecent() => _loadRecent();

  Future<void> _validateHandle(DirectoryHandle handle) async {
    try {
      await _gateway.listChildren(handle.entryId);
    } catch (_) {
      throw Exception(
        'The selected directory is not accessible anymore. Please choose it again.',
      );
    }
  }
}

final Provider<RecentItemsStore> recentItemsStoreProvider =
    Provider<RecentItemsStore>((Ref ref) => RecentItemsStore());

final NotifierProvider<DirectoryController, DirectoryState>
directoryControllerProvider =
    NotifierProvider<DirectoryController, DirectoryState>(
      DirectoryController.new,
    );
