import 'package:dio/dio.dart';

import 'floor_models.dart';
import 'hierarchy_models.dart';

class FloorApiClient {
  const FloorApiClient(this._dio);
  final Dio _dio;

  String _base(String organizationId, String buildingId) =>
      '/api/v1/organizations/${hierarchyUuid(organizationId)}/buildings/${hierarchyUuid(buildingId)}/floors';

  Future<FloorPage> list(String organizationId, String buildingId,
      {int page = 1, int perPage = 25, CancelToken? cancelToken}) async {
    final response = await _dio.get<dynamic>(_base(organizationId, buildingId),
        queryParameters: {'page': page, 'per_page': perPage},
        cancelToken: cancelToken);
    final result = FloorPage.fromJson(response.data,
        (item) => FloorRecord.fromJson(item, organizationId, buildingId),
        idOf: (record) => record.id);
    if (result.currentPage != page) {
      throw const FormatException('Invalid floor page.');
    }
    return result;
  }

  Future<FloorRecord> get(
      String organizationId, String buildingId, String floorId,
      {CancelToken? cancelToken}) async {
    final response = await _dio.get<dynamic>(
        '${_base(organizationId, buildingId)}/${hierarchyUuid(floorId)}',
        cancelToken: cancelToken);
    return FloorRecord.fromJson(
        hierarchyObject(response.data)['data'], organizationId, buildingId,
        floorId: floorId);
  }
}
