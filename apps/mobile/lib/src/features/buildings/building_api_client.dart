import 'package:dio/dio.dart';

import 'building_models.dart';

class BuildingApiClient {
  const BuildingApiClient(this._dio);

  final Dio _dio;

  String _base(String organizationId) =>
      '/api/v1/organizations/${Uri.encodeComponent(organizationId)}/buildings';

  Future<BuildingPage> list(String organizationId,
      {int page = 1, int perPage = 25, CancelToken? cancelToken}) async {
    final response = await _dio.get<dynamic>(_base(organizationId),
        queryParameters: {'page': page, 'per_page': perPage},
        cancelToken: cancelToken);
    final result = BuildingPage.fromJson(response.data, organizationId);
    if (result.currentPage != page) {
      throw const FormatException('Invalid building page.');
    }
    return result;
  }

  Future<BuildingRecord> get(String organizationId, String buildingId,
      {CancelToken? cancelToken}) async {
    final response = await _dio.get<dynamic>(
        '${_base(organizationId)}/${Uri.encodeComponent(buildingId)}',
        cancelToken: cancelToken);
    final body = response.data;
    if (body is! Map<String, dynamic>) {
      throw const FormatException('Invalid building response.');
    }
    return BuildingRecord.fromJson(body['data'], organizationId,
        buildingId: buildingId);
  }
}
