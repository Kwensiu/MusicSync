import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_sync/core/constants/app_constants.dart';
import 'package:music_sync/features/connection/state/connection_controller.dart';
import 'package:music_sync/features/connection/state/connection_state.dart';
import 'package:music_sync/features/preview/state/conflict_controller.dart';
import 'package:music_sync/features/preview/state/preview_controller.dart';
import 'package:music_sync/features/preview/state/preview_state.dart';
import 'package:music_sync/models/device_info.dart';
import 'package:music_sync/models/diff_item.dart';
import 'package:music_sync/models/file_entry.dart';
import 'package:music_sync/models/sync_plan.dart';

void main() {
  test('classifies non-music conflicts as noTag', () {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        previewControllerProvider.overrideWith(_NoTagPreviewController.new),
        connectionControllerProvider.overrideWith(
          _ConnectedConnectionController.new,
        ),
      ],
    );
    addTearDown(container.dispose);

    final ConflictState state = container.read(conflictControllerProvider);

    expect(state.categories['notes.txt'], ConflictCategory.noTag);
  });

  test(
    'classifies matching audio fingerprints as autoMerge when peer supports it',
    () {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          previewControllerProvider.overrideWith(
            _AutoMergePreviewController.new,
          ),
          connectionControllerProvider.overrideWith(
            _ConnectedConnectionController.new,
          ),
        ],
      );
      addTearDown(container.dispose);

      final ConflictState state = container.read(conflictControllerProvider);

      expect(state.categories['album/song.mp3'], ConflictCategory.autoMerge);
    },
  );

  test('falls back to conflict when peer protocol version is too old', () {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        previewControllerProvider.overrideWith(_AutoMergePreviewController.new),
        connectionControllerProvider.overrideWith(
          _OldProtocolConnectionController.new,
        ),
      ],
    );
    addTearDown(container.dispose);

    final ConflictState state = container.read(conflictControllerProvider);

    expect(state.categories['album/song.mp3'], ConflictCategory.conflict);
  });

  test('falls back to conflict when fingerprint is missing on one side', () {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        previewControllerProvider.overrideWith(
          _MissingFingerprintPreviewController.new,
        ),
        connectionControllerProvider.overrideWith(
          _ConnectedConnectionController.new,
        ),
      ],
    );
    addTearDown(container.dispose);

    final ConflictState state = container.read(conflictControllerProvider);

    expect(state.categories['album/song.mp3'], ConflictCategory.conflict);
  });
}

class _ConnectedConnectionController extends ConnectionController {
  @override
  ConnectionState build() {
    return const ConnectionState(
      status: ConnectionStatus.connected,
      peer: DeviceInfo(
        deviceId: 'peer',
        deviceName: 'Peer',
        platform: 'test',
        address: '1.2.3.4',
        port: 44888,
        protocolVersion: AppConstants.fingerprintSupportedVersion,
      ),
    );
  }
}

class _OldProtocolConnectionController extends ConnectionController {
  @override
  ConnectionState build() {
    return const ConnectionState(
      status: ConnectionStatus.connected,
      peer: DeviceInfo(
        deviceId: 'peer',
        deviceName: 'Peer',
        platform: 'test',
        address: '1.2.3.4',
        port: 44888,
        protocolVersion: 1,
      ),
    );
  }
}

class _NoTagPreviewController extends PreviewController {
  @override
  PreviewState build() {
    return PreviewState(
      status: PreviewStatus.loaded,
      plan: SyncPlan(
        copyItems: const <DiffItem>[],
        deleteItems: const <DiffItem>[],
        conflictItems: <DiffItem>[
          DiffItem(
            type: DiffType.conflict,
            relativePath: 'notes.txt',
            source: _entry(
              relativePath: 'notes.txt',
              sourceId: 'local',
              entryId: 'local-notes',
              size: 12,
              modifiedTime: DateTime.fromMillisecondsSinceEpoch(0),
            ),
            target: _entry(
              relativePath: 'notes.txt',
              sourceId: 'remote',
              entryId: 'remote-notes',
              size: 18,
              modifiedTime: DateTime.fromMillisecondsSinceEpoch(1000),
            ),
            reason: 'metadata_mismatch',
          ),
        ],
        summary: const SyncPlanSummary(
          copyCount: 0,
          deleteCount: 0,
          conflictCount: 1,
          copyBytes: 0,
        ),
        deleteEnabled: true,
      ),
    );
  }
}

class _AutoMergePreviewController extends PreviewController {
  @override
  PreviewState build() {
    return PreviewState(
      status: PreviewStatus.loaded,
      plan: SyncPlan(
        copyItems: const <DiffItem>[],
        deleteItems: const <DiffItem>[],
        conflictItems: <DiffItem>[
          DiffItem(
            type: DiffType.conflict,
            relativePath: 'album/song.mp3',
            source: _entry(
              relativePath: 'album/song.mp3',
              sourceId: 'local',
              entryId: 'local-song',
              size: 120,
              modifiedTime: DateTime.fromMillisecondsSinceEpoch(0),
              fingerprint: 'same-audio',
            ),
            target: _entry(
              relativePath: 'album/song.mp3',
              sourceId: 'remote',
              entryId: 'remote-song',
              size: 128,
              modifiedTime: DateTime.fromMillisecondsSinceEpoch(1000),
              fingerprint: 'same-audio',
            ),
            reason: 'metadata_mismatch',
          ),
        ],
        summary: const SyncPlanSummary(
          copyCount: 0,
          deleteCount: 0,
          conflictCount: 1,
          copyBytes: 0,
        ),
        deleteEnabled: true,
      ),
    );
  }
}

class _MissingFingerprintPreviewController extends PreviewController {
  @override
  PreviewState build() {
    return PreviewState(
      status: PreviewStatus.loaded,
      plan: SyncPlan(
        copyItems: const <DiffItem>[],
        deleteItems: const <DiffItem>[],
        conflictItems: <DiffItem>[
          DiffItem(
            type: DiffType.conflict,
            relativePath: 'album/song.mp3',
            source: _entry(
              relativePath: 'album/song.mp3',
              sourceId: 'local',
              entryId: 'local-song',
              size: 120,
              modifiedTime: DateTime.fromMillisecondsSinceEpoch(0),
              fingerprint: 'same-audio',
            ),
            target: _entry(
              relativePath: 'album/song.mp3',
              sourceId: 'remote',
              entryId: 'remote-song',
              size: 128,
              modifiedTime: DateTime.fromMillisecondsSinceEpoch(1000),
              // fingerprint intentionally null — simulates old remote
            ),
            reason: 'metadata_mismatch',
          ),
        ],
        summary: const SyncPlanSummary(
          copyCount: 0,
          deleteCount: 0,
          conflictCount: 1,
          copyBytes: 0,
        ),
        deleteEnabled: true,
      ),
    );
  }
}

FileEntry _entry({
  required String relativePath,
  required String sourceId,
  required String entryId,
  required int size,
  required DateTime modifiedTime,
  String? fingerprint,
}) {
  return FileEntry(
    relativePath: relativePath,
    entryId: entryId,
    sourceId: sourceId,
    isDirectory: false,
    size: size,
    modifiedTime: modifiedTime,
    fingerprint: fingerprint,
  );
}
