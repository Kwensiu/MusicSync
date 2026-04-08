import 'package:flutter_test/flutter_test.dart';
import 'package:music_sync/core/errors/app_error_localizer.dart';
import 'package:music_sync/features/execution/state/execution_controller.dart';
import 'package:music_sync/features/execution/state/execution_state.dart';
import 'package:music_sync/models/execution_result.dart';
import 'package:music_sync/models/sync_plan.dart';
import 'package:music_sync/models/transfer_progress.dart';
import 'package:music_sync/services/file_access/file_access_entry.dart';
import 'package:music_sync/services/file_access/file_access_gateway.dart';
import 'package:music_sync/services/network/connection_service.dart';
import 'package:music_sync/services/sync/local_sync_executor.dart';
import 'package:music_sync/services/sync/remote_sync_executor.dart';
import 'package:music_sync/services/sync/sync_cancel_token.dart';

void main() {
  group('ExecutionController', () {
    test('clearTransient keeps target root and clears transient result state',
        () {
      final controller = ExecutionController(
        _FakeLocalSyncExecutor(
          result: const ExecutionResult(
            copiedCount: 1,
            deletedCount: 0,
            failedCount: 0,
            totalBytes: 12,
            targetRoot: 'target',
          ),
        ),
        _FakeRemoteSyncExecutor(),
      );

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
    });

    test('completed execution with failures keeps localized error message',
        () async {
      final controller = ExecutionController(
        _FakeLocalSyncExecutor(
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
        _FakeRemoteSyncExecutor(),
      );

      await controller.execute(
        plan: SyncPlan.empty(),
        targetRoot: 'local-target',
      );

      expect(controller.state.status, ExecutionStatus.completed);
      expect(
        controller.state.errorMessage,
        AppErrorCode.remoteDeviceDisconnected,
      );
    });

    test('cancel marks execution as cancelled', () async {
      final controller = ExecutionController(
        _BlockingLocalSyncExecutor(),
        _FakeRemoteSyncExecutor(),
      );

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

    test('clearTransient cancels in-flight execution and preserves idle state',
        () async {
      final controller = ExecutionController(
        _BlockingLocalSyncExecutor(),
        _FakeRemoteSyncExecutor(),
      );

      final Future<void> run = controller.execute(
        plan: SyncPlan.empty(),
        targetRoot: 'local-target',
      );
      controller.clearTransient();
      await run;

      expect(controller.state.status, ExecutionStatus.idle);
      expect(controller.state.mode, ExecutionMode.none);
      expect(controller.state.targetRoot, 'local-target');
    });
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

class _FakeRemoteSyncExecutor extends RemoteSyncExecutor {
  _FakeRemoteSyncExecutor()
      : super(_NoopConnectionService(), _NoopFileAccessGateway());
}

class _NoopConnectionService extends ConnectionService {}

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
