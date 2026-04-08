import 'package:music_sync/services/file_access/file_access_entry.dart';
import 'package:music_sync/services/file_access/file_access_gateway.dart';

class DirectoryPreflightResult {
  const DirectoryPreflightResult({
    required this.hasRisk,
    required this.sampledDirectories,
    required this.sampledFiles,
    required this.sampledChildren,
    required this.reasons,
  });

  final bool hasRisk;
  final int sampledDirectories;
  final int sampledFiles;
  final int sampledChildren;
  final List<String> reasons;
}

class DirectoryPreflightService {
  DirectoryPreflightService(this._gateway);

  final FileAccessGateway _gateway;

  static const int _maxRootChildrenSample = 120;
  static const int _maxNestedDirectoriesSample = 24;

  Future<DirectoryPreflightResult> inspect(DirectoryHandle handle) async {
    final List<FileAccessEntry> rootChildren =
        await _gateway.listChildren(handle.entryId);
    final int sampledChildren = rootChildren.length;
    int sampledDirectories = 0;
    int sampledFiles = 0;
    final List<String> reasons = <String>[];

    final Iterable<FileAccessEntry> limitedRootChildren =
        rootChildren.take(_maxRootChildrenSample);

    for (final FileAccessEntry child in limitedRootChildren) {
      if (child.isDirectory) {
        sampledDirectories++;
      } else {
        sampledFiles++;
      }
    }

    if (sampledChildren > _maxRootChildrenSample) {
      reasons.add('many_root_children');
    }

    int nestedDirectoryChecks = 0;
    for (final FileAccessEntry child in limitedRootChildren) {
      if (!child.isDirectory ||
          nestedDirectoryChecks >= _maxNestedDirectoriesSample) {
        continue;
      }
      nestedDirectoryChecks++;
      try {
        final List<FileAccessEntry> nestedChildren =
            await _gateway.listChildren(child.entryId);
        if (nestedChildren.length > _maxRootChildrenSample) {
          reasons.add('dense_nested_directory');
          break;
        }
      } catch (_) {
        reasons.add('inaccessible_subdirectory');
        break;
      }
    }

    final String lowerName = handle.displayName.toLowerCase();
    if (lowerName.contains('appdata') ||
        lowerName.contains('programdata') ||
        lowerName.contains('windows') ||
        lowerName.contains('system volume information') ||
        lowerName.contains(r'$recycle.bin')) {
      reasons.add('system_like_directory');
    }

    return DirectoryPreflightResult(
      hasRisk: reasons.isNotEmpty,
      sampledDirectories: sampledDirectories,
      sampledFiles: sampledFiles,
      sampledChildren: sampledChildren,
      reasons: reasons,
    );
  }
}
