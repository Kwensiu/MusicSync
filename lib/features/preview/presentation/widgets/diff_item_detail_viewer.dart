import 'package:flutter/material.dart';
import 'package:music_sync/features/preview/models/diff_item_detail_view_data.dart';
import 'package:music_sync/features/preview/presentation/widgets/diff_item_detail_panel_content.dart';
import 'package:music_sync/l10n/app_localizations_ext.dart';

/// Whether this item has both source and target entries (conflict).
bool _hasBothSides(DiffItemDetailViewData data) =>
    data.source != null && data.target != null;

/// Opens a full detail viewer for a diff item.
///
/// - Conflict items (both sides): desktop → side-by-side dialog; mobile → sheet with local/remote tabs.
/// - Copy/delete items (single side): single-panel dialog or sheet, no split.
Future<void> showDiffItemDetailViewer(
  BuildContext context, {
  required DiffItemDetailViewData data,
}) {
  final double width = MediaQuery.sizeOf(context).width;
  final bool isWide = width >= 700;

  if (!_hasBothSides(data)) {
    // Single-side item (copy or delete): simple viewer
    if (isWide) {
      return _showSingleSideDialog(context, data: data);
    } else {
      return _showSingleSideSheet(context, data: data);
    }
  }

  // Both sides (conflict): side-by-side or tabbed
  if (isWide) {
    return _showDesktopDialog(context, data: data);
  } else {
    return _showMobileSheet(context, data: data);
  }
}

// ---------------------------------------------------------------------------
// Single-side viewers (copy / delete)
// ---------------------------------------------------------------------------

Future<void> _showSingleSideDialog(
  BuildContext context, {
  required DiffItemDetailViewData data,
}) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      return _SingleSideDialog(data: data);
    },
  );
}

Future<void> _showSingleSideSheet(
  BuildContext context, {
  required DiffItemDetailViewData data,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    builder: (BuildContext sheetContext) {
      return _SingleSideSheet(data: data);
    },
  );
}

class _SingleSideDialog extends StatelessWidget {
  const _SingleSideDialog({required this.data});

  final DiffItemDetailViewData data;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Dialog(
      child: SizedBox(
        width: (MediaQuery.sizeOf(context).width * 0.55).clamp(420.0, 700.0),
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      context.l10n.previewDetailViewerTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: DiffItemDetailPanelContent(data: data, showHeader: true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SingleSideSheet extends StatelessWidget {
  const _SingleSideSheet({required this.data});

  final DiffItemDetailViewData data;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.82,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Center(
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    context.l10n.previewDetailViewerTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: DiffItemDetailPanelContent(data: data, showHeader: true),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Desktop: side-by-side dialog (conflict items only)
// ---------------------------------------------------------------------------

Future<void> _showDesktopDialog(
  BuildContext context, {
  required DiffItemDetailViewData data,
}) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      return _DesktopDetailDialog(data: data);
    },
  );
}

class _DesktopDetailDialog extends StatelessWidget {
  const _DesktopDetailDialog({required this.data});

  final DiffItemDetailViewData data;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final double dialogWidth = (MediaQuery.sizeOf(context).width * 0.82).clamp(
      600.0,
      1100.0,
    );

    return Dialog(
      child: SizedBox(
        width: dialogWidth,
        height: MediaQuery.sizeOf(context).height * 0.78,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      context.l10n.previewDetailViewerTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(
                      child: _SidePanel(
                        title: context.l10n.previewDetailTabLocal,
                        icon: Icons.laptop_rounded,
                        data: _localData(data),
                      ),
                    ),
                    const SizedBox(width: 12),
                    VerticalDivider(width: 1, color: scheme.outlineVariant),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SidePanel(
                        title: context.l10n.previewDetailTabRemote,
                        icon: Icons.cloud_outlined,
                        data: _remoteData(data),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build a view-data that only contains local-side entries.
  ///
  /// The full original data is preserved so that [DiffItemDetailPanelContent]
  /// can still refresh metadata via [LocalDetailLoader] — the loader reads
  /// entry IDs from whichever entries are non-null.
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
        Expanded(
          child: SingleChildScrollView(
            child: DiffItemDetailPanelContent(data: data, showHeader: true),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Mobile: sheet with local/remote tabs (conflict items only)
// ---------------------------------------------------------------------------

Future<void> _showMobileSheet(
  BuildContext context, {
  required DiffItemDetailViewData data,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    builder: (BuildContext sheetContext) {
      return _MobileDetailSheet(data: data);
    },
  );
}

class _MobileDetailSheet extends StatefulWidget {
  const _MobileDetailSheet({required this.data});

  final DiffItemDetailViewData data;

  @override
  State<_MobileDetailSheet> createState() => _MobileDetailSheetState();
}

class _MobileDetailSheetState extends State<_MobileDetailSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.88,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Center(
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    context.l10n.previewDetailViewerTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            tabs: <Tab>[
              Tab(text: context.l10n.previewDetailTabLocal),
              Tab(text: context.l10n.previewDetailTabRemote),
            ],
            labelStyle: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: theme.textTheme.labelLarge,
            labelColor: scheme.primary,
            unselectedLabelColor: scheme.onSurfaceVariant,
            indicatorColor: scheme.primary,
            dividerColor: scheme.outlineVariant,
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: <Widget>[
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: DiffItemDetailPanelContent(
                    data: DiffItemDetailViewData(
                      path: widget.data.path,
                      type: widget.data.type,
                      reason: widget.data.reason,
                      side: widget.data.side,
                      source: !widget.data.sourceIsRemote
                          ? widget.data.source
                          : null,
                      target: !widget.data.targetIsRemote
                          ? widget.data.target
                          : null,
                      sourceIsRemote: widget.data.sourceIsRemote,
                      targetIsRemote: widget.data.targetIsRemote,
                    ),
                    showHeader: true,
                  ),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: DiffItemDetailPanelContent(
                    data: DiffItemDetailViewData(
                      path: widget.data.path,
                      type: widget.data.type,
                      reason: widget.data.reason,
                      side: widget.data.side,
                      source: widget.data.sourceIsRemote
                          ? widget.data.source
                          : null,
                      target: widget.data.targetIsRemote
                          ? widget.data.target
                          : null,
                      sourceIsRemote: widget.data.sourceIsRemote,
                      targetIsRemote: widget.data.targetIsRemote,
                    ),
                    showHeader: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
