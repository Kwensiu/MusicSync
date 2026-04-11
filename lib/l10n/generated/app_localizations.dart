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
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'MusicSync'**
  String get appTitle;

  /// No description provided for @homeOverviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get homeOverviewTitle;

  /// No description provided for @homeOverviewHeadline.
  ///
  /// In en, this message translates to:
  /// **'Enter the transfer workspace from here'**
  String get homeOverviewHeadline;

  /// No description provided for @homeOverviewBody.
  ///
  /// In en, this message translates to:
  /// **'The home page now focuses on overview and entry points. Device session, source selection, preview, and sync execution all live in the transfer page.'**
  String get homeOverviewBody;

  /// No description provided for @homeOpenTransferPage.
  ///
  /// In en, this message translates to:
  /// **'Open Transfer Page'**
  String get homeOpenTransferPage;

  /// No description provided for @homeOverviewStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Current Status'**
  String get homeOverviewStatusTitle;

  /// No description provided for @homeOverviewConnectionLabel.
  ///
  /// In en, this message translates to:
  /// **'Device Session'**
  String get homeOverviewConnectionLabel;

  /// No description provided for @homeOverviewSourceLabel.
  ///
  /// In en, this message translates to:
  /// **'Source Directory'**
  String get homeOverviewSourceLabel;

  /// No description provided for @homeOverviewPreviewLabel.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get homeOverviewPreviewLabel;

  /// No description provided for @homeOverviewNextTitle.
  ///
  /// In en, this message translates to:
  /// **'Next Step'**
  String get homeOverviewNextTitle;

  /// No description provided for @homeOverviewNextConnect.
  ///
  /// In en, this message translates to:
  /// **'Open the transfer page first and establish a device session.'**
  String get homeOverviewNextConnect;

  /// No description provided for @homeOverviewNextPickSource.
  ///
  /// In en, this message translates to:
  /// **'The device session is ready. Next, pick a local source directory in the transfer page.'**
  String get homeOverviewNextPickSource;

  /// No description provided for @homeOverviewNextBuildPreview.
  ///
  /// In en, this message translates to:
  /// **'The source directory is ready. Next, build a preview in the transfer page.'**
  String get homeOverviewNextBuildPreview;

  /// No description provided for @homeOverviewNextOpenTransfer.
  ///
  /// In en, this message translates to:
  /// **'Everything needed to continue is ready. Open the transfer page.'**
  String get homeOverviewNextOpenTransfer;

  /// No description provided for @homeOverviewPreviewPending.
  ///
  /// In en, this message translates to:
  /// **'Preview not built'**
  String get homeOverviewPreviewPending;

  /// No description provided for @homeOverviewPreviewReady.
  ///
  /// In en, this message translates to:
  /// **'Preview ready, {count} item(s)'**
  String homeOverviewPreviewReady(int count);

  /// No description provided for @homeSourceStateReady.
  ///
  /// In en, this message translates to:
  /// **'Source directory selected'**
  String get homeSourceStateReady;

  /// No description provided for @homeSourceStatePending.
  ///
  /// In en, this message translates to:
  /// **'Source directory not selected'**
  String get homeSourceStatePending;

  /// No description provided for @transferTitle.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get transferTitle;

  /// No description provided for @homeStepConnectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Step 1: Establish Device Session'**
  String get homeStepConnectionTitle;

  /// No description provided for @homeConnectionStateIdle.
  ///
  /// In en, this message translates to:
  /// **'Not listening'**
  String get homeConnectionStateIdle;

  /// No description provided for @homeConnectionStateConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get homeConnectionStateConnecting;

  /// No description provided for @homeConnectionStateListening.
  ///
  /// In en, this message translates to:
  /// **'Listening'**
  String get homeConnectionStateListening;

  /// No description provided for @homeConnectionStateConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get homeConnectionStateConnected;

  /// No description provided for @homeConnectionStateDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get homeConnectionStateDisconnected;

  /// No description provided for @homeConnectionStateConnectedListening.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get homeConnectionStateConnectedListening;

  /// No description provided for @homePortChipLabel.
  ///
  /// In en, this message translates to:
  /// **'Port {port}'**
  String homePortChipLabel(int port);

  /// No description provided for @homeShareTooltip.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get homeShareTooltip;

  /// No description provided for @homePortDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Set listening port'**
  String get homePortDialogTitle;

  /// No description provided for @homePortDialogBody.
  ///
  /// In en, this message translates to:
  /// **'After saving, listening will use the new port.'**
  String get homePortDialogBody;

  /// No description provided for @homePortDialogHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a port, for example 44888'**
  String get homePortDialogHint;

  /// No description provided for @homePortDialogInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid port between 1 and 65535.'**
  String get homePortDialogInvalid;

  /// No description provided for @homeShareDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Share Address'**
  String get homeShareDialogTitle;

  /// No description provided for @homeShareCopyDone.
  ///
  /// In en, this message translates to:
  /// **'Connection address copied.'**
  String get homeShareCopyDone;

  /// No description provided for @homeConnectStop.
  ///
  /// In en, this message translates to:
  /// **'Stop Connection'**
  String get homeConnectStop;

  /// No description provided for @homeStepSourceTitle.
  ///
  /// In en, this message translates to:
  /// **'Step 2: Pick Local Source Directory'**
  String get homeStepSourceTitle;

  /// No description provided for @homeStepSourceHint.
  ///
  /// In en, this message translates to:
  /// **'This directory will be synced to the target directory.'**
  String get homeStepSourceHint;

  /// No description provided for @homeClearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get homeClearSelection;

  /// No description provided for @homeSourcePendingBecauseRemoteReady.
  ///
  /// In en, this message translates to:
  /// **'The target directory is already ready. The only thing missing now is the local source directory.'**
  String get homeSourcePendingBecauseRemoteReady;

  /// No description provided for @homeStepPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Step 3: Review and Sync'**
  String get homeStepPreviewTitle;

  /// No description provided for @homeStepPreviewHint.
  ///
  /// In en, this message translates to:
  /// **'Analysis starts automatically after both directories are ready. Refresh the target index only if needed.'**
  String get homeStepPreviewHint;

  /// No description provided for @homeOpenPreviewWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Open Preview Workspace'**
  String get homeOpenPreviewWorkspace;

  /// No description provided for @homeViewPreviewList.
  ///
  /// In en, this message translates to:
  /// **'View Preview List'**
  String get homeViewPreviewList;

  /// No description provided for @homePreviewStateReady.
  ///
  /// In en, this message translates to:
  /// **'Preview ready'**
  String get homePreviewStateReady;

  /// No description provided for @homePreviewStatePending.
  ///
  /// In en, this message translates to:
  /// **'Preview not built'**
  String get homePreviewStatePending;

  /// No description provided for @homeAdvancedTitle.
  ///
  /// In en, this message translates to:
  /// **'Advanced and Debug'**
  String get homeAdvancedTitle;

  /// No description provided for @homeConnectionHelpersTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection helpers'**
  String get homeConnectionHelpersTitle;

  /// No description provided for @homeConnectionActionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection actions'**
  String get homeConnectionActionsTitle;

  /// No description provided for @homeLocalLibraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Local Library'**
  String get homeLocalLibraryTitle;

  /// No description provided for @homeLocalSourceHint.
  ///
  /// In en, this message translates to:
  /// **'This directory is treated as the source. The target side will be aligned to it.'**
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
    int children,
    int directories,
    int files,
  );

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
  /// **'Nearby Devices'**
  String get homeDiscoveredDevices;

  /// No description provided for @homeRefreshConnectionState.
  ///
  /// In en, this message translates to:
  /// **'Update Connection Status'**
  String get homeRefreshConnectionState;

  /// No description provided for @homeOpenConnectionPanel.
  ///
  /// In en, this message translates to:
  /// **'More Connection Options'**
  String get homeOpenConnectionPanel;

  /// No description provided for @homeManageRecentItems.
  ///
  /// In en, this message translates to:
  /// **'Manage Records'**
  String get homeManageRecentItems;

  /// No description provided for @homeRecentEmpty.
  ///
  /// In en, this message translates to:
  /// **'No records yet'**
  String get homeRecentEmpty;

  /// No description provided for @homeRecentAlias.
  ///
  /// In en, this message translates to:
  /// **'Alias'**
  String get homeRecentAlias;

  /// No description provided for @homeRecentDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get homeRecentDelete;

  /// No description provided for @homeRecentEditAlias.
  ///
  /// In en, this message translates to:
  /// **'Edit Label'**
  String get homeRecentEditAlias;

  /// No description provided for @homeRecentEditAddress.
  ///
  /// In en, this message translates to:
  /// **'Edit Address'**
  String get homeRecentEditAddress;

  /// No description provided for @homeRecentAddressField.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get homeRecentAddressField;

  /// No description provided for @homeRecentAddressRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter an address'**
  String get homeRecentAddressRequired;

  /// No description provided for @homeRecentAliasHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a short name'**
  String get homeRecentAliasHint;

  /// No description provided for @homeRemoteTargetTitle.
  ///
  /// In en, this message translates to:
  /// **'Target Side'**
  String get homeRemoteTargetTitle;

  /// No description provided for @homeRemoteTargetHint.
  ///
  /// In en, this message translates to:
  /// **'Version 1 currently supports syncing only to the target side on a remote device.'**
  String get homeRemoteTargetHint;

  /// No description provided for @homeIncomingSyncTitle.
  ///
  /// In en, this message translates to:
  /// **'Receiving Sync'**
  String get homeIncomingSyncTitle;

  /// No description provided for @homeIncomingSyncBody.
  ///
  /// In en, this message translates to:
  /// **'This device is currently receiving sync writes from {device}.'**
  String homeIncomingSyncBody(Object device);

  /// No description provided for @homeIncomingSyncHint.
  ///
  /// In en, this message translates to:
  /// **'Do not clear the directory, disconnect, switch flows, or leave the app.'**
  String get homeIncomingSyncHint;

  /// No description provided for @homeRemoteManualRefreshTitle.
  ///
  /// In en, this message translates to:
  /// **'Manual refresh'**
  String get homeRemoteManualRefreshTitle;

  /// No description provided for @homePortConfigTitle.
  ///
  /// In en, this message translates to:
  /// **'Port Settings'**
  String get homePortConfigTitle;

  /// No description provided for @homeListenerTitle.
  ///
  /// In en, this message translates to:
  /// **'Listening Port'**
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

  /// No description provided for @homeRefreshRemoteIndex.
  ///
  /// In en, this message translates to:
  /// **'Refresh Target Index'**
  String get homeRefreshRemoteIndex;

  /// No description provided for @homeRemoteRoot.
  ///
  /// In en, this message translates to:
  /// **'Target root: {name}'**
  String homeRemoteRoot(Object name);

  /// No description provided for @homeRemoteIndexedAt.
  ///
  /// In en, this message translates to:
  /// **'Target index time: {value}'**
  String homeRemoteIndexedAt(Object value);

  /// No description provided for @homeRemoteFiles.
  ///
  /// In en, this message translates to:
  /// **'Target files: {count}'**
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

  /// No description provided for @previewTransferDirection.
  ///
  /// In en, this message translates to:
  /// **'Direction: {source} -> {target}'**
  String previewTransferDirection(Object source, Object target);

  /// No description provided for @previewDirectionRemote.
  ///
  /// In en, this message translates to:
  /// **'Target Side'**
  String get previewDirectionRemote;

  /// No description provided for @previewDirectionLocalTarget.
  ///
  /// In en, this message translates to:
  /// **'Local Target'**
  String get previewDirectionLocalTarget;

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

  /// No description provided for @previewSummaryBytes.
  ///
  /// In en, this message translates to:
  /// **'Bytes'**
  String get previewSummaryBytes;

  /// No description provided for @previewSectionAll.
  ///
  /// In en, this message translates to:
  /// **'All Items'**
  String get previewSectionAll;

  /// No description provided for @previewTargetIndexedAt.
  ///
  /// In en, this message translates to:
  /// **'Current target snapshot time: {value}'**
  String previewTargetIndexedAt(Object value);

  /// No description provided for @previewBuildPlan.
  ///
  /// In en, this message translates to:
  /// **'Build Preview'**
  String get previewBuildPlan;

  /// No description provided for @previewBuildRemotePlan.
  ///
  /// In en, this message translates to:
  /// **'Build Preview'**
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

  /// No description provided for @previewWaitingDirectories.
  ///
  /// In en, this message translates to:
  /// **'Waiting for directories'**
  String get previewWaitingDirectories;

  /// No description provided for @previewWaitingLocalDirectory.
  ///
  /// In en, this message translates to:
  /// **'Waiting for local directory'**
  String get previewWaitingLocalDirectory;

  /// No description provided for @previewWaitingRemoteDirectory.
  ///
  /// In en, this message translates to:
  /// **'Waiting for target directory'**
  String get previewWaitingRemoteDirectory;

  /// No description provided for @previewNoSyncItems.
  ///
  /// In en, this message translates to:
  /// **'No items to sync right now.'**
  String get previewNoSyncItems;

  /// No description provided for @previewDetailOverviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get previewDetailOverviewTitle;

  /// No description provided for @previewDetailRelativePath.
  ///
  /// In en, this message translates to:
  /// **'Relative Path'**
  String get previewDetailRelativePath;

  /// No description provided for @previewDetailSide.
  ///
  /// In en, this message translates to:
  /// **'Scope'**
  String get previewDetailSide;

  /// No description provided for @previewDetailSourceEntry.
  ///
  /// In en, this message translates to:
  /// **'Source Entry'**
  String get previewDetailSourceEntry;

  /// No description provided for @previewDetailTargetEntry.
  ///
  /// In en, this message translates to:
  /// **'Target Entry'**
  String get previewDetailTargetEntry;

  /// No description provided for @previewDetailName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get previewDetailName;

  /// No description provided for @previewDetailLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get previewDetailLocation;

  /// No description provided for @previewDetailLocationLocal.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get previewDetailLocationLocal;

  /// No description provided for @previewDetailLocationRemote.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get previewDetailLocationRemote;

  /// No description provided for @previewDetailPath.
  ///
  /// In en, this message translates to:
  /// **'Path'**
  String get previewDetailPath;

  /// No description provided for @previewDetailSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get previewDetailSize;

  /// No description provided for @previewDetailModifiedTime.
  ///
  /// In en, this message translates to:
  /// **'Modified Time'**
  String get previewDetailModifiedTime;

  /// No description provided for @previewDetailEntryType.
  ///
  /// In en, this message translates to:
  /// **'Entry Type'**
  String get previewDetailEntryType;

  /// No description provided for @previewDetailEntryTypeDirectory.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get previewDetailEntryTypeDirectory;

  /// No description provided for @previewDetailEntryTypeFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get previewDetailEntryTypeFile;

  /// No description provided for @previewDetailAudioTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get previewDetailAudioTitle;

  /// No description provided for @previewDetailAudioArtist.
  ///
  /// In en, this message translates to:
  /// **'Artist'**
  String get previewDetailAudioArtist;

  /// No description provided for @previewDetailAudioAlbum.
  ///
  /// In en, this message translates to:
  /// **'Album'**
  String get previewDetailAudioAlbum;

  /// No description provided for @previewDetailAudioComposer.
  ///
  /// In en, this message translates to:
  /// **'Composer'**
  String get previewDetailAudioComposer;

  /// No description provided for @previewDetailAudioTrackNumber.
  ///
  /// In en, this message translates to:
  /// **'Track'**
  String get previewDetailAudioTrackNumber;

  /// No description provided for @previewDetailAudioDiscNumber.
  ///
  /// In en, this message translates to:
  /// **'Disc'**
  String get previewDetailAudioDiscNumber;

  /// No description provided for @previewDetailAudioLyrics.
  ///
  /// In en, this message translates to:
  /// **'Lyrics'**
  String get previewDetailAudioLyrics;

  /// No description provided for @previewDetailUnknownValue.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get previewDetailUnknownValue;

  /// No description provided for @previewDetailRefreshing.
  ///
  /// In en, this message translates to:
  /// **'Refreshing entry details...'**
  String get previewDetailRefreshing;

  /// No description provided for @previewDetailRefreshFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to refresh entry details. Showing the existing data instead.'**
  String get previewDetailRefreshFailed;

  /// No description provided for @previewDetailSideSourceOnly.
  ///
  /// In en, this message translates to:
  /// **'Source only'**
  String get previewDetailSideSourceOnly;

  /// No description provided for @previewDetailSideTargetOnly.
  ///
  /// In en, this message translates to:
  /// **'Target only'**
  String get previewDetailSideTargetOnly;

  /// No description provided for @previewDetailSideBoth.
  ///
  /// In en, this message translates to:
  /// **'Source and target'**
  String get previewDetailSideBoth;

  /// No description provided for @previewDetailSideUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get previewDetailSideUnknown;

  /// No description provided for @previewFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All types'**
  String get previewFilterAll;

  /// No description provided for @previewIgnoredExtensions.
  ///
  /// In en, this message translates to:
  /// **'Ignored: {value}'**
  String previewIgnoredExtensions(Object value);

  /// No description provided for @previewFilterMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get previewFilterMore;

  /// No description provided for @previewFilterCollapse.
  ///
  /// In en, this message translates to:
  /// **'Less'**
  String get previewFilterCollapse;

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

  /// No description provided for @previewSectionCount.
  ///
  /// In en, this message translates to:
  /// **'Items in current section: {count}'**
  String previewSectionCount(int count);

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

  /// No description provided for @errorRemoteDirectoryNotSelected.
  ///
  /// In en, this message translates to:
  /// **'The remote device has not selected a target directory yet.'**
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

  /// No description provided for @errorDirectoryNotExists.
  ///
  /// In en, this message translates to:
  /// **'The selected directory no longer exists. Please choose it again.'**
  String get errorDirectoryNotExists;

  /// No description provided for @errorListenPortInUse.
  ///
  /// In en, this message translates to:
  /// **'Failed to start listening because the port is already in use. Pick another port or stop the process using it.'**
  String get errorListenPortInUse;

  /// No description provided for @errorWindowsWriteCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to write to the Windows target directory. Check permissions and file locks, then try again.'**
  String get errorWindowsWriteCreateFailed;

  /// No description provided for @errorWindowsRenameFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to finalize one or more file writes. Check permissions and file locks, then try again.'**
  String get errorWindowsRenameFailed;

  /// No description provided for @errorWindowsDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to delete one or more items from the Windows target directory. Check permissions and file locks, then try again.'**
  String get errorWindowsDeleteFailed;

  /// No description provided for @errorWindowsReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to read one or more Windows source files. Check permissions and file locks, then try again.'**
  String get errorWindowsReadFailed;

  /// No description provided for @errorWindowsDirectoryCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to create one or more target folders. Check permissions and path validity, then try again.'**
  String get errorWindowsDirectoryCreateFailed;

  /// No description provided for @errorWindowsDirectoryListingFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to read the current Windows directory. Please choose another folder.'**
  String get errorWindowsDirectoryListingFailed;

  /// No description provided for @errorWindowsEntryAccessFailed.
  ///
  /// In en, this message translates to:
  /// **'Scanning failed because one or more Windows entries could not be accessed.'**
  String get errorWindowsEntryAccessFailed;

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

  /// No description provided for @commonAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

  /// No description provided for @commonYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get commonYes;

  /// No description provided for @commonNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get commonNo;

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

  /// No description provided for @executionStateLabel.
  ///
  /// In en, this message translates to:
  /// **'Execution status: {status}'**
  String executionStateLabel(Object status);

  /// No description provided for @executionRemotePending.
  ///
  /// In en, this message translates to:
  /// **'Wait for the target preview to finish before running sync.'**
  String get executionRemotePending;

  /// No description provided for @executionRemoteReady.
  ///
  /// In en, this message translates to:
  /// **'The target preview is ready. The current plan can sync local files to the target side.'**
  String get executionRemoteReady;

  /// No description provided for @executionKeepForeground.
  ///
  /// In en, this message translates to:
  /// **'When Android is the target side, keep the target device in foreground. Do not background the app or lock the screen.'**
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
  /// **'Start Sync'**
  String get executionRunRemote;

  /// No description provided for @executionStop.
  ///
  /// In en, this message translates to:
  /// **'Stop Sync'**
  String get executionStop;

  /// No description provided for @executionResultDone.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get executionResultDone;

  /// No description provided for @executionResultPartialDone.
  ///
  /// In en, this message translates to:
  /// **'Partially Completed'**
  String get executionResultPartialDone;

  /// No description provided for @executionResultFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync Failed'**
  String get executionResultFailed;

  /// No description provided for @executionResultProcessed.
  ///
  /// In en, this message translates to:
  /// **'Processed: {done} / {total}'**
  String executionResultProcessed(int done, int total);

  /// No description provided for @executionMetricCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get executionMetricCopy;

  /// No description provided for @executionMetricDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get executionMetricDelete;

  /// No description provided for @executionMetricFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get executionMetricFailed;

  /// No description provided for @executionCancelled.
  ///
  /// In en, this message translates to:
  /// **'Sync ended early. Temporary sync files were cleaned when possible.'**
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

  /// No description provided for @resultStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Execution status: {status}'**
  String resultStatusLabel(Object status);

  /// No description provided for @resultModeLocal.
  ///
  /// In en, this message translates to:
  /// **'Local Debug Copy'**
  String get resultModeLocal;

  /// No description provided for @resultModeRemote.
  ///
  /// In en, this message translates to:
  /// **'Target Sync'**
  String get resultModeRemote;

  /// No description provided for @resultModeUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get resultModeUnknown;

  /// No description provided for @resultStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get resultStatusCompleted;

  /// No description provided for @resultStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get resultStatusCancelled;

  /// No description provided for @resultStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get resultStatusFailed;

  /// No description provided for @resultStatusIdle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get resultStatusIdle;

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
  /// **'If the target side is Android, keep it in foreground and retry.'**
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

  /// No description provided for @settingsGeneralTitle.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsGeneralTitle;

  /// No description provided for @settingsAppearanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearanceTitle;

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

  /// No description provided for @settingsRulesTitle.
  ///
  /// In en, this message translates to:
  /// **'Rules'**
  String get settingsRulesTitle;

  /// No description provided for @settingsDeviceAliasTitle.
  ///
  /// In en, this message translates to:
  /// **'Device Name'**
  String get settingsDeviceAliasTitle;

  /// No description provided for @settingsDeviceAliasDescription.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to use the device model automatically, then fall back to the device type if needed.'**
  String get settingsDeviceAliasDescription;

  /// No description provided for @settingsDeviceAliasField.
  ///
  /// In en, this message translates to:
  /// **'Device Name'**
  String get settingsDeviceAliasField;

  /// No description provided for @settingsDeviceAliasHint.
  ///
  /// In en, this message translates to:
  /// **'For example Bedroom Tablet or My Windows PC'**
  String get settingsDeviceAliasHint;

  /// No description provided for @settingsAutoStartListeningTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto Listen on Launch'**
  String get settingsAutoStartListeningTitle;

  /// No description provided for @settingsAutoStartListeningDescription.
  ///
  /// In en, this message translates to:
  /// **'When enabled, MusicSync automatically starts listening after launch.'**
  String get settingsAutoStartListeningDescription;

  /// No description provided for @settingsIgnoredExtensionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Ignored File Types'**
  String get settingsIgnoredExtensionsTitle;

  /// No description provided for @settingsIgnoredExtensionsDescription.
  ///
  /// In en, this message translates to:
  /// **'Ignored suffix types will be skipped during sync.'**
  String get settingsIgnoredExtensionsDescription;

  /// No description provided for @settingsIgnoredExtensionsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No ignored file types yet'**
  String get settingsIgnoredExtensionsEmpty;

  /// No description provided for @settingsIgnoredExtensionsSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} ignored file types'**
  String settingsIgnoredExtensionsSummary(int count);

  /// No description provided for @settingsIgnoredExtensionField.
  ///
  /// In en, this message translates to:
  /// **'Extension'**
  String get settingsIgnoredExtensionField;

  /// No description provided for @settingsIgnoredExtensionHint.
  ///
  /// In en, this message translates to:
  /// **'For example flac or lrc'**
  String get settingsIgnoredExtensionHint;

  /// No description provided for @settingsIgnoredExtensionRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter an extension'**
  String get settingsIgnoredExtensionRequired;

  /// No description provided for @settingsIgnoredExtensionInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid extension format. Use letters, numbers, underscores, or hyphens only'**
  String get settingsIgnoredExtensionInvalid;

  /// No description provided for @settingsIgnoredExtensionDuplicate.
  ///
  /// In en, this message translates to:
  /// **'This extension already exists'**
  String get settingsIgnoredExtensionDuplicate;

  /// No description provided for @settingsHttpEncryptionTitle.
  ///
  /// In en, this message translates to:
  /// **'HTTP Encryption'**
  String get settingsHttpEncryptionTitle;

  /// No description provided for @settingsHttpEncryptionDescription.
  ///
  /// In en, this message translates to:
  /// **'When enabled, MusicSync uses self-signed HTTPS. When disabled, it falls back to unencrypted HTTP.'**
  String get settingsHttpEncryptionDescription;

  /// No description provided for @settingsThemeModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Theme Mode'**
  String get settingsThemeModeTitle;

  /// No description provided for @settingsThemeModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose light mode, dark mode, or follow the system.'**
  String get settingsThemeModeDescription;

  /// No description provided for @settingsThemeModeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeModeLight;

  /// No description provided for @settingsThemeModeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeModeDark;

  /// No description provided for @settingsThemeModeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeModeSystem;

  /// No description provided for @settingsPaletteTitle.
  ///
  /// In en, this message translates to:
  /// **'Palette'**
  String get settingsPaletteTitle;

  /// No description provided for @settingsPaletteDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose a Material Design palette strategy.'**
  String get settingsPaletteDescription;

  /// No description provided for @settingsPaletteNeutral.
  ///
  /// In en, this message translates to:
  /// **'Neutral'**
  String get settingsPaletteNeutral;

  /// No description provided for @settingsPaletteExpressive.
  ///
  /// In en, this message translates to:
  /// **'Expressive'**
  String get settingsPaletteExpressive;

  /// No description provided for @settingsPaletteTonalSpot.
  ///
  /// In en, this message translates to:
  /// **'Tonal Spot'**
  String get settingsPaletteTonalSpot;

  /// No description provided for @previewTransferDirectionLabel.
  ///
  /// In en, this message translates to:
  /// **'Transfer Status'**
  String get previewTransferDirectionLabel;

  /// No description provided for @previewDirectoryStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Directory Status'**
  String get previewDirectoryStatusLabel;

  /// No description provided for @previewDirectoryStatusLocal.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get previewDirectoryStatusLocal;

  /// No description provided for @previewDirectoryStatusRemote.
  ///
  /// In en, this message translates to:
  /// **'Peer'**
  String get previewDirectoryStatusRemote;

  /// No description provided for @diffTypeCopy.
  ///
  /// In en, this message translates to:
  /// **'COPY'**
  String get diffTypeCopy;

  /// No description provided for @diffTypeDelete.
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get diffTypeDelete;

  /// No description provided for @diffTypeConflict.
  ///
  /// In en, this message translates to:
  /// **'CONFLICT'**
  String get diffTypeConflict;

  /// No description provided for @diffTypeSkip.
  ///
  /// In en, this message translates to:
  /// **'SKIP'**
  String get diffTypeSkip;

  /// No description provided for @diffConflictMetadataMismatch.
  ///
  /// In en, this message translates to:
  /// **'Metadata differs'**
  String get diffConflictMetadataMismatch;

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
    'that was used.',
  );
}
