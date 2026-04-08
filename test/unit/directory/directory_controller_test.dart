import 'package:flutter_test/flutter_test.dart';
import 'package:music_sync/features/directory/state/directory_controller.dart';
import 'package:music_sync/features/directory/state/directory_state.dart';
import 'package:music_sync/services/file_access/file_access_entry.dart';
import 'package:music_sync/services/file_access/file_access_gateway.dart';
import 'package:music_sync/services/scanning/directory_preflight_service.dart';
import 'package:music_sync/services/scanning/temp_file_cleanup_service.dart';
import 'package:music_sync/services/storage/recent_items_store.dart';

void main() {
  test('pickDirectory stores preflight risk summary', () async {
    final _FakeRecentItemsStore store = _FakeRecentItemsStore();
    final DirectoryController controller = DirectoryController(
      _FakeFileAccessGateway(),
      () async =>
          const DirectoryHandle(entryId: 'root', displayName: 'AppData'),
      () {},
      (_) async {},
      store,
      DirectoryPreflightService(
        _FakePreflightGateway(),
      ),
      TempFileCleanupService(_FakeFileAccessGateway()),
    );

    await controller.pickDirectory();

    final DirectoryState state = controller.state;
    expect(state.handle?.entryId, 'root');
    expect(state.preflight, isNotNull);
    expect(state.preflight?.hasRisk, isTrue);
    expect(state.preflight?.reasons, contains('system_like_directory'));
  });
}

class _FakeFileAccessGateway implements FileAccessGateway {
  @override
  Future<String> createDirectory(String parentId, String name) async => '';

  @override
  Future<void> deleteEntry(String entryId) async {}

  @override
  Future<List<FileAccessEntry>> listChildren(String directoryId) async =>
      const <FileAccessEntry>[];

  @override
  Stream<List<int>> openRead(String entryId) async* {}

  @override
  Future<FileWriteSession> openWrite(String parentId, String name) {
    throw UnimplementedError();
  }

  @override
  Future<String> renameEntry(String entryId, String newName) async => entryId;

  @override
  Future<DirectoryHandle?> pickDirectory() async => null;

  @override
  Future<FileAccessEntry> stat(String entryId) {
    throw UnimplementedError();
  }
}

class _FakePreflightGateway extends _FakeFileAccessGateway {
  @override
  Future<List<FileAccessEntry>> listChildren(String directoryId) async {
    if (directoryId == 'root') {
      return <FileAccessEntry>[
        FileAccessEntry(
          entryId: 'child',
          name: 'child',
          isDirectory: true,
          size: 0,
          modifiedTime: DateTime.fromMillisecondsSinceEpoch(0),
        ),
      ];
    }
    return const <FileAccessEntry>[];
  }
}

class _FakeRecentItemsStore extends RecentItemsStore {
  final List<DirectoryHandle> _directories = <DirectoryHandle>[];

  @override
  Future<List<DirectoryHandle>> loadRecentDirectories() async => _directories;

  @override
  Future<void> saveRecentDirectory(DirectoryHandle handle) async {
    _directories.add(handle);
  }
}
