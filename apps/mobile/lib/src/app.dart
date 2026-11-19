import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/localization/app_strings.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_preferences.dart';
import 'features/auth/session_controller.dart';

class BmsApp extends ConsumerStatefulWidget {
  const BmsApp({super.key});

  @override
  ConsumerState<BmsApp> createState() => _BmsAppState();
}

class _BmsAppState extends ConsumerState<BmsApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(sessionControllerProvider.notifier).restore();
      }
    });
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'BMS',
        theme: ThemeData(colorSchemeSeed: const Color(0xFF17616A)),
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          colorSchemeSeed: const Color(0xFF17616A),
        ),
        themeMode: ref.watch(themeModeProvider),
        locale: ref.watch(localeProvider),
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        routerConfig: ref.watch(appRouterProvider),
      );
}
