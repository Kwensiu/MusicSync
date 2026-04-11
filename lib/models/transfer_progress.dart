enum SyncStage {
  idle,
  connecting,
  scanningSource,
  scanningTarget,
  buildingPlan,
  awaitingConfirmation,
  copying,
  deleting,
  completed,
  cancelled,
  failed,
}

class TransferProgress {
  const TransferProgress({
    required this.stage,
    required this.processedFiles,
    required this.totalFiles,
    required this.processedBytes,
    required this.totalBytes,
    this.copiedCount = 0,
    this.deletedCount = 0,
    this.failedCount = 0,
    this.currentPath,
  });

  final SyncStage stage;
  final int processedFiles;
  final int totalFiles;
  final int processedBytes;
  final int totalBytes;
  final int copiedCount;
  final int deletedCount;
  final int failedCount;
  final String? currentPath;
}
