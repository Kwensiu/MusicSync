import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_sync/core/constants/app_constants.dart';
import 'package:music_sync/services/file_access/file_access_entry.dart';
import 'package:music_sync/services/file_access/file_access_gateway.dart';
import 'package:music_sync/services/file_access/file_access_provider.dart';

class TempFileCleanupResult {
  const TempFileCleanupResult({
    required this.deletedCount,
    required this.failedPaths,
  });

  final int deletedCount;
  final List<String> failedPaths;
}

class TempFileCleanupService {
  const TempFileCleanupService(this._gateway);

  final FileAccessGateway _gateway;

  Future<bool> hasTempFiles({required String rootId}) async {
    bool found = false;
    await _walk(
      directoryId: rootId,
      relativeBase: '',
      onTempFile: (FileAccessEntry _, String _) async {
        found = true;
      },
      onDirectoryError: (_) {},
      shouldStop: () => found,
    );
    return found;
  }

  Future<TempFileCleanupResult> cleanup({required String rootId}) async {
    int deletedCount = 0;
    final List<String> failedPaths = <String>[];
    await _walk(
      directoryId: rootId,
      relativeBase: '',
      onTempFile: (FileAccessEntry entry, String relativePath) async {
        try {
          await _gateway.deleteEntry(entry.entryId);
          deletedCount++;
        } catch (_) {
          failedPaths.add(relativePath);
        }
      },
      onDirectoryError: (String relativePath) {
        failedPaths.add(relativePath);
      },
      shouldStop: () => false,
    );
    return TempFileCleanupResult(
      deletedCount: deletedCount,
      failedPaths: failedPaths,
    );
  }

  Future<void> _walk({
    required String directoryId,
    required String relativeBase,
    required Future<void> Function(FileAccessEntry entry, String relativePath)
    onTempFile,
    required void Function(String relativePath) onDirectoryError,
    required bool Function() shouldStop,
  }) async {
    if (shouldStop()) {
      return;
    }
    late final List<FileAccessEntry> children;
    try {
      children = await _gateway.listChildren(directoryId);
    } catch (_) {
      onDirectoryError(relativeBase.isEmpty ? '.' : relativeBase);
      return;
    }

    for (final FileAccessEntry child in children) {
      if (shouldStop()) {
        return;
      }
      final String relativePath = relativeBase.isEmpty
          ? child.name
          : '$relativeBase/${child.name}';
      if (child.isDirectory) {
        await _walk(
          directoryId: child.entryId,
          relativeBase: relativePath,
          onTempFile: onTempFile,
          onDirectoryError: onDirectoryError,
          shouldStop: shouldStop,
        );
        continue;
      }
      if (child.name.endsWith(AppConstants.tempFileSuffix)) {
        await onTempFile(child, relativePath);
      }
    }
  }
}

final Provider<TempFileCleanupService> tempFileCleanupServiceProvider =
    Provider<TempFileCleanupService>(
      (Ref ref) => TempFileCleanupService(ref.watch(fileAccessGatewayProvider)),
    );
