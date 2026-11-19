import 'package:dio/dio.dart';

import '../floors/hierarchy_models.dart';
import 'zone_models.dart';

class ZoneApiClient {
  const ZoneApiClient(this._dio);
  final Dio _dio;

  String _base(String organizationId, String buildingId, String floorId) =>
      '/api/v1/organizations/${hierarchyUuid(organizationId)}/buildings/${hierarchyUuid(buildingId)}/floors/${hierarchyUuid(floorId)}/zones';

  Future<ZonePage> list(
      String organizationId, String buildingId, String floorId,
      {int page = 1, int perPage = 25, CancelToken? cancelToken}) async {
    final response = await _dio.get<dynamic>(
        _base(organizationId, buildingId, floorId),
        queryParameters: {'page': page, 'per_page': perPage},
        cancelToken: cancelToken);
    final result = ZonePage.fromJson(
        response.data,
        (item) =>
            ZoneRecord.fromJson(item, organizationId, buildingId, floorId),
        idOf: (record) => record.id);
    if (result.currentPage != page) {
      throw const FormatException('Invalid zone page.');
    }
    return result;
  }

  Future<ZoneRecord> get(
      String organizationId, String buildingId, String floorId, String zoneId,
      {CancelToken? cancelToken}) async {
    final response = await _dio.get<dynamic>(
        '${_base(organizationId, buildingId, floorId)}/${hierarchyUuid(zoneId)}',
        cancelToken: cancelToken);
    return ZoneRecord.fromJson(hierarchyObject(response.data)['data'],
        organizationId, buildingId, floorId,
        zoneId: zoneId);
  }
}
