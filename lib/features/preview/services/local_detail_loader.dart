import 'package:music_sync/features/preview/models/diff_item_detail_view_data.dart';
import 'package:music_sync/features/preview/services/local_audio_metadata_reader.dart';
import 'package:music_sync/services/file_access/file_access_entry.dart';
import 'package:music_sync/services/file_access/file_access_gateway.dart';

class LocalDetailLoader {
  LocalDetailLoader(
    this._gateway, {
    this.loadRemoteEntry,
  }) : _metadataReader = LocalAudioMetadataReader(_gateway);

  static const Duration _entryRefreshTimeout = Duration(seconds: 2);
  static const Duration _metadataReadTimeout = Duration(seconds: 2);

  final FileAccessGateway _gateway;
  final Future<FileAccessEntry?> Function(String entryId)? loadRemoteEntry;
  final LocalAudioMetadataReader _metadataReader;

  Future<DiffItemDetailViewData> refresh(DiffItemDetailViewData data) async {
    final DiffEntryDetailViewData? source = await _refreshEntry(
      data.source,
      isRemote: data.sourceIsRemote,
    );
    final DiffEntryDetailViewData? target = await _refreshEntry(
      data.target,
      isRemote: data.targetIsRemote,
    );

    return DiffItemDetailViewData(
      path: data.path,
      type: data.type,
      reason: data.reason,
      side: data.side,
      source: source ?? data.source,
      target: target ?? data.target,
      sourceIsRemote: data.sourceIsRemote,
      targetIsRemote: data.targetIsRemote,
    );
  }

  Future<DiffEntryDetailViewData?> _refreshEntry(
    DiffEntryDetailViewData? entry, {
    required bool isRemote,
  }) async {
    if (entry == null || entry.entryId.isEmpty) {
      return entry;
    }

    try {
      final FileAccessEntry? refreshed = isRemote
          ? await loadRemoteEntry
              ?.call(entry.entryId)
              .timeout(_entryRefreshTimeout)
          : await _gateway.stat(entry.entryId).timeout(_entryRefreshTimeout);
      if (refreshed == null) {
        return entry;
      }
      return DiffEntryDetailViewData(
        entryId: refreshed.entryId,
        displayName: refreshed.name,
        size: refreshed.size,
        modifiedTime: refreshed.modifiedTime,
        isDirectory: refreshed.isDirectory,
        audioMetadata: isRemote
            ? entry.audioMetadata
            : await _metadataReader
                    .read(entry.entryId)
                    .timeout(_metadataReadTimeout) ??
                entry.audioMetadata,
      );
    } catch (_) {
      return entry;
    }
  }
}
