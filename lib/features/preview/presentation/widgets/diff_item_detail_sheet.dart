import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_sync/core/utils/byte_format.dart';
import 'package:music_sync/core/utils/date_time_format.dart';
import 'package:music_sync/core/utils/path_display_format.dart';
import 'package:music_sync/features/connection/state/connection_controller.dart';
import 'package:music_sync/features/preview/models/diff_item_detail_view_data.dart';
import 'package:music_sync/features/preview/services/local_detail_loader.dart';
import 'package:music_sync/l10n/app_localizations_ext.dart';
import 'package:music_sync/models/diff_item.dart';
import 'package:music_sync/services/file_access/file_access_provider.dart';

abstract final class _DetailSheetScale {
  static const int lyricsCollapsedLines = 6;
  static const double topRadius = 28;
  static const double dragHandleWidth = 40;
  static const double dragHandleHeight = 4;
  static const double contentHorizontal = 20;
  static const double contentTop = 12;
  static const double contentBottom = 24;
  static const double sectionGap = 16;
  static const double itemGap = 12;
  static const double rowGap = 8;
  static const double sectionLabelIndent = 4;
  static const double fieldLabelGap = 6;
  static const double cardRadius = 20;
  static const double valueRadius = 14;
}

Future<void> showDiffItemDetailSheet(
  BuildContext context, {
  required DiffItemDetailViewData data,
}) {
  final ProviderContainer container = ProviderScope.containerOf(
    context,
    listen: false,
  );
  final LocalDetailLoader loader = LocalDetailLoader(
    container.read(fileAccessGatewayProvider),
    loadRemoteEntryDetail: (String entryId) {
      return container
          .read(connectionControllerProvider.notifier)
          .requestRemoteEntryDetail(entryId);
    },
  );
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) {
      return _DiffItemDetailSheetBody(
        initialData: data,
        loader: loader,
      );
    },
  );
}

class _DiffItemDetailSheetBody extends StatefulWidget {
  const _DiffItemDetailSheetBody({
    required this.initialData,
    required this.loader,
  });

  final DiffItemDetailViewData initialData;
  final LocalDetailLoader loader;

  @override
  State<_DiffItemDetailSheetBody> createState() =>
      _DiffItemDetailSheetBodyState();
}

class _DiffItemDetailSheetBodyState extends State<_DiffItemDetailSheetBody> {
  late DiffItemDetailViewData _data;
  bool _isRefreshing = false;
  bool _refreshFailed = false;

