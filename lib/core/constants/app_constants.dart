abstract final class AppConstants {
  static const String appName = 'MusicSync';
  static const int defaultPort = 44888;
  static const int httpControlPortOffset = 0;
  static const int discoveryPort = 44889;
  static const int protocolVersion = 2;

  /// Minimum protocol version that supports FileEntry.fingerprint.
  /// Peers with protocolVersion < this value will not return fingerprints
  /// in scan responses, and autoMerge classification must not be activated.
  static const int fingerprintSupportedVersion = 2;
  static const String tempFileSuffix = '.music_sync_tmp';

  /// Number of bytes read from the start of each file to compute a
  /// partial-content fingerprint (XXH64). Shorter files are hashed in full.
  static const int fingerprintSampleSize = 64 * 1024; // 64 KB

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
