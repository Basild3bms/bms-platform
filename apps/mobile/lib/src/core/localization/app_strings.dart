import 'package:material_ui/material_ui.dart';

class AppStrings {
  const AppStrings(this.languageCode);

  final String languageCode;
  bool get isFrench => languageCode == 'fr';

  static const supportedLocales = [Locale('en'), Locale('fr')];

  static AppStrings of(BuildContext context) =>
      AppStrings(Localizations.localeOf(context).languageCode);

  String get foundation =>
      isFrench ? 'Fondation mobile BMS — M1' : 'BMS mobile — M1 foundation';
  String get unavailable =>
      isFrench ? 'Fonctionnalité indisponible' : 'Feature unavailable';
  String get futureFeature => isFrench
      ? 'Cette section sera disponible après la mise en place de son API et de ses autorisations.'
      : 'This section will be available after its API and permissions are implemented.';
  String get noLiveData => isFrench
      ? 'Aucune donnée de bâtiment en temps réel n’est disponible.'
      : 'No live building data is available.';
  String get language => isFrench ? 'Langue' : 'Language';
  String get appearance => isFrench ? 'Apparence' : 'Appearance';
  String get light => isFrench ? 'Clair' : 'Light';
  String get dark => isFrench ? 'Sombre' : 'Dark';
  String get system => isFrench ? 'Système' : 'System';
  String get settingsHelp => isFrench
      ? 'Les préférences s’appliquent pendant cette session.'
      : 'Preferences apply for this session.';
  String section(String key) => switch (key) {
        'overview' => isFrench ? 'Vue d’ensemble' : 'Overview',
        'buildings' => isFrench ? 'Bâtiments' : 'Buildings',
        'equipment' => isFrench ? 'Équipements' : 'Equipment',
        'monitoring' => isFrench ? 'Surveillance en direct' : 'Live monitoring',
        'alarms' => isFrench ? 'Alarmes' : 'Alarms',
        'automation' => isFrench ? 'Automatisation' : 'Automation',
        'energy' => isFrench ? 'Énergie' : 'Energy',
        'maintenance' => isFrench ? 'Maintenance' : 'Maintenance',
        'profile' => isFrench ? 'Profil' : 'User profile',
        'settings' => isFrench ? 'Paramètres' : 'Settings',
        _ => key,
      };
}
