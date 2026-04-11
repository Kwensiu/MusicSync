import 'dart:io';

import 'package:music_sync/core/constants/app_constants.dart';
import 'package:music_sync/core/errors/sync_cancelled_exception.dart';
import 'package:music_sync/models/diff_item.dart';
import 'package:music_sync/models/execution_result.dart';
import 'package:music_sync/models/sync_plan.dart';
import 'package:music_sync/models/transfer_progress.dart';
import 'package:music_sync/services/sync/sync_cancel_token.dart';
import 'package:path/path.dart' as p;

typedef ProgressCallback = void Function(TransferProgress progress);

class LocalSyncExecutor {
  Future<ExecutionResult> execute({
    required SyncPlan plan,
    required String targetRoot,
    required ProgressCallback onProgress,
    SyncCancelToken? cancelToken,
  }) async {
    int processedFiles = 0;
    int processedBytes = 0;
    int copiedCount = 0;
    int deletedCount = 0;
    int failedCount = 0;
    String? lastError;

    final int totalFiles = plan.copyItems.length + plan.deleteItems.length;
    final int totalBytes = plan.summary.copyBytes;

    for (final DiffItem item in plan.copyItems) {
      cancelToken?.throwIfCancelled();
      final String? sourcePath = item.source?.entryId;
      if (sourcePath == null) {
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

      try {
        final String destinationPath = p.join(targetRoot, item.relativePath);
        final File sourceFile = File(sourcePath);
        final File destinationFile = File(destinationPath);
        await destinationFile.parent.create(recursive: true);
        final File tempFile = File(
          '$destinationPath${AppConstants.tempFileSuffix}',
        );
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
        IOSink? sink;
        try {
          sink = tempFile.openWrite(mode: FileMode.writeOnly);
          await for (final List<int> chunk in sourceFile.openRead()) {
            cancelToken?.throwIfCancelled();
            sink.add(chunk);
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
          await sink.flush();
          await sink.close();
          sink = null;
          if (await destinationFile.exists()) {
            await destinationFile.delete();
          }
          await tempFile.rename(destinationPath);
        } on SyncCancelledException {
          await sink?.close();
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
          rethrow;
        } catch (_) {
          await sink?.close();
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
          rethrow;
        }

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
        if (error is SyncCancelledException) {
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
      }
    }

    for (final DiffItem item in plan.deleteItems) {
      cancelToken?.throwIfCancelled();
      final String destinationPath = p.join(targetRoot, item.relativePath);

      try {
        final FileSystemEntityType type = FileSystemEntity.typeSync(
          destinationPath,
        );
        switch (type) {
          case FileSystemEntityType.directory:
            await Directory(destinationPath).delete(recursive: true);
          case FileSystemEntityType.file:
            await File(destinationPath).delete();
          case FileSystemEntityType.link:
            await Link(destinationPath).delete();
          case FileSystemEntityType.notFound:
            break;
          default:
            break;
        }

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
        if (error is SyncCancelledException) {
          rethrow;
        }
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
      targetRoot: targetRoot,
      lastError: lastError,
    );
  }
}
