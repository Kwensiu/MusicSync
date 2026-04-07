import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_sync/features/directory/state/directory_state.dart';
import 'package:music_sync/features/execution/state/execution_controller.dart';
import 'package:music_sync/features/preview/state/preview_controller.dart';
import 'package:music_sync/services/file_access/file_access_entry.dart';
import 'package:music_sync/services/file_access/file_access_gateway.dart';
import 'package:music_sync/services/file_access/file_access_provider.dart';
import 'package:music_sync/services/scanning/directory_preflight_service.dart';
import 'package:music_sync/services/storage/recent_items_store.dart';

class DirectoryController extends StateNotifier<DirectoryState> {
  DirectoryController(
    this._gateway,
    this._pickDirectory,
    this._onDirectoryChanged,
    this._store,
    this._preflightService,
  )
      : super(const DirectoryState()) {
    _loadRecent();
  }

  final FileAccessGateway _gateway;
  final Future<DirectoryHandle?> Function() _pickDirectory;
  final void Function() _onDirectoryChanged;
  final RecentItemsStore _store;
  final DirectoryPreflightService _preflightService;

  Future<void> pickDirectory() async {
    try {
      final DirectoryHandle? handle = await _pickDirectory();
      if (handle == null) {
        return;
      }
      await _validateHandle(handle);
      final DirectoryPreflightResult preflight =
          await _preflightService.inspect(handle);
      _onDirectoryChanged();
      await _store.saveRecentDirectory(handle);
      state = DirectoryState(
        handle: handle,
        recentHandles: await _store.loadRecentDirectories(),
        preflight: DirectoryPreflightView(
          sampledDirectories: preflight.sampledDirectories,
          sampledFiles: preflight.sampledFiles,
          sampledChildren: preflight.sampledChildren,
          reasons: preflight.reasons,
        ),
      );
    } catch (error) {
      state = DirectoryState(
        handle: state.handle,
        recentHandles: state.recentHandles,
        errorMessage: DirectoryState.localizeErrorMessage(error.toString()),
      );
    }
  }

  void setDirectory(DirectoryHandle handle) {
    _onDirectoryChanged();
    state = DirectoryState(
      handle: handle,
      recentHandles: state.recentHandles,
      preflight: state.preflight,
    );
  }

  void setError(String message) {
      state = DirectoryState(
        handle: state.handle,
        recentHandles: state.recentHandles,
        errorMessage: DirectoryState.localizeErrorMessage(message),
      );
  }

  Future<void> useRecentDirectory(DirectoryHandle handle) async {
    try {
      await _validateHandle(handle);
      final DirectoryPreflightResult preflight =
          await _preflightService.inspect(handle);
      _onDirectoryChanged();
      await _store.saveRecentDirectory(handle);
      state = DirectoryState(
        handle: handle,
        recentHandles: await _store.loadRecentDirectories(),
        preflight: DirectoryPreflightView(
          sampledDirectories: preflight.sampledDirectories,
          sampledFiles: preflight.sampledFiles,
          sampledChildren: preflight.sampledChildren,
          reasons: preflight.reasons,
        ),
      );
    } catch (error) {
      state = DirectoryState(
        handle: state.handle,
        recentHandles: state.recentHandles,
        errorMessage: DirectoryState.localizeErrorMessage(error.toString()),
      );
    }
  }

  Future<void> _loadRecent() async {
    final List<DirectoryHandle> recentHandles =
        await _store.loadRecentDirectories();
    state = DirectoryState(
      handle: state.handle,
      recentHandles: recentHandles,
      errorMessage: state.errorMessage,
    );
  }

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

final StateNotifierProvider<DirectoryController, DirectoryState>
    directoryControllerProvider =
    StateNotifierProvider<DirectoryController, DirectoryState>(
      (Ref ref) => DirectoryController(
        ref.watch(fileAccessGatewayProvider),
        ref.watch(fileAccessGatewayProvider).pickDirectory,
        () {
          ref.read(previewControllerProvider.notifier).clear();
          ref.read(executionControllerProvider.notifier).clearTransient();
        },
        ref.watch(recentItemsStoreProvider),
        DirectoryPreflightService(ref.watch(fileAccessGatewayProvider)),
      ),
    );
