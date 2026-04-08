import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_sync/features/connection/state/connection_controller.dart';
import 'package:music_sync/features/execution/state/execution_state.dart';
import 'package:music_sync/core/errors/sync_cancelled_exception.dart';
import 'package:music_sync/models/execution_result.dart';
import 'package:music_sync/models/sync_plan.dart';
import 'package:music_sync/models/transfer_progress.dart';
import 'package:music_sync/services/file_access/file_access_provider.dart';
import 'package:music_sync/services/sync/local_sync_executor.dart';
import 'package:music_sync/services/sync/sync_cancel_token.dart';
import 'package:music_sync/services/sync/remote_sync_executor.dart';

final Provider<LocalSyncExecutor> localSyncExecutorProvider =
    Provider<LocalSyncExecutor>((Ref ref) => LocalSyncExecutor());
final Provider<RemoteSyncExecutor> remoteSyncExecutorProvider =
    Provider<RemoteSyncExecutor>(
  (Ref ref) => RemoteSyncExecutor(
    ref.watch(connectionServiceProvider),
    ref.watch(fileAccessGatewayProvider),
  ),
);

class ExecutionController extends StateNotifier<ExecutionState> {
  ExecutionController(this._executor, this._remoteExecutor)
      : super(ExecutionState.initial());

  final LocalSyncExecutor _executor;
  final RemoteSyncExecutor _remoteExecutor;
  SyncCancelToken? _cancelToken;

  void _cancelActiveExecution() {
    _cancelToken?.cancel();
    _cancelToken = null;
  }

  void clear() {
    _cancelActiveExecution();
    state = ExecutionState.initial();
  }

  void clearTransient() {
    _cancelActiveExecution();
    state = ExecutionState(
      status: ExecutionStatus.idle,
      progress: const TransferProgress(
        stage: SyncStage.idle,
        processedFiles: 0,
        totalFiles: 0,
        processedBytes: 0,
        totalBytes: 0,
      ),
      result: const ExecutionResult.empty(),
      mode: ExecutionMode.none,
      targetRoot: state.targetRoot,
    );
  }

  void setTargetRoot(String? value) {
    _cancelActiveExecution();
    state = ExecutionState(
      status: ExecutionStatus.idle,
      progress: const TransferProgress(
        stage: SyncStage.idle,
        processedFiles: 0,
        totalFiles: 0,
        processedBytes: 0,
        totalBytes: 0,
      ),
      result: const ExecutionResult.empty(),
      mode: ExecutionMode.none,
      targetRoot: value,
    );
  }

  Future<void> execute({
    required SyncPlan plan,
    required String targetRoot,
  }) async {
    final SyncCancelToken cancelToken = SyncCancelToken();
    _cancelToken = cancelToken;
    state = ExecutionState(
      status: ExecutionStatus.running,
      progress: const TransferProgress(
        stage: SyncStage.copying,
        processedFiles: 0,
        totalFiles: 0,
        processedBytes: 0,
        totalBytes: 0,
      ),
      result: state.result,
      mode: ExecutionMode.local,
      targetRoot: targetRoot,
    );

    try {
      final result = await _executor.execute(
        plan: plan,
        targetRoot: targetRoot,
        cancelToken: cancelToken,
        onProgress: (TransferProgress progress) {
          state = ExecutionState(
            status: ExecutionStatus.running,
            progress: progress,
            result: state.result,
            mode: ExecutionMode.local,
            targetRoot: targetRoot,
          );
        },
      );
      if (!identical(_cancelToken, cancelToken)) {
        return;
      }
      _cancelToken = null;

      state = ExecutionState(
        status: ExecutionStatus.completed,
        progress: TransferProgress(
          stage: SyncStage.completed,
          processedFiles: plan.copyItems.length + plan.deleteItems.length,
          totalFiles: plan.copyItems.length + plan.deleteItems.length,
          processedBytes: result.totalBytes,
          totalBytes: plan.summary.copyBytes,
        ),
        result: result,
        mode: ExecutionMode.local,
        targetRoot: targetRoot,
        errorMessage: result.failedCount > 0
            ? ExecutionState.localizeErrorMessage(result.lastError)
            : null,
      );
    } catch (error) {
      if (!identical(_cancelToken, cancelToken)) {
        return;
      }
      _cancelToken = null;
      if (error is SyncCancelledException) {
        state = ExecutionState(
          status: ExecutionStatus.cancelled,
          progress: TransferProgress(
            stage: SyncStage.cancelled,
            processedFiles: state.progress.processedFiles,
            totalFiles: state.progress.totalFiles,
            processedBytes: state.progress.processedBytes,
            totalBytes: state.progress.totalBytes,
            currentPath: state.progress.currentPath,
          ),
          result: state.result,
          mode: ExecutionMode.local,
          targetRoot: targetRoot,
          errorMessage: ExecutionState.localizeErrorMessage(error.toString()),
        );
        return;
      }
      state = ExecutionState(
        status: ExecutionStatus.failed,
        progress: state.progress,
        result: state.result,
        mode: ExecutionMode.local,
        targetRoot: targetRoot,
        errorMessage: ExecutionState.localizeErrorMessage(error.toString()),
      );
    }
  }

