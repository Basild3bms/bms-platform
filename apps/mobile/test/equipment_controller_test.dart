import 'dart:async';

import 'package:bms_mobile/src/core/storage/token_store.dart';
import 'package:bms_mobile/src/features/auth/auth_repository.dart';
import 'package:bms_mobile/src/features/auth/session_controller.dart';
import 'package:bms_mobile/src/features/buildings/building_models.dart';
import 'package:bms_mobile/src/features/equipment/equipment_controller.dart';
import 'package:bms_mobile/src/features/equipment/equipment_models.dart';
import 'package:bms_mobile/src/features/equipment/equipment_repository.dart';
import 'package:bms_mobile/src/features/equipment/equipment_scope.dart';
import 'package:bms_mobile/src/features/floors/hierarchy_controller.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'buildings_controller_test.dart' as fixture;
import 'equipment_contract_test.dart' as contract;

class FakeEquipment implements EquipmentRepository {
  Future<EquipmentListResponse> Function(
      String, EquipmentScope, int, CancelToken?)? onList;
  Future<EquipmentDetailResponse> Function(
      String, String, String, CancelToken?)? onGet;
  final scopes = <EquipmentScope>[];

  @override
  Future<EquipmentListResponse> list(String org, EquipmentScope scope,
      {int page = 1, int perPage = 25, CancelToken? cancelToken}) {
    scopes.add(scope);
    if (onList != null) return onList!(org, scope, page, cancelToken);
    return Future.value(EquipmentListResponse([
      EquipmentRecord.fromJson(
          contract.equipmentJson(floorId: scope.floorId, zoneId: scope.zoneId),
          contract.org,
          contract.building,
          floorId: scope.floorId,
          zoneId: scope.zoneId)
    ], EquipmentPageMeta(page, perPage, 1, 1)));
  }

  @override
  Future<EquipmentDetailResponse> get(String org, String building, String id,
          {CancelToken? cancelToken}) =>
      onGet?.call(org, building, id, cancelToken) ??
      Future.value(EquipmentDetailResponse(EquipmentRecord.fromJson(
          contract.equipmentJson(), contract.org, contract.building,
          equipmentId: id)));
}

Future<ProviderContainer> setup(FakeEquipment equipment) async {
  final container = ProviderContainer(overrides: [
    tokenStoreProvider.overrideWithValue(fixture.MemorySessionStore()),
    authRepositoryProvider.overrideWithValue(fixture.SessionRepo()),
    equipmentRepositoryProvider.overrideWithValue(equipment),
  ]);
  await container.read(sessionControllerProvider.notifier).restore();
  return container;
}

