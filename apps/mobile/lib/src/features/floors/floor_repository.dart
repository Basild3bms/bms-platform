import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_providers.dart';
import 'floor_api_client.dart';
import 'floor_models.dart';
import 'hierarchy_models.dart';

abstract class FloorRepository {
  Future<FloorPage> list(String organizationId, String buildingId,
      {int page = 1, int perPage = 25, CancelToken? cancelToken});
  Future<FloorRecord> get(
      String organizationId, String buildingId, String floorId,
      {CancelToken? cancelToken});
}

class DioFloorRepository implements FloorRepository {
  const DioFloorRepository(this._client);
  final FloorApiClient _client;

  @override
  Future<FloorPage> list(String organizationId, String buildingId,
          {int page = 1, int perPage = 25, CancelToken? cancelToken}) =>
      safeHierarchyRead(() => _client.list(organizationId, buildingId,
          page: page, perPage: perPage, cancelToken: cancelToken));

  @override
  Future<FloorRecord> get(
          String organizationId, String buildingId, String floorId,
          {CancelToken? cancelToken}) =>
      safeHierarchyRead(() => _client.get(organizationId, buildingId, floorId,
          cancelToken: cancelToken));
}

final floorRepositoryProvider = Provider<FloorRepository>((ref) =>
    DioFloorRepository(FloorApiClient(ref.watch(protectedDioProvider))));
