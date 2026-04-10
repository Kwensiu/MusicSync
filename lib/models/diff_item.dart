import 'package:music_sync/models/file_entry.dart';

enum DiffType { copy, delete, conflict, skip }

class DiffItem {
  const DiffItem({
    required this.type,
    required this.relativePath,
    this.source,
    this.target,
    this.reason,
  });

  final DiffType type;
  final String relativePath;
  final FileEntry? source;
  final FileEntry? target;
  final String? reason;
}
