import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_sync/core/utils/extension_normalizer.dart';
import 'package:music_sync/features/preview/state/preview_state.dart';
import 'package:music_sync/models/scan_snapshot.dart';
import 'package:music_sync/services/diff/diff_engine.dart';
import 'package:music_sync/services/file_access/file_access_entry.dart';
import 'package:music_sync/services/file_access/file_access_provider.dart';
import 'package:music_sync/services/scanning/directory_scanner.dart';
import 'package:music_sync/services/scanning/scan_cache_service.dart';

final Provider<DiffEngine> diffEngineProvider = Provider<DiffEngine>(
  (Ref ref) => DiffEngine(),
);

final Provider<ScanCacheService> scanCacheServiceProvider =
    Provider<ScanCacheService>((Ref ref) => ScanCacheService());

final Provider<DirectoryScanner> directoryScannerProvider =
    Provider<DirectoryScanner>((Ref ref) {
      return DirectoryScanner(
        gateway: ref.watch(fileAccessGatewayProvider),
        cacheService: ref.watch(scanCacheServiceProvider),
      );
    });

class PreviewController extends Notifier<PreviewState> {
  DiffEngine get _diffEngine => ref.read(diffEngineProvider);
  DirectoryScanner get _scanner => ref.read(directoryScannerProvider);

  @override
  PreviewState build() => PreviewState.initial();

  void loadPlan({
    required ScanSnapshot source,
    required ScanSnapshot target,
    required bool deleteEnabled,
    List<String> ignoredExtensions = const <String>[],
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
        ignoredExtensions: ignoredExtensions,
        excludedExtensions: state.excludedExtensions,
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
        ignoredExtensions: ignoredExtensions,
        excludedExtensions: state.excludedExtensions,
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
    List<String> ignoredExtensions = const <String>[],
    Set<String> excludedExtensions = const <String>{},
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
      final ScanSnapshot baseSource = _filterIgnored(
        rawSource,
        ignoredExtensions,
      );
      final ScanSnapshot baseTarget = _filterIgnored(
        rawTarget,
        ignoredExtensions,
      );
      final List<String> availableExtensions = _collectExtensions(
        baseSource,
        baseTarget,
      );
      final ScanSnapshot source = _applyPlanFilters(
        baseSource,
        activeExtension: extensionFilter,
        excludedExtensions: excludedExtensions,
      );
      final ScanSnapshot target = _applyPlanFilters(
        baseTarget,
        activeExtension: extensionFilter,
        excludedExtensions: excludedExtensions,
      );

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
        sourceSnapshot: baseSource,
        targetSnapshot: baseTarget,
        deleteEnabled: deleteEnabled,
        ignoredExtensions: ignoredExtensions,
        excludedExtensions: excludedExtensions,
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
        ignoredExtensions: ignoredExtensions,
        excludedExtensions: excludedExtensions,
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
    List<String> ignoredExtensions = const <String>[],
    Set<String> excludedExtensions = const <String>{},
    String? sourceRootId,
  }) async {
    state = PreviewState(status: PreviewStatus.loading, plan: state.plan);

    try {
      final ScanSnapshot baseSource = _filterIgnored(source, ignoredExtensions);
      final ScanSnapshot baseTarget = _filterIgnored(target, ignoredExtensions);
      final List<String> availableExtensions = _collectExtensions(
        baseSource,
        baseTarget,
      );
      final ScanSnapshot filteredSource = _applyPlanFilters(
        baseSource,
        activeExtension: extensionFilter,
        excludedExtensions: excludedExtensions,
      );
      final ScanSnapshot filteredTarget = _applyPlanFilters(
        baseTarget,
        activeExtension: extensionFilter,
        excludedExtensions: excludedExtensions,
      );
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
        sourceSnapshot: baseSource,
        targetSnapshot: baseTarget,
        deleteEnabled: deleteEnabled,
        ignoredExtensions: ignoredExtensions,
        excludedExtensions: excludedExtensions,
        sourceRootId: sourceRootId ?? source.rootId,
      );
    } catch (error) {
      state = PreviewState(
        status: PreviewStatus.failed,
        plan: state.plan,
        mode: PreviewMode.remote,
        availableExtensions: state.availableExtensions,
        activeExtension: extensionFilter,
        sourceSnapshot: state.sourceSnapshot ?? source,
        targetSnapshot: state.targetSnapshot ?? target,
        deleteEnabled: deleteEnabled,
        ignoredExtensions: ignoredExtensions,
        excludedExtensions: excludedExtensions,
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
        ignoredExtensions: state.ignoredExtensions,
        excludedExtensions: state.excludedExtensions,
        sourceRootId: state.sourceRootId,
        errorMessage: state.errorMessage,
      );
      return;
    }

