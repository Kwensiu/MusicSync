import 'package:flutter_test/flutter_test.dart';
import 'package:music_sync/services/file_access/file_access_entry.dart';
import 'package:music_sync/services/file_access/file_access_gateway.dart';
import 'package:music_sync/services/scanning/temp_file_cleanup_service.dart';

void main() {
  group('TempFileCleanupService', () {
    test('deletes temporary transfer files recursively', () async {
      final _CleanupFakeGateway gateway = _CleanupFakeGateway(
        childrenById: <String, List<FileAccessEntry>>{
          'root': <FileAccessEntry>[
            _dir('root/album', 'album'),
            _file('root/song.mp3', 'song.mp3'),
            _file('root/song.mp3.music_sync_tmp', 'song.mp3.music_sync_tmp'),
          ],
          'root/album': <FileAccessEntry>[
            _file(
              'root/album/track.flac.music_sync_tmp',
              'track.flac.music_sync_tmp',
            ),
          ],
        },
      );
      final TempFileCleanupService service = TempFileCleanupService(gateway);

      final TempFileCleanupResult result = await service.cleanup(rootId: 'root');

      expect(result.deletedCount, 2);
      expect(result.failedPaths, isEmpty);
      expect(gateway.deletedEntryIds, containsAll(<String>[
        'root/song.mp3.music_sync_tmp',
        'root/album/track.flac.music_sync_tmp',
      ]));
    });

    test('collects failed paths without aborting the whole cleanup', () async {
      final _CleanupFakeGateway gateway = _CleanupFakeGateway(
        childrenById: <String, List<FileAccessEntry>>{
          'root': <FileAccessEntry>[
            _file('root/a.music_sync_tmp', 'a.music_sync_tmp'),
            _file('root/b.music_sync_tmp', 'b.music_sync_tmp'),
          ],
        },
        undeletableIds: <String>{'root/b.music_sync_tmp'},
      );
      final TempFileCleanupService service = TempFileCleanupService(gateway);

      final TempFileCleanupResult result = await service.cleanup(rootId: 'root');

      expect(result.deletedCount, 1);
      expect(result.failedPaths, <String>['b.music_sync_tmp']);
    });
  });
}

class _CleanupFakeGateway implements FileAccessGateway {
  _CleanupFakeGateway({
    required this.childrenById,
    this.undeletableIds = const <String>{},
  });

  final Map<String, List<FileAccessEntry>> childrenById;
  final Set<String> undeletableIds;
  final List<String> deletedEntryIds = <String>[];

  @override
  Future<String> createDirectory(String parentId, String name) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteEntry(String entryId) async {
    if (undeletableIds.contains(entryId)) {
      throw StateError('cannot delete');
    }
    deletedEntryIds.add(entryId);
  }

  @override
  Future<List<FileAccessEntry>> listChildren(String directoryId) async =>
      childrenById[directoryId] ?? const <FileAccessEntry>[];

  @override
  Stream<List<int>> openRead(String entryId) {
    throw UnimplementedError();
  }

  @override
  Future<FileWriteSession> openWrite(String parentId, String name) {
    throw UnimplementedError();
  }

  @override
  Future<DirectoryHandle?> pickDirectory() {
    throw UnimplementedError();
  }

  @override
  Future<String> renameEntry(String entryId, String newName) {
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
