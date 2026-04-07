class FileAccessEntry {
  const FileAccessEntry({
    required this.entryId,
    required this.name,
    required this.isDirectory,
    required this.size,
    required this.modifiedTime,
  });

  final String entryId;
  final String name;
  final bool isDirectory;
  final int size;
  final DateTime modifiedTime;
}

class DirectoryHandle {
  const DirectoryHandle({
    required this.entryId,
    required this.displayName,
  });

  final String entryId;
  final String displayName;
}
