import 'package:flutter/material.dart';
import 'package:music_sync/features/preview/models/diff_item_detail_view_data.dart';
import 'package:music_sync/features/preview/presentation/widgets/diff_item_detail_panel_content.dart';
import 'package:music_sync/features/preview/state/conflict_controller.dart';
import 'package:music_sync/l10n/app_localizations_ext.dart';
import 'package:music_sync/models/diff_item.dart';

class PreviewConflictDetailPane extends StatelessWidget {
  const PreviewConflictDetailPane({
    required this.selectedItem,
    required this.draft,
    required this.sourceIsRemote,
    required this.targetIsRemote,
    required this.onResolve,
    this.shrinkWrap = false,
    this.sideBySide = false,
    super.key,
  });

  final DiffItem? selectedItem;
  final ConflictResolutionDraft? draft;
  final bool sourceIsRemote;
  final bool targetIsRemote;
  final void Function(String path, ConflictResolutionAction action) onResolve;

  /// When true, the pane sizes itself to its content height instead of
  /// expanding to fill available space. Required when placed inside a
  /// [SingleChildScrollView] (e.g. mobile layout).
  final bool shrinkWrap;

  /// When true and the item has both source and target, render a
  /// side-by-side Local/Remote layout instead of a single column.
  /// Typically used in desktop conflict detail pane.
  final bool sideBySide;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    if (selectedItem == null) {
      return Center(
        child: Text(
          context.l10n.conflictDetailEmpty,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final DiffItem item = selectedItem!;
    final DiffItemDetailViewData detailData =
        DiffItemDetailViewData.fromDiffItem(
          item,
          sourceIsRemote: sourceIsRemote,
          targetIsRemote: targetIsRemote,
        );

    final bool hasBothSides =
        detailData.source != null && detailData.target != null;
    final bool useSideBySide = sideBySide && hasBothSides;

    final Widget detailBody = useSideBySide
        ? _buildSideBySideContent(context, detailData, item, scheme, theme)
        : _buildSingleColumnContent(context, detailData, item, scheme, theme);

    final Widget scrollableContent = SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: detailBody,
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
              context.l10n.conflictDetailTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
          shrinkWrap ? scrollableContent : Expanded(child: scrollableContent),
        ],
      ),
    );
  }

  Widget _buildSideBySideContent(
    BuildContext context,
    DiffItemDetailViewData detailData,
    DiffItem item,
    ColorScheme scheme,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (item.reason != null) ...<Widget>[
          _ReasonChip(reason: item.reason!),
          const SizedBox(height: 12),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: _SidePanel(
                title: context.l10n.previewDetailTabLocal,
                icon: Icons.laptop_rounded,
                data: _localData(detailData),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 200,
              child: VerticalDivider(width: 1, color: scheme.outlineVariant),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SidePanel(
                title: context.l10n.previewDetailTabRemote,
                icon: Icons.cloud_outlined,
                data: _remoteData(detailData),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Divider(height: 1, color: scheme.outlineVariant),
        const SizedBox(height: 12),
        _buildActionChips(context, item, theme, scheme),
      ],
    );
  }

  Widget _buildSingleColumnContent(
    BuildContext context,
    DiffItemDetailViewData detailData,
    DiffItem item,
    ColorScheme scheme,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (item.reason != null) ...<Widget>[
          _ReasonChip(reason: item.reason!),
          const SizedBox(height: 12),
        ],
        DiffItemDetailPanelContent(data: detailData, showHeader: true),
        const SizedBox(height: 16),
        Divider(height: 1, color: scheme.outlineVariant),
        const SizedBox(height: 12),
        _buildActionChips(context, item, theme, scheme),
      ],
    );
  }

  Widget _buildActionChips(
    BuildContext context,
    DiffItem item,
    ThemeData theme,
    ColorScheme scheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          context.l10n.conflictActionLabel,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ConflictResolutionAction.values.map((
            ConflictResolutionAction action,
          ) {
            final bool isSelected = draft?.action == action;
            return ChoiceChip(
              label: Text(_actionLabel(context, action)),
              selected: isSelected,
              onSelected: (_) => onResolve(item.relativePath, action),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            );
          }).toList(),
        ),
      ],
    );
  }

  DiffItemDetailViewData _localData(DiffItemDetailViewData d) {
    return DiffItemDetailViewData(
      path: d.path,
      type: d.type,
      reason: d.reason,
      side: d.side,
      source: !d.sourceIsRemote ? d.source : null,
      target: !d.targetIsRemote ? d.target : null,
      sourceIsRemote: d.sourceIsRemote,
      targetIsRemote: d.targetIsRemote,
    );
  }

  DiffItemDetailViewData _remoteData(DiffItemDetailViewData d) {
    return DiffItemDetailViewData(
      path: d.path,
      type: d.type,
      reason: d.reason,
      side: d.side,
      source: d.sourceIsRemote ? d.source : null,
      target: d.targetIsRemote ? d.target : null,
      sourceIsRemote: d.sourceIsRemote,
      targetIsRemote: d.targetIsRemote,
    );
  }

  String _actionLabel(BuildContext context, ConflictResolutionAction action) {
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

class _ReasonChip extends StatelessWidget {
  const _ReasonChip({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String label = switch (reason) {
      'metadata_mismatch' => context.l10n.diffConflictMetadataMismatch,
      _ => reason,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.errorContainer),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.info_outline_rounded,
            size: 14,
            color: scheme.onErrorContainer,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onErrorContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SidePanel extends StatelessWidget {
  const _SidePanel({
    required this.title,
    required this.icon,
    required this.data,
  });

  final String title;
  final IconData icon;
  final DiffItemDetailViewData data;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                title,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        DiffItemDetailPanelContent(data: data, showHeader: true),
      ],
    );
  }
}
