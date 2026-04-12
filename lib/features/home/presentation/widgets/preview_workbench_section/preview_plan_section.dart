import 'package:flutter/material.dart';
import 'package:music_sync/features/preview/presentation/widgets/plan_item_list.dart';
import 'package:music_sync/l10n/app_localizations_ext.dart';
import 'package:music_sync/models/diff_item.dart';

class PreviewPlanSection extends StatelessWidget {
  const PreviewPlanSection({
    required this.header,
    required this.items,
    required this.targetIsRemote,
    super.key,
  });

  final Widget? header;
  final List<DiffItem> items;
  final bool targetIsRemote;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return PlanItemEmptyState(
        header: header,
        message: context.l10n.previewNoItemsInSection,
      );
    }

    return PlanItemList(
      header: header,
      items: items,
      sourceIsRemote: false,
      targetIsRemote: targetIsRemote,
    );
  }
}