  @override
  void initState() {
    super.initState();
    _data = widget.initialData;
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _isRefreshing = true;
      _refreshFailed = false;
    });
    try {
      final DiffItemDetailViewData refreshed =
          await widget.loader.refresh(_data);
      if (!mounted) {
        return;
      }
      setState(() {
        _data = refreshed;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _refreshFailed = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.62,
      minChildSize: 0.42,
      maxChildSize: 0.9,
      builder: (BuildContext context, ScrollController controller) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(_DetailSheetScale.topRadius),
            ),
          ),
          child: SafeArea(
            top: false,
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(
                _DetailSheetScale.contentHorizontal,
                _DetailSheetScale.contentTop,
                _DetailSheetScale.contentHorizontal,
                _DetailSheetScale.contentBottom,
              ),
              children: <Widget>[
                Center(
                  child: Container(
                    width: _DetailSheetScale.dragHandleWidth,
                    height: _DetailSheetScale.dragHandleHeight,
                    decoration: BoxDecoration(
                      color: scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _data.path,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _DetailChip(label: _typeLabel(context, _data.type)),
                    if (_data.reason case final String reason
                        when reason.isNotEmpty)
                      _DetailChip(label: _reasonLabel(context, _data.reason)),
                  ],
                ),
                if (_isRefreshing || _refreshFailed) ...<Widget>[
                  const SizedBox(height: 12),
                  _DetailRefreshBanner(
                    isRefreshing: _isRefreshing,
                    refreshFailed: _refreshFailed,
                  ),
                ],
                const SizedBox(height: _DetailSheetScale.sectionGap),
                _DetailSection(
                  title: context.l10n.previewDetailOverviewTitle,
                  child: _DetailCard(
                    children: <Widget>[
                      _DetailValueRow(
                        label: context.l10n.previewDetailRelativePath,
                        value: _data.path,
                      ),
                      _DetailValueRow(
                        label: context.l10n.previewDetailSide,
                        value: _sideLabel(context, _data.side),
                      ),
                    ],
                  ),
                ),
                if (_data.source != null) ...<Widget>[
                  const SizedBox(height: _DetailSheetScale.sectionGap),
                  _DetailSection(
                    title: context.l10n.previewDetailSourceEntry,
                    child: _EntryCard(
                      entry: _data.source!,
                      isRemote: _data.sourceIsRemote,
                    ),
                  ),
                ],
                if (_data.target != null) ...<Widget>[
                  const SizedBox(height: _DetailSheetScale.sectionGap),
                  _DetailSection(
                    title: context.l10n.previewDetailTargetEntry,
                    child: _EntryCard(
                      entry: _data.target!,
                      isRemote: _data.targetIsRemote,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

String _typeLabel(BuildContext context, DiffType type) {
  return switch (type) {
    DiffType.copy => context.l10n.diffTypeCopy,
    DiffType.delete => context.l10n.diffTypeDelete,
    DiffType.conflict => context.l10n.diffTypeConflict,
    DiffType.skip => context.l10n.diffTypeSkip,
  };
}

String _reasonLabel(BuildContext context, String? reason) {
  switch (reason) {
    case 'metadata_mismatch':
      return context.l10n.diffConflictMetadataMismatch;
    default:
      return reason ?? context.l10n.diffTypeConflict;
  }
}

String _sideLabel(BuildContext context, DiffItemDetailSide side) {
  return switch (side) {
    DiffItemDetailSide.sourceOnly => context.l10n.previewDetailSideSourceOnly,
    DiffItemDetailSide.targetOnly => context.l10n.previewDetailSideTargetOnly,
    DiffItemDetailSide.both => context.l10n.previewDetailSideBoth,
    DiffItemDetailSide.unknown => context.l10n.previewDetailSideUnknown,
  };
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

class _DetailRefreshBanner extends StatelessWidget {
  const _DetailRefreshBanner({
    required this.isRefreshing,
    required this.refreshFailed,
  });

  final bool isRefreshing;
  final bool refreshFailed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color background = refreshFailed
        ? scheme.errorContainer.withValues(alpha: 0.85)
        : scheme.surfaceContainerHigh;
    final Color foreground =
        refreshFailed ? scheme.onErrorContainer : scheme.onSurfaceVariant;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(_DetailSheetScale.valueRadius),
      ),
      child: Row(
        children: <Widget>[
          if (isRefreshing)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: foreground,
              ),
            )
          else
            Icon(
              Icons.error_outline_rounded,
              size: 16,
              color: foreground,
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              refreshFailed
                  ? context.l10n.previewDetailRefreshFailed
                  : context.l10n.previewDetailRefreshing,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: foreground,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(
            left: _DetailSheetScale.sectionLabelIndent,
          ),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        const SizedBox(height: _DetailSheetScale.itemGap),
        child,
      ],
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(_DetailSheetScale.cardRadius),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: children,
        ),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.entry,
    required this.isRemote,
  });

  final DiffEntryDetailViewData entry;
  final bool isRemote;

  @override
  Widget build(BuildContext context) {
    return _DetailCard(
      children: <Widget>[
        _DetailValueRow(
          label: context.l10n.previewDetailName,
          value: entry.displayName,
        ),
        _DetailValueRow(
          label: context.l10n.previewDetailLocation,
          value: isRemote
              ? context.l10n.previewDetailLocationRemote
              : context.l10n.previewDetailLocationLocal,
        ),
        _DetailValueRow(
          label: context.l10n.previewDetailPath,
          value: formatDisplayPath(entry.entryId),
        ),
        _DetailValueRow(
          label: context.l10n.previewDetailSize,
          value: formatBytes(entry.size),
        ),
        _DetailValueRow(
          label: context.l10n.previewDetailModifiedTime,
          value: formatDateTimeShort(entry.modifiedTime.toLocal()),
        ),
        _DetailValueRow(
          label: context.l10n.previewDetailEntryType,
          value: entry.isDirectory
              ? context.l10n.previewDetailEntryTypeDirectory
              : context.l10n.previewDetailEntryTypeFile,
        ),
        if (entry.audioMetadata case final AudioMetadataViewData metadata
            when metadata.hasAnyValue) ...<Widget>[
          _DetailValueRow(
            label: context.l10n.previewDetailAudioTitle,
            value: metadata.title ?? context.l10n.previewDetailUnknownValue,
          ),
          _DetailValueRow(
            label: context.l10n.previewDetailAudioArtist,
            value: metadata.artist ?? context.l10n.previewDetailUnknownValue,
          ),
          _DetailValueRow(
            label: context.l10n.previewDetailAudioAlbum,
            value: metadata.album ?? context.l10n.previewDetailUnknownValue,
          ),
          if (metadata.lyrics case final String lyrics when lyrics.isNotEmpty)
            _LyricsValueRow(
              label: context.l10n.previewDetailAudioLyrics,
              value: lyrics,
            ),
        ],
      ],
    );
  }
}

class _DetailValueRow extends StatelessWidget {
  const _DetailValueRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: _DetailSheetScale.rowGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(
              left: _DetailSheetScale.sectionLabelIndent,
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
          const SizedBox(height: _DetailSheetScale.fieldLabelGap),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius:
                  BorderRadius.circular(_DetailSheetScale.valueRadius),
            ),
            child: SelectableText(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LyricsValueRow extends StatefulWidget {
  const _LyricsValueRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  State<_LyricsValueRow> createState() => _LyricsValueRowState();
}

class _LyricsValueRowState extends State<_LyricsValueRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextStyle style = Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onSurface,
            ) ??
        const TextStyle();

    return Padding(
      padding: const EdgeInsets.only(bottom: _DetailSheetScale.rowGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(
              left: _DetailSheetScale.sectionLabelIndent,
            ),
            child: Text(
              widget.label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
          const SizedBox(height: _DetailSheetScale.fieldLabelGap),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius:
                  BorderRadius.circular(_DetailSheetScale.valueRadius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  child: SelectableText(
                    widget.value,
                    maxLines: _expanded
                        ? null
                        : _DetailSheetScale.lyricsCollapsedLines,
                    style: style,
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _expanded = !_expanded;
                      });
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(
                      _expanded
                          ? context.l10n.previewFilterCollapse
                          : context.l10n.previewFilterMore,
                    ),
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
