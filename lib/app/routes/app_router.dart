import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:music_sync/app/routes/route_names.dart';
import 'package:music_sync/features/execution/presentation/pages/result_page.dart';
import 'package:music_sync/features/home/presentation/pages/home_page.dart';
import 'package:music_sync/features/settings/presentation/pages/settings_page.dart';

final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((Ref ref) {
  return GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        name: RouteNames.home,
        builder: (_, __) => const HomePage(),
      ),
      GoRoute(
        path: '/result',
        name: RouteNames.result,
        builder: (_, __) => const ResultPage(),
      ),
      GoRoute(
        path: '/settings',
        name: RouteNames.settings,
        builder: (_, __) => const SettingsPage(),
      ),
    ],
  );
});
