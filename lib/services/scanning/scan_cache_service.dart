import 'package:music_sync/models/file_entry.dart';

class ScanCacheService {
  final Map<String, FileEntry> _cache = <String, FileEntry>{};

  FileEntry? get(String key) => _cache[key];

  void put(String key, FileEntry entry) {
    _cache[key] = entry;
  }
}
