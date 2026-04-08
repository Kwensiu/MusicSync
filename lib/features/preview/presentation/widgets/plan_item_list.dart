import 'package:flutter/material.dart';
import 'package:music_sync/l10n/app_localizations_ext.dart';
import 'package:music_sync/models/diff_item.dart';

class PlanItemList extends StatefulWidget {
  const PlanItemList({
    required this.items,
    super.key,
    this.maxHeight = 360,
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
    this.contentPadding = const EdgeInsets.all(8),
    this.showTopBorder = true,
  });

  final List<DiffItem> items;
  final double maxHeight;
  final BorderRadius borderRadius;
  final EdgeInsets contentPadding;
  final bool showTopBorder;

  @override
  State<PlanItemList> createState() => _PlanItemListState();
}

class PlanItemEmptyState extends StatelessWidget {
  const PlanItemEmptyState({
    required this.message,
    super.key,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
        child: Center(
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _PlanItemListState extends State<PlanItemList> {
  static const double _rowHeight = 44;
  static const double _rowGap = 6;
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
    final double verticalPadding = widget.contentPadding.vertical;
    final double desiredHeight =
        (widget.items.length * (_rowHeight + _rowGap)) + verticalPadding;
    final double resolvedHeight =
        desiredHeight.clamp(0, widget.maxHeight).toDouble();

    return SizedBox(
      height: resolvedHeight,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          borderRadius: widget.borderRadius,
          border: Border(
            top: widget.showTopBorder
                ? BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant)
                : BorderSide.none,
            left:
                BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
            right:
                BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
            bottom:
                BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          ),
        ),
        child: Padding(
          padding: widget.contentPadding,
          child: Scrollbar(
            controller: _controller,
            thumbVisibility: widget.items.length > 12,
            child: ListView.builder(
              controller: _controller,
              itemExtent: _rowHeight + _rowGap,
              itemCount: widget.items.length,
              itemBuilder: (BuildContext context, int index) {
                final DiffItem item = widget.items[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Theme.of(context)
                          .dividerColor
                          .withValues(alpha: 0.18),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            item.relativePath,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
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
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({
    required this.type,
    this.reason,
  });

  final DiffType type;
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final (Color background, Color foreground) = switch (type) {
      DiffType.copy => (
          const Color(0xFFD9F2E3),
          const Color(0xFF0B5D2A),
        ),
      DiffType.delete => (
          const Color(0xFFFBE2D8),
          const Color(0xFFA33D12),
        ),
      DiffType.conflict => (
          const Color(0xFFF9E1CF),
          const Color(0xFF8A4100),
        ),
      DiffType.skip => (
          const Color(0xFFE7EAF0),
          const Color(0xFF425466),
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
