import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_tags/dart_tags.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_sync/services/file_access/file_access_entry.dart';
import 'package:music_sync/services/file_access/file_access_gateway.dart';
import 'package:music_sync/services/media/audio_metadata_reader.dart';

void main() {
  test('prefers ID3v2 metadata when ID3v1 and ID3v2 are both present',
      () async {
    final Tag id3v1 = Tag()
      ..type = 'ID3'
      ..version = '1.1'
      ..tags = <String, dynamic>{
        'title': 'ÖÐÎÄ±êÌâ',
        'artist': 'ÒÕÊõ¼Ò',
        'album': '×¨¼\xad',
        'year': '2026',
        'comment': '',
        'track': '0',
        'genre': 'Blues',
      };
    final Tag id3v2 = Tag()
      ..type = 'ID3'
      ..version = '2.4'
      ..tags = <String, dynamic>{
        'title': '中文标题',
        'artist': '艺术家',
        'album': '专辑',
      };

    final List<int> bytes = await TagProcessor().putTagsToByteArray(
      Future<List<int>?>.value(List<int>.filled(32, 0)),
      <Tag>[id3v1, id3v2],
    );

    final AudioMetadataReader reader = AudioMetadataReader(
      _FakeGateway(Uint8List.fromList(bytes)),
    );

    final metadata = await reader.read('entry');

    expect(metadata?.title, '中文标题');
    expect(metadata?.artist, '艺术家');
    expect(metadata?.album, '专辑');
  });

  test('returns null when prefix read stalls instead of hanging forever',
      () async {
    final AudioMetadataReader reader = AudioMetadataReader(
      _StalledGateway(),
    );

    final DateTime startedAt = DateTime.now();
    final metadata = await reader.read('entry');
    final Duration elapsed = DateTime.now().difference(startedAt);

    expect(metadata, isNull);
    expect(elapsed, lessThan(const Duration(seconds: 4)));
  });

  test('falls back to ID3v1 metadata when ID3v2 is missing', () async {
    final Tag id3v1 = Tag()
      ..type = 'ID3'
      ..version = '1.1'
      ..tags = <String, dynamic>{
        'title': 'Fallback Song',
        'artist': 'Fallback Artist',
        'album': 'Fallback Album',
        'year': '2026',
        'comment': '',
        'track': '1',
        'genre': 'Blues',
      };

    final List<int> bytes = await TagProcessor().putTagsToByteArray(
      Future<List<int>?>.value(List<int>.filled(32, 0)),
      <Tag>[id3v1],
    );

    final AudioMetadataReader reader = AudioMetadataReader(
      _FakeGateway(Uint8List.fromList(bytes)),
    );

    final metadata = await reader.read('entry');

    expect(metadata?.title, 'Fallback Song');
    expect(metadata?.artist, 'Fallback Artist');
    expect(metadata?.album, 'Fallback Album');
  });

  test('reads FLAC vorbis comment metadata', () async {
    final AudioMetadataReader reader = AudioMetadataReader(
      _FakeGateway(
        _buildFlacBytes(
          <String, String>{
            'TITLE': 'FLAC Song',
            'ARTIST': 'FLAC Artist',
            'ALBUM': 'FLAC Album',
            'LYRICS': 'FLAC Lyrics',
          },
        ),
      ),
    );

    final metadata = await reader.read('entry');

    expect(metadata?.title, 'FLAC Song');
    expect(metadata?.artist, 'FLAC Artist');
    expect(metadata?.album, 'FLAC Album');
    expect(metadata?.lyrics, 'FLAC Lyrics');
  });

  test('decodes UTF-8 vorbis comment text correctly', () async {
    final AudioMetadataReader reader = AudioMetadataReader(
      _FakeGateway(
        _buildFlacBytes(
          <String, String>{
            'TITLE': '限りなく灰色へ',
            'ARTIST': '25時、ナイトコードで。',
            'ALBUM': 'プロセカ',
          },
        ),
      ),
    );

    final metadata = await reader.read('entry');

    expect(metadata?.title, '限りなく灰色へ');
    expect(metadata?.artist, '25時、ナイトコードで。');
    expect(metadata?.album, 'プロセカ');
  });

  test('can fall back to full read for larger FLAC metadata block', () async {
    final Map<String, String> comments = <String, String>{
      'TITLE': 'Long FLAC Song',
      'ARTIST': 'Long FLAC Artist',
      'ALBUM': 'Long FLAC Album',
      'LYRICS': 'L' * (600 * 1024),
    };
    final AudioMetadataReader reader = AudioMetadataReader(
      _FakeGateway(_buildFlacBytes(comments)),
    );

    final metadata = await reader.read('entry');

    expect(metadata?.title, 'Long FLAC Song');
    expect(metadata?.artist, 'Long FLAC Artist');
    expect(metadata?.album, 'Long FLAC Album');
    expect(metadata?.lyrics, 'L' * (600 * 1024));
  });

  test('reads Ogg Vorbis comment metadata', () async {
    final AudioMetadataReader reader = AudioMetadataReader(
      _FakeGateway(
        _buildOggVorbisBytes(
          <String, String>{
            'TITLE': 'Ogg Song',
            'ARTIST': 'Ogg Artist',
            'ALBUM': 'Ogg Album',
          },
        ),
      ),
    );

    final metadata = await reader.read('entry');

    expect(metadata?.title, 'Ogg Song');
    expect(metadata?.artist, 'Ogg Artist');
    expect(metadata?.album, 'Ogg Album');
  });

  test('reads OpusTags metadata', () async {
    final AudioMetadataReader reader = AudioMetadataReader(
      _FakeGateway(
        _buildOpusBytes(
          <String, String>{
            'TITLE': 'Opus Song',
            'ARTIST': 'Opus Artist',
            'ALBUM': 'Opus Album',
          },
        ),
      ),
    );

    final metadata = await reader.read('entry');

    expect(metadata?.title, 'Opus Song');
    expect(metadata?.artist, 'Opus Artist');
    expect(metadata?.album, 'Opus Album');
  });

  test('reads MP4 ilst metadata', () async {
    final AudioMetadataReader reader = AudioMetadataReader(
      _FakeGateway(
        _buildMp4Bytes(
          <String, String>{
            '\u00A9nam': 'M4A Song',
            '\u00A9ART': 'M4A Artist',
            '\u00A9alb': 'M4A Album',
            '\u00A9wrt': 'M4A Composer',
            'trkn': '3/12',
            'disk': '1/2',
            '\u00A9lyr': 'M4A Lyrics',
          },
        ),
      ),
    );

    final metadata = await reader.read('entry');

    expect(metadata?.title, 'M4A Song');
    expect(metadata?.artist, 'M4A Artist');
    expect(metadata?.album, 'M4A Album');
    expect(metadata?.composer, 'M4A Composer');
    expect(metadata?.trackNumber, '3/12');
    expect(metadata?.discNumber, '1/2');
    expect(metadata?.lyrics, 'M4A Lyrics');
  });

  test('reads APEv2 footer metadata', () async {
    final AudioMetadataReader reader = AudioMetadataReader(
      _FakeGateway(
        _buildApeBytes(
          <String, String>{
            'TITLE': 'APE Song',
            'ARTIST': 'APE Artist',
            'ALBUM': 'APE Album',
            'COMPOSER': 'APE Composer',
            'TRACK': '4',
            'DISC': '1',
            'LYRICS': 'APE Lyrics',
          },
        ),
      ),
    );

    final metadata = await reader.read('entry');

    expect(metadata?.title, 'APE Song');
    expect(metadata?.artist, 'APE Artist');
    expect(metadata?.album, 'APE Album');
    expect(metadata?.composer, 'APE Composer');
    expect(metadata?.trackNumber, '4');
    expect(metadata?.discNumber, '1');
    expect(metadata?.lyrics, 'APE Lyrics');
  });
}

