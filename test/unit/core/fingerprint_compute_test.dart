import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_sync/core/utils/fingerprint_compute.dart';

void main() {
  test('computes fingerprint from a small stream', () async {
    final Stream<List<int>> stream = Stream.value(
      Uint8List.fromList([1, 2, 3]),
    );
    final String? result = await computePartialFingerprint(stream);
    expect(result, isNotNull);
    expect(result!.length, 16); // XXH3-64 hex string is 16 chars
  });

  test('returns null for empty stream', () async {
    final Stream<List<int>> stream = Stream.empty();
    final String? result = await computePartialFingerprint(stream);
    expect(result, isNull);
  });

  test('respects sampleSize limit', () async {
    // 128 bytes of data, but sampleSize = 8 → only first 8 bytes are hashed
    final Uint8List fullData = Uint8List.fromList(
      List<int>.generate(128, (int i) => i),
    );
    final Uint8List partialData = Uint8List.fromList(
      List<int>.generate(8, (int i) => i),
    );

    final String? fullHash = await computePartialFingerprint(
      Stream.value(fullData),
      sampleSize: 8,
    );
    final String? partialHash = await computePartialFingerprint(
      Stream.value(partialData),
    );

    expect(fullHash, partialHash);
  });

  test('handles multi-chunk stream', () async {
    final Stream<List<int>> stream = Stream.fromIterable([
      Uint8List.fromList([1, 2]),
      Uint8List.fromList([3, 4]),
    ]);
    final String? result = await computePartialFingerprint(stream);
    expect(result, isNotNull);
  });

  test('returns null on stream error', () async {
    final Stream<List<int>> stream = Stream.error(Exception('fail'));
    final String? result = await computePartialFingerprint(stream);
    expect(result, isNull);
  });
}
