import 'package:dio/dio.dart';

import '../floors/hierarchy_models.dart';
import 'equipment_models.dart';
import 'equipment_scope.dart';

class EquipmentApiClient {
  const EquipmentApiClient(this._dio);
  final Dio _dio;

  String _base(String organizationId, String buildingId) =>
      '/api/v1/organizations/${hierarchyUuid(organizationId)}/buildings/${hierarchyUuid(buildingId)}/equipment';

  Future<EquipmentListResponse> list(
      String organizationId, EquipmentScope scope,
      {int page = 1, int perPage = 25, CancelToken? cancelToken}) async {
    if (page < 1 || perPage < 1 || perPage > 100) {
      throw const FormatException('Invalid equipment pagination.');
    }
    if (scope.floorId != null) {
      hierarchyUuid(scope.floorId!);
    }
    if (scope.zoneId != null) {
      hierarchyUuid(scope.zoneId!);
    }
    final response =
        await _dio.get<dynamic>(_base(organizationId, scope.buildingId),
            queryParameters: {
              'page': page,
              'per_page': perPage,
              if (scope.floorId != null) 'floor_id': scope.floorId,
              if (scope.zoneId != null) 'zone_id': scope.zoneId,
              if (scope.typeCode != null) 'type_code': scope.typeCode,
              if (scope.lifecycleStatus != null)
                'lifecycle_status': scope.lifecycleStatus,
              if (scope.query != null) 'q': scope.query
            },
            cancelToken: cancelToken);
    return EquipmentListResponse.fromJson(
        response.data, organizationId, scope.buildingId, page,
        floorId: scope.floorId, zoneId: scope.zoneId);
  }

  Future<EquipmentDetailResponse> get(
      String organizationId, String buildingId, String equipmentId,
      {CancelToken? cancelToken}) async {
    final response = await _dio.get<dynamic>(
        '${_base(organizationId, buildingId)}/${hierarchyUuid(equipmentId)}',
        cancelToken: cancelToken);
    return EquipmentDetailResponse.fromJson(
        response.data, organizationId, buildingId, equipmentId);
  }
}
