import 'package:bms_mobile/src/app.dart';
import 'package:bms_mobile/src/core/routing/app_router.dart';
import 'package:bms_mobile/src/features/auth/session_controller.dart';
import 'package:bms_mobile/src/features/equipment/equipment_controller.dart';
import 'package:bms_mobile/src/features/equipment/equipment_models.dart';
import 'package:bms_mobile/src/features/equipment/equipment_scope.dart';
import 'package:bms_mobile/src/features/floors/hierarchy_controller.dart';
import 'package:bms_mobile/src/core/theme/app_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'hierarchy_widget_test.dart' as fixture;

final equipment = EquipmentRecord(
    id: 'asset-1',
    organizationId: 'north',
    buildingId: fixture.building.id,
    floorId: null,
    zoneId: null,
    code: 'AHU-01',
    name: 'Main AHU',
    description: null,
    typeCode: 'ahu',
    manufacturer: null,
    model: null,
    serialNumber: null,
    lifecycleStatus: 'retired',
    installedOn: null,
    commissionedOn: null,
    specifications: null,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026));

class PreviewEquipment extends EquipmentController {
  @override
  HierarchyState<EquipmentRecord> build() => HierarchyState(
      scope: EquipmentScope(fixture.building.id),
      records: [equipment],
      listPhase: HierarchyListPhase.ready,
      currentPage: 1,
      lastPage: 1);

  @override
  Future<void> loadFirstPage(HierarchyScope scope) async {
    state = HierarchyState(
        scope: scope,
        records: scope.floorId == null ? [equipment] : [],
        listPhase: scope.floorId == null
            ? HierarchyListPhase.ready
            : HierarchyListPhase.empty,
        currentPage: 1,
        lastPage: 1);
  }

  @override
  Future<void> loadDetail(HierarchyScope scope, String id) async {
    state = HierarchyState(
        scope: scope,
        records: state.records,
        listPhase: state.listPhase,
        currentPage: state.currentPage,
        lastPage: state.lastPage,
        detail: equipment,
        detailId: id,
        detailPhase: HierarchyDetailPhase.ready);
  }
}

class DarkTheme extends ThemeModeController {
  @override
  ThemeMode build() => ThemeMode.dark;
}

void main() {
  testWidgets('signed-out equipment deep link stays behind login',
      (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      sessionControllerProvider
          .overrideWith(fixture.UnauthenticatedTestSession.new),
      initialRouteProvider
          .overrideWithValue('/buildings/building-1/equipment/asset-1'),
    ], child: const BmsApp()));
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('AHU-01'), findsNothing);
  });

  testWidgets('building asset is read-only and absent from floor list',
      (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      ...fixture.previews(),
      equipmentControllerProvider.overrideWith(PreviewEquipment.new),
    ], child: const BmsApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Browse buildings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('North Office'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Browse equipment'));
    await tester.pumpAndSettle();
    expect(find.text('AHU-01'), findsOneWidget);
    expect(find.text('All equipment in this building'), findsOneWidget);
    await tester.tap(find.text('AHU-01'));
    await tester.pumpAndSettle();
    expect(find.text('Retired'), findsWidgets);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Edit'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Browse floors'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Basement'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Browse equipment'));
    await tester.pumpAndSettle();
    expect(find.text('AHU-01'), findsNothing);
    expect(
        find.text('Equipment on this floor and in its zones'), findsOneWidget);
  });

  testWidgets('French labels and dark theme render', (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      ...fixture.previews(french: true),
      equipmentControllerProvider.overrideWith(PreviewEquipment.new),
      themeModeProvider.overrideWith(DarkTheme.new),
    ], child: const BmsApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Voir les bâtiments'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('North Office'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Voir les équipements'));
    await tester.pumpAndSettle();
    expect(find.text('Tous les équipements de ce bâtiment'), findsOneWidget);
    expect(find.textContaining('Retiré'), findsWidgets);
    expect(
        Theme.of(tester
                .element(find.text('Tous les équipements de ce bâtiment')))
            .brightness,
        Brightness.dark);
  });
}
