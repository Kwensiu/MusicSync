import 'package:flutter_test/flutter_test.dart';
import 'package:music_sync/core/constants/app_constants.dart';
import 'package:music_sync/core/utils/fingerprint_utils.dart';

void main() {
  group('normalizeFingerprint', () {
    test('returns null for null input', () {
      expect(normalizeFingerprint(null), isNull);
    });

    test('returns null for empty string', () {
      expect(normalizeFingerprint(''), isNull);
    });

    test('returns null for whitespace-only string', () {
      expect(normalizeFingerprint('   '), isNull);
    });

    test('trims and lowercases', () {
      expect(normalizeFingerprint('  ABC123  '), 'abc123');
    });
  });

  group('fingerprintsMatch', () {
    test('returns false when either is null', () {
      expect(fingerprintsMatch(null, 'abc'), isFalse);
      expect(fingerprintsMatch('abc', null), isFalse);
      expect(fingerprintsMatch(null, null), isFalse);
    });

    test('returns true for matching fingerprints', () {
      expect(fingerprintsMatch('abc', 'ABC'), isTrue);
    });

    test('returns false for different fingerprints', () {
      expect(fingerprintsMatch('abc', 'def'), isFalse);
    });
  });

  group('canUseFingerprintClassification', () {
    test('returns false when peer version is too old', () {
      expect(
        canUseFingerprintClassification(
          peerProtocolVersion: 1,
          localFingerprint: 'abc',
          remoteFingerprint: 'abc',
        ),
        isFalse,
      );
    });

    test('returns false when local fingerprint is null', () {
      expect(
        canUseFingerprintClassification(
          peerProtocolVersion: AppConstants.fingerprintSupportedVersion,
          localFingerprint: null,
          remoteFingerprint: 'abc',
        ),
        isFalse,
      );
    });

    test('returns false when remote fingerprint is null', () {
      expect(
        canUseFingerprintClassification(
          peerProtocolVersion: AppConstants.fingerprintSupportedVersion,
          localFingerprint: 'abc',
          remoteFingerprint: null,
        ),
        isFalse,
      );
    });

    test('returns false when fingerprints differ', () {
      expect(
        canUseFingerprintClassification(
          peerProtocolVersion: AppConstants.fingerprintSupportedVersion,
          localFingerprint: 'abc',
          remoteFingerprint: 'def',
        ),
        isFalse,
      );
    });

    test('returns true when all conditions are met', () {
      expect(
        canUseFingerprintClassification(
          peerProtocolVersion: AppConstants.fingerprintSupportedVersion,
          localFingerprint: 'abc',
          remoteFingerprint: 'ABC',
        ),
        isTrue,
      );
    });
  });
}
