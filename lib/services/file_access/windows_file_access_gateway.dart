import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:music_sync/core/errors/file_access_exception.dart';
import 'package:music_sync/services/file_access/file_access_entry.dart';
import 'package:music_sync/services/file_access/file_access_gateway.dart';

class WindowsFileWriteSession implements FileWriteSession {
  WindowsFileWriteSession(this._sink);

  final IOSink _sink;

  @override
  Future<void> close() async {
    await _sink.flush();
    await _sink.close();
  }

  @override
  Future<void> write(List<int> chunk) async {
    _sink.add(chunk);
  }
}

class WindowsFileAccessGateway implements FileAccessGateway {
  @override
  Future<String> createDirectory(String parentId, String name) async {
    try {
      final Directory directory = Directory(_childPath(parentId, name));
      final Directory created = await directory.create(recursive: true);
      return created.path;
    } on FileSystemException catch (error) {
      throw FileAccessException(
        error.message.isNotEmpty
            ? 'Windows directory create failed: ${error.message}'
            : 'Windows directory create failed.',
      );
    }
  }

  @override
  Future<void> deleteEntry(String entryId) async {
    try {
      final FileSystemEntityType type = FileSystemEntity.typeSync(entryId);

      switch (type) {
        case FileSystemEntityType.directory:
          await Directory(entryId).delete(recursive: true);
          return;
        case FileSystemEntityType.file:
          await File(entryId).delete();
          return;
        case FileSystemEntityType.notFound:
          return;
        case FileSystemEntityType.link:
          await Link(entryId).delete();
          return;
        default:
          throw FileAccessException(
              'Unsupported entry type for delete: $entryId');
      }
    } on FileSystemException catch (error) {
      throw FileAccessException(
        error.message.isNotEmpty
            ? 'Windows delete failed: ${error.message}'
            : 'Windows delete failed.',
      );
    }
  }

  @override
  Future<List<FileAccessEntry>> listChildren(String directoryId) async {
    try {
      final Directory directory = Directory(directoryId);
      if (!await directory.exists()) {
        throw FileAccessException('Directory does not exist: $directoryId');
      }

      final List<FileSystemEntity> children =
          await directory.list(followLinks: false).toList();
      children.sort(
          (FileSystemEntity a, FileSystemEntity b) => a.path.compareTo(b.path));

      return children.map(_toEntry).toList();
    } on FileSystemException catch (error) {
      throw FileAccessException(
        error.message.isNotEmpty
            ? 'Windows directory listing failed: ${error.message}'
            : 'Windows directory listing failed.',
      );
    }
  }

  @override
  Stream<List<int>> openRead(String entryId) {
    return _openReadSafe(entryId);
  }

  @override
  Future<FileWriteSession> openWrite(String parentId, String name) async {
    try {
      final String path = _childPath(parentId, name);
      final File file = File(path);
      await file.parent.create(recursive: true);
      final IOSink sink = file.openWrite(mode: FileMode.writeOnly);
      return WindowsFileWriteSession(sink);
    } on FileSystemException catch (error) {
      throw FileAccessException(
        error.message.isNotEmpty
            ? 'Windows write session create failed: ${error.message}'
            : 'Windows write session create failed.',
      );
    }
  }

  @override
  Future<String> renameEntry(String entryId, String newName) async {
    try {
      final FileSystemEntityType type = FileSystemEntity.typeSync(entryId);
      if (type == FileSystemEntityType.notFound) {
        throw FileAccessException('Entry does not exist: $entryId');
      }
      final String parentPath = File(entryId).parent.path;
      final String nextPath = _childPath(parentPath, newName);
      switch (type) {
        case FileSystemEntityType.directory:
          final Directory renamed = await Directory(entryId).rename(nextPath);
          return renamed.path;
        case FileSystemEntityType.file:
          final File renamed = await File(entryId).rename(nextPath);
          return renamed.path;
        case FileSystemEntityType.link:
          final Link renamed = await Link(entryId).rename(nextPath);
          return renamed.path;
        case FileSystemEntityType.notFound:
          throw FileAccessException('Entry does not exist: $entryId');
        default:
          throw FileAccessException(
              'Unsupported entry type for rename: $entryId');
      }
    } on FileSystemException catch (error) {
      throw FileAccessException(
        error.message.isNotEmpty
            ? 'Windows rename failed: ${error.message}'
            : 'Windows rename failed.',
      );
    }
  }

  @override
  Future<DirectoryHandle?> pickDirectory() async {
    final String? path = await getDirectoryPath();
    if (path == null || path.isEmpty) {
      return null;
    }

    return DirectoryHandle(
      entryId: path,
      displayName: path,
    );
  }

  @override
  Future<FileAccessEntry> stat(String entryId) async {
    try {
      final FileSystemEntityType type = FileSystemEntity.typeSync(entryId);
      switch (type) {
        case FileSystemEntityType.directory:
          final Directory directory = Directory(entryId);
          final FileStat stat = await directory.stat();
          return FileAccessEntry(
            entryId: entryId,
            name: _basename(entryId),
            isDirectory: true,
            size: 0,
            modifiedTime: stat.modified,
          );
        case FileSystemEntityType.file:
          final File file = File(entryId);
          final FileStat stat = await file.stat();
          return FileAccessEntry(
            entryId: entryId,
            name: _basename(entryId),
            isDirectory: false,
            size: stat.size,
            modifiedTime: stat.modified,
          );
        case FileSystemEntityType.link:
        case FileSystemEntityType.notFound:
          throw FileAccessException('Entry does not exist: $entryId');
        default:
          throw FileAccessException(
              'Unsupported entry type for stat: $entryId');
      }
    } on FileSystemException catch (error) {
      throw FileAccessException(
        error.message.isNotEmpty
            ? 'Windows entry access failed: ${error.message}'
            : 'Windows entry access failed.',
      );
    }
  }

  Stream<List<int>> _openReadSafe(String entryId) async* {
    try {
      final File file = File(entryId);
      if (!await file.exists()) {
        throw FileAccessException('Entry does not exist: $entryId');
      }
      yield* file.openRead();
    } on FileSystemException catch (error) {
      throw FileAccessException(
        error.message.isNotEmpty
            ? 'Windows file read failed: ${error.message}'
            : 'Windows file read failed.',
      );
    }
  }

  FileAccessEntry _toEntry(FileSystemEntity entity) {
    final FileStat stat = entity.statSync();
    final bool isDirectory = entity is Directory;
    return FileAccessEntry(
      entryId: entity.path,
      name: _basename(entity.path),
      isDirectory: isDirectory,
      size: isDirectory ? 0 : stat.size,
      modifiedTime: stat.modified,
    );
  }

  String _basename(String path) {
    final int index = path.lastIndexOf(Platform.pathSeparator);
    return index >= 0 ? path.substring(index + 1) : path;
  }

  String _childPath(String parent, String name) {
    return '$parent${Platform.pathSeparator}$name';
  }
}
