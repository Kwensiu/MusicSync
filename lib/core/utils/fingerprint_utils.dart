/// Normalizes a fingerprint string for comparison.
///
/// Handles common variations: leading/trailing whitespace and hex case.
/// Returns `null` if the input is `null` or empty after trimming.
String? normalizeFingerprint(String? value) {
  if (value == null) return null;
  final String normalized = value.trim().toLowerCase();
  return normalized.isEmpty ? null : normalized;
}

/// Returns `true` when both fingerprints are non-null and equal after
/// normalization.
bool fingerprintsMatch(String? a, String? b) {
  final String? na = normalizeFingerprint(a);
  final String? nb = normalizeFingerprint(b);
  return na != null && nb != null && na == nb;
}
