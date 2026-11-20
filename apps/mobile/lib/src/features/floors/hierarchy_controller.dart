import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_controller.dart';
import '../buildings/building_models.dart';
import 'hierarchy_models.dart';

enum HierarchyListPhase { idle, loading, ready, empty, error }

enum HierarchyDetailPhase { idle, loading, ready, unavailable, error }

class HierarchyScope {
  const HierarchyScope(this.buildingId, [this.floorId]);
  final String buildingId;
  final String? floorId;

  @override
  bool operator ==(Object other) =>
      other.runtimeType == runtimeType &&
      other is HierarchyScope &&
      other.buildingId == buildingId &&
      other.floorId == floorId;
  @override
  int get hashCode => Object.hash(buildingId, floorId);
}

class HierarchyState<T> {
  const HierarchyState(
      {this.scope,
      this.records = const [],
      this.listPhase = HierarchyListPhase.idle,
      this.listFailure,
      this.loadingMore = false,
      this.currentPage = 0,
      this.lastPage = 0,
      this.detail,
      this.detailId,
      this.detailPhase = HierarchyDetailPhase.idle,
      this.detailFailure});

  final HierarchyScope? scope;
  final List<T> records;
  final HierarchyListPhase listPhase;
  final BuildingFailureKind? listFailure;
  final bool loadingMore;
  final int currentPage, lastPage;
  final T? detail;
  final String? detailId;
  final HierarchyDetailPhase detailPhase;
  final BuildingFailureKind? detailFailure;
  bool get hasMore => currentPage < lastPage;
}

abstract class HierarchyController<T> extends Notifier<HierarchyState<T>> {
  OrganizationContext? _context;
  CancelToken? _listCancel, _detailCancel;
  int _listRequest = 0, _detailRequest = 0;

  Future<HierarchyPage<T>> list(String organizationId, HierarchyScope scope,
      int page, CancelToken cancelToken);
  Future<T> get(String organizationId, HierarchyScope scope, String id,
      CancelToken cancelToken);
  String recordId(T record);

  @override
  HierarchyState<T> build() {
    _context = ref
        .read(sessionControllerProvider.notifier)
        .captureOrganizationContext();
    ref.listen(sessionControllerProvider, (previous, next) {
      final current = ref
          .read(sessionControllerProvider.notifier)
          .captureOrganizationContext();
      if (!_sameContext(_context, current)) {
        _context = current;
        _reset();
      }
    });
    ref.onDispose(() {
      _listCancel?.cancel();
      _detailCancel?.cancel();
    });
    return HierarchyState<T>();
  }

  bool _sameContext(OrganizationContext? a, OrganizationContext? b) =>
      a?.userId == b?.userId &&
      a?.organizationId == b?.organizationId &&
      a?.generation == b?.generation;

  void _reset({HierarchyScope? scope}) {
    _listRequest++;
    _detailRequest++;
    _listCancel?.cancel();
    _detailCancel?.cancel();
    state = HierarchyState<T>(scope: scope);
  }

  OrganizationContext? _active(HierarchyScope scope) {
    final current = ref
        .read(sessionControllerProvider.notifier)
        .captureOrganizationContext();
    if (!_sameContext(_context, current)) {
      _context = current;
      _reset();
    }
    if (current == null) {
      return null;
    }
    if (state.scope != scope) {
      _reset(scope: scope);
    }
    return current;
  }

  bool _valid(OrganizationContext context, HierarchyScope scope) =>
      ref.mounted &&
      state.scope == scope &&
      ref
          .read(sessionControllerProvider.notifier)
          .isCurrentOrganizationContext(context);

  Future<void> loadFirstPage(HierarchyScope scope) async {
    final context = _active(scope);
    if (context == null) {
      return;
    }
    final request = ++_listRequest;
    _listCancel?.cancel();
    final cancel = CancelToken();
    _listCancel = cancel;
    state = HierarchyState<T>(
        scope: scope,
        listPhase: HierarchyListPhase.loading,
        detail: state.detail,
        detailId: state.detailId,
        detailPhase: state.detailPhase,
        detailFailure: state.detailFailure);
    try {
      final page = await list(context.organizationId, scope, 1, cancel);
      if (!_valid(context, scope) || request != _listRequest) {
        return;
      }
      _checkUnique(page.data);
      state = HierarchyState<T>(
          scope: scope,
          records: page.data,
          listPhase: page.data.isEmpty
              ? HierarchyListPhase.empty
              : HierarchyListPhase.ready,
          currentPage: page.currentPage,
          lastPage: page.lastPage,
          detail: state.detail,
          detailId: state.detailId,
          detailPhase: state.detailPhase,
          detailFailure: state.detailFailure);
    } catch (error) {
      if (!_valid(context, scope) || request != _listRequest) {
        return;
      }
      if (error is DioException && error.type == DioExceptionType.cancel) {
        return;
      }
      final kind =
          error is BuildingFailure ? error.kind : BuildingFailureKind.server;
      if (kind == BuildingFailureKind.unauthorized) {
        await ref.read(sessionControllerProvider.notifier).logout();
        return;
      }
      state = HierarchyState<T>(
          scope: scope,
          listPhase: HierarchyListPhase.error,
          listFailure: kind,
          detail: state.detail,
          detailId: state.detailId,
          detailPhase: state.detailPhase,
          detailFailure: state.detailFailure);
    }
  }

