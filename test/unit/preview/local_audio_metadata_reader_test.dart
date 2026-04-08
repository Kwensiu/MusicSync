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
