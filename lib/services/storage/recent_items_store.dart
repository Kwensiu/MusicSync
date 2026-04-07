import 'dart:convert';

import 'package:music_sync/services/file_access/file_access_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecentItemsStore {
  static const String _recentDirectoriesKey = 'recent_directories';
  static const String _recentAddressesKey = 'recent_addresses';
  static const int _maxItems = 8;

  Future<List<DirectoryHandle>> loadRecentDirectories() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final List<String> values =
        preferences.getStringList(_recentDirectoriesKey) ?? const <String>[];
    return values
        .map((String item) => jsonDecode(item) as Map<String, Object?>)
        .map(
          (Map<String, Object?> item) => DirectoryHandle(
            entryId: item['entryId'] as String? ?? '',
            displayName: item['displayName'] as String? ?? '',
          ),
        )
        .where((DirectoryHandle handle) => handle.entryId.isNotEmpty)
        .toList();
  }

  Future<void> saveRecentDirectory(DirectoryHandle handle) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final List<DirectoryHandle> existing = await loadRecentDirectories();
    final List<DirectoryHandle> next = <DirectoryHandle>[
      handle,
      ...existing.where((DirectoryHandle item) => item.entryId != handle.entryId),
    ].take(_maxItems).toList();
    await preferences.setStringList(
      _recentDirectoriesKey,
      next
          .map(
            (DirectoryHandle item) => jsonEncode(<String, Object?>{
              'entryId': item.entryId,
              'displayName': item.displayName,
            }),
          )
          .toList(),
    );
  }

  Future<List<String>> loadRecentAddresses() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    return preferences.getStringList(_recentAddressesKey) ?? const <String>[];
  }

  Future<void> saveRecentAddress(String address) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final List<String> existing = await loadRecentAddresses();
    final List<String> next = <String>[
      address,
      ...existing.where((String item) => item != address),
    ].take(_maxItems).toList();
    await preferences.setStringList(_recentAddressesKey, next);
  }
}
