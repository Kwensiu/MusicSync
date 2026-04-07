import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_sync/features/preview/state/preview_state.dart';
import 'package:music_sync/models/scan_snapshot.dart';
import 'package:music_sync/services/file_access/file_access_entry.dart';
import 'package:music_sync/services/file_access/file_access_provider.dart';
import 'package:music_sync/services/diff/diff_engine.dart';
import 'package:music_sync/services/scanning/directory_scanner.dart';
import 'package:music_sync/services/scanning/scan_cache_service.dart';

final Provider<DiffEngine> diffEngineProvider =
    Provider<DiffEngine>((Ref ref) => DiffEngine());

final Provider<ScanCacheService> scanCacheServiceProvider =
    Provider<ScanCacheService>((Ref ref) => ScanCacheService());

final Provider<DirectoryScanner> directoryScannerProvider =
    Provider<DirectoryScanner>((Ref ref) {
      return DirectoryScanner(
        gateway: ref.watch(fileAccessGatewayProvider),
        cacheService: ref.watch(scanCacheServiceProvider),
      );
    });

class PreviewController extends StateNotifier<PreviewState> {
  PreviewController(this._diffEngine, this._scanner) : super(PreviewState.initial());

  final DiffEngine _diffEngine;
  final DirectoryScanner _scanner;

  void loadPlan({
    required ScanSnapshot source,
    required ScanSnapshot target,
    required bool deleteEnabled,
  }) {
    state = PreviewState(status: PreviewStatus.loading, plan: state.plan);

    try {
      final plan = _diffEngine.buildPlan(
        source: source,
        target: target,
        deleteEnabled: deleteEnabled,
      );
      state = PreviewState(
        status: PreviewStatus.loaded,
        plan: plan,
        mode: state.mode,
        availableExtensions: state.availableExtensions,
        activeExtension: state.activeExtension,
        sourceSnapshot: source,
        targetSnapshot: target,
        deleteEnabled: deleteEnabled,
      );
    } catch (error) {
      state = PreviewState(
        status: PreviewStatus.failed,
        plan: state.plan,
        mode: state.mode,
        availableExtensions: state.availableExtensions,
        activeExtension: state.activeExtension,
        sourceSnapshot: source,
        targetSnapshot: target,
        deleteEnabled: deleteEnabled,
        sourceRootId: state.sourceRootId,
        errorMessage: PreviewState.localizeErrorMessage(error.toString()),
      );
    }
  }

  void clear() {
    state = PreviewState.initial();
  }

  Future<void> buildLocalPreview({
    required DirectoryHandle sourceRoot,
    required DirectoryHandle targetRoot,
    required bool deleteEnabled,
    String extensionFilter = '*',
  }) async {
    state = PreviewState(status: PreviewStatus.loading, plan: state.plan);

    try {
      final ScanSnapshot rawSource = await _scanner.scan(
        root: sourceRoot,
        deviceId: 'local-device',
      );
      final ScanSnapshot rawTarget = await _scanner.scan(
        root: targetRoot,
        deviceId: 'local-target',
      );
      final List<String> availableExtensions = _collectExtensions(
        rawSource,
        rawTarget,
      );
      final ScanSnapshot source = _filterSnapshot(rawSource, extensionFilter);
      final ScanSnapshot target = _filterSnapshot(rawTarget, extensionFilter);

      final plan = _diffEngine.buildPlan(
        source: source,
        target: target,
        deleteEnabled: deleteEnabled,
      );
      state = PreviewState(
        status: PreviewStatus.loaded,
        plan: plan,
        mode: PreviewMode.local,
        availableExtensions: availableExtensions,
        activeExtension: extensionFilter,
        sourceSnapshot: rawSource,
        targetSnapshot: rawTarget,
        deleteEnabled: deleteEnabled,
        sourceRootId: sourceRoot.entryId,
      );
    } catch (error) {
      state = PreviewState(
        status: PreviewStatus.failed,
        plan: state.plan,
        mode: PreviewMode.local,
        availableExtensions: state.availableExtensions,
        activeExtension: extensionFilter,
        sourceSnapshot: state.sourceSnapshot,
        targetSnapshot: state.targetSnapshot,
        deleteEnabled: deleteEnabled,
        sourceRootId: sourceRoot.entryId,
        errorMessage: PreviewState.localizeErrorMessage(error.toString()),
      );
    }
  }

