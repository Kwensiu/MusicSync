import 'package:flutter/material.dart';
import 'package:music_sync/features/preview/presentation/widgets/plan_item_list.dart';
import 'package:music_sync/l10n/app_localizations_ext.dart';
import 'package:music_sync/models/diff_item.dart';

class PreviewPlanSection extends StatefulWidget {
  const PreviewPlanSection({
    required this.header,
    required this.items,
    required this.conflictItems,
    required this.targetIsRemote,
    super.key,
  });

  final Widget? header;
  final List<DiffItem> items;
  final List<DiffItem> conflictItems;
  final bool targetIsRemote;

  @override
  State<PreviewPlanSection> createState() => _PreviewPlanSectionState();
}

class _PreviewPlanSectionState extends State<PreviewPlanSection> {
  bool _showConflictItems = false;

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty && widget.conflictItems.isEmpty) {
      return PlanItemEmptyState(
        header: widget.header,
        message: context.l10n.previewNoItemsInSection,
      );
    }

    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (widget.items.isNotEmpty) ...<Widget>[
          PlanItemList(
            header: widget.header,
            items: widget.items,
            sourceIsRemote: false,
            targetIsRemote: widget.targetIsRemote,
          ),
        ],
        if (widget.conflictItems.isNotEmpty) ...<Widget>[
          if (widget.items.isNotEmpty) const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              setState(() {
                _showConflictItems = !_showConflictItems;
              });
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: _showConflictItems
                    ? const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      )
                    : BorderRadius.circular(12),
                border: _showConflictItems
                    ? Border(
                        top: BorderSide(color: scheme.outlineVariant),
                        left: BorderSide(color: scheme.outlineVariant),
                        right: BorderSide(color: scheme.outlineVariant),
                        bottom: BorderSide.none,
                      )
                    : Border.all(color: scheme.outlineVariant),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${context.l10n.previewSectionConflict} ${widget.conflictItems.length}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _showConflictItems ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    child: Icon(
                      Icons.expand_more_rounded,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: _showConflictItems ? 1 : 0,
                child: PlanItemList(
                  items: widget.conflictItems,
                  maxHeight: 280,
                  sourceIsRemote: false,
                  targetIsRemote: widget.targetIsRemote,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                  showTopBorder: false,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
