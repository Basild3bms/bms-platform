import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'floor_models.dart';
import 'floor_repository.dart';
import 'hierarchy_controller.dart';
import 'hierarchy_models.dart';

class FloorsController extends HierarchyController<FloorRecord> {
  @override
  String recordId(FloorRecord record) => record.id;
  @override
  Future<HierarchyPage<FloorRecord>> list(String organizationId,
          HierarchyScope scope, int page, CancelToken cancelToken) =>
      ref.read(floorRepositoryProvider).list(organizationId, scope.buildingId,
          page: page, cancelToken: cancelToken);

  @override
  Future<FloorRecord> get(String organizationId, HierarchyScope scope,
          String id, CancelToken cancelToken) =>
      ref
          .read(floorRepositoryProvider)
          .get(organizationId, scope.buildingId, id, cancelToken: cancelToken);
}

final floorsControllerProvider =
    NotifierProvider<FloorsController, HierarchyState<FloorRecord>>(
        FloorsController.new);
