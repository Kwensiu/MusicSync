import 'package:flutter_test/flutter_test.dart';
import 'package:music_sync/core/errors/file_access_exception.dart';
import 'package:music_sync/services/file_access/file_access_entry.dart';
import 'package:music_sync/services/file_access/file_access_gateway.dart';
import 'package:music_sync/services/scanning/directory_preflight_service.dart';

void main() {
  group('DirectoryPreflightService', () {
    test('flags system-like and dense directories as risky', () async {
      final DirectoryPreflightService service = DirectoryPreflightService(
        _FakeGateway(
          childrenById: <String, List<FileAccessEntry>>{
            'root': List<FileAccessEntry>.generate(
              130,
              (int index) => FileAccessEntry(
                entryId: 'dir-$index',
                name: 'dir-$index',
                isDirectory: true,
                size: 0,
                modifiedTime: DateTime.fromMillisecondsSinceEpoch(0),
              ),
            ),
            'dir-0': List<FileAccessEntry>.generate(
              121,
              (int index) => FileAccessEntry(
                entryId: 'nested-$index',
                name: 'nested-$index',
                isDirectory: false,
                size: 1,
                modifiedTime: DateTime.fromMillisecondsSinceEpoch(0),
              ),
            ),
          },
        ),
      );

      final DirectoryPreflightResult result = await service.inspect(
        const DirectoryHandle(entryId: 'root', displayName: 'AppData'),
      );

      expect(result.hasRisk, isTrue);
      expect(result.reasons, contains('many_root_children'));
      expect(result.reasons, contains('dense_nested_directory'));
      expect(result.reasons, contains('system_like_directory'));
    });

    test('flags inaccessible shallow subdirectory as risky', () async {
      final DirectoryPreflightService service = DirectoryPreflightService(
        _FakeGateway(
          childrenById: <String, List<FileAccessEntry>>{
            'root': <FileAccessEntry>[
              FileAccessEntry(
                entryId: 'album',
                name: 'album',
                isDirectory: true,
                size: 0,
                modifiedTime: DateTime.fromMillisecondsSinceEpoch(0),
              ),
            ],
          },
          inaccessibleIds: <String>{'album'},
        ),
      );

      final DirectoryPreflightResult result = await service.inspect(
        const DirectoryHandle(entryId: 'root', displayName: 'Music'),
      );

      expect(result.hasRisk, isTrue);
      expect(result.reasons, contains('inaccessible_subdirectory'));
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

  @override
  Future<Map<String, String?>?> getAudioMetadata(String entryId) async => null;
}
