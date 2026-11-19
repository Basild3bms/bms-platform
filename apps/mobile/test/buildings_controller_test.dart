import 'dart:async';

import 'package:bms_mobile/src/core/storage/token_store.dart';
import 'package:bms_mobile/src/features/auth/auth_models.dart';
import 'package:bms_mobile/src/features/auth/auth_repository.dart';
import 'package:bms_mobile/src/features/auth/session_controller.dart';
import 'package:bms_mobile/src/features/buildings/building_models.dart';
import 'package:bms_mobile/src/features/buildings/building_repository.dart';
import 'package:bms_mobile/src/features/buildings/buildings_controller.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const north = 'north';
const south = 'south';

class MemorySessionStore implements TokenStore {
  StoredSession? value = StoredSession('test-token',
      DateTime.now().toUtc().add(const Duration(hours: 1)), north);

  @override
  Future<StoredSession?> read() async => value;
  @override
  Future<void> write(StoredSession session) async => value = session;
  @override
  Future<void> setSelectedOrganization(String? id) async {
    final saved = value;
    if (saved != null) value = StoredSession(saved.token, saved.expiresAt, id);
  }

  @override
  Future<void> clear() async => value = null;
}

class SessionRepo implements AuthRepository {
  @override
  Future<LoginResult> login(String email, String password,
          {CancelToken? cancelToken}) =>
      throw UnimplementedError();
  @override
  Future<AuthUser> me({CancelToken? cancelToken}) async =>
      const AuthUser(id: 7, name: 'Operator', email: 'operator@example.test');
  @override
  Future<List<OrganizationAccess>> organizations(
          {CancelToken? cancelToken}) async =>
      const [
        OrganizationAccess(
            id: north,
            name: 'North',
            role: 'viewer',
            permissions: ['buildings.view']),
        OrganizationAccess(
            id: south,
            name: 'South',
            role: 'viewer',
            permissions: ['buildings.view']),
      ];
  @override
  Future<void> logout(String token, {CancelToken? cancelToken}) async {}
}

class FakeBuildingRepository implements BuildingRepository {
  Future<BuildingPage> Function(String, int, CancelToken?)? onList;
  Future<BuildingRecord> Function(String, String, CancelToken?)? onGet;
  final calls = <String>[];

  @override
  Future<BuildingPage> list(String organizationId,
      {int page = 1, int perPage = 25, CancelToken? cancelToken}) {
    calls.add('$organizationId:$page');
    return onList?.call(organizationId, page, cancelToken) ??
        Future.value(BuildingPage(
          data: [recordFor(organizationId)],
          currentPage: page,
          perPage: perPage,
          total: 1,
          lastPage: 1,
        ));
  }

  @override
  Future<BuildingRecord> get(String organizationId, String buildingId,
          {CancelToken? cancelToken}) =>
      onGet?.call(organizationId, buildingId, cancelToken) ??
      Future.value(recordFor(organizationId));
}

BuildingRecord recordFor(String organizationId, {String? id}) => BuildingRecord(
      id: id ?? 'building-$organizationId',
      organizationId: organizationId,
      name: '$organizationId Office',
      code: '${organizationId[0]}-001',
      address: null,
      timezone: 'UTC',
      createdAt: DateTime.utc(2026, 11, 19),
      updatedAt: DateTime.utc(2026, 11, 19),
    );

Future<ProviderContainer> containerFor(
    FakeBuildingRepository repository) async {
  final container = ProviderContainer(overrides: [
    tokenStoreProvider.overrideWithValue(MemorySessionStore()),
    authRepositoryProvider.overrideWithValue(SessionRepo()),
    buildingRepositoryProvider.overrideWithValue(repository),
  ]);
  await container.read(sessionControllerProvider.notifier).restore();
  return container;
}

