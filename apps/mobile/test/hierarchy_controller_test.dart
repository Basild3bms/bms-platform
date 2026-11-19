import 'dart:async';

import 'package:bms_mobile/src/core/storage/token_store.dart';
import 'package:bms_mobile/src/features/auth/auth_repository.dart';
import 'package:bms_mobile/src/features/auth/session_controller.dart';
import 'package:bms_mobile/src/features/buildings/building_models.dart';
import 'package:bms_mobile/src/features/floors/floor_models.dart';
import 'package:bms_mobile/src/features/floors/floor_repository.dart';
import 'package:bms_mobile/src/features/floors/floors_controller.dart';
import 'package:bms_mobile/src/features/floors/hierarchy_controller.dart';
import 'package:bms_mobile/src/features/floors/hierarchy_models.dart';
import 'package:bms_mobile/src/features/zones/zone_models.dart';
import 'package:bms_mobile/src/features/zones/zone_repository.dart';
import 'package:bms_mobile/src/features/zones/zones_controller.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'buildings_controller_test.dart' as fixture;

FloorRecord floorFor(String organization, String building,
        {String id = 'floor'}) =>
    FloorRecord(
        id: id,
        organizationId: organization,
        buildingId: building,
        name: 'Basement',
        code: 'B1',
        level: -1,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026));

ZoneRecord zoneFor(String organization, String building, String floor,
        {String id = 'zone'}) =>
    ZoneRecord(
        id: id,
        organizationId: organization,
        buildingId: building,
        floorId: floor,
        name: 'Plant',
        code: 'P1',
        zoneType: ZoneType.plantRoom,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026));

class FakeFloors implements FloorRepository {
  Future<FloorPage> Function(String, String, int, CancelToken?)? onList;
  Future<FloorRecord> Function(String, String, String, CancelToken?)? onGet;
  final calls = <String>[];

  @override
  Future<FloorPage> list(String org, String building,
      {int page = 1, int perPage = 25, CancelToken? cancelToken}) {
    calls.add('$org:$building:$page');
    return onList?.call(org, building, page, cancelToken) ??
        Future.value(FloorPage(
            data: [floorFor(org, building)],
            currentPage: page,
            perPage: perPage,
            total: 1,
            lastPage: 1));
  }

  @override
  Future<FloorRecord> get(String org, String building, String id,
          {CancelToken? cancelToken}) =>
      onGet?.call(org, building, id, cancelToken) ??
      Future.value(floorFor(org, building, id: id));
}

class FakeZones implements ZoneRepository {
  Future<ZonePage> Function(String, String, String, int, CancelToken?)? onList;
  Future<ZoneRecord> Function(String, String, String, String, CancelToken?)?
      onGet;
  final calls = <String>[];

  @override
  Future<ZonePage> list(String org, String building, String floor,
      {int page = 1, int perPage = 25, CancelToken? cancelToken}) {
    calls.add('$org:$building:$floor:$page');
    return onList?.call(org, building, floor, page, cancelToken) ??
        Future.value(ZonePage(
            data: [zoneFor(org, building, floor)],
            currentPage: page,
            perPage: perPage,
            total: 1,
            lastPage: 1));
  }

  @override
  Future<ZoneRecord> get(String org, String building, String floor, String id,
          {CancelToken? cancelToken}) =>
      onGet?.call(org, building, floor, id, cancelToken) ??
      Future.value(zoneFor(org, building, floor, id: id));
}

Future<ProviderContainer> setup(FakeFloors floors, FakeZones zones) async {
  final container = ProviderContainer(overrides: [
    tokenStoreProvider.overrideWithValue(fixture.MemorySessionStore()),
    authRepositoryProvider.overrideWithValue(fixture.SessionRepo()),
    floorRepositoryProvider.overrideWithValue(floors),
    zoneRepositoryProvider.overrideWithValue(zones),
  ]);
  await container.read(sessionControllerProvider.notifier).restore();
  return container;
}