  Future<void> refresh(HierarchyScope scope) => loadFirstPage(scope);

  void releaseList(HierarchyScope scope) {
    if (!ref.mounted) return;
    if (state.scope != scope) return;
    _listRequest++;
    _listCancel?.cancel();
    if (state.loadingMore) {
      state = HierarchyState<T>(
          scope: scope,
          records: state.records,
          listPhase: state.listPhase,
          listFailure: state.listFailure,
          currentPage: state.currentPage,
          lastPage: state.lastPage,
          detail: state.detail,
          detailId: state.detailId,
          detailPhase: state.detailPhase,
          detailFailure: state.detailFailure);
    }
  }

  void releaseDetail(HierarchyScope scope, String id) {
    if (!ref.mounted) return;
    if (state.scope != scope || state.detailId != id) return;
    _detailRequest++;
    _detailCancel?.cancel();
  }

  Future<void> loadMore(HierarchyScope scope) async {
    final context = _active(scope);
    if (context == null ||
        !state.hasMore ||
        state.loadingMore ||
        state.listPhase != HierarchyListPhase.ready) {
      return;
    }
    final request = ++_listRequest;
    _listCancel?.cancel();
    final cancel = CancelToken();
    _listCancel = cancel;
    final existing = state.records;
    final currentPage = state.currentPage;
    final lastPage = state.lastPage;
    state = HierarchyState<T>(
        scope: scope,
        records: existing,
        listPhase: HierarchyListPhase.ready,
        loadingMore: true,
        currentPage: currentPage,
        lastPage: lastPage,
        detail: state.detail,
        detailId: state.detailId,
        detailPhase: state.detailPhase,
        detailFailure: state.detailFailure);
    try {
      final page =
          await list(context.organizationId, scope, currentPage + 1, cancel);
      if (!_valid(context, scope) || request != _listRequest) {
        return;
      }
      _checkUnique(page.data, existing: existing);
      state = HierarchyState<T>(
          scope: scope,
          records: List.unmodifiable([...existing, ...page.data]),
          listPhase: HierarchyListPhase.ready,
          currentPage: page.currentPage,
          lastPage: page.lastPage,
          detail: state.detail,
          detailId: state.detailId,
          detailPhase: state.detailPhase,
          detailFailure: state.detailFailure);
    } catch (error) {
      if (!_valid(context, scope) || request != _listRequest) {
        return;
      }
      if (error is DioException && error.type == DioExceptionType.cancel) {
        return;
      }
      final kind =
          error is BuildingFailure ? error.kind : BuildingFailureKind.server;
      if (kind == BuildingFailureKind.unauthorized) {
        await ref.read(sessionControllerProvider.notifier).logout();
        return;
      }
      state = HierarchyState<T>(
          scope: scope,
          records: existing,
          listPhase: HierarchyListPhase.ready,
          listFailure: kind,
          currentPage: currentPage,
          lastPage: lastPage,
          detail: state.detail,
          detailId: state.detailId,
          detailPhase: state.detailPhase,
          detailFailure: state.detailFailure);
    }
  }

  Future<void> loadDetail(HierarchyScope scope, String id) async {
    final context = _active(scope);
    if (context == null) {
      return;
    }
    final request = ++_detailRequest;
    _detailCancel?.cancel();
    final cancel = CancelToken();
    _detailCancel = cancel;
    _withDetail(null, id, HierarchyDetailPhase.loading);
    try {
      final result = await get(context.organizationId, scope, id, cancel);
      if (!_valid(context, scope) || request != _detailRequest) {
        return;
      }
      _withDetail(result, id, HierarchyDetailPhase.ready);
    } catch (error) {
      if (!_valid(context, scope) || request != _detailRequest) {
        return;
      }
      if (error is DioException && error.type == DioExceptionType.cancel) {
        return;
      }
      final kind =
          error is BuildingFailure ? error.kind : BuildingFailureKind.server;
      if (kind == BuildingFailureKind.unauthorized) {
        await ref.read(sessionControllerProvider.notifier).logout();
        return;
      }
      _withDetail(
          null,
          id,
          kind == BuildingFailureKind.forbidden ||
                  kind == BuildingFailureKind.notFound
              ? HierarchyDetailPhase.unavailable
              : HierarchyDetailPhase.error,
          failure: kind);
    }
  }

  void _withDetail(T? detail, String id, HierarchyDetailPhase phase,
      {BuildingFailureKind? failure}) {
    state = HierarchyState<T>(
        scope: state.scope,
        records: state.records,
        listPhase: state.listPhase,
        listFailure: state.listFailure,
        loadingMore: state.loadingMore,
        currentPage: state.currentPage,
        lastPage: state.lastPage,
        detail: detail,
        detailId: id,
        detailPhase: phase,
        detailFailure: failure);
  }

  void _checkUnique(List<T> records, {List<T> existing = const []}) {
    final ids = existing.map(recordId).toSet();
    for (final record in records) {
      if (!ids.add(recordId(record))) {
        throw const BuildingFailure(BuildingFailureKind.invalidResponse);
      }
    }
  }
}
