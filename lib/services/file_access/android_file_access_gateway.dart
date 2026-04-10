import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:music_sync/core/errors/file_access_exception.dart';
import 'package:music_sync/services/file_access/file_access_entry.dart';
import 'package:music_sync/services/file_access/file_access_gateway.dart';

class AndroidFileWriteSession implements FileWriteSession {
  AndroidFileWriteSession(this._sessionId);

  final String _sessionId;

  @override
  Future<void> close() async {
    try {
      await AndroidFileAccessGateway._channel.invokeMethod<void>(
        'closeWriteSession',
        <String, Object?>{'sessionId': _sessionId},
      );
    } on PlatformException catch (error) {
      throw FileAccessException(error.message ?? 'Android file close failed.');
    }
  }

  @override
  Future<void> write(List<int> chunk) async {
    try {
      await AndroidFileAccessGateway._channel.invokeMethod<void>(
        'writeChunk',
        <String, Object?>{'sessionId': _sessionId, 'data': base64Encode(chunk)},
      );
    } on PlatformException catch (error) {
      throw FileAccessException(error.message ?? 'Android file write failed.');
    }
  }
}

class _AndroidReadStreamController {
  _AndroidReadStreamController(this._entryId);

  final String _entryId;
  String? _sessionId;

  Stream<List<int>> stream() async* {
    try {
      _sessionId = await AndroidFileAccessGateway._channel.invokeMethod<String>(
        'openRead',
        <String, Object?>{'entryId': _entryId},
      );
      if (_sessionId == null || _sessionId!.isEmpty) {
        throw FileAccessException('Android read session create failed.');
      }

      while (true) {
        final String? encoded = await AndroidFileAccessGateway._channel
            .invokeMethod<String>('readChunk', <String, Object?>{
              'sessionId': _sessionId,
            });
        if (encoded == null || encoded.isEmpty) {
          break;
        }
        yield base64Decode(encoded);
      }
    } on PlatformException catch (error) {
      throw FileAccessException(error.message ?? 'Android file read failed.');
    } finally {
      final String? sessionId = _sessionId;
      if (sessionId != null && sessionId.isNotEmpty) {
        try {
          await AndroidFileAccessGateway._channel.invokeMethod<void>(
            'closeReadSession',
            <String, Object?>{'sessionId': sessionId},
          );
        } on PlatformException {
          // Ignore close failures during stream teardown.
        }
      }
    }
  }
}

class AndroidFileAccessGateway implements FileAccessGateway {
  static const MethodChannel _channel = MethodChannel(
    'music_sync/android_file_access',
  );

  @override
  Future<String> createDirectory(String parentId, String name) async {
    try {
      final String? entryId = await _channel.invokeMethod<String>(
        'createDirectory',
        <String, Object?>{'parentId': parentId, 'name': name},
      );
      if (entryId == null || entryId.isEmpty) {
        throw FileAccessException('Android directory create failed.');
      }
      return entryId;
    } on PlatformException catch (error) {
      throw FileAccessException(
        error.message ?? 'Android directory create failed.',
      );
    }
  }

  @override
  Future<void> deleteEntry(String entryId) async {
    try {
      await _channel.invokeMethod<void>('deleteEntry', <String, Object?>{
        'entryId': entryId,
      });
    } on PlatformException catch (error) {
      throw FileAccessException(
        error.message ?? 'Android entry delete failed.',
      );
    }
  }

  @override
  Future<List<FileAccessEntry>> listChildren(String directoryId) async {
    try {
      final List<Object?>? rawEntries = await _channel
          .invokeMethod<List<Object?>>('listChildren', <String, Object?>{
            'directoryId': directoryId,
          });
      if (rawEntries == null) {
        return const <FileAccessEntry>[];
      }
      return rawEntries
          .whereType<Map<Object?, Object?>>()
          .map(_toEntry)
          .toList();
    } on PlatformException catch (error) {
      throw FileAccessException(
        error.message ?? 'Android directory listing failed.',
      );
    }
  }

  @override
  Stream<List<int>> openRead(String entryId) {
    return _AndroidReadStreamController(entryId).stream();
  }

  @override
  Future<FileWriteSession> openWrite(String parentId, String name) async {
    try {
      final String? sessionId = await _channel.invokeMethod<String>(
        'openWrite',
        <String, Object?>{'parentId': parentId, 'name': name},
      );
      if (sessionId == null || sessionId.isEmpty) {
        throw FileAccessException('Android write session create failed.');
      }
      return AndroidFileWriteSession(sessionId);
    } on PlatformException catch (error) {
      throw FileAccessException(
        error.message ?? 'Android write session create failed.',
      );
    }
  }

  @override
  Future<String> renameEntry(String entryId, String newName) async {
    try {
      final String? renamedEntryId = await _channel.invokeMethod<String>(
        'renameEntry',
        <String, Object?>{'entryId': entryId, 'newName': newName},
      );
      if (renamedEntryId == null || renamedEntryId.isEmpty) {
        throw FileAccessException('Android entry rename failed.');
      }
      return renamedEntryId;
    } on PlatformException catch (error) {
      throw FileAccessException(
        error.message ?? 'Android entry rename failed.',
      );
    }
  }

  @override
  Future<DirectoryHandle?> pickDirectory() async {
    try {
      final Map<Object?, Object?>? rawHandle = await _channel
          .invokeMethod<Map<Object?, Object?>>('pickDirectory');
      if (rawHandle == null) {
        return null;
      }

      final Map<String, Object?> handle = rawHandle.map(
        (Object? key, Object? value) => MapEntry(key.toString(), value),
      );
      return DirectoryHandle(
        entryId: handle['entryId'] as String? ?? '',
        displayName: handle['displayName'] as String? ?? '',
      );
    } on PlatformException catch (error) {
      throw FileAccessException(
        error.message ?? 'Android directory picker failed.',
      );
    }
  }

  @override
  Future<FileAccessEntry> stat(String entryId) async {
    try {
      final Map<Object?, Object?>? rawEntry = await _channel
          .invokeMethod<Map<Object?, Object?>>('stat', <String, Object?>{
            'entryId': entryId,
          });
      if (rawEntry == null) {
        throw FileAccessException('Android entry not found.');
      }
      return _toEntry(rawEntry);
    } on PlatformException catch (error) {
      throw FileAccessException(
        error.message ?? 'Android entry access failed.',
      );
    }
  }

  FileAccessEntry _toEntry(Map<Object?, Object?> rawEntry) {
    final Map<String, Object?> entry = rawEntry.map(
      (Object? key, Object? value) => MapEntry(key.toString(), value),
    );
    return FileAccessEntry(
      entryId: entry['entryId'] as String? ?? '',
      name: entry['name'] as String? ?? '',
      isDirectory: entry['isDirectory'] as bool? ?? false,
      size: (entry['size'] as num?)?.toInt() ?? 0,
      modifiedTime: DateTime.fromMillisecondsSinceEpoch(
        (entry['modifiedTime'] as num?)?.toInt() ?? 0,
      ),
    );
  }
}
