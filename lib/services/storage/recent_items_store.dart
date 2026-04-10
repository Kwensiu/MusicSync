import 'dart:convert';

import 'package:music_sync/services/file_access/file_access_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecentDirectoryRecord {
  const RecentDirectoryRecord({
    required this.handle,
    this.note,
    this.lastUsedAt,
  });

  final DirectoryHandle handle;
  final String? note;
  final DateTime? lastUsedAt;

  String get label => (note != null && note!.trim().isNotEmpty)
      ? note!.trim()
      : handle.displayName;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'entryId': handle.entryId,
      'displayName': handle.displayName,
      'note': note,
      'lastUsedAt': lastUsedAt?.toIso8601String(),
    };
  }

  factory RecentDirectoryRecord.fromJson(Map<String, Object?> json) {
    return RecentDirectoryRecord(
      handle: DirectoryHandle(
        entryId: json['entryId'] as String? ?? '',
        displayName: json['displayName'] as String? ?? '',
      ),
      note: json['note'] as String?,
      lastUsedAt: _parseDateTime(json['lastUsedAt']),
    );
  }
}

class RecentAddressRecord {
  // TODO(http-fingerprint): if we pin HTTPS peers by certificate fingerprint,
  // recent/manual addresses should be able to persist that fingerprint too.
  const RecentAddressRecord({
    required this.address,
    this.note,
    this.lastUsedAt,
  });

  final String address;
  final String? note;
  final DateTime? lastUsedAt;

  String get label =>
      (note != null && note!.trim().isNotEmpty) ? note!.trim() : address;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'address': address,
      'note': note,
      'lastUsedAt': lastUsedAt?.toIso8601String(),
    };
  }

  factory RecentAddressRecord.fromJson(Map<String, Object?> json) {
    return RecentAddressRecord(
      address: json['address'] as String? ?? '',
      note: json['note'] as String?,
      lastUsedAt: _parseDateTime(json['lastUsedAt']),
    );
  }
}

class RecentItemsStore {
  static const String _recentDirectoriesKey = 'recent_directories';
  static const String _recentAddressesKey = 'recent_addresses';
  static const int _maxItems = 8;

  Future<List<DirectoryHandle>> loadRecentDirectories() async {
    final List<RecentDirectoryRecord> records =
        await loadRecentDirectoryRecords();
    return records.map((RecentDirectoryRecord item) => item.handle).toList();
  }

  Future<List<RecentDirectoryRecord>> loadRecentDirectoryRecords() async {
    try {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      final List<String> values =
          preferences.getStringList(_recentDirectoriesKey) ?? const <String>[];
      final List<RecentDirectoryRecord> records = values
          .map(_decodeDirectoryRecord)
          .where((RecentDirectoryRecord item) => item.handle.entryId.isNotEmpty)
          .toList();
      return records;
    } catch (_) {
      return const <RecentDirectoryRecord>[];
    }
  }

  Future<Map<String, String>> loadRecentDirectoryLabels() async {
    final List<RecentDirectoryRecord> records =
        await loadRecentDirectoryRecords();
    return <String, String>{
      for (final RecentDirectoryRecord item in records)
        item.handle.entryId: item.label,
    };
  }

  Future<void> saveRecentDirectory(DirectoryHandle handle) async {
    final List<RecentDirectoryRecord> existing =
        await loadRecentDirectoryRecords();
    final RecentDirectoryRecord? previous = existing
        .cast<RecentDirectoryRecord?>()
        .firstWhere(
          (RecentDirectoryRecord? item) =>
              item?.handle.entryId == handle.entryId,
          orElse: () => null,
        );
    final RecentDirectoryRecord nextRecord = RecentDirectoryRecord(
      handle: handle,
      note: previous?.note,
      lastUsedAt: DateTime.now(),
    );
    final List<RecentDirectoryRecord> next = <RecentDirectoryRecord>[
      nextRecord,
      ...existing.where(
        (RecentDirectoryRecord item) => item.handle.entryId != handle.entryId,
      ),
    ];
    await _saveDirectoryRecords(next);
  }

  Future<void> removeRecentDirectory(String entryId) async {
    final List<RecentDirectoryRecord> existing =
        await loadRecentDirectoryRecords();
    await _saveDirectoryRecords(
      existing
          .where((RecentDirectoryRecord item) => item.handle.entryId != entryId)
          .toList(),
    );
  }

  Future<void> updateRecentDirectoryNote(String entryId, String? note) async {
    final List<RecentDirectoryRecord> existing =
        await loadRecentDirectoryRecords();
    await _saveDirectoryRecords(
      existing
          .map(
            (RecentDirectoryRecord item) => item.handle.entryId == entryId
                ? RecentDirectoryRecord(
                    handle: item.handle,
                    note: _normalizeNote(note),
                    lastUsedAt: item.lastUsedAt,
                  )
                : item,
          )
          .toList(),
    );
  }