  Future<void> executeRemote({
    required SyncPlan plan,
    required String remoteRootId,
  }) async {
    final SyncCancelToken cancelToken = SyncCancelToken();
    _cancelToken = cancelToken;
    state = ExecutionState(
      status: ExecutionStatus.running,
      progress: const TransferProgress(
        stage: SyncStage.copying,
        processedFiles: 0,
        totalFiles: 0,
        processedBytes: 0,
        totalBytes: 0,
      ),
      result: state.result,
      mode: ExecutionMode.remote,
      targetRoot: remoteRootId,
    );

    try {
      final result = await _remoteExecutor.execute(
        plan: plan,
        remoteRootId: remoteRootId,
        cancelToken: cancelToken,
        onProgress: (TransferProgress progress) {
          state = ExecutionState(
            status: ExecutionStatus.running,
            progress: progress,
            result: state.result,
            mode: ExecutionMode.remote,
            targetRoot: remoteRootId,
          );
        },
      );
      if (!identical(_cancelToken, cancelToken)) {
        return;
      }
      _cancelToken = null;

      state = ExecutionState(
        status: ExecutionStatus.completed,
        progress: TransferProgress(
          stage: SyncStage.completed,
          processedFiles: plan.copyItems.length + plan.deleteItems.length,
          totalFiles: plan.copyItems.length + plan.deleteItems.length,
          processedBytes: result.totalBytes,
          totalBytes: plan.summary.copyBytes,
        ),
        result: result,
        mode: ExecutionMode.remote,
        targetRoot: remoteRootId,
        errorMessage: result.failedCount > 0
            ? ExecutionState.localizeErrorMessage(result.lastError)
            : null,
      );
    } catch (error) {
      if (!identical(_cancelToken, cancelToken)) {
        return;
      }
      _cancelToken = null;
      if (error is SyncCancelledException) {
        state = ExecutionState(
          status: ExecutionStatus.cancelled,
          progress: TransferProgress(
            stage: SyncStage.cancelled,
            processedFiles: state.progress.processedFiles,
            totalFiles: state.progress.totalFiles,
            processedBytes: state.progress.processedBytes,
            totalBytes: state.progress.totalBytes,
            currentPath: state.progress.currentPath,
          ),
          result: state.result,
          mode: ExecutionMode.remote,
          targetRoot: remoteRootId,
          errorMessage: ExecutionState.localizeErrorMessage(error.toString()),
        );
        return;
      }
      state = ExecutionState(
        status: ExecutionStatus.failed,
        progress: state.progress,
        result: state.result,
        mode: ExecutionMode.remote,
        targetRoot: remoteRootId,
        errorMessage: ExecutionState.localizeErrorMessage(error.toString()),
      );
    }
  }

  void cancel() {
    _cancelToken?.cancel();
  }
}

final StateNotifierProvider<ExecutionController, ExecutionState>
    executionControllerProvider =
    StateNotifierProvider<ExecutionController, ExecutionState>(
  (Ref ref) => ExecutionController(
    ref.watch(localSyncExecutorProvider),
    ref.watch(remoteSyncExecutorProvider),
  ),
);
