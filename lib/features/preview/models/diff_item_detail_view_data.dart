import 'package:music_sync/models/diff_item.dart';
import 'package:music_sync/models/file_entry.dart';
import 'package:path/path.dart' as p;

class DiffItemDetailViewData {
  const DiffItemDetailViewData({
    required this.path,
    required this.type,
    required this.reason,
    required this.side,
    required this.source,
    required this.target,
    required this.sourceIsRemote,
    required this.targetIsRemote,
  });

  factory DiffItemDetailViewData.fromDiffItem(
    DiffItem item, {
    bool sourceIsRemote = false,
    bool targetIsRemote = false,
  }) {
    return DiffItemDetailViewData(
      path: item.relativePath,
      type: item.type,
      reason: item.reason,
      side: switch (item.type) {
        DiffType.copy => DiffItemDetailSide.sourceOnly,
        DiffType.delete => DiffItemDetailSide.targetOnly,
        DiffType.conflict => DiffItemDetailSide.both,
        DiffType.skip => DiffItemDetailSide.unknown,
      },
      source: item.source == null
          ? null
          : DiffEntryDetailViewData.fromEntry(item.source!),
      target: item.target == null
          ? null
          : DiffEntryDetailViewData.fromEntry(item.target!),
      sourceIsRemote: sourceIsRemote,
      targetIsRemote: targetIsRemote,
    );
  }

  final String path;
  final DiffType type;
  final String? reason;
  final DiffItemDetailSide side;
  final DiffEntryDetailViewData? source;
  final DiffEntryDetailViewData? target;
  final bool sourceIsRemote;
  final bool targetIsRemote;
}

enum DiffItemDetailSide { sourceOnly, targetOnly, both, unknown }

class DiffEntryDetailViewData {
  const DiffEntryDetailViewData({
    required this.entryId,
    required this.displayName,
    required this.size,
    required this.modifiedTime,
    required this.isDirectory,
    this.audioMetadata,
  });

  factory DiffEntryDetailViewData.fromEntry(FileEntry entry) {
    return DiffEntryDetailViewData(
      entryId: entry.entryId,
      displayName: p.basename(entry.relativePath),
      size: entry.size,
      modifiedTime: entry.modifiedTime,
      isDirectory: entry.isDirectory,
    );
  }

  final String entryId;
  final String displayName;
  final int size;
  final DateTime modifiedTime;
  final bool isDirectory;
  final AudioMetadataViewData? audioMetadata;
}

class AudioMetadataViewData {
  const AudioMetadataViewData({
    this.title,
    this.artist,
    this.album,
    this.composer,
    this.trackNumber,
    this.discNumber,
    this.lyrics,
  });

  final String? title;
  final String? artist;
  final String? album;
  final String? composer;
  final String? trackNumber;
  final String? discNumber;
  final String? lyrics;

  bool get hasAnyValue =>
      (title != null && title!.isNotEmpty) ||
      (artist != null && artist!.isNotEmpty) ||
      (album != null && album!.isNotEmpty) ||
      (composer != null && composer!.isNotEmpty) ||
      (trackNumber != null && trackNumber!.isNotEmpty) ||
      (discNumber != null && discNumber!.isNotEmpty) ||
      (lyrics != null && lyrics!.isNotEmpty);
}
