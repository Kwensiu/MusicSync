import 'package:music_sync/core/errors/app_error_localizer.dart';
import 'package:music_sync/models/execution_result.dart';
import 'package:music_sync/models/transfer_progress.dart';

enum ExecutionStatus { idle, running, cancelled, completed, failed }

enum ExecutionMode { none, local, remote }

class ExecutionState {
  const ExecutionState({
    required this.status,
    required this.progress,
    required this.result,
    this.mode = ExecutionMode.none,
    required this.targetRoot,
    this.errorMessage,
  });

  final ExecutionStatus status;
  final TransferProgress progress;
  final ExecutionResult result;
  final ExecutionMode mode;
  final String? targetRoot;
  final String? errorMessage;

  static String localizeErrorMessage(String? value) {
    return AppErrorLocalizer.resolve(value);
  }

  factory ExecutionState.initial() {
    return const ExecutionState(
      status: ExecutionStatus.idle,
      result: ExecutionResult.empty(),
      targetRoot: null,
      progress: TransferProgress(
        stage: SyncStage.idle,
        processedFiles: 0,
        totalFiles: 0,
        processedBytes: 0,
        totalBytes: 0,
      ),
    );
  }
}
