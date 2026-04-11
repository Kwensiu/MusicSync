import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_sync/app/app.dart';
import 'package:music_sync/features/home/presentation/pages/home_page.dart';

void main() {
  testWidgets('app boots to home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MusicSyncApp()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(MusicSyncApp), findsOneWidget);
    expect(find.byType(HomePage), findsOneWidget);
  });
}