Uint8List _buildFlacBytes(Map<String, String> comments) {
  final List<int> vendor = utf8.encode('MusicSyncTest');
  final BytesBuilder vorbisBuilder = BytesBuilder(copy: false)
    ..add(_uint32Le(vendor.length))
    ..add(vendor)
    ..add(_uint32Le(comments.length));

  for (final MapEntry<String, String> entry in comments.entries) {
    final List<int> raw = utf8.encode('${entry.key}=${entry.value}');
    vorbisBuilder
      ..add(_uint32Le(raw.length))
      ..add(raw);
  }

  final Uint8List vorbisBlock = vorbisBuilder.takeBytes();
  final BytesBuilder flacBuilder = BytesBuilder(copy: false)
    ..add('fLaC'.codeUnits)
    ..add(<int>[
      0x80 | 4,
      (vorbisBlock.length >> 16) & 0xFF,
      (vorbisBlock.length >> 8) & 0xFF,
      vorbisBlock.length & 0xFF,
    ])
    ..add(vorbisBlock);

  return flacBuilder.takeBytes();
}

List<int> _uint32Le(int value) {
  return <int>[
    value & 0xFF,
    (value >> 8) & 0xFF,
    (value >> 16) & 0xFF,
    (value >> 24) & 0xFF,
  ];
}