    try {
      final ScanSnapshot source = _applyPlanFilters(
        rawSource,
        activeExtension: extensionFilter,
        excludedExtensions: state.excludedExtensions,
      );
      final ScanSnapshot target = _applyPlanFilters(
        rawTarget,
        activeExtension: extensionFilter,
        excludedExtensions: state.excludedExtensions,
      );
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
        ignoredExtensions: state.ignoredExtensions,
        excludedExtensions: state.excludedExtensions,
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
        ignoredExtensions: state.ignoredExtensions,
        excludedExtensions: state.excludedExtensions,
        sourceRootId: state.sourceRootId,
        errorMessage: PreviewState.localizeErrorMessage(error.toString()),
      );
    }
  }

  void toggleExcludedExtension(String extension) {
    if (extension == '*') {
      return;
    }
    final ScanSnapshot? rawSource = state.sourceSnapshot;
    final ScanSnapshot? rawTarget = state.targetSnapshot;
    if (rawSource == null || rawTarget == null) {
      return;
    }

    final Set<String> nextExcluded = <String>{...state.excludedExtensions};
    if (nextExcluded.contains(extension)) {
      nextExcluded.remove(extension);
    } else {
      nextExcluded.add(extension);
    }

    try {
      final ScanSnapshot source = _applyPlanFilters(
        rawSource,
        activeExtension: state.activeExtension,
        excludedExtensions: nextExcluded,
      );
      final ScanSnapshot target = _applyPlanFilters(
        rawTarget,
        activeExtension: state.activeExtension,
        excludedExtensions: nextExcluded,
      );
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
        activeExtension: state.activeExtension,
        sourceSnapshot: rawSource,
        targetSnapshot: rawTarget,
        deleteEnabled: state.deleteEnabled,
        ignoredExtensions: state.ignoredExtensions,
        excludedExtensions: nextExcluded,
        sourceRootId: state.sourceRootId,
      );
    } catch (error) {
      state = PreviewState(
        status: PreviewStatus.failed,
        plan: state.plan,
        mode: state.mode,
        availableExtensions: state.availableExtensions,
        activeExtension: state.activeExtension,
        sourceSnapshot: rawSource,
        targetSnapshot: rawTarget,
        deleteEnabled: state.deleteEnabled,
        ignoredExtensions: state.ignoredExtensions,
        excludedExtensions: nextExcluded,
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

  ScanSnapshot _filterExcluded(
    ScanSnapshot snapshot,
    Set<String> excludedExtensions,
  ) {
    if (excludedExtensions.isEmpty) {
      return snapshot;
    }
    return ScanSnapshot(
      rootId: snapshot.rootId,
      rootDisplayName: snapshot.rootDisplayName,
      deviceId: snapshot.deviceId,
      scannedAt: snapshot.scannedAt,
      entries: snapshot.entries.where((entry) {
        if (entry.isDirectory) {
          return true;
        }
        return !excludedExtensions.contains(_extensionOf(entry.relativePath));
      }).toList(),
      cacheVersion: snapshot.cacheVersion,
      warnings: snapshot.warnings,
    );
  }

  ScanSnapshot _applyPlanFilters(
    ScanSnapshot snapshot, {
    required String activeExtension,
    required Set<String> excludedExtensions,
  }) {
    final ScanSnapshot afterExcluded = _filterExcluded(
      snapshot,
      excludedExtensions,
    );
    return _filterSnapshot(afterExcluded, activeExtension);
  }

  ScanSnapshot _filterIgnored(
    ScanSnapshot snapshot,
    List<String> ignoredExtensions,
  ) {
    if (ignoredExtensions.isEmpty) {
      return snapshot;
    }
    final Set<String> ignored = ignoredExtensions
        .map(normalizeExtensionRule)
        .where((String value) => value.isNotEmpty)
        .toSet();
    return ScanSnapshot(
      rootId: snapshot.rootId,
      rootDisplayName: snapshot.rootDisplayName,
      deviceId: snapshot.deviceId,
      scannedAt: snapshot.scannedAt,
      entries: snapshot.entries.where((entry) {
        if (entry.isDirectory) {
          return true;
        }
        return !ignored.contains(_extensionOf(entry.relativePath));
      }).toList(),
      cacheVersion: snapshot.cacheVersion,
      warnings: snapshot.warnings,
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

final NotifierProvider<PreviewController, PreviewState>
previewControllerProvider = NotifierProvider<PreviewController, PreviewState>(
  PreviewController.new,
);
