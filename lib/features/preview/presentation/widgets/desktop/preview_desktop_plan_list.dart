import 'package:flutter/material.dart';
import 'package:music_sync/l10n/app_localizations_ext.dart';
import 'package:music_sync/models/diff_item.dart';
import 'package:smooth_list_view/smooth_list_view.dart';

class PreviewDesktopPlanList extends StatefulWidget {
  const PreviewDesktopPlanList({
    required this.items,
    required this.selectedItemPath,
    required this.onSelectItem,
    required this.targetIsRemote,
    super.key,
  });

  final List<DiffItem> items;
  final String? selectedItemPath;
  final ValueChanged<DiffItem> onSelectItem;
  final bool targetIsRemote;

  @override
  State<PreviewDesktopPlanList> createState() => _PreviewDesktopPlanListState();
}

class _PreviewDesktopPlanListState extends State<PreviewDesktopPlanList> {
  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    if (widget.items.isEmpty) {
      return Center(
        child: Text(
          context.l10n.previewNoItemsInSection,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Scrollbar(
      controller: _controller,
      thumbVisibility: true,
      child: SmoothListView.separated(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        controller: _controller,
        itemCount: widget.items.length,
        separatorBuilder: (BuildContext context, int index) {
          return Divider(
            height: 1,
            thickness: 1,
            color: scheme.outlineVariant.withValues(alpha: 0.32),
          );
        },
        itemBuilder: (BuildContext context, int index) {
          final DiffItem item = widget.items[index];
          final bool isSelected = widget.selectedItemPath == item.relativePath;

          return Material(
            color: isSelected
                ? scheme.secondaryContainer.withValues(alpha: 0.5)
                : Colors.transparent,
            child: InkWell(
              onTap: () => widget.onSelectItem(item),
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
                      _TypeBadge(type: item.type, reason: item.reason),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type, this.reason});

  final DiffType type;
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final (Color background, Color foreground) = switch (type) {
      DiffType.copy => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      DiffType.delete => (scheme.errorContainer, scheme.onErrorContainer),
      DiffType.conflict => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      DiffType.skip => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _label(context),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  String _label(BuildContext context) {
    if (type == DiffType.conflict) {
      return _conflictReasonLabel(context, reason);
    }
    return switch (type) {
      DiffType.copy => context.l10n.diffTypeCopy,
      DiffType.delete => context.l10n.diffTypeDelete,
      DiffType.conflict => context.l10n.diffTypeConflict,
      DiffType.skip => context.l10n.diffTypeSkip,
    };
  }

  String _conflictReasonLabel(BuildContext context, String? value) {
    switch (value) {
      case 'metadata_mismatch':
        return context.l10n.diffConflictMetadataMismatch;
      default:
        return context.l10n.diffTypeConflict;
    }
  }
}
