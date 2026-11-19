import 'package:bms_mobile/src/app.dart';
import 'package:bms_mobile/src/core/routing/app_router.dart';
import 'package:bms_mobile/src/core/theme/app_preferences.dart';
import 'package:bms_mobile/src/features/auth/session_controller.dart';
import 'package:bms_mobile/src/features/buildings/building_models.dart';
import 'package:bms_mobile/src/features/buildings/buildings_controller.dart';
import 'package:bms_mobile/src/features/floors/floor_models.dart';
import 'package:bms_mobile/src/features/floors/floors_controller.dart';
import 'package:bms_mobile/src/features/floors/floor_repository.dart';
import 'package:bms_mobile/src/features/floors/floors_screen.dart';
import 'package:bms_mobile/src/features/floors/hierarchy_controller.dart';
import 'package:bms_mobile/src/features/zones/zone_models.dart';
import 'package:bms_mobile/src/features/zones/zone_repository.dart';
import 'package:bms_mobile/src/features/zones/zone_detail_screen.dart';
import 'package:bms_mobile/src/features/zones/zones_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'support/authenticated_session.dart';
import 'hierarchy_controller_test.dart' as fixture;

final building = BuildingRecord(
    id: 'building-1',
    organizationId: 'north',
    name: 'North Office',
    code: 'N-001',
    address: null,
    timezone: 'UTC',
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026));
final floor = FloorRecord(
    id: 'floor-1',
    organizationId: 'north',
    buildingId: building.id,
    name: 'Basement',
    code: 'B1',
    level: -1,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026));
final zone = ZoneRecord(
    id: 'zone-1',
    organizationId: 'north',
    buildingId: building.id,
    floorId: floor.id,
    name: 'Plant room',
    code: 'P1',
    zoneType: ZoneType.plantRoom,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026));

class PreviewBuildings extends BuildingsController {
  @override
  BuildingsState build() => BuildingsState(
      records: [building],
      listPhase: BuildingListPhase.ready,
      currentPage: 1,
      lastPage: 1);
  @override
  Future<void> loadFirstPage() async {}
  @override
  Future<void> loadDetail(String id) async {
    state = BuildingsState(
        records: [building],
        listPhase: BuildingListPhase.ready,
        currentPage: 1,
        lastPage: 1,
        detail: building,
        detailPhase: BuildingDetailPhase.ready);
  }
}

class PreviewFloors extends FloorsController {
  @override
  HierarchyState<FloorRecord> build() => HierarchyState(
      scope: HierarchyScope(building.id),
      records: [floor],
      listPhase: HierarchyListPhase.ready,
      currentPage: 1,
      lastPage: 1);
  @override
  Future<void> loadFirstPage(HierarchyScope scope) async {}
  @override
  Future<void> loadDetail(HierarchyScope scope, String id) async {
    state = HierarchyState(
        scope: scope,
        records: [floor],
        listPhase: HierarchyListPhase.ready,
        currentPage: 1,
        lastPage: 1,
        detail: floor,
        detailId: id,
        detailPhase: HierarchyDetailPhase.ready);
  }
}

class PreviewZones extends ZonesController {
  @override
  HierarchyState<ZoneRecord> build() => HierarchyState(
      scope: HierarchyScope(building.id, floor.id),
      records: [zone],
      listPhase: HierarchyListPhase.ready,
      currentPage: 1,
      lastPage: 1);
  @override
  Future<void> loadFirstPage(HierarchyScope scope) async {}
  @override
  Future<void> loadDetail(HierarchyScope scope, String id) async {
    state = HierarchyState(
        scope: scope,
        records: [zone],
        listPhase: HierarchyListPhase.ready,
        currentPage: 1,
        lastPage: 1,
        detail: zone,
        detailId: id,
        detailPhase: HierarchyDetailPhase.ready);
  }
}

class EmptyFloors extends PreviewFloors {
  @override
  HierarchyState<FloorRecord> build() => HierarchyState(
      scope: HierarchyScope(building.id), listPhase: HierarchyListPhase.empty);
}

class ErrorZones extends PreviewZones {
  @override
  HierarchyState<ZoneRecord> build() => HierarchyState(
      scope: HierarchyScope(building.id, floor.id),
      listPhase: HierarchyListPhase.error,
      listFailure: BuildingFailureKind.network);
}

class FrenchLocale extends LocaleController {
  @override
  Locale build() => const Locale('fr');
}

class UnauthenticatedTestSession extends SessionController {
  @override
  SessionState build() =>
      const SessionState(phase: SessionPhase.unauthenticated);
  @override
  Future<void> restore() async {}
}

class HierarchyTestSession extends AuthenticatedTestSession {
  @override
  OrganizationContext? captureOrganizationContext() =>
      const OrganizationContext(7, 'north', 1);
  @override
  bool isCurrentOrganizationContext(OrganizationContext? context) =>
      context?.organizationId == 'north' && context?.generation == 1;
}

List<Override> previews({bool french = false}) => [
      sessionControllerProvider.overrideWith(AuthenticatedTestSession.new),
      buildingsControllerProvider.overrideWith(PreviewBuildings.new),
      floorsControllerProvider.overrideWith(PreviewFloors.new),
      zonesControllerProvider.overrideWith(PreviewZones.new),
      if (french) localeProvider.overrideWith(FrenchLocale.new),
    ];

