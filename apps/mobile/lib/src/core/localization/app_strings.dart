import 'package:material_ui/material_ui.dart';

import '../../features/auth/auth_models.dart';
import '../../features/buildings/building_models.dart';
import '../../features/zones/zone_models.dart';

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
  String get checkApi =>
      isFrench ? 'Vérifier la connexion API' : 'Check API connection';
  String get apiReachable =>
      isFrench ? 'Processus API accessible' : 'API process reachable';
  String get apiUnavailable =>
      isFrench ? 'Connexion API indisponible' : 'API connection unavailable';
  String get statusScope => isFrench
      ? 'Ce contrôle vérifie uniquement la réponse du processus API.'
      : 'This checks only whether the API process responds.';
  String get language => isFrench ? 'Langue' : 'Language';
  String get appearance => isFrench ? 'Apparence' : 'Appearance';
  String get light => isFrench ? 'Clair' : 'Light';
  String get dark => isFrench ? 'Sombre' : 'Dark';
  String get system => isFrench ? 'Système' : 'System';
  String get settingsHelp => isFrench
      ? 'Les préférences s’appliquent pendant cette session.'
      : 'Preferences apply for this session.';
  String get signIn => isFrench ? 'Se connecter' : 'Sign in';
  String get signOut => isFrench ? 'Se déconnecter' : 'Sign out';
  String get email => isFrench ? 'Adresse e-mail' : 'Email address';
  String get password => isFrench ? 'Mot de passe' : 'Password';
  String get showPassword =>
      isFrench ? 'Afficher le mot de passe' : 'Show password';
  String get hidePassword =>
      isFrench ? 'Masquer le mot de passe' : 'Hide password';
  String get invalidEmail => isFrench
      ? 'Saisissez une adresse e-mail valide.'
      : 'Enter a valid email address.';
  String get missingPassword =>
      isFrench ? 'Saisissez votre mot de passe.' : 'Enter your password.';
  String get invalidCredentials => isFrench
      ? 'Adresse e-mail ou mot de passe incorrect.'
      : 'Invalid email or password.';
  String get invalidInput =>
      isFrench ? 'Vérifiez les champs saisis.' : 'Check the submitted fields.';
  String get rateLimited => isFrench
      ? 'Trop de tentatives. Réessayez plus tard.'
      : 'Too many attempts. Try again later.';
  String get networkError => isFrench
      ? 'Réseau indisponible. Réessayez.'
      : 'Network unavailable. Try again.';
  String get serviceError => isFrench
      ? 'Service indisponible. Réessayez.'
      : 'Service unavailable. Try again.';
  String get storageError => isFrench
      ? 'Stockage sécurisé indisponible. Réessayez.'
      : 'Secure storage unavailable. Try again.';
  String get sessionExpired => isFrench
      ? 'Votre session a expiré. Reconnectez-vous.'
      : 'Session expired. Sign in again.';
  String get chooseOrganization =>
      isFrench ? 'Choisir une organisation' : 'Choose organization';
  String get noOrganizations => isFrench
      ? 'Aucune organisation disponible.'
      : 'No organizations available.';
  String get refreshAccess =>
      isFrench ? 'Actualiser les accès' : 'Refresh access';
  String get switchOrganization =>
      isFrench ? 'Changer d’organisation' : 'Switch organization';
  String get retry => isFrench ? 'Réessayer' : 'Retry';
  String get restoringSession =>
      isFrench ? 'Vérification de la session…' : 'Checking session…';
  String get revocationUnconfirmed => isFrench
      ? 'La déconnexion du serveur n’a pas pu être confirmée.'
      : 'Server sign-out could not be confirmed.';
  String get localRemovalFailed => isFrench
      ? 'La suppression locale du jeton n’a pas pu être confirmée. Ne partagez pas cet appareil.'
      : 'Local token removal could not be confirmed. Do not share this device.';
  String get toggleTheme => isFrench ? 'Changer le thème' : 'Toggle theme';
  String get organizationContext =>
      isFrench ? 'Organisation active' : 'Active organization';
  String get browseBuildings =>
      isFrench ? 'Voir les bâtiments' : 'Browse buildings';
  String get buildingsOverview => isFrench
      ? 'Consultez les bâtiments de votre organisation active.'
      : 'View buildings in your active organization.';
  String get loadingBuildings =>
      isFrench ? 'Chargement des bâtiments…' : 'Loading buildings…';
  String get noBuildings => isFrench
      ? 'Aucun bâtiment dans cette organisation.'
      : 'No buildings in this organization.';
  String get loadMore => isFrench ? 'Charger plus' : 'Load more';
  String get buildingUnavailable =>
      isFrench ? 'Bâtiment indisponible.' : 'Building unavailable.';
  String get address => isFrench ? 'Adresse' : 'Address';
  String get timezone => isFrench ? 'Fuseau horaire' : 'Time zone';
  String get code => isFrench ? 'Code' : 'Code';
  String get refreshBuildings =>
      isFrench ? 'Actualiser les bâtiments' : 'Refresh buildings';
  String get building => isFrench ? 'Bâtiment' : 'Building';
  String get floors => isFrench ? 'Étages' : 'Floors';
  String get floor => isFrench ? 'Étage' : 'Floor';
  String get browseFloors => isFrench ? 'Voir les étages' : 'Browse floors';
  String get loadingFloors =>
      isFrench ? 'Chargement des étages…' : 'Loading floors…';
  String get noFloors => isFrench
      ? 'Aucun étage dans ce bâtiment.'
      : 'No floors in this building.';
  String get floorUnavailable =>
      isFrench ? 'Étage indisponible.' : 'Floor unavailable.';
  String get level => isFrench ? 'Niveau' : 'Level';
  String get zones => isFrench ? 'Zones' : 'Zones';
  String get zone => isFrench ? 'Zone' : 'Zone';
  String get browseZones => isFrench ? 'Voir les zones' : 'Browse zones';
  String get loadingZones =>
      isFrench ? 'Chargement des zones…' : 'Loading zones…';
  String get noZones =>
      isFrench ? 'Aucune zone à cet étage.' : 'No zones on this floor.';
  String get zoneUnavailable =>
      isFrench ? 'Zone indisponible.' : 'Zone unavailable.';
  String get zoneType => isFrench ? 'Type de zone' : 'Zone type';
  String get browseEquipment =>
      isFrench ? 'Voir les équipements' : 'Browse equipment';
  String get chooseEquipmentBuilding => isFrench
      ? 'Choisissez un bâtiment pour voir ses équipements.'
      : 'Choose a building to view its equipment.';
  String get equipmentBuildingScope => isFrench
      ? 'Tous les équipements de ce bâtiment'
      : 'All equipment in this building';
  String get equipmentFloorScope => isFrench
      ? 'Équipements de cet étage et de ses zones'
      : 'Equipment on this floor and in its zones';
  String get equipmentZoneScope =>
      isFrench ? 'Équipements de cette zone' : 'Equipment in this zone';
  String get loadingEquipment =>
      isFrench ? 'Chargement des équipements…' : 'Loading equipment…';
  String get noEquipment => isFrench
      ? 'Aucun équipement à cet emplacement.'
      : 'No equipment at this location.';
  String get equipmentUnavailable => isFrench
      ? 'Équipement indisponible ou accès refusé.'
      : 'Equipment unavailable or access denied.';
  String get equipmentType => isFrench ? 'Type d’équipement' : 'Equipment type';
  String get lifecycleStatus =>
      isFrench ? 'État du cycle de vie' : 'Lifecycle status';
  String get buildingLevel =>
      isFrench ? 'Au niveau du bâtiment' : 'Building level';
  String get description => isFrench ? 'Description' : 'Description';
  String get manufacturer => isFrench ? 'Fabricant' : 'Manufacturer';
  String get model => isFrench ? 'Modèle' : 'Model';
  String get serialNumber => isFrench ? 'Numéro de série' : 'Serial number';
  String get installedOn => isFrench ? 'Date d’installation' : 'Installed on';
  String get commissionedOn =>
      isFrench ? 'Date de mise en service' : 'Commissioned on';
  String get specifications =>
      isFrench ? 'Caractéristiques techniques' : 'Engineering specifications';
  String get specificationsUnsupported => isFrench
      ? 'Version des caractéristiques non prise en charge.'
      : 'Specification version is not supported.';
  String get notAvailable => isFrench ? 'Non renseigné' : 'Not available';
  String equipmentDate(String? iso) {
    if (iso == null) return notAvailable;
    return isFrench
        ? '${iso.substring(8, 10)}/${iso.substring(5, 7)}/${iso.substring(0, 4)}'
        : iso;
  }

  String equipmentTypeLabel(String code) => switch (code) {
        'ahu' =>
          isFrench ? 'Centrale de traitement d’air' : 'Air handling unit',
        'fcu' => isFrench ? 'Ventilo-convecteur' : 'Fan coil unit',
        'vav' => isFrench ? 'Boîte VAV' : 'VAV box',
        'fan' => isFrench ? 'Ventilateur' : 'Fan',
        'chiller' => isFrench ? 'Groupe froid' : 'Chiller',
        'boiler' => isFrench ? 'Chaudière' : 'Boiler',
        'heat_pump' => isFrench ? 'Pompe à chaleur' : 'Heat pump',
        'circulation_pump' =>
          isFrench ? 'Pompe de circulation' : 'Circulation pump',
        'motorized_valve' => isFrench ? 'Vanne motorisée' : 'Motorized valve',
        'electrical_meter' =>
          isFrench ? 'Compteur électrique' : 'Electrical meter',
        'water_meter' => isFrench ? 'Compteur d’eau' : 'Water meter',
        'temperature_sensor' =>
          isFrench ? 'Capteur de température' : 'Temperature sensor',
        'pressure_transmitter' =>
          isFrench ? 'Transmetteur de pression' : 'Pressure transmitter',
        'co2_sensor' => isFrench ? 'Capteur de CO₂' : 'CO₂ sensor',
        'ddc_controller' => isFrench ? 'Contrôleur DDC' : 'DDC controller',
        'gateway' => isFrench ? 'Passerelle' : 'Gateway',
        'other' => isFrench ? 'Autre' : 'Other',
        _ => code,
      };
  String equipmentStatusLabel(String code) => switch (code) {
        'planned' => isFrench ? 'Prévu' : 'Planned',
        'installed' => isFrench ? 'Installé' : 'Installed',
        'commissioned' => isFrench ? 'Mis en service' : 'Commissioned',
        'active' => isFrench ? 'Actif' : 'Active',
        'out_of_service' => isFrench ? 'Hors service' : 'Out of service',
        'retired' => isFrench ? 'Retiré' : 'Retired',
        _ => code,
      };
  String specificationLabel(String key) => switch (key) {
        'design_airflow_m3_h' =>
          isFrench ? 'Débit d’air nominal' : 'Design airflow',
        'design_flow_m3_h' => isFrench ? 'Débit nominal' : 'Design flow',
        'design_capacity_kw' =>
          isFrench ? 'Capacité nominale' : 'Design capacity',
        'rated_power_kw' => isFrench ? 'Puissance nominale' : 'Rated power',
        _ => key,
      };
  String zoneTypeLabel(ZoneType type) => switch (type) {
        ZoneType.office => isFrench ? 'Bureau' : 'Office',
        ZoneType.plantRoom => isFrench ? 'Local technique' : 'Plant room',
        ZoneType.common => isFrench ? 'Espace commun' : 'Common area',
        ZoneType.retail => isFrench ? 'Commerce' : 'Retail',
        ZoneType.storage => isFrench ? 'Stockage' : 'Storage',
        ZoneType.other => isFrench ? 'Autre' : 'Other',
      };
  String hierarchyFailureMessage(
          BuildingFailureKind? kind, String unavailable) =>
      switch (kind) {
        BuildingFailureKind.network ||
        BuildingFailureKind.timeout =>
          networkError,
        BuildingFailureKind.rateLimited => rateLimited,
        BuildingFailureKind.unauthorized => sessionExpired,
        BuildingFailureKind.forbidden ||
        BuildingFailureKind.notFound =>
          unavailable,
        BuildingFailureKind.invalidResponse => isFrench
            ? 'Réponse du serveur invalide. Réessayez.'
            : 'Invalid server response. Try again.',
        _ => serviceError,
      };
  String buildingFailureMessage(BuildingFailureKind? kind) => switch (kind) {
        BuildingFailureKind.network ||
        BuildingFailureKind.timeout =>
          networkError,
        BuildingFailureKind.rateLimited => rateLimited,
        BuildingFailureKind.unauthorized => sessionExpired,
        BuildingFailureKind.forbidden ||
        BuildingFailureKind.notFound =>
          buildingUnavailable,
        _ => serviceError,
      };
  String failureMessage(AuthFailureKind? kind) => switch (kind) {
        AuthFailureKind.invalidCredentials => invalidCredentials,
        AuthFailureKind.invalidInput => invalidInput,
        AuthFailureKind.rateLimited => rateLimited,
        AuthFailureKind.network || AuthFailureKind.timeout => networkError,
        AuthFailureKind.storage => storageError,
        AuthFailureKind.unauthorized => sessionExpired,
        _ => serviceError,
      };
  String section(String key) => switch (key) {
        'overview' => isFrench ? 'Vue d’ensemble' : 'Overview',
        'buildings' => isFrench ? 'Bâtiments' : 'Buildings',
        'equipment' => isFrench ? 'Équipements' : 'Equipment',
        'monitoring' => isFrench ? 'Surveillance en direct' : 'Live monitoring',
        'alarms' => isFrench ? 'Alarmes' : 'Alarms',
        'automation' => isFrench ? 'Automatisation' : 'Automation',
        'energy' => isFrench ? 'Gestion de l’énergie' : 'Energy management',
        'reports' => isFrench ? 'Rapports' : 'Reports',
        'maintenance' => isFrench ? 'Maintenance' : 'Maintenance',
        'profile' => isFrench ? 'Profil' : 'User profile',
        'settings' => isFrench ? 'Paramètres' : 'Settings',
        _ => key,
      };
}
