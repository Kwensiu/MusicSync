import 'package:flutter/material.dart';
import 'package:music_sync/features/preview/presentation/widgets/desktop/preview_desktop_list_header.dart';
import 'package:music_sync/features/preview/presentation/widgets/desktop/preview_desktop_plan_list.dart';
import 'package:music_sync/models/diff_item.dart';

class PreviewDesktopListPane extends StatelessWidget {
  const PreviewDesktopListPane({
    required this.items,
    required this.selectedItemPath,
    required this.onSelectItem,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.selectAllSections,
    required this.selectedSections,
    required this.onToggleSection,
    required this.activeItemCount,
    required this.filteredCopyCount,
    required this.filteredDeleteCount,
    required this.filteredConflictCount,
    required this.targetIsRemote,
    super.key,
  });

  final List<DiffItem> items;
  final String? selectedItemPath;
  final ValueChanged<DiffItem> onSelectItem;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final bool selectAllSections;
  final Set<DiffType> selectedSections;
  final ValueChanged<DiffType?> onToggleSection;
  final int activeItemCount;
  final int filteredCopyCount;
  final int filteredDeleteCount;
  final int filteredConflictCount;
  final bool targetIsRemote;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: PreviewDesktopListHeader(
              searchQuery: searchQuery,
              onSearchChanged: onSearchChanged,
              selectAllSections: selectAllSections,
              selectedSections: selectedSections,
              onToggleSection: onToggleSection,
              activeItemCount: activeItemCount,
              filteredCopyCount: filteredCopyCount,
              filteredDeleteCount: filteredDeleteCount,
              filteredConflictCount: filteredConflictCount,
            ),
          ),
          const SizedBox(height: 8),
          Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
              child: PreviewDesktopPlanList(
                items: items,
                selectedItemPath: selectedItemPath,
                onSelectItem: onSelectItem,
                targetIsRemote: targetIsRemote,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
