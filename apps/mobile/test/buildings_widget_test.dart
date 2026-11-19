import 'package:bms_mobile/src/app.dart';
import 'package:bms_mobile/src/core/theme/app_preferences.dart';
import 'package:bms_mobile/src/features/auth/session_controller.dart';
import 'package:bms_mobile/src/features/buildings/building_models.dart';
import 'package:bms_mobile/src/features/buildings/buildings_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'support/authenticated_session.dart';

final record = BuildingRecord(
  id: 'building-1',
  organizationId: 'north',
  name: 'North Office',
  code: 'N-001',
  address: '1 Main Street',
  timezone: 'Europe/Paris',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

class PreviewBuildings extends BuildingsController {
  @override
  BuildingsState build() => BuildingsState(
        records: [record],
        listPhase: BuildingListPhase.ready,
        currentPage: 1,
        lastPage: 1,
      );

  @override
  Future<void> loadFirstPage() async {}

  @override
  Future<void> loadDetail(String buildingId) async {
    state = BuildingsState(
      records: [record],
      listPhase: BuildingListPhase.ready,
      currentPage: 1,
      lastPage: 1,
      detail: record,
      detailPhase: BuildingDetailPhase.ready,
    );
  }
}

class EmptyBuildings extends PreviewBuildings {
  @override
  BuildingsState build() =>
      const BuildingsState(listPhase: BuildingListPhase.empty);
}

void main() {
  testWidgets('overview opens building list and detail with read-only fields',
      (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      sessionControllerProvider.overrideWith(AuthenticatedTestSession.new),
      buildingsControllerProvider.overrideWith(PreviewBuildings.new),
    ], child: const BmsApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Browse buildings'));
    await tester.pumpAndSettle();
    expect(find.text('North Office'), findsOneWidget);
    expect(find.textContaining('N-001'), findsOneWidget);
    await tester.tap(find.text('North Office'));
    await tester.pumpAndSettle();
    expect(find.text('1 Main Street'), findsOneWidget);
    expect(find.text('Europe/Paris'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('empty state and French labels are readable', (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      sessionControllerProvider.overrideWith(AuthenticatedTestSession.new),
      buildingsControllerProvider.overrideWith(EmptyBuildings.new),
      localeProvider.overrideWith(() => _FrenchLocale()),
    ], child: const BmsApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Voir les bâtiments'));
    await tester.pumpAndSettle();
    expect(
        find.text('Aucun bâtiment dans cette organisation.'), findsOneWidget);
  });
}

class _FrenchLocale extends LocaleController {
  @override
  Locale build() => const Locale('fr');
}
