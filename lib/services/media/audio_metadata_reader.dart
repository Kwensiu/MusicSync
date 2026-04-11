import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_tags/dart_tags.dart';
import 'package:music_sync/core/logging/app_logger.dart';
import 'package:music_sync/features/preview/models/diff_item_detail_view_data.dart';
import 'package:music_sync/services/file_access/file_access_gateway.dart';

class AudioMetadataReader {
  AudioMetadataReader(this._gateway, {bool? isAndroid})
    : _isAndroid = isAndroid ?? Platform.isAndroid;

  static const int _fastReadLimit = 512 * 1024;
  static const Duration _readTimeout = Duration(seconds: 2);

  final FileAccessGateway _gateway;
  final bool _isAndroid;
  final TagProcessor _processor = TagProcessor();

  Future<AudioMetadataViewData?> read(String entryId) async {
    if (_isAndroid) {
      try {
        final AudioMetadataViewData? nativeMetadata = await _tryNativeMetadata(
          entryId,
        );
        if (nativeMetadata != null && nativeMetadata.hasAnyKeyField) {
          final AudioMetadataViewData? dartMetadata = await _readDartMetadata(
            entryId,
          );
          return _mergeMetadata(nativeMetadata, dartMetadata);
        }
      } catch (error) {
        AppLogger.warning(
          'Android native metadata read failed, falling back to Dart: $error',
        );
      }
    }

    try {
      return await _readDartMetadata(entryId);
    } catch (_) {
      return null;
    }
  }

  Future<AudioMetadataViewData?> _tryNativeMetadata(String entryId) async {
    try {
      final Map<String, String?>? nativeMap = await _gateway
          .getAudioMetadata(entryId)
          .timeout(_readTimeout);
      if (nativeMap == null) {
        return null;
      }
      final AudioMetadataViewData metadata = AudioMetadataViewData(
        title: _trimOrNull(nativeMap['title']),
        artist: _trimOrNull(nativeMap['artist']),
        album: _trimOrNull(nativeMap['album']),
        composer: _trimOrNull(nativeMap['composer']),
        trackNumber: _trimOrNull(nativeMap['trackNumber']),
        discNumber: _trimOrNull(nativeMap['discNumber']),
        lyrics: _trimOrNull(nativeMap['lyrics']),
      );
      if (!metadata.hasAnyValue) {
        return null;
      }
      AppLogger.fine('Android native metadata read succeeded for $entryId');
      return metadata;
    } catch (error) {
      AppLogger.fine('Android native metadata read skipped: $error');
      return null;
    }
  }

