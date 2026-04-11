import 'dart:math';

import 'package:music_sync/models/device_info.dart';
import 'package:music_sync/models/diff_item.dart';
import 'package:music_sync/models/execution_result.dart';
import 'package:music_sync/models/sync_plan.dart';
import 'package:music_sync/models/transfer_progress.dart';
import 'package:music_sync/services/file_access/file_access_gateway.dart';
import 'package:music_sync/services/network/http/http_sync_client.dart';
import 'package:music_sync/services/sync/sync_cancel_token.dart';

typedef RemoteProgressCallback = void Function(TransferProgress progress);

class RemoteSyncExecutor {
  RemoteSyncExecutor(this._httpClient, this._fileAccessGateway, this._getPeer);

  final HttpSyncClient _httpClient;
  final FileAccessGateway _fileAccessGateway;
  final DeviceInfo? Function() _getPeer;
  final Random _random = Random();

  Future<ExecutionResult> execute({
    required SyncPlan plan,
    required String remoteRootId,
    required RemoteProgressCallback onProgress,
    SyncCancelToken? cancelToken,
  }) async {
    final DeviceInfo peer =
        _getPeer() ?? (throw const FormatException('Remote peer unavailable.'));
    await _httpClient.notifySyncSessionState(
      address: peer.address,
      port: peer.port,
      active: true,
      httpEncryptionEnabled: peer.httpEncryptionEnabled,
    );
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
          processedFiles++;
          onProgress(
            TransferProgress(
              stage: SyncStage.copying,
              processedFiles: processedFiles,
              totalFiles: totalFiles,
              processedBytes: processedBytes,
              totalBytes: totalBytes,
              copiedCount: copiedCount,
              deletedCount: deletedCount,
              failedCount: failedCount,
              currentPath: item.relativePath,
            ),
          );
          continue;
        }

        final String transferId = _nextTransferId();
        try {
          cancelToken?.throwIfCancelled();
          await _httpClient.beginCopy(
            address: peer.address,
            port: peer.port,
            remoteRootId: remoteRootId,
            relativePath: item.relativePath,
            transferId: transferId,
            httpEncryptionEnabled: peer.httpEncryptionEnabled,
          );

          await for (final List<int> chunk in _fileAccessGateway.openRead(
            sourceEntryId,
          )) {
            cancelToken?.throwIfCancelled();
            await _httpClient.writeChunk(
              address: peer.address,
              port: peer.port,
              transferId: transferId,
              chunk: chunk,
              httpEncryptionEnabled: peer.httpEncryptionEnabled,
            );
            processedBytes += chunk.length;
            onProgress(
              TransferProgress(
                stage: SyncStage.copying,
                processedFiles: processedFiles,
                totalFiles: totalFiles,
                processedBytes: processedBytes,
                totalBytes: totalBytes,
                copiedCount: copiedCount,
                deletedCount: deletedCount,
                failedCount: failedCount,
                currentPath: item.relativePath,
              ),
            );
          }

          await _httpClient.finishCopy(
            address: peer.address,
            port: peer.port,
            transferId: transferId,
            httpEncryptionEnabled: peer.httpEncryptionEnabled,
          );
          copiedCount++;
          processedFiles++;
          onProgress(
            TransferProgress(
              stage: SyncStage.copying,
              processedFiles: processedFiles,
              totalFiles: totalFiles,
              processedBytes: processedBytes,
              totalBytes: totalBytes,
              copiedCount: copiedCount,
              deletedCount: deletedCount,
              failedCount: failedCount,
              currentPath: item.relativePath,
            ),
          );
        } catch (error) {
          if (cancelToken?.isCancelled == true) {
            try {
              await _httpClient.abortCopy(
                address: peer.address,
                port: peer.port,
                transferId: transferId,
                httpEncryptionEnabled: peer.httpEncryptionEnabled,
              );
            } catch (_) {
              // Ignore cleanup failures while cancelling.
            }
            rethrow;
          }
          failedCount++;
          processedFiles++;
          lastError = error.toString();
          onProgress(
            TransferProgress(
              stage: SyncStage.copying,
              processedFiles: processedFiles,
              totalFiles: totalFiles,
              processedBytes: processedBytes,
              totalBytes: totalBytes,
              copiedCount: copiedCount,
              deletedCount: deletedCount,
              failedCount: failedCount,
              currentPath: item.relativePath,
            ),
          );
          try {
            await _httpClient.abortCopy(
              address: peer.address,
              port: peer.port,
              transferId: transferId,
              httpEncryptionEnabled: peer.httpEncryptionEnabled,
            );
          } catch (_) {
            // Ignore cleanup failures; preserve original transfer error.
          }
        }
      }

      for (final DiffItem item in plan.deleteItems) {
        cancelToken?.throwIfCancelled();
        try {
          await _httpClient.deleteEntry(
            address: peer.address,
            port: peer.port,
            remoteRootId: remoteRootId,
            relativePath: item.relativePath,
            httpEncryptionEnabled: peer.httpEncryptionEnabled,
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
              copiedCount: copiedCount,
              deletedCount: deletedCount,
              failedCount: failedCount,
              currentPath: item.relativePath,
            ),
          );
        } catch (error) {
          failedCount++;
          processedFiles++;
          lastError = error.toString();
          onProgress(
            TransferProgress(
              stage: SyncStage.deleting,
              processedFiles: processedFiles,
              totalFiles: totalFiles,
              processedBytes: processedBytes,
              totalBytes: totalBytes,
              copiedCount: copiedCount,
              deletedCount: deletedCount,
              failedCount: failedCount,
              currentPath: item.relativePath,
            ),
          );
        }
      }

      onProgress(
        TransferProgress(
          stage: SyncStage.completed,
          processedFiles: processedFiles,
          totalFiles: totalFiles,
          processedBytes: processedBytes,
          totalBytes: totalBytes,
          copiedCount: copiedCount,
          deletedCount: deletedCount,
          failedCount: failedCount,
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
        await _httpClient.notifySyncSessionState(
          address: peer.address,
          port: peer.port,
          active: false,
          httpEncryptionEnabled: peer.httpEncryptionEnabled,
        );
      } catch (_) {
        // Best effort only.
      }
    }
  }

  String _nextTransferId() {
    return '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 32)}';
  }
}