void main() {
  test('pagination appends a new page and keeps first page after failure',
      () async {
    final first = EquipmentRecord.fromJson(
        contract.equipmentJson(), contract.org, contract.building);
    final second = EquipmentRecord.fromJson({
      ...contract.equipmentJson(),
      'id': '66666666-6666-4666-8666-666666666666',
      'code': 'AHU-02'
    }, contract.org, contract.building);
    final fake = FakeEquipment()
      ..onList = (_, __, page, ___) async => EquipmentListResponse(
          [page == 1 ? first : second], EquipmentPageMeta(page, 1, 2, 2));
    final container = await setup(fake);
    addTearDown(container.dispose);
    final controller = container.read(equipmentControllerProvider.notifier);
    final scope = EquipmentScope(contract.building);
    await controller.loadFirstPage(scope);
    expect(container.read(equipmentControllerProvider).hasMore, isTrue);
    fake.onList = (_, __, page, ___) async {
      if (page == 2) throw const BuildingFailure(BuildingFailureKind.network);
      return EquipmentListResponse(
          [first], const EquipmentPageMeta(1, 1, 2, 2));
    };
    await controller.loadMore(scope);
    expect(container.read(equipmentControllerProvider).records, [first]);
    expect(container.read(equipmentControllerProvider).listFailure,
        BuildingFailureKind.network);
    fake.onList = (_, __, page, ___) async => EquipmentListResponse(
        [page == 1 ? first : second], EquipmentPageMeta(page, 1, 2, 2));
    await controller.loadMore(scope);
    expect(
        container.read(equipmentControllerProvider).records, [first, second]);
  });

  test('building, floor, zone scopes stay separate and refresh reloads',
      () async {
    final fake = FakeEquipment();
    final container = await setup(fake);
    addTearDown(container.dispose);
    final controller = container.read(equipmentControllerProvider.notifier);
    final buildingScope = EquipmentScope(contract.building);
    final floorScope =
        EquipmentScope(contract.building, floorId: contract.floor);
    final zoneScope = EquipmentScope(contract.building,
        floorId: contract.floor, zoneId: contract.zone);
    await controller.loadFirstPage(buildingScope);
    expect(container.read(equipmentControllerProvider).records.single.floorId,
        isNull);
    await controller.loadFirstPage(floorScope);
    expect(container.read(equipmentControllerProvider).records.single.floorId,
        contract.floor);
    await controller.loadFirstPage(zoneScope);
    expect(container.read(equipmentControllerProvider).records.single.zoneId,
        contract.zone);
    await controller.refresh(zoneScope);
    expect(fake.scopes, [buildingScope, floorScope, zoneScope, zoneScope]);
  });

  test('stale response is canceled when location scope changes', () async {
    final gate = Completer<EquipmentListResponse>();
    CancelToken? oldCancel;
    final fake = FakeEquipment()
      ..onList = (_, __, ___, cancel) {
        oldCancel = cancel;
        return gate.future;
      };
    final container = await setup(fake);
    addTearDown(container.dispose);
    final controller = container.read(equipmentControllerProvider.notifier);
    final pending = controller.loadFirstPage(EquipmentScope(contract.building));
    await Future<void>.delayed(Duration.zero);
    fake.onList = null;
    await controller.loadFirstPage(
        EquipmentScope(contract.building, floorId: contract.floor));
    expect(oldCancel?.isCancelled, isTrue);
    gate.complete(EquipmentListResponse([
      EquipmentRecord.fromJson(
          contract.equipmentJson(), contract.org, contract.building)
    ], const EquipmentPageMeta(1, 25, 1, 1)));
    await pending;
    expect(container.read(equipmentControllerProvider).records.single.floorId,
        contract.floor);
  });

  test('organization switch cancels a pending equipment response', () async {
    final gate = Completer<EquipmentListResponse>();
    CancelToken? oldCancel;
    final fake = FakeEquipment()
      ..onList = (_, __, ___, cancel) {
        oldCancel = cancel;
        return gate.future;
      };
    final container = await setup(fake);
    addTearDown(container.dispose);
    final controller = container.read(equipmentControllerProvider.notifier);
    final pending = controller.loadFirstPage(EquipmentScope(contract.building));
    await Future<void>.delayed(Duration.zero);
    await container
        .read(sessionControllerProvider.notifier)
        .switchOrganization('south');
    expect(oldCancel?.isCancelled, isTrue);
    gate.complete(EquipmentListResponse([
      EquipmentRecord.fromJson(
          contract.equipmentJson(), contract.org, contract.building)
    ], const EquipmentPageMeta(1, 25, 1, 1)));
    await pending;
    expect(container.read(equipmentControllerProvider).records, isEmpty);
  });

  test('detail, offline retry, unauthorized and logout clear state', () async {
    final fake = FakeEquipment();
    final container = await setup(fake);
    addTearDown(container.dispose);
    final controller = container.read(equipmentControllerProvider.notifier);
    final scope = EquipmentScope(contract.building);
    fake.onList = (_, __, ___, ____) async =>
        throw const BuildingFailure(BuildingFailureKind.network);
    await controller.loadFirstPage(scope);
    expect(container.read(equipmentControllerProvider).listPhase,
        HierarchyListPhase.error);
    fake.onList = null;
    await controller.refresh(scope);
    expect(container.read(equipmentControllerProvider).records.single.code,
        'AHU-01');
    await controller.loadDetail(scope, contract.equipment);
    expect(container.read(equipmentControllerProvider).detail?.id,
        contract.equipment);
    fake.onList = (_, __, ___, ____) async =>
        throw const BuildingFailure(BuildingFailureKind.unauthorized);
    await controller.refresh(scope);
    expect(container.read(equipmentControllerProvider).records, isEmpty);
  });
}
