import 'package:flutter/material.dart';
import 'package:music_sync/features/preview/state/conflict_controller.dart';
import 'package:music_sync/l10n/app_localizations_ext.dart';
import 'package:music_sync/models/diff_item.dart';

class PreviewConflictListPane extends StatelessWidget {
  const PreviewConflictListPane({
    required this.items,
    required this.categories,
    required this.drafts,
    required this.selectedItemPath,
    required this.onSelectItem,
    this.shrinkWrap = false,
    super.key,
  });

  final List<DiffItem> items;
  final Map<String, ConflictCategory> categories;
  final Map<String, ConflictResolutionDraft> drafts;
  final String? selectedItemPath;
  final ValueChanged<String> onSelectItem;

  /// When true, the list sizes itself to its content height instead of
  /// expanding to fill available space. Required when placed inside a
  /// [SingleChildScrollView] (e.g. mobile layout).
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    if (items.isEmpty) {
      return Center(
        child: Text(
          context.l10n.conflictListEmpty,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      );
    }

    // Group items by category.
    final Map<ConflictCategory, List<DiffItem>> grouped =
        <ConflictCategory, List<DiffItem>>{};
    for (final ConflictCategory cat in ConflictCategory.values) {
      grouped[cat] = <DiffItem>[];
    }
    for (final DiffItem item in items) {
      final ConflictCategory cat =
          categories[item.relativePath] ?? ConflictCategory.conflict;
      grouped[cat]!.add(item);
    }

    final Widget listContent = ClipRRect(
      borderRadius: shrinkWrap
          ? BorderRadius.zero
          : const BorderRadius.only(
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(18),
            ),
      child: _buildGroupedList(context, grouped),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Text(
              context.l10n.conflictListTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
          shrinkWrap ? listContent : Expanded(child: listContent),
        ],
      ),
    );
  }

  Widget _buildGroupedList(
    BuildContext context,
    Map<ConflictCategory, List<DiffItem>> grouped,
  ) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final ScrollController controller = ScrollController();

    final List<Widget> slivers = <Widget>[];

    for (final ConflictCategory cat in ConflictCategory.values) {
      final List<DiffItem> catItems = grouped[cat]!;
      if (catItems.isEmpty) continue;

      slivers.add(
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            child: Row(
              children: <Widget>[
                Icon(
                  _categoryIcon(cat),
                  size: 14,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  _categoryLabel(context, cat, catItems.length),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      slivers.add(
        SliverList.builder(
          itemCount: catItems.length,
          itemBuilder: (BuildContext context, int index) {
            final DiffItem item = catItems[index];
            final bool isSelected = selectedItemPath == item.relativePath;
            final ConflictResolutionDraft? draft = drafts[item.relativePath];

            return Material(
              color: isSelected
                  ? scheme.secondaryContainer.withValues(alpha: 0.5)
                  : Colors.transparent,
              child: InkWell(
                onTap: () => onSelectItem(item.relativePath),
                child: SizedBox(
                  height: 50,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            item.relativePath,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isSelected
                                  ? scheme.onSecondaryContainer
                                  : null,
                              fontWeight: isSelected ? FontWeight.w600 : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (draft != null) _DraftBadge(action: draft.action),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );

      slivers.add(
        const SliverToBoxAdapter(child: Divider(height: 1, thickness: 1)),
      );
    }

    return Scrollbar(
      controller: controller,
      thumbVisibility: !shrinkWrap,
      child: CustomScrollView(
        controller: controller,
        slivers: slivers,
        shrinkWrap: shrinkWrap,
        physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      ),
    );
  }

  IconData _categoryIcon(ConflictCategory cat) {
    return switch (cat) {
      ConflictCategory.skip => Icons.skip_next_rounded,
      ConflictCategory.conflict => Icons.warning_amber_rounded,
      ConflictCategory.autoMerge => Icons.merge_rounded,
      ConflictCategory.noTag => Icons.music_off_rounded,
    };
  }

  String _categoryLabel(BuildContext context, ConflictCategory cat, int count) {
    return switch (cat) {
      ConflictCategory.skip => context.l10n.conflictCategorySkip(count),
      ConflictCategory.conflict => context.l10n.conflictCategoryConflict(count),
      ConflictCategory.autoMerge => context.l10n.conflictCategoryAutoMerge(
        count,
      ),
      ConflictCategory.noTag => context.l10n.conflictCategoryNoTag(count),
    };
  }
}

class _DraftBadge extends StatelessWidget {
  const _DraftBadge({required this.action});

  final ConflictResolutionAction action;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final (Color bg, Color fg) = switch (action) {
      ConflictResolutionAction.later => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
      ConflictResolutionAction.keepSource => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      ConflictResolutionAction.keepTarget => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      ConflictResolutionAction.autoMerge => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _label(context),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _label(BuildContext context) {
    return switch (action) {
      ConflictResolutionAction.later => context.l10n.conflictActionLater,
      ConflictResolutionAction.keepSource =>
        context.l10n.conflictActionKeepSource,
      ConflictResolutionAction.keepTarget =>
        context.l10n.conflictActionKeepTarget,
      ConflictResolutionAction.autoMerge =>
        context.l10n.conflictActionAutoMerge,
    };
  }
}
