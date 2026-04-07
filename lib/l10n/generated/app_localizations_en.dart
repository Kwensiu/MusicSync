// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'MusicSync';

  @override
  String get homeModeTitle => 'Mode';

  @override
  String get homeModeDescription => 'Single-direction mirror sync over LAN.';

  @override
  String get homeSyncDirectionTitle => 'Current Direction';

  @override
  String get homeSyncDirectionDescription =>
      'Version 1 is fixed to: local directory -> remote directory. Listening and connecting only establish the session, not the copy direction.';

  @override
  String get homeLocalLibraryTitle => 'Local Library';

  @override
  String get homeLocalSourceHint =>
      'This directory is treated as the source. The remote side will be aligned to it.';

  @override
  String get directoryPreflightWarningTitle =>
      'Preflight warning: this directory may be heavy and preview generation could be slow.';

  @override
  String directoryPreflightSampleSummary(
      int children, int directories, int files) {
    return 'Preflight sample: $children top-level items, $directories directories, $files files.';
  }

  @override
  String get directoryPreflightManyRootChildren =>
      'A large number of top-level items was detected, so full scanning may be slow.';

  @override
  String get directoryPreflightDenseNestedDirectory =>
      'A dense shallow directory was detected, so full scanning may be slow.';

  @override
  String get directoryPreflightInaccessibleSubdirectory =>
      'A shallow subdirectory appears to have access restrictions, so preview may warn or time out.';

  @override
  String get directoryPreflightSystemLikeDirectory =>
      'This directory looks like a system or cache location and is not a good fit for a music library.';

  @override
  String get homeNoDirectorySelected => 'No directory selected yet.';

  @override
  String get homePickDirectory => 'Pick Directory';

  @override
  String get homeRecentDirectories => 'Recent Directories';

  @override
  String get homeCleanupTempFiles => 'Clean Incomplete Transfer Files';

  @override
  String homeCleanupTempSuccess(int count) {
    return 'Removed $count temporary file(s).';
  }

  @override
  String homeCleanupTempPartial(int deleted, int failed) {
    return 'Removed $deleted temporary file(s), but $failed item(s) could not be cleaned.';
  }

  @override
  String get homeCleanupTempFailed =>
      'Failed to clean temporary files. Please try again later.';

  @override
  String get homeRecentAddresses => 'Recent Addresses';

  @override
  String get homeDiscoveredDevices => 'Discovered Devices';

  @override
  String get homeRemoteTargetTitle => 'Remote Target';

  @override
  String get homeRemoteTargetHint =>
      'Version 1 currently supports only local-to-remote sync.';

  @override
  String get homeRemoteDirectoryReady =>
      'The remote shared directory is ready. You can refresh the index or build a remote preview.';

  @override
  String get homeRemoteDirectoryMissing =>
      'The remote shared directory is not ready yet. Select a shared directory on the remote device, then refresh the index or build a remote preview.';

  @override
  String get homeListenerTitle => 'Listener';

  @override
  String get homeListenerStart => 'Start Listening';

  @override
  String get homeListenerStop => 'Stop Listening';

  @override
  String homeListenerPort(int port) {
    return 'Listening port: $port';
  }

  @override
  String get homePeerAddressLabel => 'Peer Address';

  @override
  String get homePeerAddressHint => '192.168.1.8:44888';

  @override
  String get homeConnect => 'Connect';

  @override
  String get homeDisconnect => 'Disconnect';

  @override
  String homeConnectionStatus(Object status) {
    return 'Status: $status';
  }

  @override
  String homePeerName(Object name) {
    return 'Peer: $name';
  }

  @override
  String get homeRefreshRemoteIndex => 'Refresh Remote Index';

  @override
  String homeRemoteRoot(Object name) {
    return 'Remote root: $name';
  }

  @override
  String homeRemoteFiles(int count) {
    return 'Remote files: $count';
  }

  @override
  String get homeOpenPreview => 'Open Preview';

  @override
  String get previewTitle => 'Preview';

  @override
  String get previewSummaryTitle => 'Summary';

  @override
  String get previewScopeLocal => 'Local debug preview: local -> local target';

  @override
  String get previewScopeRemote => 'LAN preview: local -> remote';

  @override
  String previewStatus(Object status) {
    return 'Status: $status';
  }

  @override
  String previewCopyCount(int count) {
    return 'Copy: $count';
  }

  @override
  String previewDeleteCount(int count) {
    return 'Delete: $count';
  }

  @override
  String previewConflictCount(int count) {
    return 'Conflict: $count';
  }

  @override
  String previewCopyBytes(Object size) {
    return 'Data to copy: $size';
  }

  @override
  String get previewBuildPlan => 'Build Preview';

  @override
  String get previewBuildRemotePlan => 'Build Remote Preview';

  @override
  String get previewPlanItemsTitle => 'Plan Items';

  @override
  String get previewEmptyPlan =>
      'Copy, delete, and conflict items will appear here.';

  @override
  String get previewSectionCopy => 'Copy Items';

  @override
  String get previewSectionDelete => 'Delete Items';

  @override
  String get previewSectionConflict => 'Conflicts';

  @override
  String get previewNoItemsInSection => 'No items in this section.';

  @override
  String get previewFilterAll => 'All types';

  @override
  String get previewFilterTitle => 'File Type';

  @override
  String get previewStalePlan =>
      'The selected directory changed. Rebuild preview.';

  @override
  String get previewSectionTitle => 'Category';

  @override
  String get previewScanTimeout =>
      'Scanning may be blocked by a large or inaccessible directory.';

  @override
  String previewPartialScanWarning(int count) {
    return 'Scanning skipped $count inaccessible subdirectories.';
  }

  @override
  String get previewPartialScanAdvice =>
      'Preview can continue, but the result may be incomplete.';

  @override
  String previewSkippedPath(Object path) {
    return 'Skipped: $path';
  }

  @override
  String get previewStartSync => 'Start Sync';

  @override
  String get previewDirectoryRequired =>
      'Select a local directory before building preview.';

  @override
  String get previewRemoteDirectoryRequired =>
      'Connect to a peer and load its index before building remote preview.';

  @override
  String get errorRemoteDirectoryNotSelected =>
      'The remote device has not selected a shared directory yet.';

  @override
  String get errorRemoteDeviceDisconnected =>
      'The remote device disconnected. Keep the target device in foreground and reconnect.';

  @override
  String get errorConnectionRefused =>
      'Connection was refused. Check the target address and ensure the remote listener is running.';

  @override
  String get errorConnectionTimedOut =>
      'Connection timed out. Check that both devices are on the same LAN and try again.';

  @override
  String get errorRemoteProtocolInvalid =>
      'The remote device responded with an incompatible or invalid protocol message.';

  @override
  String get errorNoRemoteDeviceConnected => 'No remote device is connected.';

  @override
  String get errorScanTimedOut =>
      'Scanning timed out. The folder may be too large or contain inaccessible subdirectories.';

  @override
  String get errorDirectoryUnavailable =>
      'Unable to access the selected directory. Please choose another accessible folder.';

  @override
  String get errorDirectoryTreeAccessDenied =>
      'Scanning failed because part of the directory tree is not accessible.';

  @override
  String get errorDirectoryAccessDenied =>
      'Directory access was denied. Please choose a folder you can read.';

  @override
  String get executionConfirmDeleteTitle => 'Confirm deletion';

  @override
  String executionConfirmDeleteBody(int count) {
    return 'This sync will delete $count extra items from the target directory. Continue?';
  }

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get executionTitle => 'Execution';

  @override
  String get executionProgressTitle => 'Progress';

  @override
  String get executionRemotePending =>
      'Build a remote preview before running remote sync.';

  @override
  String get executionRemoteReady =>
      'Remote preview is ready. The current plan can sync local files to the remote side.';

  @override
  String get executionKeepForeground =>
      'When Android is the remote side, keep the target device in foreground. Do not background the app or lock the screen.';

  @override
  String get executionLocalPending =>
      'Local debug copy is only for local preview mode and is not part of the main LAN sync flow.';

  @override
  String get executionProgressPlaceholder =>
      'Transfer progress will appear here.';

  @override
  String get executionLogsTitle => 'Logs';

  @override
  String get executionLogsPlaceholder => 'Execution logs will appear here.';

  @override
  String get executionTargetTitle => 'Local Debug Target';

  @override
  String get executionTargetHint =>
      'Used only for local debug flow. It is not the actual LAN sync target.';

  @override
  String get executionNoTarget => 'No target directory selected.';

  @override
  String get executionPickTarget => 'Pick Target Directory';

  @override
  String get executionRun => 'Run Local Copy';

  @override
  String get executionRunLocalDebug => 'Run Local Debug Copy';

  @override
  String get executionRunRemote => 'Run Remote Sync';

  @override
  String get executionStop => 'Stop Sync';

  @override
  String get executionCancelled =>
      'Sync was stopped manually. Incomplete temporary files were cleaned when possible.';

  @override
  String executionCurrentFile(Object path) {
    return 'Current file: $path';
  }

  @override
  String executionProgressFiles(int done, int total) {
    return 'Files: $done/$total';
  }

  @override
  String get executionTargetRequired =>
      'Pick a local target directory before running.';

  @override
  String get executionPlanSummaryTitle => 'Execution Scope';

  @override
  String executionWillCopy(int count) {
    return 'Copy items to execute: $count';
  }

  @override
  String executionWillDelete(int count) {
    return 'Delete items to execute: $count';
  }

  @override
  String executionWillSkipConflict(int count) {
    return 'Conflict items will not be executed: $count';
  }

  @override
  String get executionOpenResult => 'Open Result';

  @override
  String get resultTitle => 'Result';

  @override
  String get resultSummaryTitle => 'Summary';

  @override
  String get resultSummaryPlaceholder =>
      'Sync result summary will appear here.';

  @override
  String resultModeLabel(Object mode) {
    return 'Execution mode: $mode';
  }

  @override
  String get resultModeLocal => 'Local Debug Copy';

  @override
  String get resultModeRemote => 'Remote Sync';

  @override
  String get resultModeUnknown => 'Unknown';

  @override
  String get resultErrorTitle => 'Error';

  @override
  String get resultAdviceTitle => 'Advice';

  @override
  String get resultAdviceKeepForeground =>
      'If the remote side is Android, keep it in foreground and retry.';

  @override
  String get resultAdviceRebuildPreview =>
      'If directory access or contents changed, re-select the directory and rebuild the preview.';

  @override
  String resultCopiedCount(int count) {
    return 'Copied: $count';
  }

  @override
  String resultDeletedCount(int count) {
    return 'Deleted: $count';
  }

  @override
  String resultFailedCount(int count) {
    return 'Failed: $count';
  }

  @override
  String resultTargetRoot(Object path) {
    return 'Target: $path';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsDefaultsTitle => 'Defaults';

  @override
  String get settingsDefaultsPlaceholder =>
      'Project-wide settings will live here.';

  @override
  String get statusIdle => 'idle';

  @override
  String get statusListening => 'listening';

  @override
  String get statusConnecting => 'connecting';

  @override
  String get statusConnected => 'connected';

  @override
  String get statusDisconnected => 'disconnected';

  @override
  String get statusFailed => 'failed';

  @override
  String get statusLoading => 'loading';

  @override
  String get statusLoaded => 'loaded';
}
