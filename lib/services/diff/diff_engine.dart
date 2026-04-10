import 'package:music_sync/models/diff_item.dart';
import 'package:music_sync/models/file_entry.dart';
import 'package:music_sync/models/scan_snapshot.dart';
import 'package:music_sync/models/sync_plan.dart';

class DiffEngine {
  SyncPlan buildPlan({
    required ScanSnapshot source,
    required ScanSnapshot target,
    required bool deleteEnabled,
  }) {
    final Map<String, FileEntry> sourceEntries = source.asPathMap();
    final Map<String, FileEntry> targetEntries = target.asPathMap();
    final List<String> allPaths = <String>{
      ...sourceEntries.keys,
      ...targetEntries.keys,
    }.toList()..sort();

    final List<DiffItem> copyItems = <DiffItem>[];
    final List<DiffItem> deleteItems = <DiffItem>[];
    final List<DiffItem> conflictItems = <DiffItem>[];

    for (final String path in allPaths) {
      final FileEntry? sourceEntry = sourceEntries[path];
      final FileEntry? targetEntry = targetEntries[path];

      if (sourceEntry != null && targetEntry == null) {
        copyItems.add(
          DiffItem(
            type: DiffType.copy,
            relativePath: path,
            source: sourceEntry,
          ),
        );
        continue;
      }

      if (sourceEntry == null && targetEntry != null) {
        if (deleteEnabled) {
          deleteItems.add(
            DiffItem(
              type: DiffType.delete,
              relativePath: path,
              target: targetEntry,
            ),
          );
        }
        continue;
      }

      if (sourceEntry == null || targetEntry == null) {
        continue;
      }

      final bool isSame =
          sourceEntry.size == targetEntry.size &&
          sourceEntry.modifiedTime == targetEntry.modifiedTime;

      if (!isSame) {
        conflictItems.add(
          DiffItem(
            type: DiffType.conflict,
            relativePath: path,
            source: sourceEntry,
            target: targetEntry,
            reason: 'metadata_mismatch',
          ),
        );
      }
    }

    return SyncPlan(
      copyItems: copyItems,
      deleteItems: deleteItems,
      conflictItems: conflictItems,
      deleteEnabled: deleteEnabled,
      summary: SyncPlanSummary(
        copyCount: copyItems.length,
        deleteCount: deleteItems.length,
        conflictCount: conflictItems.length,
        copyBytes: copyItems.fold<int>(
          0,
          (int total, DiffItem item) => total + (item.source?.size ?? 0),
        ),
      ),
    );
  }
}
