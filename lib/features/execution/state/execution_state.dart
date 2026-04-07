import 'package:music_sync/models/execution_result.dart';
import 'package:music_sync/models/transfer_progress.dart';

enum ExecutionStatus {
  idle,
  running,
  cancelled,
  completed,
  failed,
}

enum ExecutionMode {
  none,
  local,
  remote,
}

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
    if (value == null || value.isEmpty) {
      return '';
    }
    if (value.contains('errno = 10054') ||
        value.contains('远程主机强迫关闭了一个现有的连接') ||
        value.contains('Remote device disconnected') ||
        value.contains('Peer disconnected')) {
      return '远端设备已断开连接。请保持目标设备在前台后重试。';
    }
    if (value.contains('Not connected to any peer')) {
      return '当前没有已连接的远端设备。';
    }
    if (value.contains('SyncCancelledException')) {
      return '同步已手动停止。未完成的临时文件已尽量清理。';
    }
    if (value.contains('Unable to access the selected directory')) {
      return '当前目录已无法访问，请重新选择目录后再生成预览。';
    }
    if (value.contains('Windows write session create failed')) {
      return 'Unable to write to the Windows target directory. Check permissions and file locks, then try again.';
    }
    if (value.contains('Windows rename failed')) {
      return 'Unable to finalize one or more files on the Windows target directory. Check permissions and file locks, then try again.';
    }
    if (value.contains('Windows delete failed')) {
      return 'Unable to delete one or more items on the Windows target directory. Check permissions and file locks, then try again.';
    }
    if (value.contains('Windows file read failed')) {
      return 'Unable to read one or more source files on Windows. Check permissions and file locks, then try again.';
    }
    if (value.contains('Windows directory create failed')) {
      return 'Unable to create one or more target folders on Windows. Check permissions and path validity, then try again.';
    }
    if (value.contains('SocketException: ')) {
      return value.replaceFirst('SocketException: ', '');
    }
    if (value.contains('FileAccessException: ')) {
      return value.replaceFirst('FileAccessException: ', '');
    }
    return value;
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
