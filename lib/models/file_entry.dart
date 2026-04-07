class FileEntry {
  const FileEntry({
    required this.relativePath,
    required this.entryId,
    required this.sourceId,
    required this.isDirectory,
    required this.size,
    required this.modifiedTime,
    this.fingerprint,
  });

  final String relativePath;
  final String entryId;
  final String sourceId;
  final bool isDirectory;
  final int size;
  final DateTime modifiedTime;
  final String? fingerprint;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'relativePath': relativePath,
      'entryId': entryId,
      'sourceId': sourceId,
      'isDirectory': isDirectory,
      'size': size,
      'modifiedTime': modifiedTime.toIso8601String(),
      'fingerprint': fingerprint,
    };
  }

  factory FileEntry.fromJson(Map<String, Object?> json) {
    return FileEntry(
      relativePath: json['relativePath'] as String? ?? '',
      entryId: json['entryId'] as String? ?? '',
      sourceId: json['sourceId'] as String? ?? '',
      isDirectory: json['isDirectory'] as bool? ?? false,
      size: (json['size'] as num?)?.toInt() ?? 0,
      modifiedTime: DateTime.tryParse(
            json['modifiedTime'] as String? ?? '',
          ) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      fingerprint: json['fingerprint'] as String?,
    );
  }
}
