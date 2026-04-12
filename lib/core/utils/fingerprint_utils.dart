import 'package:music_sync/core/constants/app_constants.dart';

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

/// Returns `true` when fingerprint-based classification is allowed.
///
/// Consolidates three checks into a single guard:
/// 1. [peerProtocolVersion] must be >= [AppConstants.fingerprintSupportedVersion]
/// 2. Both [localFingerprint] and [remoteFingerprint] must be valid
///    (non-null, non-empty after normalization)
/// 3. [fingerprintsMatch] must return `true`
///
/// If any check fails, the caller must fall back to size + mTime comparison
/// and must NOT activate autoMerge classification.
bool canUseFingerprintClassification({
  required int peerProtocolVersion,
  required String? localFingerprint,
  required String? remoteFingerprint,
}) {
  if (peerProtocolVersion < AppConstants.fingerprintSupportedVersion) {
    return false;
  }
  final String? na = normalizeFingerprint(localFingerprint);
  final String? nb = normalizeFingerprint(remoteFingerprint);
  if (na == null || nb == null) {
    return false;
  }
  return na == nb;
}