  Future<void> reorderRecentDirectories(
    List<RecentDirectoryRecord> records,
  ) async {
    await _saveDirectoryRecords(records);
  }

  Future<List<String>> loadRecentAddresses() async {
    final List<RecentAddressRecord> records = await loadRecentAddressRecords();
    return records.map((RecentAddressRecord item) => item.address).toList();
  }

  Future<List<RecentAddressRecord>> loadRecentAddressRecords() async {
    try {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      final List<String> values =
          preferences.getStringList(_recentAddressesKey) ?? const <String>[];
      final List<RecentAddressRecord> records = values
          .map(_decodeAddressRecord)
          .where((RecentAddressRecord item) => item.address.isNotEmpty)
          .toList();
      return records;
    } catch (_) {
      return const <RecentAddressRecord>[];
    }
  }

  Future<Map<String, String>> loadRecentAddressLabels() async {
    final List<RecentAddressRecord> records = await loadRecentAddressRecords();
    return <String, String>{
      for (final RecentAddressRecord item in records) item.address: item.label,
    };
  }

  Future<void> saveRecentAddress(String address) async {
    final List<RecentAddressRecord> existing = await loadRecentAddressRecords();
    final RecentAddressRecord? previous = existing
        .cast<RecentAddressRecord?>()
        .firstWhere(
          (RecentAddressRecord? item) => item?.address == address,
          orElse: () => null,
        );
    final RecentAddressRecord nextRecord = RecentAddressRecord(
      address: address,
      note: previous?.note,
      lastUsedAt: DateTime.now(),
    );
    final List<RecentAddressRecord> next = <RecentAddressRecord>[
      nextRecord,
      ...existing.where((RecentAddressRecord item) => item.address != address),
    ];
    await _saveAddressRecords(next);
  }

  Future<void> removeRecentAddress(String address) async {
    final List<RecentAddressRecord> existing = await loadRecentAddressRecords();
    await _saveAddressRecords(
      existing
          .where((RecentAddressRecord item) => item.address != address)
          .toList(),
    );
  }

  Future<void> updateRecentAddress({
    required String oldAddress,
    required String newAddress,
    String? note,
  }) async {
    final String normalizedAddress = newAddress.trim();
    final List<RecentAddressRecord> existing = await loadRecentAddressRecords();
    final RecentAddressRecord? current = existing
        .cast<RecentAddressRecord?>()
        .firstWhere(
          (RecentAddressRecord? item) => item?.address == oldAddress,
          orElse: () => null,
        );
    if (current == null || normalizedAddress.isEmpty) {
      return;
    }
    final List<RecentAddressRecord> next = existing
        .where(
          (RecentAddressRecord item) =>
              item.address != oldAddress && item.address != normalizedAddress,
        )
        .toList();
    next.add(
      RecentAddressRecord(
        address: normalizedAddress,
        note: _normalizeNote(note),
        lastUsedAt: current.lastUsedAt,
      ),
    );
    await _saveAddressRecords(next);
  }

  Future<void> reorderRecentAddresses(List<RecentAddressRecord> records) async {
    await _saveAddressRecords(records);
  }

  Future<void> _saveDirectoryRecords(
    List<RecentDirectoryRecord> records,
  ) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _recentDirectoriesKey,
      records
          .take(_maxItems)
          .map((RecentDirectoryRecord item) => jsonEncode(item.toJson()))
          .toList(),
    );
  }

  Future<void> _saveAddressRecords(List<RecentAddressRecord> records) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _recentAddressesKey,
      records
          .take(_maxItems)
          .map((RecentAddressRecord item) => jsonEncode(item.toJson()))
          .toList(),
    );
  }

  RecentDirectoryRecord _decodeDirectoryRecord(String item) {
    final Object? decoded = jsonDecode(item);
    if (decoded is Map<String, Object?>) {
      return RecentDirectoryRecord.fromJson(decoded);
    }
    throw const FormatException('Invalid recent directory payload.');
  }

  RecentAddressRecord _decodeAddressRecord(String item) {
    final Object? decoded = jsonDecode(item);
    if (decoded is String) {
      return RecentAddressRecord(address: decoded);
    }
    if (decoded is Map<String, Object?>) {
      return RecentAddressRecord.fromJson(decoded);
    }
    return RecentAddressRecord(address: item);
  }
}

DateTime? _parseDateTime(Object? value) {
  final String? text = value as String?;
  if (text == null || text.isEmpty) {
    return null;
  }
  return DateTime.tryParse(text);
}

String? _normalizeNote(String? value) {
  final String trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}
