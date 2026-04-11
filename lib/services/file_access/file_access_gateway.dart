import 'package:music_sync/services/file_access/file_access_entry.dart';

abstract class FileWriteSession {
  Future<void> write(List<int> chunk);
  Future<void> close();
}

abstract class FileAccessGateway {
  Future<DirectoryHandle?> pickDirectory();
  Future<List<FileAccessEntry>> listChildren(String directoryId);
  Future<FileAccessEntry> stat(String entryId);
  Stream<List<int>> openRead(String entryId);
  Future<FileWriteSession> openWrite(String parentId, String name);
  Future<String> createDirectory(String parentId, String name);
  Future<String> renameEntry(String entryId, String newName);
  Future<void> deleteEntry(String entryId);
  Future<Map<String, String?>?> getAudioMetadata(String entryId);
}
