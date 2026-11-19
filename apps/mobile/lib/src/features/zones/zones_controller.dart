import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../floors/hierarchy_controller.dart';
import '../floors/hierarchy_models.dart';
import 'zone_models.dart';
import 'zone_repository.dart';

class ZonesController extends HierarchyController<ZoneRecord> {
  @override
  String recordId(ZoneRecord record) => record.id;
  @override
  Future<HierarchyPage<ZoneRecord>> list(String organizationId,
          HierarchyScope scope, int page, CancelToken cancelToken) =>
      ref.read(zoneRepositoryProvider).list(
          organizationId, scope.buildingId, scope.floorId!,
          page: page, cancelToken: cancelToken);

  @override
  Future<ZoneRecord> get(String organizationId, HierarchyScope scope, String id,
          CancelToken cancelToken) =>
      ref.read(zoneRepositoryProvider).get(
          organizationId, scope.buildingId, scope.floorId!, id,
          cancelToken: cancelToken);
}

final zonesControllerProvider =
    NotifierProvider<ZonesController, HierarchyState<ZoneRecord>>(
        ZonesController.new);
