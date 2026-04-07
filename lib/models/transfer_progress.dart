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
    this.currentPath,
  });

  final SyncStage stage;
  final int processedFiles;
  final int totalFiles;
  final int processedBytes;
  final int totalBytes;
  final String? currentPath;
}
