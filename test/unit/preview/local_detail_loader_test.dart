import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_sync/features/preview/models/diff_item_detail_view_data.dart';
import 'package:music_sync/features/preview/services/local_detail_loader.dart';
import 'package:music_sync/models/diff_item.dart';
import 'package:music_sync/services/file_access/file_access_entry.dart';
import 'package:music_sync/services/file_access/file_access_gateway.dart';

void main() {
  test('refresh keeps existing entry when local stat stalls', () async {
    final LocalDetailLoader loader = LocalDetailLoader(_SlowStatGateway());
    final DiffItemDetailViewData data = DiffItemDetailViewData(
      path: 'Music/song.mp3',
      type: DiffType.copy,
      reason: null,
      side: DiffItemDetailSide.sourceOnly,
      source: DiffEntryDetailViewData(
        entryId: 'entry-1',
        displayName: 'song.mp3',
        size: 128,
        modifiedTime: DateTime.fromMillisecondsSinceEpoch(1),
        isDirectory: false,
      ),
      target: null,
      sourceIsRemote: false,
      targetIsRemote: false,
    );

    final DateTime startedAt = DateTime.now();
    final DiffItemDetailViewData refreshed = await loader.refresh(data);
    final Duration elapsed = DateTime.now().difference(startedAt);

    expect(refreshed.source?.entryId, 'entry-1');
    expect(refreshed.source?.size, 128);
    expect(elapsed, lessThan(const Duration(seconds: 4)));
  });

  test('refresh keeps existing remote entry when remote stat fails', () async {
    final LocalDetailLoader loader = LocalDetailLoader(
      _NoopGateway(),
      loadRemoteEntryDetail: (String entryId) async => throw Exception('boom'),
    );
    final DiffItemDetailViewData data = DiffItemDetailViewData(
      path: 'Music/song.mp3',
      type: DiffType.copy,
      reason: null,
      side: DiffItemDetailSide.targetOnly,
      source: null,
      target: DiffEntryDetailViewData(
        entryId: 'remote-entry',
        displayName: 'song.mp3',
        size: 256,
        modifiedTime: DateTime.fromMillisecondsSinceEpoch(2),
        isDirectory: false,
      ),
      sourceIsRemote: false,
      targetIsRemote: true,
    );

    final DiffItemDetailViewData refreshed = await loader.refresh(data);

    expect(refreshed.target?.entryId, 'remote-entry');
    expect(refreshed.target?.size, 256);
  });

  test('refresh applies remote audio metadata when remote detail succeeds',
      () async {
    final LocalDetailLoader loader = LocalDetailLoader(
      _NoopGateway(),
      loadRemoteEntryDetail: (String entryId) async => DiffEntryDetailViewData(
        entryId: entryId,
        displayName: 'song.mp3',
        size: 512,
        modifiedTime: DateTime.fromMillisecondsSinceEpoch(4),
        isDirectory: false,
        audioMetadata: const AudioMetadataViewData(
          title: 'Remote Song',
          artist: 'Remote Artist',
          album: 'Remote Album',
        ),
      ),
    );
    final DiffItemDetailViewData data = DiffItemDetailViewData(
      path: 'Music/song.mp3',
      type: DiffType.delete,
      reason: null,
      side: DiffItemDetailSide.targetOnly,
      source: null,
      target: DiffEntryDetailViewData(
        entryId: 'remote-entry',
        displayName: 'song.mp3',
        size: 256,
        modifiedTime: DateTime.fromMillisecondsSinceEpoch(2),
        isDirectory: false,
      ),
      sourceIsRemote: false,
      targetIsRemote: true,
    );

    final DiffItemDetailViewData refreshed = await loader.refresh(data);

    expect(refreshed.target?.size, 512);
    expect(refreshed.target?.audioMetadata?.title, 'Remote Song');
    expect(refreshed.target?.audioMetadata?.artist, 'Remote Artist');
  });

  test('refresh keeps existing remote entry when remote detail stalls',
      () async {
    final LocalDetailLoader loader = LocalDetailLoader(
      _NoopGateway(),
      loadRemoteEntryDetail: (String entryId) async {
        await Future<void>.delayed(const Duration(seconds: 5));
        return DiffEntryDetailViewData(
          entryId: entryId,
          displayName: 'late.mp3',
          size: 999,
          modifiedTime: DateTime.fromMillisecondsSinceEpoch(9),
          isDirectory: false,
        );
      },
    );
    final DiffItemDetailViewData data = DiffItemDetailViewData(
      path: 'Music/song.mp3',
      type: DiffType.delete,
      reason: null,
      side: DiffItemDetailSide.targetOnly,
      source: null,
      target: DiffEntryDetailViewData(
        entryId: 'remote-entry',
        displayName: 'song.mp3',
        size: 256,
        modifiedTime: DateTime.fromMillisecondsSinceEpoch(2),
        isDirectory: false,
      ),
      sourceIsRemote: false,
      targetIsRemote: true,
    );

    final DateTime startedAt = DateTime.now();
    final DiffItemDetailViewData refreshed = await loader.refresh(data);
    final Duration elapsed = DateTime.now().difference(startedAt);

    expect(refreshed.target?.entryId, 'remote-entry');
    expect(refreshed.target?.size, 256);
    expect(elapsed, lessThan(const Duration(seconds: 4)));
  });
}

class _NoopGateway implements FileAccessGateway {
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
  Stream<List<int>> openRead(String entryId) async* {}

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

class _SlowStatGateway extends _NoopGateway {
  @override
  Future<FileAccessEntry> stat(String entryId) async {
    await Future<void>.delayed(const Duration(seconds: 5));
    return FileAccessEntry(
      entryId: entryId,
      name: 'late.mp3',
      isDirectory: false,
      size: 1024,
      modifiedTime: DateTime.fromMillisecondsSinceEpoch(3),
    );
  }
}