void main() {
  const building = 'building-a';
  const scope = HierarchyScope(building);
  const zoneScope = HierarchyScope(building, 'floor-a');

  test('floor pagination, refresh, empty, error, and retry', () async {
    final floors = FakeFloors()
      ..onList = (org, building, page, _) async => FloorPage(
          data: [floorFor(org, building, id: 'floor-$page')],
          currentPage: page,
          perPage: 1,
          total: 2,
          lastPage: 2);
    final container = await setup(floors, FakeZones());
    addTearDown(container.dispose);
    final controller = container.read(floorsControllerProvider.notifier);
    await controller.loadFirstPage(scope);
    expect(container.read(floorsControllerProvider).hasMore, isTrue);
    await controller.loadMore(scope);
    expect(container.read(floorsControllerProvider).records.length, 2);
    floors.onList = (_, __, ___, ____) async =>
        const HierarchyPage<FloorRecord>(
            data: [], currentPage: 1, perPage: 25, total: 0, lastPage: 1);
    await controller.refresh(scope);
    expect(container.read(floorsControllerProvider).listPhase,
        HierarchyListPhase.empty);
    floors.onList = (_, __, ___, ____) async =>
        throw const BuildingFailure(BuildingFailureKind.network);
    await controller.refresh(scope);
    expect(container.read(floorsControllerProvider).listPhase,
        HierarchyListPhase.error);
    floors.onList = null;
    await controller.refresh(scope);
    expect(container.read(floorsControllerProvider).records.single.level, -1);
  });

  test('zone scope changes cancel old requests and reject stale responses',
      () async {
    final gate = Completer<ZonePage>();
    CancelToken? oldCancel;
    final zones = FakeZones()
      ..onList = (org, building, floor, page, cancel) {
        oldCancel = cancel;
        return gate.future;
      };
    final container = await setup(FakeFloors(), zones);
    addTearDown(container.dispose);
    final controller = container.read(zonesControllerProvider.notifier);
    final pending = controller.loadFirstPage(zoneScope);
    await Future<void>.delayed(Duration.zero);
    zones.onList = null;
    await controller.loadFirstPage(const HierarchyScope(building, 'floor-b'));
    expect(oldCancel?.isCancelled, isTrue);
    gate.complete(ZonePage(
        data: [zoneFor('north', building, 'floor-a')],
        currentPage: 1,
        perPage: 25,
        total: 1,
        lastPage: 1));
    await pending;
    expect(container.read(zonesControllerProvider).records.single.floorId,
        'floor-b');
  });

  test('organization switch cancels both resource requests and clears data',
      () async {
    final gate = Completer<FloorPage>();
    CancelToken? oldCancel;
    final floors = FakeFloors()
      ..onList = (org, building, page, cancel) {
        oldCancel = cancel;
        return gate.future;
      };
    final container = await setup(floors, FakeZones());
    addTearDown(container.dispose);
    final controller = container.read(floorsControllerProvider.notifier);
    final pending = controller.loadFirstPage(scope);
    await Future<void>.delayed(Duration.zero);
    await container
        .read(sessionControllerProvider.notifier)
        .switchOrganization('south');
    expect(oldCancel?.isCancelled, isTrue);
    gate.complete(FloorPage(
        data: [floorFor('north', building)],
        currentPage: 1,
        perPage: 25,
        total: 1,
        lastPage: 1));
    await pending;
    expect(container.read(floorsControllerProvider).records, isEmpty);
    floors.onList = null;
    await controller.loadFirstPage(scope);
    expect(
        container.read(floorsControllerProvider).records.single.organizationId,
        'south');
  });

  test('detail errors, unauthorized logout, and logout data clearing',
      () async {
    final zones = FakeZones()
      ..onGet = (_, __, ___, ____, _____) async =>
          throw const BuildingFailure(BuildingFailureKind.notFound);
    final container = await setup(FakeFloors(), zones);
    addTearDown(container.dispose);
    final controller = container.read(zonesControllerProvider.notifier);
    await controller.loadFirstPage(zoneScope);
    await controller.loadDetail(zoneScope, 'missing');
    expect(container.read(zonesControllerProvider).detailPhase,
        HierarchyDetailPhase.unavailable);
    zones.onGet = null;
    await controller.loadDetail(zoneScope, 'zone');
    expect(container.read(zonesControllerProvider).detail?.zoneType,
        ZoneType.plantRoom);
    await container.read(sessionControllerProvider.notifier).logout();
    expect(container.read(zonesControllerProvider).records, isEmpty);
    expect(container.read(zonesControllerProvider).detail, isNull);
  });

  test('leaving a list or detail cancels pending work and discards replies',
      () async {
    final listGate = Completer<FloorPage>();
    final detailGate = Completer<FloorRecord>();
    CancelToken? listCancel, detailCancel;
    final floors = FakeFloors()
      ..onList = (org, building, page, cancel) {
        listCancel = cancel;
        return listGate.future;
      }
      ..onGet = (org, building, id, cancel) {
        detailCancel = cancel;
        return detailGate.future;
      };
    final container = await setup(floors, FakeZones());
    addTearDown(container.dispose);
    final controller = container.read(floorsControllerProvider.notifier);
    final pendingList = controller.loadFirstPage(scope);
    controller.releaseList(scope);
    expect(listCancel?.isCancelled, isTrue);
    final pendingDetail = controller.loadDetail(scope, 'floor');
    controller.releaseDetail(scope, 'floor');
    expect(detailCancel?.isCancelled, isTrue);
    listGate.complete(FloorPage(
        data: [floorFor('north', building)],
        currentPage: 1,
        perPage: 25,
        total: 1,
        lastPage: 1));
    detailGate.complete(floorFor('north', building));
    await Future.wait([pendingList, pendingDetail]);
    expect(container.read(floorsControllerProvider).records, isEmpty);
    expect(container.read(floorsControllerProvider).detail, isNull);
  });

  test('unauthorized hierarchy request closes the session', () async {
    final floors = FakeFloors()
      ..onList = (_, __, ___, ____) async =>
          throw const BuildingFailure(BuildingFailureKind.unauthorized);
    final container = await setup(floors, FakeZones());
    addTearDown(container.dispose);
    await container
        .read(floorsControllerProvider.notifier)
        .loadFirstPage(scope);
    expect(container.read(sessionControllerProvider).phase,
        SessionPhase.unauthenticated);
    expect(container.read(floorsControllerProvider).records, isEmpty);
  });

  test('provider disposal while list and detail are pending is safe', () async {
    final listGate = Completer<FloorPage>();
    final detailGate = Completer<FloorRecord>();
    final floors = FakeFloors()
      ..onList = ((_, __, ___, ____) => listGate.future)
      ..onGet = ((_, __, ___, ____) => detailGate.future);
    final container = await setup(floors, FakeZones());
    final controller = container.read(floorsControllerProvider.notifier);
    final list = controller.loadFirstPage(scope);
    final detail = controller.loadDetail(scope, 'floor');
    container.dispose();
    listGate.complete(FloorPage(
        data: [floorFor('north', building)],
        currentPage: 1,
        perPage: 25,
        total: 1,
        lastPage: 1));
    detailGate.complete(floorFor('north', building));
    await Future.wait([list, detail]);
  });

  test('leaving during load more restores a usable list', () async {
    final gate = Completer<FloorPage>();
    final floors = FakeFloors()
      ..onList = (org, building, page, _) {
        if (page == 2) return gate.future;
        return Future.value(FloorPage(
            data: [floorFor(org, building)],
            currentPage: 1,
            perPage: 1,
            total: 2,
            lastPage: 2));
      };
    final container = await setup(floors, FakeZones());
    addTearDown(container.dispose);
    final controller = container.read(floorsControllerProvider.notifier);
    await controller.loadFirstPage(scope);
    final pending = controller.loadMore(scope);
    expect(container.read(floorsControllerProvider).loadingMore, isTrue);
    controller.releaseList(scope);
    expect(container.read(floorsControllerProvider).loadingMore, isFalse);
    gate.complete(FloorPage(
        data: [floorFor('north', building, id: 'second')],
        currentPage: 2,
        perPage: 1,
        total: 2,
        lastPage: 2));
    await pending;
    expect(container.read(floorsControllerProvider).records.length, 1);
    await controller.loadMore(scope);
    expect(container.read(floorsControllerProvider).records.length, 2);
  });

  test('overlapping page IDs keep the existing list and allow retry', () async {
    var duplicate = true;
    final floors = FakeFloors()
      ..onList = (org, building, page, _) async => FloorPage(data: [
            floorFor(org, building,
                id: page == 1 || duplicate ? 'first' : 'second')
          ], currentPage: page, perPage: 1, total: 2, lastPage: 2);
    final container = await setup(floors, FakeZones());
    addTearDown(container.dispose);
    final controller = container.read(floorsControllerProvider.notifier);
    await controller.loadFirstPage(scope);
    await controller.loadMore(scope);
    final state = container.read(floorsControllerProvider);
    expect(state.records.map((item) => item.id), ['first']);
    expect(state.listFailure, BuildingFailureKind.invalidResponse);
    expect(state.loadingMore, isFalse);
    duplicate = false;
    await controller.loadMore(scope);
    expect(
        container.read(floorsControllerProvider).records.map((item) => item.id),
        ['first', 'second']);
  });
}