void main() {
  test('loads first page only for selected organization', () async {
    final repo = FakeBuildingRepository();
    final container = await containerFor(repo);
    addTearDown(container.dispose);
    await container.read(buildingsControllerProvider.notifier).loadFirstPage();
    final state = container.read(buildingsControllerProvider);
    expect(state.listPhase, BuildingListPhase.ready);
    expect(state.records.single.organizationId, north);
    expect(repo.calls, ['north:1']);
  });

  test('empty response and pagination states are explicit', () async {
    final repo = FakeBuildingRepository()
      ..onList = (organization, page, _) async => BuildingPage(
          data: page == 1
              ? [recordFor(organization)]
              : [recordFor(organization, id: 'second')],
          currentPage: page,
          perPage: 1,
          total: 2,
          lastPage: 2);
    final container = await containerFor(repo);
    addTearDown(container.dispose);
    final controller = container.read(buildingsControllerProvider.notifier);
    await controller.loadFirstPage();
    expect(container.read(buildingsControllerProvider).hasMore, isTrue);
    await controller.loadMore();
    expect(container.read(buildingsControllerProvider).records.length, 2);
    expect(container.read(buildingsControllerProvider).hasMore, isFalse);
    repo.onList = (_, __, ___) async => const BuildingPage(
        data: [], currentPage: 1, perPage: 25, total: 0, lastPage: 1);
    await controller.refresh();
    expect(container.read(buildingsControllerProvider).listPhase,
        BuildingListPhase.empty);
  });

  test('error and retry retain only current organization data', () async {
    final repo = FakeBuildingRepository()
      ..onList = (_, __, ___) async =>
          throw const BuildingFailure(BuildingFailureKind.network);
    final container = await containerFor(repo);
    addTearDown(container.dispose);
    final controller = container.read(buildingsControllerProvider.notifier);
    await controller.loadFirstPage();
    expect(container.read(buildingsControllerProvider).listPhase,
        BuildingListPhase.error);
    expect(container.read(buildingsControllerProvider).listFailure,
        BuildingFailureKind.network);
    repo.onList = null;
    await controller.loadFirstPage();
    expect(
        container
            .read(buildingsControllerProvider)
            .records
            .single
            .organizationId,
        north);
  });

  test('organization switch cancels and discards late north response',
      () async {
    final gate = Completer<BuildingPage>();
    CancelToken? request;
    final repo = FakeBuildingRepository()
      ..onList = (organization, page, cancelToken) {
        request = cancelToken;
        return gate.future;
      };
    final container = await containerFor(repo);
    addTearDown(container.dispose);
    final controller = container.read(buildingsControllerProvider.notifier);
    final pending = controller.loadFirstPage();
    await Future<void>.delayed(Duration.zero);
    await container
        .read(sessionControllerProvider.notifier)
        .switchOrganization(south);
    expect(request?.isCancelled, isTrue);
    expect(container.read(buildingsControllerProvider).records, isEmpty);
    gate.complete(const BuildingPage(
        data: [], currentPage: 1, perPage: 25, total: 0, lastPage: 1));
    await pending;
    expect(container.read(buildingsControllerProvider).records, isEmpty);
    repo.onList = null;
    await controller.loadFirstPage();
    expect(
        container
            .read(buildingsControllerProvider)
            .records
            .single
            .organizationId,
        south);
  });

  test('logout clears records and invalidates in-flight detail', () async {
    final gate = Completer<BuildingRecord>();
    final repo = FakeBuildingRepository()..onGet = (_, __, ___) => gate.future;
    final container = await containerFor(repo);
    addTearDown(container.dispose);
    final controller = container.read(buildingsControllerProvider.notifier);
    await controller.loadFirstPage();
    final pending = controller.loadDetail('building-north');
    await Future<void>.delayed(Duration.zero);
    await container.read(sessionControllerProvider.notifier).logout();
    gate.complete(recordFor(north));
    await pending;
    expect(container.read(buildingsControllerProvider).records, isEmpty);
    expect(container.read(buildingsControllerProvider).detail, isNull);
  });

  test('detail 404 shows unavailable and 401 closes session', () async {
    final repo = FakeBuildingRepository()
      ..onGet = (_, __, ___) async =>
          throw const BuildingFailure(BuildingFailureKind.notFound);
    final container = await containerFor(repo);
    addTearDown(container.dispose);
    final controller = container.read(buildingsControllerProvider.notifier);
    await controller.loadDetail('missing');
    expect(container.read(buildingsControllerProvider).detailPhase,
        BuildingDetailPhase.unavailable);
    repo.onList = (_, __, ___) async =>
        throw const BuildingFailure(BuildingFailureKind.unauthorized);
    await controller.loadFirstPage();
    expect(container.read(sessionControllerProvider).phase,
        SessionPhase.unauthenticated);
    expect(container.read(buildingsControllerProvider).records, isEmpty);
  });
}
