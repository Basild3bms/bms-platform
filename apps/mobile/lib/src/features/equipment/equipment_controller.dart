import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../floors/hierarchy_controller.dart';
import '../floors/hierarchy_models.dart';
import 'equipment_models.dart';
import 'equipment_repository.dart';
import 'equipment_scope.dart';

class EquipmentController extends HierarchyController<EquipmentRecord> {
  @override
  String recordId(EquipmentRecord record) => record.id;

  @override
  Future<HierarchyPage<EquipmentRecord>> list(String organizationId,
      HierarchyScope scope, int page, CancelToken cancelToken) async {
    final equipmentScope = scope as EquipmentScope;
    final result = await ref.read(equipmentRepositoryProvider).list(
        organizationId, equipmentScope,
        page: page, cancelToken: cancelToken);
    return HierarchyPage(
        data: result.data,
        currentPage: result.meta.currentPage,
        perPage: result.meta.perPage,
        total: result.meta.total,
        lastPage: result.meta.lastPage);
  }

  @override
  Future<EquipmentRecord> get(String organizationId, HierarchyScope scope,
          String id, CancelToken cancelToken) async =>
      (await ref.read(equipmentRepositoryProvider).get(
              organizationId, scope.buildingId, id,
              cancelToken: cancelToken))
          .data;
}

final equipmentControllerProvider =
    NotifierProvider<EquipmentController, HierarchyState<EquipmentRecord>>(
        EquipmentController.new);
