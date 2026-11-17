import 'package:go_router/go_router.dart';

import '../../features/shell/section_screen.dart';

const sections = [
  'overview',
  'buildings',
  'equipment',
  'monitoring',
  'alarms',
  'automation',
  'energy',
  'maintenance',
  'profile',
  'settings',
];

final appRouter = GoRouter(
  initialLocation: '/overview',
  routes: [
    GoRoute(
      path: '/:section',
      redirect: (_, state) => sections.contains(state.pathParameters['section'])
          ? null
          : '/overview',
      builder: (_, state) => SectionScreen(
        section: state.pathParameters['section']!,
      ),
    ),
  ],
);
