import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;

  void setMode(ThemeMode mode) => state = mode;
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

class LocaleController extends Notifier<Locale> {
  @override
  Locale build() => const Locale('en');

  void setLocale(Locale locale) => state = locale;
}

final localeProvider = NotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);
