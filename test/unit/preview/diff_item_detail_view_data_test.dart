import 'package:flutter_test/flutter_test.dart';
import 'package:music_sync/features/preview/models/diff_item_detail_view_data.dart';

void main() {
  group('AudioMetadataViewData.diffFields', () {
    test('returns empty set when both are null-equivalent', () {
      const AudioMetadataViewData a = AudioMetadataViewData();
      const AudioMetadataViewData b = AudioMetadataViewData();
      expect(a.diffFields(b), isEmpty);
    });

    test('returns empty set when all fields match', () {
      const AudioMetadataViewData a = AudioMetadataViewData(
        title: 'Song',
        artist: 'Artist',
      );
      const AudioMetadataViewData b = AudioMetadataViewData(
        title: 'Song',
        artist: 'Artist',
      );
      expect(a.diffFields(b), isEmpty);
    });

    test('detects title difference', () {
      const AudioMetadataViewData a = AudioMetadataViewData(title: 'A');
      const AudioMetadataViewData b = AudioMetadataViewData(title: 'B');
      expect(a.diffFields(b), contains('title'));
    });

    test('treats null and empty as equal', () {
      const AudioMetadataViewData a = AudioMetadataViewData(title: '');
      const AudioMetadataViewData b = AudioMetadataViewData();
      expect(a.diffFields(b), isEmpty);
    });

    test('detects multiple differences', () {
      const AudioMetadataViewData a = AudioMetadataViewData(
        title: 'A',
        artist: 'X',
        album: 'Same',
      );
      const AudioMetadataViewData b = AudioMetadataViewData(
        title: 'B',
        artist: 'Y',
        album: 'Same',
      );
      final Set<String> diffs = a.diffFields(b);
      expect(diffs, containsAll(<String>['title', 'artist']));
      expect(diffs, isNot(contains('album')));
    });

    test('detects lyrics difference', () {
      const AudioMetadataViewData a = AudioMetadataViewData(lyrics: 'la la');
      const AudioMetadataViewData b = AudioMetadataViewData(lyrics: 'lo lo');
      expect(a.diffFields(b), contains('lyrics'));
    });

    test('handles null other', () {
      const AudioMetadataViewData a = AudioMetadataViewData(title: 'Song');
      expect(a.diffFields(null), contains('title'));
    });
  });
}
