import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/login_screen.dart';
import '../../features/auth/organization_screen.dart';
import '../../features/auth/session_controller.dart';
import '../../features/auth/startup_screen.dart';
import '../../features/buildings/building_detail_screen.dart';
import '../../features/floors/floor_detail_screen.dart';
import '../../features/floors/floors_screen.dart';
import '../../features/zones/zone_detail_screen.dart';
import '../../features/zones/zones_screen.dart';
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
      final parts = path.split('/');
      if (parts.length >= 3 &&
          parts[1] == 'buildings' &&
          parts.skip(2).every((part) => part.isNotEmpty) &&
          (parts.length == 3 ||
              (parts.length == 4 && parts[3] == 'floors') ||
              (parts.length == 5 && parts[3] == 'floors') ||
              (parts.length == 6 &&
                  parts[3] == 'floors' &&
                  parts[5] == 'zones') ||
              (parts.length == 7 &&
                  parts[3] == 'floors' &&
                  parts[5] == 'zones'))) {
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
          path: '/buildings/:building/floors',
          builder: (_, state) =>
              FloorsScreen(buildingId: state.pathParameters['building']!)),
      GoRoute(
          path: '/buildings/:building/floors/:floor',
          builder: (_, state) => FloorDetailScreen(
              buildingId: state.pathParameters['building']!,
              floorId: state.pathParameters['floor']!)),
      GoRoute(
          path: '/buildings/:building/floors/:floor/zones',
          builder: (_, state) => ZonesScreen(
              buildingId: state.pathParameters['building']!,
              floorId: state.pathParameters['floor']!)),
      GoRoute(
          path: '/buildings/:building/floors/:floor/zones/:zone',
          builder: (_, state) => ZoneDetailScreen(
              buildingId: state.pathParameters['building']!,
              floorId: state.pathParameters['floor']!,
              zoneId: state.pathParameters['zone']!)),
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
