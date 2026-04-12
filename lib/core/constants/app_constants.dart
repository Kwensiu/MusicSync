abstract final class AppConstants {
  static const String appName = 'MusicSync';
  static const int defaultPort = 44888;
  static const int httpControlPortOffset = 0;
  static const int discoveryPort = 44889;
  static const int protocolVersion = 1;
  static const String tempFileSuffix = '.music_sync_tmp';

  /// Audio file extensions that MusicSync considers as music files.
  /// Non-music files are classified as [ConflictCategory.noTag]
  /// in conflict resolution.
  static const Set<String> musicExtensions = <String>{
    'mp3',
    'flac',
    'm4a',
    'aac',
    'ogg',
    'opus',
    'wav',
    'ape',
    'wma',
    'aiff',
    'alac',
  };
}
