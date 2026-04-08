import 'dart:typed_data';

import 'package:dart_tags/dart_tags.dart';
import 'package:music_sync/features/preview/models/diff_item_detail_view_data.dart';
import 'package:music_sync/services/file_access/file_access_gateway.dart';

class LocalAudioMetadataReader {
  LocalAudioMetadataReader(this._gateway);

  static const int _fastReadLimit = 512 * 1024;
  static const Duration _readTimeout = Duration(seconds: 2);

  final FileAccessGateway _gateway;
  final TagProcessor _processor = TagProcessor();

  Future<AudioMetadataViewData?> read(String entryId) async {
    try {
      final Uint8List prefixBytes =
          await _readPrefix(entryId, _fastReadLimit).timeout(_readTimeout);
      if (prefixBytes.isEmpty) {
        return null;
      }

      Tag? tagWithValues = await _readPreferredTag(prefixBytes);
      if (tagWithValues == null) {
        final Uint8List fullBytes =
            await _readAll(entryId).timeout(_readTimeout);
        if (fullBytes.isEmpty) {
          return null;
        }
        tagWithValues = await _readFallbackTag(fullBytes);
      }
      if (tagWithValues == null) {
        return null;
      }

      final Map<String, dynamic> values = tagWithValues.tags;
      final AudioMetadataViewData metadata = AudioMetadataViewData(
        title: _stringValue(values['title']),
        artist: _stringValue(values['artist']),
        album: _stringValue(values['album']),
        lyrics: _lyricsValue(values['lyrics']),
      );
      return metadata.hasAnyValue ? metadata : null;
    } catch (_) {
      return null;
    }
  }

  Future<Tag?> _readPreferredTag(Uint8List bytes) async {
    final List<Tag> tags = await _processor.getTagsFromByteArray(
      Future<List<int>>.value(bytes),
      <TagType>[TagType.id3v2],
    );
    return _selectBestTag(tags);
  }

  Future<Tag?> _readFallbackTag(Uint8List bytes) async {
    final List<Tag> tags = await _processor.getTagsFromByteArray(
      Future<List<int>>.value(bytes),
      <TagType>[TagType.id3v1, TagType.id3v2],
    );
    return _selectBestTag(tags);
  }

  Future<Uint8List> _readAll(String entryId) async {
    final BytesBuilder builder = BytesBuilder(copy: false);
    await for (final List<int> chunk in _gateway.openRead(entryId)) {
      if (chunk.isEmpty) {
        continue;
      }
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  Future<Uint8List> _readPrefix(String entryId, int limit) async {
    final BytesBuilder builder = BytesBuilder(copy: false);
    int total = 0;
    await for (final List<int> chunk in _gateway.openRead(entryId)) {
      if (chunk.isEmpty) {
        continue;
      }
      final int remaining = limit - total;
      if (remaining <= 0) {
        break;
      }
      if (chunk.length <= remaining) {
        builder.add(chunk);
        total += chunk.length;
      } else {
        builder.add(chunk.sublist(0, remaining));
        total += remaining;
        break;
      }
    }
    return builder.takeBytes();
  }

  Tag? _selectBestTag(List<Tag> tags) {
    final List<Tag> candidates =
        tags.where((Tag tag) => tag.tags.isNotEmpty).toList();
    if (candidates.isEmpty) {
      return null;
    }

    candidates.sort((Tag left, Tag right) {
      final int versionOrder =
          _tagPriority(right).compareTo(_tagPriority(left));
      if (versionOrder != 0) {
        return versionOrder;
      }
      return _metadataFieldCount(right).compareTo(_metadataFieldCount(left));
    });
    return candidates.first;
  }

  int _tagPriority(Tag tag) {
    final String version = tag.version ?? '';
    if (version.startsWith('2.')) {
      return 2;
    }
    if (version.startsWith('1.')) {
      return 1;
    }
    return 0;
  }

  int _metadataFieldCount(Tag tag) {
    return <Object?>[
      tag.tags['title'],
      tag.tags['artist'],
      tag.tags['album'],
      tag.tags['lyrics'],
    ].where((Object? value) => _stringValue(value) != null).length;
  }

  String? _stringValue(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is String) {
      final String normalized = value.trim();
      return normalized.isEmpty ? null : normalized;
    }
    if (value is List && value.isNotEmpty) {
      return _stringValue(value.first);
    }
    final String normalized = value.toString().trim();
    return normalized.isEmpty ? null : normalized;
  }

  String? _lyricsValue(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is UnSyncLyric) {
      final String normalized = value.lyrics.trim();
      return normalized.isEmpty ? null : normalized;
    }
    if (value is List && value.isNotEmpty) {
      return _lyricsValue(value.first);
    }
    if (value is Map && value.isNotEmpty) {
      return _lyricsValue(value.values.first);
    }
    final String raw = value.toString();
    final RegExp bodyPattern = RegExp(r'body:\s*(.+?)(?:\}+\s*)?$');
    final RegExpMatch? match = bodyPattern.firstMatch(raw);
    final String candidate = match?.group(1)?.trim() ?? raw.trim();
    return candidate.isEmpty ? null : candidate;
  }
}
