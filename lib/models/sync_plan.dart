import 'package:music_sync/models/diff_item.dart';

class SyncPlanSummary {
  const SyncPlanSummary({
    required this.copyCount,
    required this.deleteCount,
    required this.conflictCount,
    required this.copyBytes,
  });

  final int copyCount;
  final int deleteCount;
  final int conflictCount;
  final int copyBytes;
}

class SyncPlan {
  const SyncPlan({
    required this.copyItems,
    required this.deleteItems,
    required this.conflictItems,
    required this.summary,
    required this.deleteEnabled,
  });

  final List<DiffItem> copyItems;
  final List<DiffItem> deleteItems;
  final List<DiffItem> conflictItems;
  final SyncPlanSummary summary;
  final bool deleteEnabled;

  factory SyncPlan.empty() {
    return const SyncPlan(
      copyItems: <DiffItem>[],
      deleteItems: <DiffItem>[],
      conflictItems: <DiffItem>[],
      summary: SyncPlanSummary(
        copyCount: 0,
        deleteCount: 0,
        conflictCount: 0,
        copyBytes: 0,
      ),
      deleteEnabled: false,
    );
  }
}
