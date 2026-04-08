import 'package:flutter_test/flutter_test.dart';
import 'package:music_sync/core/utils/path_display_format.dart';

void main() {
  test('formats Android content tree path into readable display path', () {
    expect(
      formatDisplayPath(
        'content://com.android.externalstorage.documents/tree/primary%3Atest',
      ),
      'Internal storage/test',
    );
  });

  test('formats Android document path with encoded separators', () {
    expect(
      formatDisplayPath('primary:Download%2Fnetease%2Fcloudmusic%2FMusic'),
      'Internal storage/Download/netease/cloudmusic/Music',
    );
  });

  test('uses document-like segment from composite Android path value', () {
    expect(
      formatDisplayPath(
        'content://com.android.externalstorage.documents/tree/primary%3Atest|||primary:test/40mP - Scrap&Build.mp3',
      ),
      'Internal storage/test/40mP - Scrap&Build.mp3',
    );
  });

  test('keeps malformed encoded path safe instead of throwing', () {
    expect(
      () => formatDisplayPath('content://broken%zz/tree/primary%3Atest'),
      returnsNormally,
    );
  });
}