void main() {
  testWidgets('building to floor to zone navigation shows read-only hierarchy',
      (tester) async {
    await tester.pumpWidget(
        ProviderScope(overrides: previews(), child: const BmsApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Browse buildings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('North Office'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Browse floors'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Level -1'), findsOneWidget);
    await tester.tap(find.text('Basement'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Browse zones'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Plant room'), findsWidgets);
    await tester.tap(find.text('Plant room').last);
    await tester.pumpAndSettle();
    expect(find.text('Zone type'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('French floor and zone labels are localized', (tester) async {
    await tester.pumpWidget(ProviderScope(
        overrides: previews(french: true), child: const BmsApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Voir les bâtiments'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('North Office'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Voir les étages'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Niveau -1'), findsOneWidget);
    await tester.tap(find.text('Basement'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Voir les zones'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Local technique'), findsOneWidget);
  });

  testWidgets('unauthenticated deep link redirects to login', (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      sessionControllerProvider.overrideWith(UnauthenticatedTestSession.new),
      initialRouteProvider.overrideWithValue(
          '/buildings/building-1/floors/floor-1/zones/zone-1'),
    ], child: const BmsApp()));
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Plant room'), findsNothing);
  });

  testWidgets('direct floor link shows parent and empty state', (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      sessionControllerProvider.overrideWith(AuthenticatedTestSession.new),
      buildingsControllerProvider.overrideWith(PreviewBuildings.new),
      floorsControllerProvider.overrideWith(EmptyFloors.new),
      initialRouteProvider.overrideWithValue('/buildings/building-1/floors'),
    ], child: const BmsApp()));
    await tester.pumpAndSettle();
    expect(find.text('No floors in this building.'), findsOneWidget);
    expect(find.text('building-1'), findsOneWidget);
  });

  testWidgets('zone network error has a localized retry action',
      (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      sessionControllerProvider.overrideWith(AuthenticatedTestSession.new),
      buildingsControllerProvider.overrideWith(PreviewBuildings.new),
      floorsControllerProvider.overrideWith(PreviewFloors.new),
      zonesControllerProvider.overrideWith(ErrorZones.new),
      localeProvider.overrideWith(FrenchLocale.new),
      initialRouteProvider
          .overrideWithValue('/buildings/building-1/floors/floor-1/zones'),
    ], child: const BmsApp()));
    await tester.pumpAndSettle();
    expect(find.text('Réseau indisponible. Réessayez.'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
    expect(find.text('floor-1'), findsOneWidget);
  });

  testWidgets('returning to an older floor list reloads its parent scope',
      (tester) async {
    final floors = fixture.FakeFloors();
    await tester.pumpWidget(ProviderScope(overrides: [
      sessionControllerProvider.overrideWith(HierarchyTestSession.new),
      floorRepositoryProvider.overrideWithValue(floors),
      initialRouteProvider.overrideWithValue('/buildings/building-a/floors'),
    ], child: const BmsApp()));
    await tester.pumpAndSettle();
    expect(find.text('Basement'), findsOneWidget);
    final router = GoRouter.of(tester.element(find.byType(FloorsScreen)));
    router.push('/buildings/building-b/floors');
    await tester.pumpAndSettle();
    expect(find.text('building-b'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('building-a'), findsOneWidget);
    expect(find.text('Basement'), findsOneWidget);
    expect(floors.calls,
        ['north:building-a:1', 'north:building-b:1', 'north:building-a:1']);
  });

  testWidgets('returning to an older zone detail reloads its requested ID',
      (tester) async {
    final zones = fixture.FakeZones();
    await tester.pumpWidget(ProviderScope(overrides: [
      sessionControllerProvider.overrideWith(HierarchyTestSession.new),
      zoneRepositoryProvider.overrideWithValue(zones),
      initialRouteProvider.overrideWithValue(
          '/buildings/building-a/floors/floor-a/zones/zone-a'),
    ], child: const BmsApp()));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(ZoneDetailScreen));
    final router = GoRouter.of(context);
    final container = ProviderScope.containerOf(context);
    expect(container.read(zonesControllerProvider).detailId, 'zone-a');
    router.push('/buildings/building-a/floors/floor-a/zones/zone-b');
    await tester.pumpAndSettle();
    expect(container.read(zonesControllerProvider).detailId, 'zone-b');
    router.pop();
    await tester.pumpAndSettle();
    expect(container.read(zonesControllerProvider).detailId, 'zone-a');
    expect(find.text('Plant'), findsOneWidget);
  });

  testWidgets('zone detail remains readable in dark theme', (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      ...previews(),
      initialRouteProvider.overrideWithValue(
          '/buildings/building-1/floors/floor-1/zones/zone-1'),
    ], child: const BmsApp()));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(ZoneDetailScreen));
    ProviderScope.containerOf(context)
        .read(themeModeProvider.notifier)
        .setMode(ThemeMode.dark);
    await tester.pumpAndSettle();
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark);
    expect(find.text('Zone type'), findsOneWidget);
    expect(find.text('Plant room'), findsWidgets);
  });
}