Uint8List _buildOggVorbisBytes(Map<String, String> comments) {
  final Uint8List identificationPacket = Uint8List.fromList(
    <int>[
      0x01,
      ...'vorbis'.codeUnits,
      0x00,
    ],
  );
  final Uint8List commentPacket = Uint8List.fromList(
    <int>[
      0x03,
      ...'vorbis'.codeUnits,
      ..._buildVorbisCommentPayload(comments),
    ],
  );
  return _buildOggContainer(<Uint8List>[identificationPacket, commentPacket]);
}

Uint8List _buildOpusBytes(Map<String, String> comments) {
  final Uint8List identificationPacket = Uint8List.fromList(
    <int>[
      ...'OpusHead'.codeUnits,
      0x01,
      0x02,
    ],
  );
  final Uint8List commentPacket = Uint8List.fromList(
    <int>[
      ...'OpusTags'.codeUnits,
      ..._buildVorbisCommentPayload(comments),
    ],
  );
  return _buildOggContainer(<Uint8List>[identificationPacket, commentPacket]);
}

Uint8List _buildVorbisCommentPayload(Map<String, String> comments) {
  final List<int> vendor = utf8.encode('MusicSyncTest');
  final BytesBuilder builder = BytesBuilder(copy: false)
    ..add(_uint32Le(vendor.length))
    ..add(vendor)
    ..add(_uint32Le(comments.length));

  for (final MapEntry<String, String> entry in comments.entries) {
    final List<int> raw = utf8.encode('${entry.key}=${entry.value}');
    builder
      ..add(_uint32Le(raw.length))
      ..add(raw);
  }

  return builder.takeBytes();
}

Uint8List _buildOggContainer(List<Uint8List> packets) {
  final BytesBuilder builder = BytesBuilder(copy: false);
  int sequence = 0;
  for (int i = 0; i < packets.length; i++) {
    final Uint8List packet = packets[i];
    final List<int> lacingValues = <int>[];
    int remaining = packet.length;
    while (remaining >= 255) {
      lacingValues.add(255);
      remaining -= 255;
    }
    lacingValues.add(remaining);

    builder
      ..add('OggS'.codeUnits)
      ..add(<int>[0x00, i == 0 ? 0x02 : 0x00])
      ..add(List<int>.filled(8, 0))
      ..add(<int>[1, 0, 0, 0])
      ..add(_uint32Le(sequence++))
      ..add(List<int>.filled(4, 0))
      ..add(<int>[lacingValues.length])
      ..add(lacingValues)
      ..add(packet);
  }

  return builder.takeBytes();
}

Uint8List _buildMp4Bytes(Map<String, String> metadata) {
  final List<Uint8List> items =
      metadata.entries.map((MapEntry<String, String> entry) {
    final Uint8List data = switch (entry.key) {
      'trkn' || 'disk' => _mp4NumberPairDataAtom(entry.value),
      _ => _mp4DataAtom(entry.value),
    };
    return _mp4Atom(entry.key, data);
  }).toList();

  final Uint8List ilst = _mp4Atom(
    'ilst',
    _concatBytes(items),
  );
  final Uint8List meta = _mp4Atom(
    'meta',
    Uint8List.fromList(<int>[
      0,
      0,
      0,
      0,
      ...ilst,
    ]),
  );
  final Uint8List udta = _mp4Atom('udta', meta);
  final Uint8List moov = _mp4Atom('moov', udta);
  final Uint8List ftyp = _mp4Atom(
    'ftyp',
    Uint8List.fromList(<int>[
      ...'M4A '.codeUnits,
      0,
      0,
      0,
      0,
      ...'isom'.codeUnits,
      ...'M4A '.codeUnits,
    ]),
  );

  return Uint8List.fromList(<int>[
    ...ftyp,
    ...moov,
  ]);
}

