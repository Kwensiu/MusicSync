import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_sync/app/app.dart';

void main() {
  testWidgets('app boots to home screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MusicSyncApp(),
      ),
    );

    expect(find.text('MusicSync'), findsOneWidget);
    expect(find.text('Step 1: Connect Remote Device'), findsOneWidget);
  });
}
