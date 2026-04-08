String normalizeExtensionRule(String value) {
  final String normalized =
      value.trim().toLowerCase().replaceFirst(RegExp(r'^\.+'), '');
  return normalized;
}
