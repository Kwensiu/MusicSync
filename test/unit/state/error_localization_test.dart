import 'package:flutter_test/flutter_test.dart';
import 'package:music_sync/features/connection/state/connection_state.dart';
import 'package:music_sync/features/directory/state/directory_state.dart';
import 'package:music_sync/features/execution/state/execution_state.dart';
import 'package:music_sync/features/preview/state/preview_state.dart';

void main() {
  test('error localization normalizes common user-facing errors', () {
    expect(
      ConnectionState.localizeErrorMessage('SocketException: Connection refused'),
      'Connection was refused. Check the target address and ensure the remote listener is running.',
    );
    expect(
      DirectoryState.localizeErrorMessage('PathAccessException: 拒绝访问'),
      'Directory access was denied. Please choose a folder you can read.',
    );
    expect(
      PreviewState.localizeErrorMessage(
        'FileAccessException: Unable to access the selected directory. Please choose another folder.',
      ),
      'Unable to access the selected directory. Please choose another folder.',
    );
    expect(
      ExecutionState.localizeErrorMessage(
        'SocketException: Remote device disconnected. Keep the target device in foreground and try again.',
      ),
      '远端设备已断开连接。请保持目标设备在前台后重试。',
    );
    expect(
      ExecutionState.localizeErrorMessage(
        'SocketException: Not connected to any peer.',
      ),
      '当前没有已连接的远端设备。',
    );
    expect(
      ExecutionState.localizeErrorMessage(
        'FileAccessException: Windows write session create failed: Access is denied.',
      ),
      'Unable to write to the Windows target directory. Check permissions and file locks, then try again.',
    );
    expect(
      PreviewState.localizeErrorMessage(
        'FileAccessException: Windows directory listing failed: Access is denied.',
      ),
      'Scanning failed because the Windows directory could not be listed.',
    );
    expect(
      DirectoryState.localizeErrorMessage(
        'FileAccessException: Windows directory listing failed: Access is denied.',
      ),
      'Unable to inspect the selected Windows directory. Please choose another folder.',
    );
    expect(
      ConnectionState.localizeErrorMessage(
        'SocketException: No shared directory selected on peer.',
      ),
      '远端设备还没有选择共享目录。',
    );
    expect(
      ConnectionState.localizeErrorMessage(
        'SocketException: Not connected to any peer.',
      ),
      '当前没有已连接的远端设备。',
    );
  });
}
