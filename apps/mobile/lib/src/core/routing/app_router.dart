import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/login_screen.dart';
import '../../features/auth/organization_screen.dart';
import '../../features/auth/session_controller.dart';
import '../../features/auth/startup_screen.dart';
import '../../features/buildings/building_detail_screen.dart';
import '../../features/shell/section_screen.dart';

const sections = [
  'overview',
  'buildings',
  'equipment',
  'monitoring',
  'alarms',
  'automation',
  'energy',
  'reports',
  'maintenance',
  'profile',
  'settings',
];

final initialRouteProvider = Provider<String>((ref) => '/startup');

class _RouterRefresh extends ChangeNotifier {
  void refresh() => notifyListeners();
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.listen(sessionControllerProvider, (previous, next) => refresh.refresh());
  final router = GoRouter(
    initialLocation: ref.watch(initialRouteProvider),
    refreshListenable: refresh,
    redirect: (_, state) {
      final phase = ref.read(sessionControllerProvider).phase;
      final path = state.uri.path;
      if (phase == SessionPhase.loading || phase == SessionPhase.retry) {
        return path == '/startup' ? null : '/startup';
      }
      if (phase == SessionPhase.unauthenticated) {
        return path == '/login' ? null : '/login';
      }
      if (phase == SessionPhase.chooseOrganization ||
          phase == SessionPhase.noOrganizations) {
        return path == '/organizations' ? null : '/organizations';
      }
      if (path == '/login' || path == '/startup' || path == '/organizations') {
        return '/overview';
      }
      final section = path.startsWith('/') ? path.substring(1) : path;
      if (path.startsWith('/buildings/') &&
          path.split('/').length == 3 &&
          path.split('/').last.isNotEmpty) {
        return null;
      }
      return sections.contains(section) ? null : '/overview';
    },
    routes: [
      GoRoute(
          path: '/startup', builder: (context, state) => const StartupScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
          path: '/organizations',
          builder: (context, state) => const OrganizationScreen()),
      GoRoute(
          path: '/buildings/:building',
          builder: (_, state) => BuildingDetailScreen(
              buildingId: state.pathParameters['building']!)),
      GoRoute(
          path: '/:section',
          builder: (_, state) =>
              SectionScreen(section: state.pathParameters['section']!)),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
