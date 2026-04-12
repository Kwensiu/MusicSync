import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_sync/core/constants/app_constants.dart';
import 'package:music_sync/core/utils/fingerprint_utils.dart';
import 'package:music_sync/features/preview/state/preview_controller.dart';
import 'package:music_sync/models/diff_item.dart';
import 'package:music_sync/models/file_entry.dart';

enum ConflictResolutionAction { later, keepSource, keepTarget, autoMerge }

class ConflictResolutionDraft {
  const ConflictResolutionDraft({required this.itemPath, required this.action});

  final String itemPath;
  final ConflictResolutionAction action;
}

enum ConflictCategory { skip, conflict, autoMerge, noTag }

class ConflictState {
  const ConflictState({
    required this.items,
    required this.categories,
    required this.drafts,
    this.selectedItemPath,
  });

  final List<DiffItem> items;
  final Map<String, ConflictCategory> categories;
  final Map<String, ConflictResolutionDraft> drafts;
  final String? selectedItemPath;

  DiffItem? get selectedItem {
    if (selectedItemPath == null) return null;
    for (final DiffItem item in items) {
      if (item.relativePath == selectedItemPath) return item;
    }
    return null;
  }

  ConflictState copyWith({
    List<DiffItem>? items,
    Map<String, ConflictCategory>? categories,
    Map<String, ConflictResolutionDraft>? drafts,
    String? selectedItemPath,
    bool clearSelection = false,
  }) {
    return ConflictState(
      items: items ?? this.items,
      categories: categories ?? this.categories,
      drafts: drafts ?? this.drafts,
      selectedItemPath: clearSelection
          ? null
          : (selectedItemPath ?? this.selectedItemPath),
    );
  }

  static ConflictState initial() {
    return const ConflictState(
      items: <DiffItem>[],
      categories: <String, ConflictCategory>{},
      drafts: <String, ConflictResolutionDraft>{},
    );
  }
}

class ConflictController extends Notifier<ConflictState> {
  @override
  ConflictState build() {
    // Rebuild conflict state whenever preview state changes (session binding).
    ref.watch(previewControllerProvider);
    return _rebuildFromPreview();
  }

  ConflictState _rebuildFromPreview() {
    final previewState = ref.read(previewControllerProvider);
    final List<DiffItem> conflictItems = previewState.plan.conflictItems;
    final Map<String, ConflictCategory> categories =
        <String, ConflictCategory>{};

    for (final DiffItem item in conflictItems) {
      categories[item.relativePath] = _classify(item);
    }

    return ConflictState(
      items: conflictItems,
      categories: categories,
      drafts: const <String, ConflictResolutionDraft>{},
    );
  }

  void selectItem(String path) {
    state = state.copyWith(selectedItemPath: path);
  }

  void setDraft(String path, ConflictResolutionAction action) {
    final Map<String, ConflictResolutionDraft> nextDrafts =
        <String, ConflictResolutionDraft>{...state.drafts};
    nextDrafts[path] = ConflictResolutionDraft(itemPath: path, action: action);
    state = state.copyWith(drafts: nextDrafts);
  }

  ConflictCategory _classify(DiffItem item) {
    final FileEntry? source = item.source;
    final FileEntry? target = item.target;

    if (source == null || target == null) {
      return ConflictCategory.noTag;
    }

    if (!_isLikelyMusicFile(item.relativePath)) {
      return ConflictCategory.noTag;
    }

    if (source.size == target.size &&
        source.modifiedTime == target.modifiedTime) {
      return ConflictCategory.skip;
    }

    // Fingerprint comparison: currently the scanner does not compute
    // fingerprints, so this branch is effectively dead code until
    // DirectoryScanner is updated to populate FileEntry.fingerprint.
    if (fingerprintsMatch(source.fingerprint, target.fingerprint)) {
      return ConflictCategory.autoMerge;
    }

    return ConflictCategory.conflict;
  }

  bool _isLikelyMusicFile(String relativePath) {
    final int dotIndex = relativePath.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex == relativePath.length - 1) {
      return false;
    }
    final String extension = relativePath.substring(dotIndex + 1).toLowerCase();
    return AppConstants.musicExtensions.contains(extension);
  }
}

final NotifierProvider<ConflictController, ConflictState>
conflictControllerProvider =
    NotifierProvider<ConflictController, ConflictState>(ConflictController.new);