  Future<void> buildPreviewFromSnapshots({
    required ScanSnapshot source,
    required ScanSnapshot target,
    required bool deleteEnabled,
    String extensionFilter = '*',
    String? sourceRootId,
  }) async {
    state = PreviewState(status: PreviewStatus.loading, plan: state.plan);

    try {
      final List<String> availableExtensions = _collectExtensions(source, target);
      final ScanSnapshot filteredSource = _filterSnapshot(source, extensionFilter);
      final ScanSnapshot filteredTarget = _filterSnapshot(target, extensionFilter);
      final plan = _diffEngine.buildPlan(
        source: filteredSource,
        target: filteredTarget,
        deleteEnabled: deleteEnabled,
      );
      state = PreviewState(
        status: PreviewStatus.loaded,
        plan: plan,
        mode: PreviewMode.remote,
        availableExtensions: availableExtensions,
        activeExtension: extensionFilter,
        sourceSnapshot: source,
        targetSnapshot: target,
        deleteEnabled: deleteEnabled,
        sourceRootId: sourceRootId ?? source.rootId,
      );
    } catch (error) {
      state = PreviewState(
        status: PreviewStatus.failed,
        plan: state.plan,
        mode: PreviewMode.remote,
        availableExtensions: state.availableExtensions,
        activeExtension: extensionFilter,
        sourceSnapshot: source,
        targetSnapshot: target,
        deleteEnabled: deleteEnabled,
        sourceRootId: sourceRootId ?? source.rootId,
        errorMessage: PreviewState.localizeErrorMessage(error.toString()),
      );
    }
  }

  void applyExtensionFilter(String extensionFilter) {
    final ScanSnapshot? rawSource = state.sourceSnapshot;
    final ScanSnapshot? rawTarget = state.targetSnapshot;
    if (rawSource == null || rawTarget == null) {
      state = PreviewState(
        status: state.status,
        plan: state.plan,
        mode: state.mode,
        availableExtensions: state.availableExtensions,
        activeExtension: extensionFilter,
        sourceSnapshot: state.sourceSnapshot,
        targetSnapshot: state.targetSnapshot,
        deleteEnabled: state.deleteEnabled,
        sourceRootId: state.sourceRootId,
        errorMessage: state.errorMessage,
      );
      return;
    }

    try {
      final ScanSnapshot source = _filterSnapshot(rawSource, extensionFilter);
      final ScanSnapshot target = _filterSnapshot(rawTarget, extensionFilter);
      final plan = _diffEngine.buildPlan(
        source: source,
        target: target,
        deleteEnabled: state.deleteEnabled,
      );
      state = PreviewState(
        status: PreviewStatus.loaded,
        plan: plan,
        mode: state.mode,
        availableExtensions: state.availableExtensions,
        activeExtension: extensionFilter,
        sourceSnapshot: rawSource,
        targetSnapshot: rawTarget,
        deleteEnabled: state.deleteEnabled,
        sourceRootId: state.sourceRootId,
      );
    } catch (error) {
      state = PreviewState(
        status: PreviewStatus.failed,
        plan: state.plan,
        mode: state.mode,
        availableExtensions: state.availableExtensions,
        activeExtension: extensionFilter,
        sourceSnapshot: rawSource,
        targetSnapshot: rawTarget,
        deleteEnabled: state.deleteEnabled,
        sourceRootId: state.sourceRootId,
        errorMessage: PreviewState.localizeErrorMessage(error.toString()),
      );
    }
  }

  List<String> _collectExtensions(ScanSnapshot source, ScanSnapshot target) {
    final Set<String> extensions = <String>{'*'};
    for (final file in [...source.entries, ...target.entries]) {
      final String extension = _extensionOf(file.relativePath);
      if (extension.isNotEmpty) {
        extensions.add(extension);
      }
    }

    final List<String> values = extensions.toList();
    values.sort();
    if (values.remove('*')) {
      values.insert(0, '*');
    }
    return values;
  }

  ScanSnapshot _filterSnapshot(ScanSnapshot snapshot, String extensionFilter) {
    if (extensionFilter == '*') {
      return snapshot;
    }

    return ScanSnapshot(
      rootId: snapshot.rootId,
      rootDisplayName: snapshot.rootDisplayName,
      deviceId: snapshot.deviceId,
      scannedAt: snapshot.scannedAt,
      entries: snapshot.entries.where((entry) {
        if (entry.isDirectory) {
          return false;
        }
        return _extensionOf(entry.relativePath) == extensionFilter;
      }).toList(),
      cacheVersion: snapshot.cacheVersion,
    );
  }

  String _extensionOf(String path) {
    final int dotIndex = path.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex == path.length - 1) {
      return '';
    }
    return path.substring(dotIndex + 1).toLowerCase();
  }
}

final StateNotifierProvider<PreviewController, PreviewState>
    previewControllerProvider =
    StateNotifierProvider<PreviewController, PreviewState>(
      (Ref ref) => PreviewController(
        ref.watch(diffEngineProvider),
        ref.watch(directoryScannerProvider),
      ),
    );
