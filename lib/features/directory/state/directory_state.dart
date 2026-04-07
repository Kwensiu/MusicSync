import 'package:music_sync/services/file_access/file_access_entry.dart';

class DirectoryState {
  const DirectoryState({
    this.handle,
    this.recentHandles = const <DirectoryHandle>[],
    this.errorMessage,
    this.preflight,
  });

  final DirectoryHandle? handle;
  final List<DirectoryHandle> recentHandles;
  final String? errorMessage;
  final DirectoryPreflightView? preflight;

  static String localizeErrorMessage(String? value) {
    if (value == null || value.isEmpty) {
      return '';
    }
    if (value.contains('not accessible anymore')) {
      return 'The selected directory is no longer accessible. Please choose it again.';
    }
    if (value.contains('Unable to access the selected directory')) {
      return 'Unable to access the selected directory. Please choose another folder.';
    }
    if (value.contains('Windows directory listing failed')) {
      return 'Unable to inspect the selected Windows directory. Please choose another folder.';
    }
    if (value.contains('PathAccessException') ||
        value.contains('拒绝访问') ||
        value.contains('Access is denied')) {
      return 'Directory access was denied. Please choose a folder you can read.';
    }
    if (value.contains('Directory does not exist')) {
      return 'The selected directory no longer exists. Please choose it again.';
    }
    if (value.contains('FileAccessException: ')) {
      return value.replaceFirst('FileAccessException: ', '');
    }
    if (value.contains('Exception: ')) {
      return value.replaceFirst('Exception: ', '');
    }
    return value;
  }
}

class DirectoryPreflightView {
  const DirectoryPreflightView({
    required this.sampledDirectories,
    required this.sampledFiles,
    required this.sampledChildren,
    required this.reasons,
  });

  final int sampledDirectories;
  final int sampledFiles;
  final int sampledChildren;
  final List<String> reasons;

  bool get hasRisk => reasons.isNotEmpty;
}