  Future<AudioMetadataViewData?> _readDartMetadata(String entryId) async {
    final Uint8List prefixBytes = await _readPrefix(
      entryId,
      _fastReadLimit,
    ).timeout(_readTimeout);
    if (prefixBytes.isEmpty) {
      return null;
    }

    final _AudioContainerKind kind = _detectContainer(prefixBytes);
    switch (kind) {
      case _AudioContainerKind.flac:
        final AudioMetadataViewData? flacMetadata = _readFlacMetadata(
          prefixBytes,
        );
        if (flacMetadata != null) {
          return flacMetadata;
        }
        final Uint8List fullFlacBytes = await _readAll(
          entryId,
        ).timeout(_readTimeout);
        final AudioMetadataViewData? fullFlacMetadata = _readFlacMetadata(
          fullFlacBytes,
        );
        if (fullFlacMetadata != null) {
          return fullFlacMetadata;
        }
      case _AudioContainerKind.ogg:
        final AudioMetadataViewData? oggMetadata = _readOggMetadata(
          prefixBytes,
        );
        if (oggMetadata != null) {
          return oggMetadata;
        }
        final Uint8List fullOggBytes = await _readAll(
          entryId,
        ).timeout(_readTimeout);
        final AudioMetadataViewData? fullOggMetadata = _readOggMetadata(
          fullOggBytes,
        );
        if (fullOggMetadata != null) {
          return fullOggMetadata;
        }
      case _AudioContainerKind.mp4:
        final AudioMetadataViewData? mp4Metadata = _readMp4Metadata(
          prefixBytes,
        );
        if (mp4Metadata != null) {
          return mp4Metadata;
        }
        final Uint8List fullMp4Bytes = await _readAll(
          entryId,
        ).timeout(_readTimeout);
        final AudioMetadataViewData? fullMp4Metadata = _readMp4Metadata(
          fullMp4Bytes,
        );
        if (fullMp4Metadata != null) {
          return fullMp4Metadata;
        }
      case _AudioContainerKind.id3OrUnknown:
        break;
    }

    Tag? tagWithValues = await _readPreferredTag(prefixBytes);
    if (tagWithValues == null) {
      final Uint8List fullBytes = await _readAll(entryId).timeout(_readTimeout);
      if (fullBytes.isEmpty) {
        return null;
      }
      final AudioMetadataViewData? apeMetadata = _readApeMetadata(fullBytes);
      if (apeMetadata != null) {
        return apeMetadata;
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
      composer: _stringValue(values['composer'] ?? values['writer']),
      trackNumber: _stringValue(values['track']),
      discNumber: _stringValue(values['disc']),
      lyrics: _lyricsValue(values['lyrics']),
    );
    return metadata.hasAnyValue ? metadata : null;
  }

  static AudioMetadataViewData _mergeMetadata(
    AudioMetadataViewData native,
    AudioMetadataViewData? dart,
  ) {
    if (dart == null) {
      return native;
    }
    return AudioMetadataViewData(
      title: native.title ?? dart.title,
      artist: native.artist ?? dart.artist,
      album: native.album ?? dart.album,
      composer: native.composer ?? dart.composer,
      trackNumber: native.trackNumber ?? dart.trackNumber,
      discNumber: native.discNumber ?? dart.discNumber,
      lyrics: native.lyrics ?? dart.lyrics,
    );
  }

  static String? _trimOrNull(String? value) {
    if (value == null) return null;
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
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
    final List<Tag> candidates = tags
        .where((Tag tag) => tag.tags.isNotEmpty)
        .toList();
    if (candidates.isEmpty) {
      return null;
    }

    candidates.sort((Tag left, Tag right) {
      final int versionOrder = _tagPriority(
        right,
      ).compareTo(_tagPriority(left));
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
      tag.tags['composer'] ?? tag.tags['writer'],
      tag.tags['track'],
      tag.tags['disc'],
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

  AudioMetadataViewData? _readFlacMetadata(Uint8List bytes) {
    final int flacOffset = _findFlacOffset(bytes);
    if (flacOffset < 0 || flacOffset + 8 > bytes.length) {
      return null;
    }

    int offset = flacOffset + 4;
    while (offset + 4 <= bytes.length) {
      final int header = bytes[offset];
      final bool isLastBlock = (header & 0x80) != 0;
      final int blockType = header & 0x7F;
      final int blockLength =
          (bytes[offset + 1] << 16) |
          (bytes[offset + 2] << 8) |
          bytes[offset + 3];
      offset += 4;

      if (offset + blockLength > bytes.length) {
        return null;
      }

      if (blockType == 4) {
        return _parseVorbisCommentBlock(
          bytes.sublist(offset, offset + blockLength),
        );
      }

      offset += blockLength;
      if (isLastBlock) {
        break;
      }
    }

    return null;
  }

  bool _looksLikeFlac(Uint8List bytes) {
    return _findFlacOffset(bytes) >= 0;
  }

  bool _looksLikeOgg(Uint8List bytes) {
    if (bytes.length < 4) {
      return false;
    }
    return bytes[0] == 0x4F &&
        bytes[1] == 0x67 &&
        bytes[2] == 0x67 &&
        bytes[3] == 0x53;
  }

  bool _looksLikeMp4(Uint8List bytes) {
    if (bytes.length < 12) {
      return false;
    }
    return _matchesAscii(bytes, 4, 'ftyp');
  }

  _AudioContainerKind _detectContainer(Uint8List bytes) {
    if (_looksLikeFlac(bytes)) {
      return _AudioContainerKind.flac;
    }
    if (_looksLikeOgg(bytes)) {
      return _AudioContainerKind.ogg;
    }
    if (_looksLikeMp4(bytes)) {
      return _AudioContainerKind.mp4;
    }
    return _AudioContainerKind.id3OrUnknown;
  }

  AudioMetadataViewData? _parseVorbisCommentBlock(Uint8List block) {
    if (block.length < 8) {
      return null;
    }

    int offset = 0;
    final int vendorLength = _readUint32Le(block, offset);
    offset += 4;
    if (offset + vendorLength + 4 > block.length) {
      return null;
    }

    offset += vendorLength;
    final int commentCount = _readUint32Le(block, offset);
    offset += 4;

    String? title;
    String? artist;
    String? album;
    String? composer;
    String? trackNumber;
    String? discNumber;
    String? lyrics;

    for (int i = 0; i < commentCount; i++) {
      if (offset + 4 > block.length) {
        break;
      }
      final int commentLength = _readUint32Le(block, offset);
      offset += 4;
      if (offset + commentLength > block.length) {
        break;
      }

      final String comment = utf8.decode(
        block.sublist(offset, offset + commentLength),
        allowMalformed: true,
      );
      offset += commentLength;

      final int separatorIndex = comment.indexOf('=');
      if (separatorIndex <= 0) {
        continue;
      }

      final String key = comment.substring(0, separatorIndex).toUpperCase();
      final String value = comment.substring(separatorIndex + 1).trim();
      if (value.isEmpty) {
        continue;
      }

      switch (key) {
        case 'TITLE':
          title ??= value;
        case 'ARTIST':
          artist ??= value;
        case 'ALBUM':
          album ??= value;
        case 'COMPOSER':
        case 'WRITER':
          composer ??= value;
        case 'TRACKNUMBER':
        case 'TRACKTOTAL':
          trackNumber ??= value;
        case 'DISCNUMBER':
        case 'DISCTOTAL':
          discNumber ??= value;
        case 'LYRICS':
        case 'UNSYNCEDLYRICS':
        case 'UNSYNCED LYRICS':
          lyrics ??= value;
      }
    }

    final AudioMetadataViewData metadata = AudioMetadataViewData(
      title: title,
      artist: artist,
      album: album,
      composer: composer,
      trackNumber: trackNumber,
      discNumber: discNumber,
      lyrics: lyrics,
    );
    return metadata.hasAnyValue ? metadata : null;
  }

  AudioMetadataViewData? _readOggMetadata(Uint8List bytes) {
    if (!_looksLikeOgg(bytes)) {
      return null;
    }

    final List<Uint8List> packets = _extractOggPackets(bytes, maxPackets: 2);
    if (packets.length < 2) {
      return null;
    }

    final Uint8List identificationPacket = packets[0];
    final Uint8List commentPacket = packets[1];

    if (_isVorbisIdentificationPacket(identificationPacket)) {
      if (commentPacket.length < 7 ||
          commentPacket[0] != 0x03 ||
          String.fromCharCodes(commentPacket.sublist(1, 7)) != 'vorbis') {
        return null;
      }
      return _parseVorbisCommentBlock(commentPacket.sublist(7));
    }

    if (_isOpusIdentificationPacket(identificationPacket)) {
      if (commentPacket.length < 8 ||
          String.fromCharCodes(commentPacket.sublist(0, 8)) != 'OpusTags') {
        return null;
      }
      return _parseVorbisCommentBlock(commentPacket.sublist(8));
    }

    return null;
  }

  AudioMetadataViewData? _readMp4Metadata(Uint8List bytes) {
    if (!_looksLikeMp4(bytes)) {
      return null;
    }

    final Uint8List? ilst = _findMp4AtomPath(bytes, <String>[
      'moov',
      'udta',
      'meta',
      'ilst',
    ]);
    if (ilst == null) {
      return null;
    }

    String? title;
    String? artist;
    String? album;
    String? composer;
    String? trackNumber;
    String? discNumber;
    String? lyrics;

    int offset = 0;
    while (offset + 8 <= ilst.length) {
      final _Mp4AtomHeader? itemHeader = _readMp4AtomHeader(ilst, offset);
      if (itemHeader == null || itemHeader.size <= 8) {
        break;
      }
      if (itemHeader.end > ilst.length) {
        break;
      }

      final Uint8List itemPayload = ilst.sublist(
        itemHeader.payloadOffset,
        itemHeader.end,
      );
      if (itemHeader.type == 'trkn') {
        trackNumber ??= _readMp4NumberPair(itemPayload);
        offset = itemHeader.end;
        continue;
      }
      if (itemHeader.type == 'disk') {
        discNumber ??= _readMp4NumberPair(itemPayload);
        offset = itemHeader.end;
        continue;
      }
      final String? text = _readMp4MetadataItemText(itemPayload);
      if (text != null) {
        switch (itemHeader.type) {
          case '©nam':
            title ??= text;
          case '©ART':
          case 'aART':
            artist ??= text;
          case '©alb':
            album ??= text;
          case '©wrt':
            composer ??= text;
          case '©lyr':
            lyrics ??= text;
        }
      }

      offset = itemHeader.end;
    }

    final AudioMetadataViewData metadata = AudioMetadataViewData(
      title: title,
      artist: artist,
      album: album,
      composer: composer,
      trackNumber: trackNumber,
      discNumber: discNumber,
      lyrics: lyrics,
    );
    return metadata.hasAnyValue ? metadata : null;
  }

  AudioMetadataViewData? _readApeMetadata(Uint8List bytes) {
    final int footerOffset = _findApeFooterOffset(bytes);
    if (footerOffset < 0 || footerOffset + 32 > bytes.length) {
      return null;
    }

    final int tagSize = _readUint32Le(bytes, footerOffset + 12);
    final int itemCount = _readUint32Le(bytes, footerOffset + 16);
    if (tagSize < 32 || itemCount <= 0) {
      return null;
    }

    final int tagStart = footerOffset - (tagSize - 32);
    if (tagStart < 0 || tagStart >= footerOffset) {
      return null;
    }

    String? title;
    String? artist;
    String? album;
    String? composer;
    String? trackNumber;
    String? discNumber;
    String? lyrics;

    int offset = tagStart;
    for (int i = 0; i < itemCount; i++) {
      if (offset + 9 > footerOffset) {
        break;
      }
      final int valueSize = _readUint32Le(bytes, offset);
      final int flags = _readUint32Le(bytes, offset + 4);
      offset += 8;

      int keyEnd = offset;
      while (keyEnd < footerOffset && bytes[keyEnd] != 0) {
        keyEnd += 1;
      }
      if (keyEnd >= footerOffset) {
        break;
      }

      final String key = ascii
          .decode(bytes.sublist(offset, keyEnd))
          .toUpperCase();
      offset = keyEnd + 1;
      if (offset + valueSize > footerOffset) {
        break;
      }

      final Uint8List valueBytes = bytes.sublist(offset, offset + valueSize);
      offset += valueSize;

      // Binary items like cover art should not be decoded as text.
      final bool isText = (flags & 0x00000006) == 0;
      if (!isText) {
        continue;
      }

      final String value = utf8.decode(valueBytes, allowMalformed: true).trim();
      if (value.isEmpty) {
        continue;
      }

      switch (key) {
        case 'TITLE':
          title ??= value;
        case 'ARTIST':
          artist ??= value;
        case 'ALBUM':
          album ??= value;
        case 'COMPOSER':
        case 'WRITER':
          composer ??= value;
        case 'TRACK':
        case 'TRACKNUMBER':
          trackNumber ??= value;
        case 'DISC':
        case 'DISCNUMBER':
          discNumber ??= value;
        case 'LYRICS':
        case 'UNSYNCEDLYRICS':
          lyrics ??= value;
      }
    }

    final AudioMetadataViewData metadata = AudioMetadataViewData(
      title: title,
      artist: artist,
      album: album,
      composer: composer,
      trackNumber: trackNumber,
      discNumber: discNumber,
      lyrics: lyrics,
    );
    return metadata.hasAnyValue ? metadata : null;
  }

  int _findApeFooterOffset(Uint8List bytes) {
    for (int offset = bytes.length - 32; offset >= 0; offset--) {
      if (_matchesAscii(bytes, offset, 'APETAGEX')) {
        return offset;
      }
    }
    return -1;
  }

  int _findFlacOffset(Uint8List bytes) {
    if (bytes.length < 4) {
      return -1;
    }
    if (_matchesAscii(bytes, 0, 'fLaC')) {
      return 0;
    }
    if (_looksLikeId3v2Header(bytes)) {
      final int id3Size = _readSynchsafeInt(bytes, 6);
      final int candidate = 10 + id3Size;
      if (candidate + 4 <= bytes.length &&
          _matchesAscii(bytes, candidate, 'fLaC')) {
        return candidate;
      }
    }
    return -1;
  }

  bool _looksLikeId3v2Header(Uint8List bytes) {
    return bytes.length >= 10 && _matchesAscii(bytes, 0, 'ID3');
  }

  Uint8List? _findMp4AtomPath(Uint8List bytes, List<String> path) {
    Uint8List current = bytes;
    for (int i = 0; i < path.length; i++) {
      final String type = path[i];
      int offset = 0;
      bool found = false;
      while (offset + 8 <= current.length) {
        final _Mp4AtomHeader? header = _readMp4AtomHeader(current, offset);
        if (header == null || header.size <= 0 || header.end > current.length) {
          return null;
        }
        if (header.type == type) {
          current = current.sublist(header.payloadOffset, header.end);
          if (type == 'meta') {
            if (current.length < 4) {
              return null;
            }
            current = current.sublist(4);
          }
          found = true;
          break;
        }
        offset = header.end;
      }
      if (!found) {
        return null;
      }
    }
    return current;
  }

  String? _readMp4MetadataItemText(Uint8List itemPayload) {
    int offset = 0;
    while (offset + 8 <= itemPayload.length) {
      final _Mp4AtomHeader? header = _readMp4AtomHeader(itemPayload, offset);
      if (header == null ||
          header.size <= 8 ||
          header.end > itemPayload.length) {
        return null;
      }
      if (header.type == 'data') {
        final Uint8List dataPayload = itemPayload.sublist(
          header.payloadOffset,
          header.end,
        );
        if (dataPayload.length < 8) {
          return null;
        }
        final int dataType = _readUint32Be(dataPayload, 0);
        final Uint8List valueBytes = dataPayload.sublist(8);
        if (dataType == 1 || dataType == 0) {
          final String value = utf8
              .decode(valueBytes, allowMalformed: true)
              .trim();
          return value.isEmpty ? null : value;
        }
        final String fallback = utf8
            .decode(valueBytes, allowMalformed: true)
            .trim();
        return fallback.isEmpty ? null : fallback;
      }
      offset = header.end;
    }
    return null;
  }

  String? _readMp4NumberPair(Uint8List itemPayload) {
    int offset = 0;
    while (offset + 8 <= itemPayload.length) {
      final _Mp4AtomHeader? header = _readMp4AtomHeader(itemPayload, offset);
      if (header == null ||
          header.size <= 8 ||
          header.end > itemPayload.length) {
        return null;
      }
      if (header.type == 'data') {
        final Uint8List dataPayload = itemPayload.sublist(
          header.payloadOffset,
          header.end,
        );
        if (dataPayload.length < 14) {
          return null;
        }
        final int current = _readUint16Be(dataPayload, 10);
        final int total = _readUint16Be(dataPayload, 12);
        if (current <= 0) {
          return null;
        }
        return total > 0 ? '$current/$total' : '$current';
      }
      offset = header.end;
    }
    return null;
  }

  List<Uint8List> _extractOggPackets(
    Uint8List bytes, {
    required int maxPackets,
  }) {
    final List<Uint8List> packets = <Uint8List>[];
    final BytesBuilder packetBuilder = BytesBuilder(copy: false);
    int offset = 0;

    while (offset + 27 <= bytes.length && packets.length < maxPackets) {
      if (!_matchesAscii(bytes, offset, 'OggS')) {
        break;
      }

      final int pageSegments = bytes[offset + 26];
      final int segmentTableOffset = offset + 27;
      if (segmentTableOffset + pageSegments > bytes.length) {
        break;
      }

      int payloadOffset = segmentTableOffset + pageSegments;
      for (int i = 0; i < pageSegments; i++) {
        final int segmentLength = bytes[segmentTableOffset + i];
        if (payloadOffset + segmentLength > bytes.length) {
          return packets;
        }
        if (segmentLength > 0) {
          packetBuilder.add(
            bytes.sublist(payloadOffset, payloadOffset + segmentLength),
          );
        }
        payloadOffset += segmentLength;
        if (segmentLength < 255) {
          packets.add(packetBuilder.takeBytes());
          if (packets.length >= maxPackets) {
            return packets;
          }
        }
      }

      offset = payloadOffset;
    }

    return packets;
  }

  bool _isVorbisIdentificationPacket(Uint8List packet) {
    return packet.length >= 7 &&
        packet[0] == 0x01 &&
        String.fromCharCodes(packet.sublist(1, 7)) == 'vorbis';
  }

  bool _isOpusIdentificationPacket(Uint8List packet) {
    return packet.length >= 8 &&
        String.fromCharCodes(packet.sublist(0, 8)) == 'OpusHead';
  }

  bool _matchesAscii(Uint8List bytes, int offset, String value) {
    if (offset + value.length > bytes.length) {
      return false;
    }
    for (int i = 0; i < value.length; i++) {
      if (bytes[offset + i] != value.codeUnitAt(i)) {
        return false;
      }
    }
    return true;
  }

  int _readUint32Le(Uint8List bytes, int offset) {
    return bytes[offset] |
        (bytes[offset + 1] << 8) |
        (bytes[offset + 2] << 16) |
        (bytes[offset + 3] << 24);
  }

  int _readUint32Be(Uint8List bytes, int offset) {
    return (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
  }

  int _readUint16Be(Uint8List bytes, int offset) {
    return (bytes[offset] << 8) | bytes[offset + 1];
  }

  int _readSynchsafeInt(Uint8List bytes, int offset) {
    return ((bytes[offset] & 0x7F) << 21) |
        ((bytes[offset + 1] & 0x7F) << 14) |
        ((bytes[offset + 2] & 0x7F) << 7) |
        (bytes[offset + 3] & 0x7F);
  }

  _Mp4AtomHeader? _readMp4AtomHeader(Uint8List bytes, int offset) {
    if (offset + 8 > bytes.length) {
      return null;
    }
    final int size32 = _readUint32Be(bytes, offset);
    final String type = String.fromCharCodes(
      bytes.sublist(offset + 4, offset + 8),
    );
    int headerSize = 8;
    int size = size32;
    if (size32 == 1) {
      if (offset + 16 > bytes.length) {
        return null;
      }
      final int high = _readUint32Be(bytes, offset + 8);
      final int low = _readUint32Be(bytes, offset + 12);
      if (high != 0) {
        return null;
      }
      size = low;
      headerSize = 16;
    } else if (size32 == 0) {
      size = bytes.length - offset;
    }
    return _Mp4AtomHeader(
      type: type,
      size: size,
      payloadOffset: offset + headerSize,
      end: offset + size,
    );
  }
}

enum _AudioContainerKind { flac, ogg, mp4, id3OrUnknown }

class _Mp4AtomHeader {
  const _Mp4AtomHeader({
    required this.type,
    required this.size,
    required this.payloadOffset,
    required this.end,
  });

  final String type;
  final int size;
  final int payloadOffset;
  final int end;
}
