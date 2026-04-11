import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_sync/core/errors/app_error_localizer.dart';
import 'package:music_sync/features/execution/state/execution_controller.dart';
import 'package:music_sync/features/execution/state/execution_state.dart';
import 'package:music_sync/models/execution_result.dart';
import 'package:music_sync/models/device_info.dart';
import 'package:music_sync/models/diff_item.dart';
import 'package:music_sync/models/file_entry.dart';
import 'package:music_sync/models/sync_plan.dart';
import 'package:music_sync/models/transfer_progress.dart';
import 'package:music_sync/services/file_access/file_access_entry.dart';
import 'package:music_sync/services/file_access/file_access_gateway.dart';
import 'package:music_sync/services/network/http/http_sync_client.dart';
import 'package:music_sync/services/sync/local_sync_executor.dart';
import 'package:music_sync/services/sync/remote_sync_executor.dart';
import 'package:music_sync/services/sync/sync_cancel_token.dart';

void main() {
  group('ExecutionController', () {
    test(
      'clearTransient keeps target root and clears transient result state',
      () {
        final bundle = _createController(
          localExecutor: _FakeLocalSyncExecutor(
            result: const ExecutionResult(
              copiedCount: 1,
              deletedCount: 0,
              failedCount: 0,
              totalBytes: 12,
              targetRoot: 'target',
            ),
          ),
          remoteExecutor: _FakeRemoteSyncExecutor(),
        );
        addTearDown(bundle.container.dispose);
        final controller = bundle.controller;

        controller.setTargetRoot('local-target');
        controller.state = ExecutionState(
          status: ExecutionStatus.completed,
          progress: controller.state.progress,
          result: const ExecutionResult(
            copiedCount: 2,
            deletedCount: 1,
            failedCount: 0,
            totalBytes: 128,
            targetRoot: 'local-target',
          ),
          mode: ExecutionMode.local,
          targetRoot: 'local-target',
        );

        controller.clearTransient();

        expect(controller.state.status, ExecutionStatus.idle);
        expect(controller.state.targetRoot, 'local-target');
        expect(controller.state.result.copiedCount, 0);
        expect(controller.state.mode, ExecutionMode.none);
      },
    );

    test(
      'completed execution with failures keeps localized error message',
      () async {
        final bundle = _createController(
          localExecutor: _FakeLocalSyncExecutor(
            result: const ExecutionResult(
              copiedCount: 0,
              deletedCount: 0,
              failedCount: 1,
              totalBytes: 0,
              targetRoot: 'local-target',
              lastError:
                  'SocketException: Remote device disconnected. Keep the target device in foreground and try again.',
            ),
          ),
          remoteExecutor: _FakeRemoteSyncExecutor(),
        );
        addTearDown(bundle.container.dispose);
        final controller = bundle.controller;

        await controller.execute(
          plan: SyncPlan.empty(),
          targetRoot: 'local-target',
        );

        expect(controller.state.status, ExecutionStatus.completed);
        expect(
          controller.state.errorMessage,
          AppErrorCode.remoteDeviceDisconnected,
        );
      },
    );

    test('cancel marks execution as cancelled', () async {
      final bundle = _createController(
        localExecutor: _BlockingLocalSyncExecutor(),
        remoteExecutor: _FakeRemoteSyncExecutor(),
      );
      addTearDown(bundle.container.dispose);
      final controller = bundle.controller;

      final Future<void> run = controller.execute(
        plan: SyncPlan.empty(),
        targetRoot: 'local-target',
      );
      controller.cancel();
      await run;

      expect(controller.state.status, ExecutionStatus.cancelled);
      expect(controller.state.progress.stage, SyncStage.cancelled);
      expect(controller.state.errorMessage, AppErrorCode.syncCancelled);
    });

    test('cancel keeps partial transfer result from progress', () async {
      final bundle = _createController(
        localExecutor: _ProgressEmittingBlockingLocalSyncExecutor(),
        remoteExecutor: _FakeRemoteSyncExecutor(),
      );
      addTearDown(bundle.container.dispose);
      final controller = bundle.controller;

      final Future<void> run = controller.execute(
        plan: SyncPlan.empty(),
        targetRoot: 'local-target',
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      controller.cancel();
      await run;

      expect(controller.state.status, ExecutionStatus.cancelled);
      expect(controller.state.result.copiedCount, 2);
      expect(controller.state.result.deletedCount, 1);
      expect(controller.state.result.failedCount, 1);
      expect(controller.state.result.totalBytes, 512);
    });

    test('execute seeds plan totals before first progress event', () async {
      final bundle = _createController(
        localExecutor: _NeverCompletingLocalSyncExecutor(),
        remoteExecutor: _FakeRemoteSyncExecutor(),
      );
      addTearDown(bundle.container.dispose);
      final controller = bundle.controller;

      final SyncPlan plan = SyncPlan(
        copyItems: <DiffItem>[
          DiffItem(
            type: DiffType.copy,
            relativePath: 'a.mp3',
            source: FileEntry(
              relativePath: 'a.mp3',
              entryId: 'source-a',
              sourceId: 'local-device',
              isDirectory: false,
              size: 512,
              modifiedTime: DateTime.fromMillisecondsSinceEpoch(0),
            ),
          ),
          DiffItem(
            type: DiffType.copy,
            relativePath: 'b.mp3',
            source: FileEntry(
              relativePath: 'b.mp3',
              entryId: 'source-b',
              sourceId: 'local-device',
              isDirectory: false,
              size: 512,
              modifiedTime: DateTime.fromMillisecondsSinceEpoch(0),
            ),
          ),
        ],
        deleteItems: <DiffItem>[
          const DiffItem(type: DiffType.delete, relativePath: 'c.mp3'),
        ],
        conflictItems: const [],
        summary: const SyncPlanSummary(
          copyCount: 2,
          deleteCount: 1,
          conflictCount: 0,
          copyBytes: 1024,
        ),
        deleteEnabled: true,
      );

      unawaited(controller.execute(plan: plan, targetRoot: 'local-target'));
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.status, ExecutionStatus.running);
      expect(controller.state.progress.totalFiles, 3);
      expect(controller.state.progress.totalBytes, 1024);

      controller.cancel();
    });

    test('cancelled local execution can run again', () async {
      final bundle = _createController(
        localExecutor: _BlockingLocalSyncExecutor(),
        remoteExecutor: _FakeRemoteSyncExecutor(),
      );
      addTearDown(bundle.container.dispose);
      final controller = bundle.controller;

      final Future<void> firstRun = controller.execute(
        plan: SyncPlan.empty(),
        targetRoot: 'local-target',
      );
      controller.cancel();
      await firstRun;

      expect(controller.state.status, ExecutionStatus.cancelled);

      await controller.execute(
        plan: SyncPlan.empty(),
        targetRoot: 'local-target',
      );

      expect(controller.state.status, ExecutionStatus.completed);
      expect(controller.state.mode, ExecutionMode.local);
      expect(controller.state.targetRoot, 'local-target');
    });

    test(
      'cancel marks remote execution as cancelled and allows retry',
      () async {
        final bundle = _createController(
          localExecutor: _FakeLocalSyncExecutor(
            result: const ExecutionResult.empty(),
          ),
          remoteExecutor: _BlockingRemoteSyncExecutor(),
        );
        addTearDown(bundle.container.dispose);
        final controller = bundle.controller;

        final Future<void> firstRun = controller.executeRemote(
          plan: SyncPlan.empty(),
          remoteRootId: 'remote-root',
        );
        controller.cancel();
        await firstRun;

        expect(controller.state.status, ExecutionStatus.cancelled);
        expect(controller.state.mode, ExecutionMode.remote);
        expect(controller.state.errorMessage, AppErrorCode.syncCancelled);

        await controller.executeRemote(
          plan: SyncPlan.empty(),
          remoteRootId: 'remote-root',
        );

        expect(controller.state.status, ExecutionStatus.completed);
        expect(controller.state.mode, ExecutionMode.remote);
        expect(controller.state.targetRoot, 'remote-root');
      },
    );

    test(
      'clearTransient cancels in-flight execution and preserves idle state',
      () async {
        final bundle = _createController(
          localExecutor: _BlockingLocalSyncExecutor(),
          remoteExecutor: _FakeRemoteSyncExecutor(),
        );
        addTearDown(bundle.container.dispose);
        final controller = bundle.controller;

        final Future<void> run = controller.execute(
          plan: SyncPlan.empty(),
          targetRoot: 'local-target',
        );
        controller.clearTransient();
        await run;

        expect(controller.state.status, ExecutionStatus.idle);
        expect(controller.state.mode, ExecutionMode.none);
        expect(controller.state.targetRoot, 'local-target');
      },
    );

    test('failActiveExecution marks running remote execution as failed', () {
      final bundle = _createController(
        localExecutor: _FakeLocalSyncExecutor(
          result: const ExecutionResult.empty(),
        ),
        remoteExecutor: _FakeRemoteSyncExecutor(),
      );
      addTearDown(bundle.container.dispose);
      final controller = bundle.controller;

      controller.state = const ExecutionState(
        status: ExecutionStatus.running,
        progress: TransferProgress(
          stage: SyncStage.copying,
          processedFiles: 1,
          totalFiles: 4,
          processedBytes: 128,
          totalBytes: 512,
          currentPath: 'Album/song.mp3',
        ),
        result: ExecutionResult.empty(),
        mode: ExecutionMode.remote,
        targetRoot: 'remote-root',
      );

      controller.failActiveExecution(
        'The selected directory is not accessible anymore.',
      );

      expect(controller.state.status, ExecutionStatus.failed);
      expect(controller.state.mode, ExecutionMode.remote);
      expect(controller.state.progress.stage, SyncStage.failed);
      expect(controller.state.errorMessage, AppErrorCode.directoryUnavailable);
    });

    test(
      'stale remote progress does not overwrite failed state after active execution is failed',
      () async {
        final _ProgressControlledRemoteSyncExecutor remoteExecutor =
            _ProgressControlledRemoteSyncExecutor();
        final bundle = _createController(
          localExecutor: _FakeLocalSyncExecutor(
            result: const ExecutionResult.empty(),
          ),
          remoteExecutor: remoteExecutor,
        );
        addTearDown(bundle.container.dispose);
        final controller = bundle.controller;

        final Future<void> run = controller.executeRemote(
          plan: SyncPlan.empty(),
          remoteRootId: 'remote-root',
        );

        await remoteExecutor.started.future;
        controller.failActiveExecution(
          'The selected directory is not accessible anymore.',
        );

        remoteExecutor.emitProgress(
          const TransferProgress(
            stage: SyncStage.copying,
            processedFiles: 1,
            totalFiles: 4,
            processedBytes: 64,
            totalBytes: 256,
            currentPath: 'Album/song.mp3',
          ),
        );
        remoteExecutor.complete();
        await run;

        expect(controller.state.status, ExecutionStatus.failed);
        expect(controller.state.mode, ExecutionMode.remote);
        expect(controller.state.progress.stage, SyncStage.failed);
        expect(
          controller.state.errorMessage,
          AppErrorCode.directoryUnavailable,
        );
      },
    );
  });
}

