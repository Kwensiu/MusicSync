import 'package:music_sync/models/file_entry.dart';

class ScanSnapshot {
  const ScanSnapshot({
    required this.rootId,
    required this.rootDisplayName,
    required this.deviceId,
    required this.scannedAt,
    required this.entries,
    required this.cacheVersion,
    this.warnings = const <String>[],
  });

  final String rootId;
  final String rootDisplayName;
  final String deviceId;
  final DateTime scannedAt;
  final List<FileEntry> entries;
  final int cacheVersion;
  final List<String> warnings;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'rootId': rootId,
      'rootDisplayName': rootDisplayName,
      'deviceId': deviceId,
      'scannedAt': scannedAt.toIso8601String(),
      'entries': entries.map((FileEntry entry) => entry.toJson()).toList(),
      'cacheVersion': cacheVersion,
      'warnings': warnings,
    };
  }

  factory ScanSnapshot.fromJson(Map<String, Object?> json) {
    final Object? rawEntries = json['entries'];
    final Object? rawWarnings = json['warnings'];
    return ScanSnapshot(
      rootId: json['rootId'] as String? ?? '',
      rootDisplayName: json['rootDisplayName'] as String? ?? '',
      deviceId: json['deviceId'] as String? ?? '',
      scannedAt:
          DateTime.tryParse(json['scannedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      entries: rawEntries is List<Object?>
          ? rawEntries
                .whereType<Map<Object?, Object?>>()
                .map(
                  (Map<Object?, Object?> entry) => FileEntry.fromJson(
                    entry.map(
                      (Object? key, Object? value) =>
                          MapEntry(key.toString(), value),
                    ),
                  ),
                )
                .toList()
          : const <FileEntry>[],
      cacheVersion: (json['cacheVersion'] as num?)?.toInt() ?? 1,
      warnings: rawWarnings is List<Object?>
          ? rawWarnings.whereType<String>().toList()
          : const <String>[],
    );
  }

  Map<String, FileEntry> asPathMap() {
    return <String, FileEntry>{
      for (final FileEntry entry in entries)
        if (!entry.isDirectory) entry.relativePath: entry,
    };
  }
}
