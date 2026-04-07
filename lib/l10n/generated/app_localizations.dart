import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'MusicSync'**
  String get appTitle;

  /// No description provided for @homeModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get homeModeTitle;

  /// No description provided for @homeModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Single-direction mirror sync over LAN.'**
  String get homeModeDescription;

  /// No description provided for @homeSyncDirectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Current Direction'**
  String get homeSyncDirectionTitle;

  /// No description provided for @homeSyncDirectionDescription.
  ///
  /// In en, this message translates to:
  /// **'Version 1 is fixed to: local directory -> remote directory. Listening and connecting only establish the session, not the copy direction.'**
  String get homeSyncDirectionDescription;

  /// No description provided for @homeLocalLibraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Local Library'**
  String get homeLocalLibraryTitle;

  /// No description provided for @homeLocalSourceHint.
  ///
  /// In en, this message translates to:
  /// **'This directory is treated as the source. The remote side will be aligned to it.'**
  String get homeLocalSourceHint;

  /// No description provided for @directoryPreflightWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Preflight warning: this directory may be heavy and preview generation could be slow.'**
  String get directoryPreflightWarningTitle;

  /// No description provided for @directoryPreflightSampleSummary.
  ///
  /// In en, this message translates to:
  /// **'Preflight sample: {children} top-level items, {directories} directories, {files} files.'**
  String directoryPreflightSampleSummary(
      int children, int directories, int files);

  /// No description provided for @directoryPreflightManyRootChildren.
  ///
  /// In en, this message translates to:
  /// **'A large number of top-level items was detected, so full scanning may be slow.'**
  String get directoryPreflightManyRootChildren;

  /// No description provided for @directoryPreflightDenseNestedDirectory.
  ///
  /// In en, this message translates to:
  /// **'A dense shallow directory was detected, so full scanning may be slow.'**
  String get directoryPreflightDenseNestedDirectory;

  /// No description provided for @directoryPreflightInaccessibleSubdirectory.
  ///
  /// In en, this message translates to:
  /// **'A shallow subdirectory appears to have access restrictions, so preview may warn or time out.'**
  String get directoryPreflightInaccessibleSubdirectory;

  /// No description provided for @directoryPreflightSystemLikeDirectory.
  ///
  /// In en, this message translates to:
  /// **'This directory looks like a system or cache location and is not a good fit for a music library.'**
  String get directoryPreflightSystemLikeDirectory;

  /// No description provided for @homeNoDirectorySelected.
  ///
  /// In en, this message translates to:
  /// **'No directory selected yet.'**
  String get homeNoDirectorySelected;

  /// No description provided for @homePickDirectory.
  ///
  /// In en, this message translates to:
  /// **'Pick Directory'**
  String get homePickDirectory;

  /// No description provided for @homeRecentDirectories.
  ///
  /// In en, this message translates to:
  /// **'Recent Directories'**
  String get homeRecentDirectories;

  /// No description provided for @homeCleanupTempFiles.
  ///
  /// In en, this message translates to:
  /// **'Clean Incomplete Transfer Files'**
  String get homeCleanupTempFiles;

  /// No description provided for @homeCleanupTempSuccess.
  ///
  /// In en, this message translates to:
  /// **'Removed {count} temporary file(s).'**
  String homeCleanupTempSuccess(int count);

  /// No description provided for @homeCleanupTempPartial.
  ///
  /// In en, this message translates to:
  /// **'Removed {deleted} temporary file(s), but {failed} item(s) could not be cleaned.'**
  String homeCleanupTempPartial(int deleted, int failed);

  /// No description provided for @homeCleanupTempFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to clean temporary files. Please try again later.'**
  String get homeCleanupTempFailed;

  /// No description provided for @homeRecentAddresses.
  ///
  /// In en, this message translates to:
  /// **'Recent Addresses'**
  String get homeRecentAddresses;

  /// No description provided for @homeDiscoveredDevices.
  ///
  /// In en, this message translates to:
  /// **'Discovered Devices'**
  String get homeDiscoveredDevices;

  /// No description provided for @homeRemoteTargetTitle.
  ///
  /// In en, this message translates to:
  /// **'Remote Target'**
  String get homeRemoteTargetTitle;

  /// No description provided for @homeRemoteTargetHint.
  ///
  /// In en, this message translates to:
  /// **'Version 1 currently supports only local-to-remote sync.'**
  String get homeRemoteTargetHint;

  /// No description provided for @homeRemoteDirectoryReady.
  ///
  /// In en, this message translates to:
  /// **'The remote shared directory is ready. You can refresh the index or build a remote preview.'**
  String get homeRemoteDirectoryReady;

  /// No description provided for @homeRemoteDirectoryMissing.
  ///
  /// In en, this message translates to:
  /// **'The remote shared directory is not ready yet. Select a shared directory on the remote device, then refresh the index or build a remote preview.'**
  String get homeRemoteDirectoryMissing;

  /// No description provided for @homeListenerTitle.
  ///
  /// In en, this message translates to:
  /// **'Listener'**
  String get homeListenerTitle;

  /// No description provided for @homeListenerStart.
  ///
  /// In en, this message translates to:
  /// **'Start Listening'**
  String get homeListenerStart;

  /// No description provided for @homeListenerStop.
  ///
  /// In en, this message translates to:
  /// **'Stop Listening'**
  String get homeListenerStop;

  /// No description provided for @homeListenerPort.
  ///
  /// In en, this message translates to:
  /// **'Listening port: {port}'**
  String homeListenerPort(int port);

  /// No description provided for @homePeerAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Peer Address'**
  String get homePeerAddressLabel;

  /// No description provided for @homePeerAddressHint.
  ///
  /// In en, this message translates to:
  /// **'192.168.1.8:44888'**
  String get homePeerAddressHint;

  /// No description provided for @homeConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get homeConnect;

  /// No description provided for @homeDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get homeDisconnect;

  /// No description provided for @homeConnectionStatus.
  ///
  /// In en, this message translates to:
  /// **'Status: {status}'**
  String homeConnectionStatus(Object status);

  /// No description provided for @homePeerName.
  ///
  /// In en, this message translates to:
  /// **'Peer: {name}'**
  String homePeerName(Object name);

  /// No description provided for @homeRefreshRemoteIndex.
  ///
  /// In en, this message translates to:
  /// **'Refresh Remote Index'**
  String get homeRefreshRemoteIndex;

  /// No description provided for @homeRemoteRoot.
  ///
  /// In en, this message translates to:
  /// **'Remote root: {name}'**
  String homeRemoteRoot(Object name);

  /// No description provided for @homeRemoteFiles.
  ///
  /// In en, this message translates to:
  /// **'Remote files: {count}'**
  String homeRemoteFiles(int count);

  /// No description provided for @homeOpenPreview.
  ///
  /// In en, this message translates to:
  /// **'Open Preview'**
  String get homeOpenPreview;

  /// No description provided for @previewTitle.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get previewTitle;

  /// No description provided for @previewSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get previewSummaryTitle;

  /// No description provided for @previewScopeLocal.
  ///
  /// In en, this message translates to:
  /// **'Local debug preview: local -> local target'**
  String get previewScopeLocal;

  /// No description provided for @previewScopeRemote.
  ///
  /// In en, this message translates to:
  /// **'LAN preview: local -> remote'**
  String get previewScopeRemote;

  /// No description provided for @previewStatus.
  ///
  /// In en, this message translates to:
  /// **'Status: {status}'**
  String previewStatus(Object status);

  /// No description provided for @previewCopyCount.
  ///
  /// In en, this message translates to:
  /// **'Copy: {count}'**
  String previewCopyCount(int count);

  /// No description provided for @previewDeleteCount.
  ///
  /// In en, this message translates to:
  /// **'Delete: {count}'**
  String previewDeleteCount(int count);

  /// No description provided for @previewConflictCount.
  ///
  /// In en, this message translates to:
  /// **'Conflict: {count}'**
  String previewConflictCount(int count);

  /// No description provided for @previewCopyBytes.
  ///
  /// In en, this message translates to:
  /// **'Data to copy: {size}'**
  String previewCopyBytes(Object size);

  /// No description provided for @previewBuildPlan.
  ///
  /// In en, this message translates to:
  /// **'Build Preview'**
  String get previewBuildPlan;

  /// No description provided for @previewBuildRemotePlan.
  ///
  /// In en, this message translates to:
  /// **'Build Remote Preview'**
  String get previewBuildRemotePlan;

  /// No description provided for @previewPlanItemsTitle.
  ///
  /// In en, this message translates to:
  /// **'Plan Items'**
  String get previewPlanItemsTitle;

  /// No description provided for @previewEmptyPlan.
  ///
  /// In en, this message translates to:
  /// **'Copy, delete, and conflict items will appear here.'**
  String get previewEmptyPlan;

  /// No description provided for @previewSectionCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy Items'**
  String get previewSectionCopy;

  /// No description provided for @previewSectionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete Items'**
  String get previewSectionDelete;

  /// No description provided for @previewSectionConflict.
  ///
  /// In en, this message translates to:
  /// **'Conflicts'**
  String get previewSectionConflict;

  /// No description provided for @previewNoItemsInSection.
  ///
  /// In en, this message translates to:
  /// **'No items in this section.'**
  String get previewNoItemsInSection;

  /// No description provided for @previewFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All types'**
  String get previewFilterAll;

  /// No description provided for @previewFilterTitle.
  ///
  /// In en, this message translates to:
  /// **'File Type'**
  String get previewFilterTitle;

  /// No description provided for @previewStalePlan.
  ///
  /// In en, this message translates to:
  /// **'The selected directory changed. Rebuild preview.'**
  String get previewStalePlan;

  /// No description provided for @previewSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get previewSectionTitle;

  /// No description provided for @previewScanTimeout.
  ///
  /// In en, this message translates to:
  /// **'Scanning may be blocked by a large or inaccessible directory.'**
  String get previewScanTimeout;

  /// No description provided for @previewPartialScanWarning.
  ///
  /// In en, this message translates to:
  /// **'Scanning skipped {count} inaccessible subdirectories.'**
  String previewPartialScanWarning(int count);

  /// No description provided for @previewPartialScanAdvice.
  ///
  /// In en, this message translates to:
  /// **'Preview can continue, but the result may be incomplete.'**
  String get previewPartialScanAdvice;

  /// No description provided for @previewSkippedPath.
  ///
  /// In en, this message translates to:
  /// **'Skipped: {path}'**
  String previewSkippedPath(Object path);

  /// No description provided for @previewStartSync.
  ///
  /// In en, this message translates to:
  /// **'Start Sync'**
  String get previewStartSync;

  /// No description provided for @previewDirectoryRequired.
  ///
  /// In en, this message translates to:
  /// **'Select a local directory before building preview.'**
  String get previewDirectoryRequired;

  /// No description provided for @previewRemoteDirectoryRequired.
  ///
  /// In en, this message translates to:
  /// **'Connect to a peer and load its index before building remote preview.'**
  String get previewRemoteDirectoryRequired;

  /// No description provided for @errorRemoteDirectoryNotSelected.
  ///
  /// In en, this message translates to:
  /// **'The remote device has not selected a shared directory yet.'**
  String get errorRemoteDirectoryNotSelected;

  /// No description provided for @errorRemoteDeviceDisconnected.
  ///
  /// In en, this message translates to:
  /// **'The remote device disconnected. Keep the target device in foreground and reconnect.'**
  String get errorRemoteDeviceDisconnected;

  /// No description provided for @errorConnectionRefused.
  ///
  /// In en, this message translates to:
  /// **'Connection was refused. Check the target address and ensure the remote listener is running.'**
  String get errorConnectionRefused;

  /// No description provided for @errorConnectionTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Connection timed out. Check that both devices are on the same LAN and try again.'**
  String get errorConnectionTimedOut;

  /// No description provided for @errorRemoteProtocolInvalid.
  ///
  /// In en, this message translates to:
  /// **'The remote device responded with an incompatible or invalid protocol message.'**
  String get errorRemoteProtocolInvalid;

  /// No description provided for @errorNoRemoteDeviceConnected.
  ///
  /// In en, this message translates to:
  /// **'No remote device is connected.'**
  String get errorNoRemoteDeviceConnected;

  /// No description provided for @errorScanTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Scanning timed out. The folder may be too large or contain inaccessible subdirectories.'**
  String get errorScanTimedOut;

  /// No description provided for @errorDirectoryUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unable to access the selected directory. Please choose another accessible folder.'**
  String get errorDirectoryUnavailable;

  /// No description provided for @errorDirectoryTreeAccessDenied.
  ///
  /// In en, this message translates to:
  /// **'Scanning failed because part of the directory tree is not accessible.'**
  String get errorDirectoryTreeAccessDenied;

  /// No description provided for @errorDirectoryAccessDenied.
  ///
  /// In en, this message translates to:
  /// **'Directory access was denied. Please choose a folder you can read.'**
  String get errorDirectoryAccessDenied;

  /// No description provided for @executionConfirmDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm deletion'**
  String get executionConfirmDeleteTitle;

  /// No description provided for @executionConfirmDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'This sync will delete {count} extra items from the target directory. Continue?'**
  String executionConfirmDeleteBody(int count);

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @executionTitle.
  ///
  /// In en, this message translates to:
  /// **'Execution'**
  String get executionTitle;

  /// No description provided for @executionProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get executionProgressTitle;

  /// No description provided for @executionRemotePending.
  ///
  /// In en, this message translates to:
  /// **'Build a remote preview before running remote sync.'**
  String get executionRemotePending;

  /// No description provided for @executionRemoteReady.
  ///
  /// In en, this message translates to:
  /// **'Remote preview is ready. The current plan can sync local files to the remote side.'**
  String get executionRemoteReady;

  /// No description provided for @executionKeepForeground.
  ///
  /// In en, this message translates to:
  /// **'When Android is the remote side, keep the target device in foreground. Do not background the app or lock the screen.'**
  String get executionKeepForeground;

  /// No description provided for @executionLocalPending.
  ///
  /// In en, this message translates to:
  /// **'Local debug copy is only for local preview mode and is not part of the main LAN sync flow.'**
  String get executionLocalPending;

  /// No description provided for @executionProgressPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Transfer progress will appear here.'**
  String get executionProgressPlaceholder;

  /// No description provided for @executionLogsTitle.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get executionLogsTitle;

  /// No description provided for @executionLogsPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Execution logs will appear here.'**
  String get executionLogsPlaceholder;

  /// No description provided for @executionTargetTitle.
  ///
  /// In en, this message translates to:
  /// **'Local Debug Target'**
  String get executionTargetTitle;

  /// No description provided for @executionTargetHint.
  ///
  /// In en, this message translates to:
  /// **'Used only for local debug flow. It is not the actual LAN sync target.'**
  String get executionTargetHint;

  /// No description provided for @executionNoTarget.
  ///
  /// In en, this message translates to:
  /// **'No target directory selected.'**
  String get executionNoTarget;

  /// No description provided for @executionPickTarget.
  ///
  /// In en, this message translates to:
  /// **'Pick Target Directory'**
  String get executionPickTarget;

  /// No description provided for @executionRun.
  ///
  /// In en, this message translates to:
  /// **'Run Local Copy'**
  String get executionRun;

  /// No description provided for @executionRunLocalDebug.
  ///
  /// In en, this message translates to:
  /// **'Run Local Debug Copy'**
  String get executionRunLocalDebug;

  /// No description provided for @executionRunRemote.
  ///
  /// In en, this message translates to:
  /// **'Run Remote Sync'**
  String get executionRunRemote;

  /// No description provided for @executionStop.
  ///
  /// In en, this message translates to:
  /// **'Stop Sync'**
  String get executionStop;

  /// No description provided for @executionCancelled.
  ///
  /// In en, this message translates to:
  /// **'Sync was stopped manually. Incomplete temporary files were cleaned when possible.'**
  String get executionCancelled;

  /// No description provided for @executionCurrentFile.
  ///
  /// In en, this message translates to:
  /// **'Current file: {path}'**
  String executionCurrentFile(Object path);

  /// No description provided for @executionProgressFiles.
  ///
  /// In en, this message translates to:
  /// **'Files: {done}/{total}'**
  String executionProgressFiles(int done, int total);

  /// No description provided for @executionTargetRequired.
  ///
  /// In en, this message translates to:
  /// **'Pick a local target directory before running.'**
  String get executionTargetRequired;

  /// No description provided for @executionPlanSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Execution Scope'**
  String get executionPlanSummaryTitle;

  /// No description provided for @executionWillCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy items to execute: {count}'**
  String executionWillCopy(int count);

  /// No description provided for @executionWillDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete items to execute: {count}'**
  String executionWillDelete(int count);

  /// No description provided for @executionWillSkipConflict.
  ///
  /// In en, this message translates to:
  /// **'Conflict items will not be executed: {count}'**
  String executionWillSkipConflict(int count);

  /// No description provided for @executionOpenResult.
  ///
  /// In en, this message translates to:
  /// **'Open Result'**
  String get executionOpenResult;

  /// No description provided for @resultTitle.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get resultTitle;

  /// No description provided for @resultSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get resultSummaryTitle;

  /// No description provided for @resultSummaryPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Sync result summary will appear here.'**
  String get resultSummaryPlaceholder;

  /// No description provided for @resultModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Execution mode: {mode}'**
  String resultModeLabel(Object mode);

  /// No description provided for @resultModeLocal.
  ///
  /// In en, this message translates to:
  /// **'Local Debug Copy'**
  String get resultModeLocal;

  /// No description provided for @resultModeRemote.
  ///
  /// In en, this message translates to:
  /// **'Remote Sync'**
  String get resultModeRemote;

  /// No description provided for @resultModeUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get resultModeUnknown;

  /// No description provided for @resultErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get resultErrorTitle;

  /// No description provided for @resultAdviceTitle.
  ///
  /// In en, this message translates to:
  /// **'Advice'**
  String get resultAdviceTitle;

  /// No description provided for @resultAdviceKeepForeground.
  ///
  /// In en, this message translates to:
  /// **'If the remote side is Android, keep it in foreground and retry.'**
  String get resultAdviceKeepForeground;

  /// No description provided for @resultAdviceRebuildPreview.
  ///
  /// In en, this message translates to:
  /// **'If directory access or contents changed, re-select the directory and rebuild the preview.'**
  String get resultAdviceRebuildPreview;

  /// No description provided for @resultCopiedCount.
  ///
  /// In en, this message translates to:
  /// **'Copied: {count}'**
  String resultCopiedCount(int count);

  /// No description provided for @resultDeletedCount.
  ///
  /// In en, this message translates to:
  /// **'Deleted: {count}'**
  String resultDeletedCount(int count);

  /// No description provided for @resultFailedCount.
  ///
  /// In en, this message translates to:
  /// **'Failed: {count}'**
  String resultFailedCount(int count);

  /// No description provided for @resultTargetRoot.
  ///
  /// In en, this message translates to:
  /// **'Target: {path}'**
  String resultTargetRoot(Object path);

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsDefaultsTitle.
  ///
  /// In en, this message translates to:
  /// **'Defaults'**
  String get settingsDefaultsTitle;

  /// No description provided for @settingsDefaultsPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Project-wide settings will live here.'**
  String get settingsDefaultsPlaceholder;

  /// No description provided for @statusIdle.
  ///
  /// In en, this message translates to:
  /// **'idle'**
  String get statusIdle;

  /// No description provided for @statusListening.
  ///
  /// In en, this message translates to:
  /// **'listening'**
  String get statusListening;

  /// No description provided for @statusConnecting.
  ///
  /// In en, this message translates to:
  /// **'connecting'**
  String get statusConnecting;

  /// No description provided for @statusConnected.
  ///
  /// In en, this message translates to:
  /// **'connected'**
  String get statusConnected;

  /// No description provided for @statusDisconnected.
  ///
  /// In en, this message translates to:
  /// **'disconnected'**
  String get statusDisconnected;

  /// No description provided for @statusFailed.
  ///
  /// In en, this message translates to:
  /// **'failed'**
  String get statusFailed;

  /// No description provided for @statusLoading.
  ///
  /// In en, this message translates to:
  /// **'loading'**
  String get statusLoading;

  /// No description provided for @statusLoaded.
  ///
  /// In en, this message translates to:
  /// **'loaded'**
  String get statusLoaded;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
