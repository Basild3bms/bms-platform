import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_providers.dart';
import '../floors/hierarchy_models.dart';
import 'zone_api_client.dart';
import 'zone_models.dart';

abstract class ZoneRepository {
  Future<ZonePage> list(
      String organizationId, String buildingId, String floorId,
      {int page = 1, int perPage = 25, CancelToken? cancelToken});
  Future<ZoneRecord> get(
      String organizationId, String buildingId, String floorId, String zoneId,
      {CancelToken? cancelToken});
}

class DioZoneRepository implements ZoneRepository {
  const DioZoneRepository(this._client);
  final ZoneApiClient _client;

  @override
  Future<ZonePage> list(
          String organizationId, String buildingId, String floorId,
          {int page = 1, int perPage = 25, CancelToken? cancelToken}) =>
      safeHierarchyRead(() => _client.list(organizationId, buildingId, floorId,
          page: page, perPage: perPage, cancelToken: cancelToken));

  @override
  Future<ZoneRecord> get(String organizationId, String buildingId,
          String floorId, String zoneId, {CancelToken? cancelToken}) =>
      safeHierarchyRead(() => _client.get(
          organizationId, buildingId, floorId, zoneId,
          cancelToken: cancelToken));
}

final zoneRepositoryProvider = Provider<ZoneRepository>(
    (ref) => DioZoneRepository(ZoneApiClient(ref.watch(protectedDioProvider))));
