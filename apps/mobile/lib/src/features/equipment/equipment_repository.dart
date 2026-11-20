import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_providers.dart';
import '../floors/hierarchy_models.dart';
import 'equipment_api_client.dart';
import 'equipment_models.dart';
import 'equipment_scope.dart';

abstract class EquipmentRepository {
  Future<EquipmentListResponse> list(
      String organizationId, EquipmentScope scope,
      {int page = 1, int perPage = 25, CancelToken? cancelToken});
  Future<EquipmentDetailResponse> get(
      String organizationId, String buildingId, String equipmentId,
      {CancelToken? cancelToken});
}

class DioEquipmentRepository implements EquipmentRepository {
  const DioEquipmentRepository(this._client);
  final EquipmentApiClient _client;
  @override
  Future<EquipmentListResponse> list(
          String organizationId, EquipmentScope scope,
          {int page = 1, int perPage = 25, CancelToken? cancelToken}) =>
      safeHierarchyRead(() => _client.list(organizationId, scope,
          page: page, perPage: perPage, cancelToken: cancelToken));
  @override
  Future<EquipmentDetailResponse> get(
          String organizationId, String buildingId, String equipmentId,
          {CancelToken? cancelToken}) =>
      safeHierarchyRead(() => _client.get(
          organizationId, buildingId, equipmentId,
          cancelToken: cancelToken));
}

final equipmentRepositoryProvider = Provider<EquipmentRepository>((ref) =>
    DioEquipmentRepository(
        EquipmentApiClient(ref.watch(protectedDioProvider))));
