import 'package:music_sync/core/errors/app_error_localizer.dart';
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
    this.ignoredExtensions = const <String>[],
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
  final List<String> ignoredExtensions;
  final String? sourceRootId;
  final String? errorMessage;

  static String localizeErrorMessage(String? value) {
    return AppErrorLocalizer.resolve(value);
  }

  factory PreviewState.initial() {
    return PreviewState(
      status: PreviewStatus.idle,
      plan: SyncPlan.empty(),
    );
  }
}