Uint8List _buildApeBytes(Map<String, String> metadata) {
  final BytesBuilder itemsBuilder = BytesBuilder(copy: false);
  for (final MapEntry<String, String> entry in metadata.entries) {
    final List<int> key = ascii.encode(entry.key);
    final List<int> value = utf8.encode(entry.value);
    itemsBuilder
      ..add(_uint32Le(value.length))
      ..add(_uint32Le(0))
      ..add(key)
      ..add(<int>[0])
      ..add(value);
  }

  final Uint8List items = itemsBuilder.takeBytes();
  final int totalSize = items.length + 32;
  final Uint8List footer = Uint8List.fromList(<int>[
    ...ascii.encode('APETAGEX'),
    ..._uint32Le(2000),
    ..._uint32Le(totalSize),
    ..._uint32Le(metadata.length),
    ..._uint32Le(0),
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
  ]);

  return Uint8List.fromList(<int>[
    ...utf8.encode('audio payload'),
    ...items,
    ...footer,
  ]);
}

Uint8List _mp4DataAtom(String value) {
  final List<int> payload = utf8.encode(value);
  return _mp4Atom(
    'data',
    Uint8List.fromList(<int>[
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      ...payload,
    ]),
  );
}

Uint8List _mp4NumberPairDataAtom(String value) {
  final List<String> parts = value.split('/');
  final int current = int.tryParse(parts.first) ?? 0;
  final int total = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
  return _mp4Atom(
    'data',
    Uint8List.fromList(<int>[
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      (current >> 8) & 0xFF,
      current & 0xFF,
      (total >> 8) & 0xFF,
      total & 0xFF,
    ]),
  );
}

Uint8List _mp4Atom(String type, Uint8List payload) {
  final int size = 8 + payload.length;
  return Uint8List.fromList(<int>[
    ..._uint32Be(size),
    ...type.codeUnits,
    ...payload,
  ]);
}

Uint8List _concatBytes(List<Uint8List> chunks) {
  final BytesBuilder builder = BytesBuilder(copy: false);
  for (final Uint8List chunk in chunks) {
    builder.add(chunk);
  }
  return builder.takeBytes();
}

List<int> _uint32Be(int value) {
  return <int>[
    (value >> 24) & 0xFF,
    (value >> 16) & 0xFF,
    (value >> 8) & 0xFF,
    value & 0xFF,
  ];
}

class _FakeGateway implements FileAccessGateway {
  _FakeGateway(this._bytes);

  final Uint8List _bytes;

  @override
  Future<String> createDirectory(String parentId, String name) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteEntry(String entryId) {
    throw UnimplementedError();
  }

  @override
  Future<List<FileAccessEntry>> listChildren(String directoryId) {
    throw UnimplementedError();
  }

  @override
  Stream<List<int>> openRead(String entryId) async* {
    yield _bytes;
  }

  @override
  Future<FileWriteSession> openWrite(String parentId, String name) {
    throw UnimplementedError();
  }

  @override
  Future<DirectoryHandle?> pickDirectory() async => null;

  @override
  Future<String> renameEntry(String entryId, String newName) {
    throw UnimplementedError();
  }

  @override
  Future<FileAccessEntry> stat(String entryId) {
    throw UnimplementedError();
  }
}

class _StalledGateway implements FileAccessGateway {
  @override
  Future<String> createDirectory(String parentId, String name) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteEntry(String entryId) {
    throw UnimplementedError();
  }

  @override
  Future<List<FileAccessEntry>> listChildren(String directoryId) {
    throw UnimplementedError();
  }

  @override
  Stream<List<int>> openRead(String entryId) async* {
    await Future<void>.delayed(const Duration(seconds: 5));
    yield const <int>[];
  }

  @override
  Future<FileWriteSession> openWrite(String parentId, String name) {
    throw UnimplementedError();
  }

  @override
  Future<DirectoryHandle?> pickDirectory() async => null;

  @override
  Future<String> renameEntry(String entryId, String newName) {
    throw UnimplementedError();
  }

  @override
  Future<FileAccessEntry> stat(String entryId) {
    throw UnimplementedError();
  }
}