class _FakeLocalSyncExecutor extends LocalSyncExecutor {
  _FakeLocalSyncExecutor({required this.result});

  final ExecutionResult result;

  @override
  Future<ExecutionResult> execute({
    required SyncPlan plan,
    required String targetRoot,
    required ProgressCallback onProgress,
    SyncCancelToken? cancelToken,
  }) async {
    return result;
  }
}

({ProviderContainer container, ExecutionController controller})
_createController({
  required LocalSyncExecutor localExecutor,
  required RemoteSyncExecutor remoteExecutor,
}) {
  final ProviderContainer container = ProviderContainer(
    overrides: [
      localSyncExecutorProvider.overrideWithValue(localExecutor),
      remoteSyncExecutorProvider.overrideWithValue(remoteExecutor),
    ],
  );
  return (
    container: container,
    controller: container.read(executionControllerProvider.notifier),
  );
}

class _BlockingLocalSyncExecutor extends LocalSyncExecutor {
  @override
  Future<ExecutionResult> execute({
    required SyncPlan plan,
    required String targetRoot,
    required ProgressCallback onProgress,
    SyncCancelToken? cancelToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    cancelToken?.throwIfCancelled();
    return const ExecutionResult.empty();
  }
}

class _NeverCompletingLocalSyncExecutor extends LocalSyncExecutor {
  @override
  Future<ExecutionResult> execute({
    required SyncPlan plan,
    required String targetRoot,
    required ProgressCallback onProgress,
    SyncCancelToken? cancelToken,
  }) async {
    await Completer<void>().future;
    return const ExecutionResult.empty();
  }
}

class _ProgressEmittingBlockingLocalSyncExecutor extends LocalSyncExecutor {
  @override
  Future<ExecutionResult> execute({
    required SyncPlan plan,
    required String targetRoot,
    required ProgressCallback onProgress,
    SyncCancelToken? cancelToken,
  }) async {
    onProgress(
      const TransferProgress(
        stage: SyncStage.copying,
        processedFiles: 4,
        totalFiles: 6,
        processedBytes: 512,
        totalBytes: 2048,
        copiedCount: 2,
        deletedCount: 1,
        failedCount: 1,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 60));
    cancelToken?.throwIfCancelled();
    return ExecutionResult(
      copiedCount: 2,
      deletedCount: 1,
      failedCount: 1,
      totalBytes: 512,
      targetRoot: targetRoot,
    );
  }
}

class _FakeRemoteSyncExecutor extends RemoteSyncExecutor {
  _FakeRemoteSyncExecutor()
    : super(_NoopHttpSyncClient(), _NoopFileAccessGateway(), () => _peer);
}

class _BlockingRemoteSyncExecutor extends RemoteSyncExecutor {
  _BlockingRemoteSyncExecutor()
    : super(_NoopHttpSyncClient(), _NoopFileAccessGateway(), () => _peer);

