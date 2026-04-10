String formatDisplayPath(String raw) {
  final String value = raw.trim();
  if (value.isEmpty) {
    return value;
  }

  final String normalized = _normalizeCompositeValue(_safeDecode(value));
  if (normalized.startsWith('content://')) {
    final String? treeValue = _extractAfter(normalized, '/tree/');
    final String? documentValue = _extractAfter(normalized, '/document/');
    final String candidate = documentValue ?? treeValue ?? normalized;
    return _formatAndroidDocumentPath(candidate);
  }

  if (_looksLikeAndroidDocumentPath(normalized)) {
    return _formatAndroidDocumentPath(normalized);
  }

  return normalized;
}

String _normalizeCompositeValue(String value) {
  if (!value.contains('|||')) {
    return value;
  }

  final List<String> parts = value
      .split('|||')
      .map((String part) => part.trim())
      .where((String part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) {
    return value;
  }

  final String? documentPart = parts.reversed.cast<String?>().firstWhere(
    (String? part) =>
        part != null &&
        _looksLikeAndroidDocumentPath(part) &&
        !part.startsWith('content://'),
    orElse: () => null,
  );
  if (documentPart != null) {
    return documentPart;
  }
  return parts.last;
}

String _safeDecode(String value) {
  try {
    return Uri.decodeFull(value);
  } on ArgumentError {
    return value;
  }
}

String? _extractAfter(String value, String marker) {
  final int index = value.indexOf(marker);
  if (index < 0) {
    return null;
  }
  return value.substring(index + marker.length);
}

bool _looksLikeAndroidDocumentPath(String value) {
  return value.contains(':') &&
      !value.contains(r':\') &&
      !value.startsWith('http://') &&
      !value.startsWith('https://');
}

String _formatAndroidDocumentPath(String value) {
  final String normalized = value
      .replaceAll('%3A', ':')
      .replaceAll('%2F', '/')
      .replaceAll('%2f', '/')
      .trim();
  final int separator = normalized.indexOf(':');
  if (separator <= 0) {
    return normalized;
  }

  final String volume = normalized.substring(0, separator);
  final String tail = normalized.substring(separator + 1).replaceAll('\\', '/');
  final String volumeLabel = switch (volume.toLowerCase()) {
    'primary' => 'Internal storage',
    _ => volume,
  };
  if (tail.isEmpty) {
    return volumeLabel;
  }
  return '$volumeLabel/$tail';
}
