String formatBytes(int bytes) {
  const List<String> units = <String>['B', 'KB', 'MB', 'GB', 'TB'];

  double value = bytes.toDouble();
  int unitIndex = 0;

  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }

  final String formatted = value >= 10 || unitIndex == 0
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);

  return '$formatted ${units[unitIndex]}';
}