  @override
  Future<ExecutionResult> execute({
    required SyncPlan plan,
    required String remoteRootId,
    required RemoteProgressCallback onProgress,
    SyncCancelToken? cancelToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    cancelToken?.throwIfCancelled();
    return ExecutionResult(
      copiedCount: 0,
      deletedCount: 0,
      failedCount: 0,
      totalBytes: 0,
      targetRoot: remoteRootId,
    );
  }
}

class _ProgressControlledRemoteSyncExecutor extends RemoteSyncExecutor {
  _ProgressControlledRemoteSyncExecutor()
    : super(_NoopHttpSyncClient(), _NoopFileAccessGateway(), () => _peer);

  final Completer<void> started = Completer<void>();
  final Completer<void> _finish = Completer<void>();
  RemoteProgressCallback? _progressCallback;

  void emitProgress(TransferProgress progress) {
    _progressCallback?.call(progress);
  }

  void complete() {
    if (!_finish.isCompleted) {
      _finish.complete();
    }
  }

  @override
  Future<ExecutionResult> execute({
    required SyncPlan plan,
    required String remoteRootId,
    required RemoteProgressCallback onProgress,
    SyncCancelToken? cancelToken,
  }) async {
    _progressCallback = onProgress;
    if (!started.isCompleted) {
      started.complete();
    }
    await _finish.future;
    return ExecutionResult(
      copiedCount: 0,
      deletedCount: 0,
      failedCount: 0,
      totalBytes: 0,
      targetRoot: remoteRootId,
    );
  }
}

const DeviceInfo _peer = DeviceInfo(
  deviceId: 'peer',
  deviceName: 'Peer',
  platform: 'android',
  address: '127.0.0.1',
  port: 44888,
);

class _NoopHttpSyncClient extends HttpSyncClient {}

class _NoopFileAccessGateway implements FileAccessGateway {
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
