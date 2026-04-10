import 'dart:developer' as developer;

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
    const String protocolLabel = 'stream-v1';
    // TODO(transfer-telemetry): surface lightweight throughput metrics from
    // here so we can compare platforms and verify future transport changes.
    developer.log(
      'Remote sync protocol: $protocolLabel, target=$remoteRootId, peer=${peer.address}:${peer.port}',
      name: 'RemoteSyncExecutor',
    );

    try {
      for (final DiffItem item in plan.copyItems) {
        cancelToken?.throwIfCancelled();
        final String? sourceEntryId = item.source?.entryId;
        if (sourceEntryId == null) {
          failedCount++;
          continue;
        }

        developer.log(
          '[$protocolLabel] copy start: ${item.relativePath}',
          name: 'RemoteSyncExecutor',
        );
        try {
          cancelToken?.throwIfCancelled();
          // TODO(transfer-cancel): actively tear down the in-flight HTTP upload
          // when cancellation happens, instead of only stopping future reads.
          final Stream<List<int>> source = _fileAccessGateway
              .openRead(sourceEntryId)
              .map((List<int> chunk) {
                cancelToken?.throwIfCancelled();
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
                return chunk;
              });
          await _httpClient.copyFileStream(
            address: peer.address,
            port: peer.port,
            remoteRootId: remoteRootId,
            relativePath: item.relativePath,
            expectedBytes: item.source?.size ?? 0,
            source: source,
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
              currentPath: item.relativePath,
            ),
          );
          developer.log(
            '[$protocolLabel] copy done: ${item.relativePath}',
            name: 'RemoteSyncExecutor',
          );
        } catch (error) {
          if (cancelToken?.isCancelled == true) {
            rethrow;
          }
          failedCount++;
          processedFiles++;
          lastError = error.toString();
          developer.log(
            '[$protocolLabel] copy failed: ${item.relativePath} (${error.toString()})',
            name: 'RemoteSyncExecutor',
          );
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
              currentPath: item.relativePath,
            ),
          );
        } catch (error) {
          failedCount++;
          processedFiles++;
          lastError = error.toString();
        }
      }

      // TODO(transfer-concurrency): evaluate a small-file concurrency window
      // here once Android write performance and cancellation semantics are
      // stable, instead of widening scope inside the HTTP client.

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
}
