import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_controller.dart';
import 'building_models.dart';
import 'building_repository.dart';

enum BuildingListPhase { idle, loading, ready, empty, error }

enum BuildingDetailPhase { idle, loading, ready, unavailable, error }

class BuildingsState {
  const BuildingsState({
    this.records = const [],
    this.listPhase = BuildingListPhase.idle,
    this.listFailure,
    this.loadingMore = false,
    this.currentPage = 0,
    this.lastPage = 0,
    this.detail,
    this.detailPhase = BuildingDetailPhase.idle,
    this.detailFailure,
  });

  final List<BuildingRecord> records;
  final BuildingListPhase listPhase;
  final BuildingFailureKind? listFailure;
  final bool loadingMore;
  final int currentPage;
  final int lastPage;
  final BuildingRecord? detail;
  final BuildingDetailPhase detailPhase;
  final BuildingFailureKind? detailFailure;

  bool get hasMore => currentPage < lastPage;
}

class BuildingsController extends Notifier<BuildingsState> {
  OrganizationContext? _context;
  CancelToken? _listCancel;
  CancelToken? _detailCancel;
  int _listRequest = 0;
  int _detailRequest = 0;

  @override
  BuildingsState build() {
    _context = ref
        .read(sessionControllerProvider.notifier)
        .captureOrganizationContext();
    ref.listen(sessionControllerProvider, (previous, next) {
      final current = ref
          .read(sessionControllerProvider.notifier)
          .captureOrganizationContext();
      if (!_sameContext(_context, current)) {
        _context = current;
        _listRequest++;
        _detailRequest++;
        _listCancel?.cancel();
        _detailCancel?.cancel();
        state = const BuildingsState();
      }
    });
    ref.onDispose(() {
      _listCancel?.cancel();
      _detailCancel?.cancel();
    });
    return const BuildingsState();
  }

  bool _sameContext(OrganizationContext? a, OrganizationContext? b) =>
      a?.userId == b?.userId &&
      a?.organizationId == b?.organizationId &&
      a?.generation == b?.generation;

  OrganizationContext? _activeContext() {
    final current = ref
        .read(sessionControllerProvider.notifier)
        .captureOrganizationContext();
    if (!_sameContext(_context, current)) {
      _context = current;
      _listRequest++;
      _detailRequest++;
      _listCancel?.cancel();
      _detailCancel?.cancel();
      state = const BuildingsState();
    }
    return current;
  }

  bool _valid(OrganizationContext context) => ref
      .read(sessionControllerProvider.notifier)
      .isCurrentOrganizationContext(context);

  Future<void> loadFirstPage() async {
    final context = _activeContext();
    if (context == null) return;
    final request = ++_listRequest;
    _listCancel?.cancel();
    final cancel = CancelToken();
    _listCancel = cancel;
    state = BuildingsState(
      listPhase: BuildingListPhase.loading,
      detail: state.detail,
      detailPhase: state.detailPhase,
      detailFailure: state.detailFailure,
    );
    try {
      final page = await ref
          .read(buildingRepositoryProvider)
          .list(context.organizationId, page: 1, cancelToken: cancel);
      if (!_valid(context) || request != _listRequest) return;
      state = BuildingsState(
        records: page.data,
        listPhase: page.data.isEmpty
            ? BuildingListPhase.empty
            : BuildingListPhase.ready,
        currentPage: page.currentPage,
        lastPage: page.lastPage,
        detail: state.detail,
        detailPhase: state.detailPhase,
        detailFailure: state.detailFailure,
      );
    } catch (error) {
      if (!_valid(context) || request != _listRequest) return;
      await _listFailure(error, context);
    }
  }

  Future<void> refresh() => loadFirstPage();

