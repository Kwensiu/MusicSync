import 'package:music_sync/core/errors/app_error_localizer.dart';
import 'package:music_sync/services/file_access/file_access_entry.dart';

class DirectoryState {
  const DirectoryState({
    this.handle,
    this.recentHandles = const <DirectoryHandle>[],
    this.recentLabels = const <String, String>{},
    this.errorMessage,
    this.preflight,
    this.hasTempFiles = false,
  });

  final DirectoryHandle? handle;
  final List<DirectoryHandle> recentHandles;
  final Map<String, String> recentLabels;
  final String? errorMessage;
  final DirectoryPreflightView? preflight;
  final bool hasTempFiles;

  static String localizeErrorMessage(String? value) {
    return AppErrorLocalizer.resolve(value);
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
