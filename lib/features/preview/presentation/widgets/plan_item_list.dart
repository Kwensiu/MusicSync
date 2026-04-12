import 'package:flutter/material.dart';
import 'package:music_sync/features/preview/models/diff_item_detail_view_data.dart';
import 'package:music_sync/features/preview/presentation/widgets/diff_item_detail_viewer.dart';
import 'package:music_sync/l10n/app_localizations_ext.dart';
import 'package:music_sync/models/diff_item.dart';
import 'package:smooth_list_view/smooth_list_view.dart';

class PlanItemList extends StatefulWidget {
  const PlanItemList({
    required this.items,
    super.key,
    this.header,
    this.maxHeight = 280,
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
    this.contentPadding = const EdgeInsets.symmetric(vertical: 0),
    this.showTopBorder = true,
    this.sourceIsRemote = false,
    this.targetIsRemote = false,
  });

  final List<DiffItem> items;
  final Widget? header;
  final double maxHeight;
  final BorderRadius borderRadius;
  final EdgeInsets contentPadding;
  final bool showTopBorder;
  final bool sourceIsRemote;
  final bool targetIsRemote;

  @override
  State<PlanItemList> createState() => _PlanItemListState();
}

class PlanItemEmptyState extends StatelessWidget {
  const PlanItemEmptyState({required this.message, super.key, this.header});

  final String message;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (header != null) ...<Widget>[header!, const SizedBox(height: 6)],
            Padding(
              padding: EdgeInsets.zero,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 18,
                  ),
                  child: Center(
                    child: Text(
                      message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanItemListState extends State<PlanItemList> {
  static const double _rowHeight = 50;
  static const double _separatorHeight = 1;
  static const Duration _scrollDuration = Duration(milliseconds: 140);
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
    final BorderRadius innerListBorderRadius = widget.header == null
        ? widget.borderRadius
        : BorderRadius.circular(16);
    final double containerTopPadding = widget.header == null ? 0 : 8;
    final double verticalPadding = widget.contentPadding.vertical;
    final double separatorsHeight = widget.items.isEmpty
        ? 0
        : (widget.items.length - 1) * _separatorHeight;
    final double desiredListHeight =
        (widget.items.length * _rowHeight) + separatorsHeight + verticalPadding;
    final double resolvedListHeight = desiredListHeight
        .clamp(0, widget.maxHeight)
        .toDouble();

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: widget.borderRadius,
        border: Border(
          top: widget.showTopBorder
              ? BorderSide(color: scheme.outlineVariant)
              : BorderSide.none,
          left: BorderSide(color: scheme.outlineVariant),
          right: BorderSide(color: scheme.outlineVariant),
          bottom: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(0, containerTopPadding, 0, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (widget.header != null) ...<Widget>[
              widget.header!,
              const SizedBox(height: 6),
            ],
            SizedBox(
              height: resolvedListHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: innerListBorderRadius,
                ),
                child: ClipRRect(
                  borderRadius: innerListBorderRadius,
                  child: Padding(
                    padding: widget.contentPadding,
                    child: Scrollbar(
                      controller: _controller,
                      thumbVisibility: widget.items.length > 12,
                      child: SmoothListView.separated(
                        duration: _scrollDuration,
                        curve: Curves.easeOutCubic,
                        controller: _controller,
                        itemCount: widget.items.length,
                        separatorBuilder: (BuildContext context, int index) {
                          return Divider(
                            height: _separatorHeight,
                            thickness: _separatorHeight,
                            color: scheme.outlineVariant.withValues(
                              alpha: 0.32,
                            ),
                          );
                        },
                        itemBuilder: (BuildContext context, int index) {
                          final DiffItem item = widget.items[index];
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => showDiffItemDetailViewer(
                                context,
                                data: DiffItemDetailViewData.fromDiffItem(
                                  item,
                                  sourceIsRemote: widget.sourceIsRemote,
                                  targetIsRemote: widget.targetIsRemote,
                                ),
                              ),
                              child: SizedBox(
                                height: _rowHeight,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: Text(
                                          item.relativePath,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      _TypeBadge(
                                        type: item.type,
                                        reason: item.reason,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
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
