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

abstract final class _PanelScale {
  static const double sectionGap = 16;
  static const double itemGap = 12;
  static const double rowGap = 8;
  static const double sectionLabelIndent = 4;
  static const double fieldLabelGap = 6;
  static const double cardRadius = 20;
  static const double valueRadius = 14;
}

class DiffItemDetailPanelContent extends StatefulWidget {
  const DiffItemDetailPanelContent({
    required this.data,
    super.key,
    this.showHeader = true,
  });

  final DiffItemDetailViewData data;
  final bool showHeader;

  @override
  State<DiffItemDetailPanelContent> createState() =>
      _DiffItemDetailPanelContentState();
}

class _DiffItemDetailPanelContentState
    extends State<DiffItemDetailPanelContent> {
  late DiffItemDetailViewData _data;
  bool _isRefreshing = false;
  bool _refreshFailed = false;

  @override
  void initState() {
    super.initState();
    _data = widget.data;
    _refresh();
  }

  @override
  void didUpdateWidget(covariant DiffItemDetailPanelContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.path != widget.data.path ||
        oldWidget.data.type != widget.data.type) {
      _data = widget.data;
      _refresh();
    }
  }

  Future<void> _refresh() async {
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
    setState(() {
      _isRefreshing = true;
      _refreshFailed = false;
    });
    try {
      final DiffItemDetailViewData refreshed = await loader.refresh(_data);
      if (!mounted) return;
      setState(() {
        _data = refreshed;
      });
    } catch (_) {
      if (!mounted) return;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (widget.showHeader) ...<Widget>[
          Text(
            _data.path,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _PanelChip(label: _typeLabel(context, _data.type)),
              if (_data.reason case final String reason when reason.isNotEmpty)
                _PanelChip(label: _reasonLabel(context, _data.reason)),
            ],
          ),
        ],
        if (_isRefreshing || _refreshFailed) ...<Widget>[
          const SizedBox(height: 12),
          _PanelRefreshBanner(
            isRefreshing: _isRefreshing,
            refreshFailed: _refreshFailed,
          ),
        ],
        const SizedBox(height: _PanelScale.sectionGap),
        _PanelSection(
          title: context.l10n.previewDetailOverviewTitle,
          child: _PanelCard(
            children: <Widget>[
              _PanelValueRow(
                label: context.l10n.previewDetailRelativePath,
                value: _data.path,
              ),
              _PanelValueRow(
                label: context.l10n.previewDetailSide,
                value: _sideLabel(context, _data.side),
              ),
            ],
          ),
        ),
        if (_data.source != null) ...<Widget>[
          const SizedBox(height: _PanelScale.sectionGap),
          _PanelSection(
            title: context.l10n.previewDetailSourceEntry,
            child: _PanelEntryCard(
              entry: _data.source!,
              isRemote: _data.sourceIsRemote,
            ),
          ),
        ],
        if (_data.target != null) ...<Widget>[
          const SizedBox(height: _PanelScale.sectionGap),
          _PanelSection(
            title: context.l10n.previewDetailTargetEntry,
            child: _PanelEntryCard(
              entry: _data.target!,
              isRemote: _data.targetIsRemote,
            ),
          ),
        ],
      ],
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

class _PanelChip extends StatelessWidget {
  const _PanelChip({required this.label});

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
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
  }
}

class _PanelRefreshBanner extends StatelessWidget {
  const _PanelRefreshBanner({
    required this.isRefreshing,
    required this.refreshFailed,
  });

  final bool isRefreshing;
  final bool refreshFailed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color background = refreshFailed
        ? scheme.errorContainer
        : scheme.surfaceContainerHigh;
    final Color foreground = refreshFailed
        ? scheme.onErrorContainer
        : scheme.onSurfaceVariant;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(_PanelScale.valueRadius),
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
            Icon(Icons.error_outline_rounded, size: 16, color: foreground),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              refreshFailed
                  ? context.l10n.previewDetailRefreshFailed
                  : context.l10n.previewDetailRefreshing,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelSection extends StatelessWidget {
  const _PanelSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: _PanelScale.sectionLabelIndent),
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: _PanelScale.itemGap),
        child,
      ],
    );
  }
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(_PanelScale.cardRadius),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(children: children),
      ),
    );
  }
}

