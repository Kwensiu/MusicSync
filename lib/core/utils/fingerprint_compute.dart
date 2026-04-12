import 'dart:typed_data';

import 'package:xxh3/xxh3.dart';

/// Computes a partial-content XXH3 fingerprint for the given byte stream.
///
/// Reads up to [sampleSize] bytes from [stream], then returns the hex-encoded
/// XXH3-64 digest.  If the stream yields fewer than [sampleSize] bytes the
/// whole content is hashed.  Returns `null` when the stream is empty or an
/// error occurs.
Future<String?> computePartialFingerprint(
  Stream<List<int>> stream, {
  int sampleSize = 64 * 1024,
}) async {
  try {
    final XXH3State hash = xxh3Stream();
    int totalRead = 0;

    await for (final List<int> chunk in stream) {
      final Uint8List typed = Uint8List.fromList(chunk);
      if (totalRead + typed.length <= sampleSize) {
        hash.update(typed);
        totalRead += typed.length;
      } else {
        final int remaining = sampleSize - totalRead;
        hash.update(Uint8List.sublistView(typed, 0, remaining));
        totalRead = sampleSize;
        break;
      }
    }

    if (totalRead == 0) return null;
    return hash.digestString();
  } catch (_) {
    return null;
  }
}
