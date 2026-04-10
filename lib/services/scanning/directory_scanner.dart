import 'package:music_sync/core/constants/app_constants.dart';
import 'package:music_sync/core/errors/file_access_exception.dart';
import 'package:music_sync/core/utils/path_utils.dart';
import 'package:music_sync/models/file_entry.dart';
import 'package:music_sync/models/scan_snapshot.dart';
import 'package:music_sync/services/file_access/file_access_entry.dart';
import 'package:music_sync/services/file_access/file_access_gateway.dart';
import 'package:music_sync/services/scanning/scan_cache_service.dart';

class DirectoryScanner {
  DirectoryScanner({required this.gateway, required this.cacheService});

  final FileAccessGateway gateway;
  final ScanCacheService cacheService;

  Future<ScanSnapshot> scan({
    required DirectoryHandle root,
    required String deviceId,
  }) async {
    final List<FileEntry> entries = <FileEntry>[];
    final List<String> warnings = <String>[];
    await _walk(root.entryId, '', root.entryId, entries, warnings).timeout(
      const Duration(seconds: 20),
      onTimeout: () {
        throw FileAccessException(
          'Scanning timed out. The folder may be too large or not fully accessible.',
        );
      },
    );

    return ScanSnapshot(
      rootId: root.entryId,
      rootDisplayName: root.displayName,
      deviceId: deviceId,
      scannedAt: DateTime.now(),
      entries: entries,
      cacheVersion: 1,
      warnings: warnings,
    );
  }

  Future<void> _walk(
    String directoryId,
    String relativeBase,
    String sourceId,
    List<FileEntry> output,
    List<String> warnings,
  ) async {
    late final List<FileAccessEntry> children;
    try {
      children = await gateway.listChildren(directoryId);
    } catch (error) {
      if (relativeBase.isEmpty) {
        throw FileAccessException(
          'Unable to access the selected directory. Please choose another folder.',
        );
      }
      warnings.add(relativeBase);
      return;
    }

    for (final FileAccessEntry child in children) {
      if (!child.isDirectory &&
          child.name.endsWith(AppConstants.tempFileSuffix)) {
        continue;
      }
      final String relativePath = joinRelativePath(relativeBase, child.name);
      final FileEntry entry = FileEntry(
        relativePath: relativePath,
        entryId: child.entryId,
        sourceId: sourceId,
        isDirectory: child.isDirectory,
        size: child.size,
        modifiedTime: child.modifiedTime,
      );

      output.add(entry);
      cacheService.put('$sourceId::$relativePath', entry);

      if (child.isDirectory) {
        await _walk(child.entryId, relativePath, sourceId, output, warnings);
      }
    }
  }
}
