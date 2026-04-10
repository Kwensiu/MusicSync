import 'dart:math';

import 'package:music_sync/models/diff_item.dart';
import 'package:music_sync/models/execution_result.dart';
import 'package:music_sync/models/sync_plan.dart';
import 'package:music_sync/models/transfer_progress.dart';
import 'package:music_sync/services/file_access/file_access_gateway.dart';
import 'package:music_sync/services/network/connection_service.dart';
import 'package:music_sync/services/sync/sync_cancel_token.dart';

typedef RemoteProgressCallback = void Function(TransferProgress progress);

class RemoteSyncExecutor {
  RemoteSyncExecutor(this._connectionService, this._fileAccessGateway);

  final ConnectionService _connectionService;
  final FileAccessGateway _fileAccessGateway;
  final Random _random = Random();

  Future<ExecutionResult> execute({
    required SyncPlan plan,
    required String remoteRootId,
    required RemoteProgressCallback onProgress,
    SyncCancelToken? cancelToken,
  }) async {
    await _connectionService.notifySyncSessionState(active: true);
    int processedFiles = 0;
    int processedBytes = 0;
    int copiedCount = 0;
    int deletedCount = 0;
    int failedCount = 0;
    String? lastError;
    final int totalFiles = plan.copyItems.length + plan.deleteItems.length;
    final int totalBytes = plan.summary.copyBytes;

    try {
      for (final DiffItem item in plan.copyItems) {
        cancelToken?.throwIfCancelled();
        final String? sourceEntryId = item.source?.entryId;
        if (sourceEntryId == null) {
          failedCount++;
          continue;
        }

        final String transferId = _nextTransferId();
        try {
          cancelToken?.throwIfCancelled();
          await _connectionService.beginRemoteCopy(
            remoteRootId: remoteRootId,
            relativePath: item.relativePath,
            transferId: transferId,
          );

          await for (final List<int> chunk in _fileAccessGateway.openRead(
            sourceEntryId,
          )) {
            cancelToken?.throwIfCancelled();
            await _connectionService.writeRemoteChunk(
              transferId: transferId,
              chunk: chunk,
            );
            processedBytes += chunk.length;
            onProgress(
              TransferProgress(
                stage: SyncStage.copying,
                processedFiles: processedFiles,
                totalFiles: totalFiles,
                processedBytes: processedBytes,
                totalBytes: totalBytes,
                currentPath: item.relativePath,
              ),
            );
          }

          await _connectionService.finishRemoteCopy(transferId: transferId);
          copiedCount++;
          processedFiles++;
          onProgress(
            TransferProgress(
              stage: SyncStage.copying,
              processedFiles: processedFiles,
              totalFiles: totalFiles,
              processedBytes: processedBytes,
              totalBytes: totalBytes,
              currentPath: item.relativePath,
            ),
          );
        } catch (error) {
          if (cancelToken?.isCancelled == true) {
            try {
              await _connectionService.abortRemoteCopy(transferId: transferId);
            } catch (_) {
              // Ignore cleanup failures while cancelling.
            }
            rethrow;
          }
          failedCount++;
          processedFiles++;
          lastError = error.toString();
          try {
            await _connectionService.abortRemoteCopy(transferId: transferId);
          } catch (_) {
            // Ignore cleanup failures; preserve original transfer error.
          }
        }
      }

      for (final DiffItem item in plan.deleteItems) {
        cancelToken?.throwIfCancelled();
        try {
          await _connectionService.deleteRemoteEntry(
            remoteRootId: remoteRootId,
            relativePath: item.relativePath,
          );
          deletedCount++;
          processedFiles++;
          onProgress(
            TransferProgress(
              stage: SyncStage.deleting,
              processedFiles: processedFiles,
              totalFiles: totalFiles,
              processedBytes: processedBytes,
              totalBytes: totalBytes,
              currentPath: item.relativePath,
            ),
          );
        } catch (error) {
          failedCount++;
          processedFiles++;
          lastError = error.toString();
        }
      }

      onProgress(
        TransferProgress(
          stage: SyncStage.completed,
          processedFiles: processedFiles,
          totalFiles: totalFiles,
          processedBytes: processedBytes,
          totalBytes: totalBytes,
        ),
      );

      return ExecutionResult(
        copiedCount: copiedCount,
        deletedCount: deletedCount,
        failedCount: failedCount,
        totalBytes: processedBytes,
        targetRoot: remoteRootId,
        lastError: lastError,
      );
    } finally {
      try {
        await _connectionService.notifySyncSessionState(active: false);
      } catch (_) {
        // Best effort only.
      }
    }
  }

  String _nextTransferId() {
    return '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 32)}';
  }
}