  Future<void> loadMore() async {
    final context = _activeContext();
    if (context == null ||
        !state.hasMore ||
        state.loadingMore ||
        state.listPhase != BuildingListPhase.ready) {
      return;
    }
    final request = ++_listRequest;
    _listCancel?.cancel();
    final cancel = CancelToken();
    _listCancel = cancel;
    final existing = state.records;
    final currentPage = state.currentPage;
    final lastPage = state.lastPage;
    state = BuildingsState(
      records: existing,
      listPhase: BuildingListPhase.ready,
      currentPage: currentPage,
      lastPage: lastPage,
      loadingMore: true,
      detail: state.detail,
      detailPhase: state.detailPhase,
      detailFailure: state.detailFailure,
    );
    try {
      final page = await ref.read(buildingRepositoryProvider).list(
          context.organizationId,
          page: currentPage + 1,
          cancelToken: cancel);
      if (!_valid(context) || request != _listRequest) return;
      state = BuildingsState(
        records: List.unmodifiable([...existing, ...page.data]),
        listPhase: BuildingListPhase.ready,
        currentPage: page.currentPage,
        lastPage: page.lastPage,
        detail: state.detail,
        detailPhase: state.detailPhase,
        detailFailure: state.detailFailure,
      );
    } catch (error) {
      if (!_valid(context) || request != _listRequest) return;
      if (error is BuildingFailure &&
          (error.kind == BuildingFailureKind.unauthorized ||
              error.kind == BuildingFailureKind.forbidden ||
              error.kind == BuildingFailureKind.notFound)) {
        await _listFailure(error, context);
        return;
      }
      state = BuildingsState(
        records: existing,
        listPhase: BuildingListPhase.ready,
        listFailure:
            error is BuildingFailure ? error.kind : BuildingFailureKind.server,
        currentPage: currentPage,
        lastPage: lastPage,
        detail: state.detail,
        detailPhase: state.detailPhase,
        detailFailure: state.detailFailure,
      );
    }
  }

  Future<void> _listFailure(Object error, OrganizationContext context) async {
    if (error is DioException && error.type == DioExceptionType.cancel) return;
    final kind =
        error is BuildingFailure ? error.kind : BuildingFailureKind.server;
    if (kind == BuildingFailureKind.unauthorized) {
      await ref.read(sessionControllerProvider.notifier).logout();
      return;
    }
    if (kind == BuildingFailureKind.forbidden ||
        kind == BuildingFailureKind.notFound) {
      await ref
          .read(sessionControllerProvider.notifier)
          .organizationAccessLost();
      return;
    }
    if (!_valid(context)) return;
    state = BuildingsState(
      listPhase: BuildingListPhase.error,
      listFailure: kind,
      detail: state.detail,
      detailPhase: state.detailPhase,
      detailFailure: state.detailFailure,
    );
  }

  Future<void> loadDetail(String buildingId) async {
    final context = _activeContext();
    if (context == null) return;
    final request = ++_detailRequest;
    _detailCancel?.cancel();
    final cancel = CancelToken();
    _detailCancel = cancel;
    state = BuildingsState(
      records: state.records,
      listPhase: state.listPhase,
      listFailure: state.listFailure,
      loadingMore: state.loadingMore,
      currentPage: state.currentPage,
      lastPage: state.lastPage,
      detailPhase: BuildingDetailPhase.loading,
    );
    try {
      final detail = await ref
          .read(buildingRepositoryProvider)
          .get(context.organizationId, buildingId, cancelToken: cancel);
      if (!_valid(context) || request != _detailRequest) return;
      state = _withDetail(detail, BuildingDetailPhase.ready);
    } catch (error) {
      if (!_valid(context) || request != _detailRequest) return;
      if (error is DioException && error.type == DioExceptionType.cancel) {
        return;
      }
      final kind =
          error is BuildingFailure ? error.kind : BuildingFailureKind.server;
      if (kind == BuildingFailureKind.unauthorized) {
        await ref.read(sessionControllerProvider.notifier).logout();
        return;
      }
      state = _withDetail(
          null,
          kind == BuildingFailureKind.forbidden ||
                  kind == BuildingFailureKind.notFound
              ? BuildingDetailPhase.unavailable
              : BuildingDetailPhase.error,
          failure: kind);
    }
  }

  BuildingsState _withDetail(BuildingRecord? detail, BuildingDetailPhase phase,
          {BuildingFailureKind? failure}) =>
      BuildingsState(
        records: state.records,
        listPhase: state.listPhase,
        listFailure: state.listFailure,
        loadingMore: state.loadingMore,
        currentPage: state.currentPage,
        lastPage: state.lastPage,
        detail: detail,
        detailPhase: phase,
        detailFailure: failure,
      );
}

final buildingsControllerProvider =
    NotifierProvider<BuildingsController, BuildingsState>(
        BuildingsController.new);
