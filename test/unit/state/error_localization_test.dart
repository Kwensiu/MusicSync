import 'package:flutter_test/flutter_test.dart';
import 'package:music_sync/core/errors/app_error_localizer.dart';
import 'package:music_sync/features/connection/state/connection_state.dart';
import 'package:music_sync/features/directory/state/directory_state.dart';
import 'package:music_sync/features/execution/state/execution_state.dart';
import 'package:music_sync/features/preview/state/preview_state.dart';

void main() {
  test('error localization normalizes common user-facing errors', () {
    expect(
      ConnectionState.localizeErrorMessage(
          'SocketException: Connection refused'),
      AppErrorCode.connectionRefused,
    );
    expect(
      DirectoryState.localizeErrorMessage('PathAccessException: 拒绝访问'),
      AppErrorCode.directoryAccessDenied,
    );
    expect(
      PreviewState.localizeErrorMessage(
        'FileAccessException: Unable to access the selected directory. Please choose another folder.',
      ),
      AppErrorCode.directoryUnavailable,
    );
    expect(
      ExecutionState.localizeErrorMessage(
        'SocketException: Remote device disconnected. Keep the target device in foreground and try again.',
      ),
      AppErrorCode.remoteDeviceDisconnected,
    );
    expect(
      ExecutionState.localizeErrorMessage(
        'SocketException: Not connected to any peer.',
      ),
      AppErrorCode.noRemoteDeviceConnected,
    );
    expect(
      ExecutionState.localizeErrorMessage(
        'FileAccessException: Windows write session create failed: Access is denied.',
      ),
      AppErrorCode.windowsWriteCreateFailed,
    );
    expect(
      PreviewState.localizeErrorMessage(
        'FileAccessException: Windows directory listing failed: Access is denied.',
      ),
      AppErrorCode.windowsDirectoryListingFailed,
    );
    expect(
      DirectoryState.localizeErrorMessage(
        'FileAccessException: Windows directory listing failed: Access is denied.',
      ),
      AppErrorCode.windowsDirectoryListingFailed,
    );
    expect(
      ConnectionState.localizeErrorMessage(
        'SocketException: No shared directory selected on peer.',
      ),
      AppErrorCode.remoteDirectoryNotSelected,
    );
    expect(
      ConnectionState.localizeErrorMessage(
        'SocketException: Not connected to any peer.',
      ),
      AppErrorCode.noRemoteDeviceConnected,
    );
  });
}
