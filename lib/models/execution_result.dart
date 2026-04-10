class ExecutionResult {
  const ExecutionResult({
    required this.copiedCount,
    required this.deletedCount,
    required this.failedCount,
    required this.totalBytes,
    required this.targetRoot,
    this.lastError,
  });

  final int copiedCount;
  final int deletedCount;
  final int failedCount;
  final int totalBytes;
  final String targetRoot;
  final String? lastError;

  const factory ExecutionResult.empty() = _EmptyExecutionResult;
}

class _EmptyExecutionResult extends ExecutionResult {
  const _EmptyExecutionResult()
    : super(
        copiedCount: 0,
        deletedCount: 0,
        failedCount: 0,
        totalBytes: 0,
        targetRoot: '',
      );
}