class _PanelEntryCard extends StatelessWidget {
  const _PanelEntryCard({required this.entry, required this.isRemote});

  final DiffEntryDetailViewData entry;
  final bool isRemote;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      children: <Widget>[
        _PanelValueRow(
          label: context.l10n.previewDetailName,
          value: entry.displayName,
        ),
        _PanelValueRow(
          label: context.l10n.previewDetailLocation,
          value: isRemote
              ? context.l10n.previewDetailLocationRemote
              : context.l10n.previewDetailLocationLocal,
        ),
        _PanelValueRow(
          label: context.l10n.previewDetailPath,
          value: formatDisplayPath(entry.entryId),
        ),
        _PanelValueRow(
          label: context.l10n.previewDetailSize,
          value: formatBytes(entry.size),
        ),
        _PanelValueRow(
          label: context.l10n.previewDetailModifiedTime,
          value: formatDateTimeShort(entry.modifiedTime.toLocal()),
        ),
        _PanelValueRow(
          label: context.l10n.previewDetailEntryType,
          value: entry.isDirectory
              ? context.l10n.previewDetailEntryTypeDirectory
              : context.l10n.previewDetailEntryTypeFile,
        ),
        if (!entry.isDirectory) ...<Widget>[
          _PanelValueRow(
            label: context.l10n.previewDetailAudioTitle,
            value: _metadataValueOrUnknown(context, entry.audioMetadata?.title),
          ),
          _PanelValueRow(
            label: context.l10n.previewDetailAudioArtist,
            value: _metadataValueOrUnknown(
              context,
              entry.audioMetadata?.artist,
            ),
          ),
          _PanelValueRow(
            label: context.l10n.previewDetailAudioAlbum,
            value: _metadataValueOrUnknown(context, entry.audioMetadata?.album),
          ),
          _PanelValueRow(
            label: context.l10n.previewDetailAudioComposer,
            value: _metadataValueOrUnknown(
              context,
              entry.audioMetadata?.composer,
            ),
          ),
          _PanelValueRow(
            label: context.l10n.previewDetailAudioTrackNumber,
            value: _metadataValueOrUnknown(
              context,
              entry.audioMetadata?.trackNumber,
            ),
          ),
          _PanelValueRow(
            label: context.l10n.previewDetailAudioDiscNumber,
            value: _metadataValueOrUnknown(
              context,
              entry.audioMetadata?.discNumber,
            ),
          ),
          if ((entry.audioMetadata?.lyrics ?? '').trim().isNotEmpty)
            _PanelLyricsValueRow(
              label: context.l10n.previewDetailAudioLyrics,
              value: entry.audioMetadata!.lyrics!,
            )
          else
            _PanelValueRow(
              label: context.l10n.previewDetailAudioLyrics,
              value: context.l10n.previewDetailUnknownValue,
            ),
        ],
      ],
    );
  }
}

String _metadataValueOrUnknown(BuildContext context, String? value) {
  final String normalized = value?.trim() ?? '';
  if (normalized.isEmpty) {
    return context.l10n.previewDetailUnknownValue;
  }
  return normalized;
}

class _PanelValueRow extends StatelessWidget {
  const _PanelValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: _PanelScale.rowGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(
              left: _PanelScale.sectionLabelIndent,
            ),
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: _PanelScale.fieldLabelGap),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(_PanelScale.valueRadius),
            ),
            child: SelectableText(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelLyricsValueRow extends StatefulWidget {
  const _PanelLyricsValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  State<_PanelLyricsValueRow> createState() => _PanelLyricsValueRowState();
}

class _PanelLyricsValueRowState extends State<_PanelLyricsValueRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextStyle style =
        Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: scheme.onSurface) ??
        const TextStyle();

    return Padding(
      padding: const EdgeInsets.only(bottom: _PanelScale.rowGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(
              left: _PanelScale.sectionLabelIndent,
            ),
            child: Text(
              widget.label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: _PanelScale.fieldLabelGap),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(_PanelScale.valueRadius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  child: SelectableText(
                    widget.value,
                    maxLines: _expanded ? null : 6,
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
