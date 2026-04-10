abstract final class HttpSyncRoutes {
  static const String apiBase = '/api/v1';

  static const String hello = '$apiBase/hello';
  static const String sessionClose = '$apiBase/session-close';
  static const String directoryStatus = '$apiBase/directory-status';
  static const String scan = '$apiBase/scan';
  static const String entryDetail = '$apiBase/entry-detail';
  static const String syncSessionState = '$apiBase/sync-session-state';
  static const String beginCopy = '$apiBase/begin-copy';
  static const String writeChunk = '$apiBase/write-chunk';
  static const String finishCopy = '$apiBase/finish-copy';
  static const String abortCopy = '$apiBase/abort-copy';
  static const String deleteEntry = '$apiBase/delete-entry';
}
