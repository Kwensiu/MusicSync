import 'package:flutter/widgets.dart';
import 'package:music_sync/l10n/app_localizations_ext.dart';

abstract final class AppErrorCode {
  static const String remoteDeviceDisconnected =
      'error.remoteDeviceDisconnected';
  static const String noRemoteDeviceConnected = 'error.noRemoteDeviceConnected';
  static const String syncCancelled = 'error.syncCancelled';
  static const String directoryUnavailable = 'error.directoryUnavailable';
  static const String windowsWriteCreateFailed =
      'error.windowsWriteCreateFailed';
  static const String windowsRenameFailed = 'error.windowsRenameFailed';
  static const String windowsDeleteFailed = 'error.windowsDeleteFailed';
  static const String windowsReadFailed = 'error.windowsReadFailed';
  static const String windowsDirectoryCreateFailed =
      'error.windowsDirectoryCreateFailed';
  static const String remoteDirectoryNotSelected =
      'error.remoteDirectoryNotSelected';
  static const String connectionRefused = 'error.connectionRefused';
  static const String listenPortInUse = 'error.listenPortInUse';
  static const String connectionTimedOut = 'error.connectionTimedOut';
  static const String remoteProtocolInvalid = 'error.remoteProtocolInvalid';
  static const String directoryAccessDenied = 'error.directoryAccessDenied';
  static const String directoryNotExists = 'error.directoryNotExists';
  static const String windowsDirectoryListingFailed =
      'error.windowsDirectoryListingFailed';
  static const String scanTimedOut = 'error.scanTimedOut';
  static const String windowsEntryAccessFailed =
      'error.windowsEntryAccessFailed';
}

class AppErrorLocalizer {
  static String resolve(String? value) {
    if (value == null || value.isEmpty) {
      return '';
    }
    if (value.contains('errno = 10054') ||
        value.contains('远程主机强迫关闭了一个现有的连接') ||
        value.contains('Remote device disconnected') ||
        value.contains('Peer disconnected')) {
      return AppErrorCode.remoteDeviceDisconnected;
    }
    if (value.contains('Not connected to any peer')) {
      return AppErrorCode.noRemoteDeviceConnected;
    }
    if (value.contains('SyncCancelledException')) {
      return AppErrorCode.syncCancelled;
    }
    if (value.contains('Unable to access the selected directory') ||
        value.contains('not accessible anymore')) {
      return AppErrorCode.directoryUnavailable;
    }
    if (value.contains('Windows write session create failed')) {
      return AppErrorCode.windowsWriteCreateFailed;
    }
    if (value.contains('Windows rename failed')) {
      return AppErrorCode.windowsRenameFailed;
    }
    if (value.contains('Windows delete failed')) {
      return AppErrorCode.windowsDeleteFailed;
    }
    if (value.contains('Windows file read failed')) {
      return AppErrorCode.windowsReadFailed;
    }
    if (value.contains('Windows directory create failed')) {
      return AppErrorCode.windowsDirectoryCreateFailed;
    }
    if (value.contains('No shared directory selected on peer')) {
      return AppErrorCode.remoteDirectoryNotSelected;
    }
    if (value.contains('Connection refused')) {
      return AppErrorCode.connectionRefused;
    }
    if (value.contains('Failed to create server socket') ||
        value.contains('Only one usage of each socket address') ||
        value.contains('errno = 10048')) {
      return AppErrorCode.listenPortInUse;
    }
    if (value.contains('timed out')) {
      return AppErrorCode.connectionTimedOut;
    }
    if (value.contains('Peer handshake failed') ||
        value.contains('Peer handshake payload invalid') ||
        value.contains('Peer scan response invalid') ||
        value.contains('Peer snapshot payload invalid')) {
      return AppErrorCode.remoteProtocolInvalid;
    }
    if (value.contains('Windows directory listing failed')) {
      return AppErrorCode.windowsDirectoryListingFailed;
    }
    if (value.contains('Windows entry access failed')) {
      return AppErrorCode.windowsEntryAccessFailed;
    }
    if (value.contains('Scanning timed out')) {
      return AppErrorCode.scanTimedOut;
    }
    if (value.contains('PathAccessException') ||
        value.contains('拒绝访问') ||
        value.contains('Access is denied')) {
      return AppErrorCode.directoryAccessDenied;
    }
    if (value.contains('Directory does not exist')) {
      return AppErrorCode.directoryNotExists;
    }
    return _stripPrefixes(value);
  }

  static bool isScanTimeout(String? value) {
    return resolve(value) == AppErrorCode.scanTimedOut;
  }

  static String localize(BuildContext context, String? value) {
    final String resolved = resolve(value);
    switch (resolved) {
      case AppErrorCode.remoteDeviceDisconnected:
        return context.l10n.errorRemoteDeviceDisconnected;
      case AppErrorCode.noRemoteDeviceConnected:
        return context.l10n.errorNoRemoteDeviceConnected;
      case AppErrorCode.syncCancelled:
        return context.l10n.executionCancelled;
      case AppErrorCode.directoryUnavailable:
        return context.l10n.errorDirectoryUnavailable;
      case AppErrorCode.windowsWriteCreateFailed:
        return context.l10n.errorWindowsWriteCreateFailed;
      case AppErrorCode.windowsRenameFailed:
        return context.l10n.errorWindowsRenameFailed;
      case AppErrorCode.windowsDeleteFailed:
        return context.l10n.errorWindowsDeleteFailed;
      case AppErrorCode.windowsReadFailed:
        return context.l10n.errorWindowsReadFailed;
      case AppErrorCode.windowsDirectoryCreateFailed:
        return context.l10n.errorWindowsDirectoryCreateFailed;
      case AppErrorCode.remoteDirectoryNotSelected:
        return context.l10n.errorRemoteDirectoryNotSelected;
      case AppErrorCode.connectionRefused:
        return context.l10n.errorConnectionRefused;
      case AppErrorCode.listenPortInUse:
        return context.l10n.errorListenPortInUse;
      case AppErrorCode.connectionTimedOut:
        return context.l10n.errorConnectionTimedOut;
      case AppErrorCode.remoteProtocolInvalid:
        return context.l10n.errorRemoteProtocolInvalid;
      case AppErrorCode.directoryAccessDenied:
        return context.l10n.errorDirectoryAccessDenied;
      case AppErrorCode.directoryNotExists:
        return context.l10n.errorDirectoryNotExists;
      case AppErrorCode.windowsDirectoryListingFailed:
        return context.l10n.errorWindowsDirectoryListingFailed;
      case AppErrorCode.windowsEntryAccessFailed:
        return context.l10n.errorWindowsEntryAccessFailed;
      case AppErrorCode.scanTimedOut:
        return context.l10n.errorScanTimedOut;
      default:
        return resolved;
    }
  }

  static String _stripPrefixes(String value) {
    String next = value;
    if (next.contains('SocketException: ')) {
      next = next.replaceFirst('SocketException: ', '');
    }
    if (next.contains('FileAccessException: ')) {
      next = next.replaceFirst('FileAccessException: ', '');
    }
    if (next.contains('Exception: ')) {
      next = next.replaceFirst('Exception: ', '');
    }
    return next;
  }
}
