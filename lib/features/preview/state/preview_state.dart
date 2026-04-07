import 'package:music_sync/models/sync_plan.dart';
import 'package:music_sync/models/scan_snapshot.dart';

enum PreviewStatus {
  idle,
  loading,
  loaded,
  failed,
}

enum PreviewMode {
  none,
  local,
  remote,
}

class PreviewState {
  const PreviewState({
    required this.status,
    required this.plan,
    this.mode = PreviewMode.none,
    this.availableExtensions = const <String>['*'],
    this.activeExtension = '*',
    this.sourceSnapshot,
    this.targetSnapshot,
    this.deleteEnabled = false,
    this.sourceRootId,
    this.errorMessage,
  });

  final PreviewStatus status;
  final SyncPlan plan;
  final PreviewMode mode;
  final List<String> availableExtensions;
  final String activeExtension;
  final ScanSnapshot? sourceSnapshot;
  final ScanSnapshot? targetSnapshot;
  final bool deleteEnabled;
  final String? sourceRootId;
  final String? errorMessage;

  static String localizeErrorMessage(String? value) {
    if (value == null || value.isEmpty) {
      return '';
    }
    if (value.contains('Scanning timed out')) {
      return 'Scanning timed out. The folder may be too large or not fully accessible.';
    }
    if (value.contains('Unable to access the selected directory')) {
      return 'Unable to access the selected directory. Please choose another folder.';
    }
    if (value.contains('Windows directory listing failed')) {
      return 'Scanning failed because the Windows directory could not be listed.';
    }
    if (value.contains('Windows entry access failed')) {
      return 'Scanning failed because one or more Windows entries could not be accessed.';
    }
    if (value.contains('PathAccessException') ||
        value.contains('拒绝访问') ||
        value.contains('Access is denied')) {
      return 'Scanning failed because part of the directory tree is not accessible.';
    }
    if (value.contains('SocketException: ')) {
      return value.replaceFirst('SocketException: ', '');
    }
    if (value.contains('FileAccessException: ')) {
      return value.replaceFirst('FileAccessException: ', '');
    }
    return value;
  }

  factory PreviewState.initial() {
    return PreviewState(
      status: PreviewStatus.idle,
      plan: SyncPlan.empty(),
    );
  }
}
