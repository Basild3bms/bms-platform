import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/localization/app_strings.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_preferences.dart';

class BmsApp extends ConsumerWidget {
  const BmsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
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
        routerConfig: appRouter,
      );
}
