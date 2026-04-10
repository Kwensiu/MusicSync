import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_sync/core/errors/file_access_exception.dart';
import 'package:music_sync/services/file_access/file_access_entry.dart';
import 'package:music_sync/services/file_access/file_access_gateway.dart';
import 'package:music_sync/services/scanning/directory_scanner.dart';
import 'package:music_sync/services/scanning/scan_cache_service.dart';

void main() {
  group('DirectoryScanner', () {
    test('records warnings for inaccessible nested directories', () async {
      final DirectoryScanner scanner = DirectoryScanner(
        gateway: _FakeGateway(
          childrenById: <String, List<FileAccessEntry>>{
            'root': <FileAccessEntry>[
              _dir('album-a', 'AlbumA'),
              _dir('album-b', 'AlbumB'),
              _file('track-1', 'song.mp3'),
            ],
            'album-a': <FileAccessEntry>[_file('track-2', 'song-a.flac')],
          },
          inaccessibleIds: <String>{'album-b'},
        ),
        cacheService: ScanCacheService(),
      );

      final snapshot = await scanner.scan(
        root: const DirectoryHandle(entryId: 'root', displayName: 'Music'),
        deviceId: 'local-device',
      );

      expect(
        snapshot.asPathMap().keys,
        containsAll(<String>['song.mp3', 'AlbumA/song-a.flac']),
      );
      expect(snapshot.warnings, <String>['AlbumB']);
    });

    test('throws when root directory is inaccessible', () async {
      final DirectoryScanner scanner = DirectoryScanner(
        gateway: _FakeGateway(
          childrenById: const <String, List<FileAccessEntry>>{},
          inaccessibleIds: <String>{'root'},
        ),
        cacheService: ScanCacheService(),
      );

      await expectLater(
        () => scanner.scan(
          root: const DirectoryHandle(entryId: 'root', displayName: 'Music'),
          deviceId: 'local-device',
        ),
        throwsA(isA<FileAccessException>()),
      );
    });

    test('ignores temporary transfer files during scan', () async {
      final DirectoryScanner scanner = DirectoryScanner(
        gateway: _FakeGateway(
          childrenById: <String, List<FileAccessEntry>>{
            'root': <FileAccessEntry>[
              _file('track-1', 'song.mp3'),
              _file('track-temp', 'song.mp3.music_sync_tmp'),
            ],
          },
        ),
        cacheService: ScanCacheService(),
      );

      final snapshot = await scanner.scan(
        root: const DirectoryHandle(entryId: 'root', displayName: 'Music'),
        deviceId: 'local-device',
      );

      expect(snapshot.asPathMap().keys, contains('song.mp3'));
      expect(
        snapshot.asPathMap().keys,
        isNot(contains('song.mp3.music_sync_tmp')),
      );
    });
  });
}

class _FakeGateway implements FileAccessGateway {
  _FakeGateway({
    required this.childrenById,
    this.inaccessibleIds = const <String>{},
  });

  final Map<String, List<FileAccessEntry>> childrenById;
  final Set<String> inaccessibleIds;

  @override
  Future<String> createDirectory(String parentId, String name) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteEntry(String entryId) {
    throw UnimplementedError();
  }

  @override
  Future<List<FileAccessEntry>> listChildren(String directoryId) async {
    if (inaccessibleIds.contains(directoryId)) {
      throw FileAccessException('denied');
    }
    return childrenById[directoryId] ?? const <FileAccessEntry>[];
  }

  @override
  Stream<List<int>> openRead(String entryId) {
    throw UnimplementedError();
  }

  @override
  Future<FileWriteSession> openWrite(String parentId, String name) {
    throw UnimplementedError();
  }

  @override
  Future<String> renameEntry(String entryId, String newName) {
    throw UnimplementedError();
  }

  @override
  Future<DirectoryHandle?> pickDirectory() {
    throw UnimplementedError();
  }

  @override
  Future<FileAccessEntry> stat(String entryId) {
    throw UnimplementedError();
  }
}

FileAccessEntry _dir(String entryId, String name) {
  return FileAccessEntry(
    entryId: entryId,
    name: name,
    isDirectory: true,
    size: 0,
    modifiedTime: DateTime.fromMillisecondsSinceEpoch(0),
  );
}

FileAccessEntry _file(String entryId, String name) {
  return FileAccessEntry(
    entryId: entryId,
    name: name,
    isDirectory: false,
    size: 1,
    modifiedTime: DateTime.fromMillisecondsSinceEpoch(0),
  );
}
