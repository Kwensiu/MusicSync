import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:music_sync/app/routes/route_names.dart';
import 'package:music_sync/features/home/presentation/pages/home_page.dart';
import 'package:music_sync/features/preview/presentation/pages/preview_conflict_page.dart';
import 'package:music_sync/features/preview/presentation/pages/preview_page.dart';
import 'package:music_sync/features/settings/presentation/pages/settings_page.dart';
import 'package:music_sync/features/transfer/presentation/pages/transfer_page.dart';

final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((Ref ref) {
  return GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        name: RouteNames.home,
        builder: (_, _) => const HomePage(),
      ),
      GoRoute(
        path: '/transfer',
        name: RouteNames.transfer,
        builder: (_, _) => const TransferPage(),
      ),
      GoRoute(
        path: '/preview',
        name: RouteNames.preview,
        builder: (_, _) => const PreviewPage(),
        routes: <RouteBase>[
          GoRoute(
            path: 'conflicts',
            name: RouteNames.previewConflicts,
            builder: (_, _) => const PreviewConflictPage(),
          ),
        ],
      ),
      GoRoute(
        path: '/settings',
        name: RouteNames.settings,
        builder: (_, _) => const SettingsPage(),
      ),
    ],
  );
});
