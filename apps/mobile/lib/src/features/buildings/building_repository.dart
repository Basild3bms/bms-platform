import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_providers.dart';
import 'building_api_client.dart';
import 'building_models.dart';

abstract class BuildingRepository {
  Future<BuildingPage> list(String organizationId,
      {int page = 1, int perPage = 25, CancelToken? cancelToken});
  Future<BuildingRecord> get(String organizationId, String buildingId,
      {CancelToken? cancelToken});
}

class DioBuildingRepository implements BuildingRepository {
  const DioBuildingRepository(this._client);

  final BuildingApiClient _client;

  Future<T> _safe<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on FormatException {
      throw const BuildingFailure(BuildingFailureKind.invalidResponse);
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) rethrow;
      final status = error.response?.statusCode;
      if (status == 401) {
        throw const BuildingFailure(BuildingFailureKind.unauthorized);
      }
      if (status == 403) {
        throw const BuildingFailure(BuildingFailureKind.forbidden);
      }
      if (status == 404) {
        throw const BuildingFailure(BuildingFailureKind.notFound);
      }
      if (status == 422) {
        throw const BuildingFailure(BuildingFailureKind.invalidInput);
      }
      if (status == 429) {
        throw const BuildingFailure(BuildingFailureKind.rateLimited);
      }
      if (status != null) {
        throw const BuildingFailure(BuildingFailureKind.server);
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        throw const BuildingFailure(BuildingFailureKind.timeout);
      }
      throw const BuildingFailure(BuildingFailureKind.network);
    }
  }

  @override
  Future<BuildingPage> list(String organizationId,
          {int page = 1, int perPage = 25, CancelToken? cancelToken}) =>
      _safe(() => _client.list(organizationId,
          page: page, perPage: perPage, cancelToken: cancelToken));

  @override
  Future<BuildingRecord> get(String organizationId, String buildingId,
          {CancelToken? cancelToken}) =>
      _safe(() =>
          _client.get(organizationId, buildingId, cancelToken: cancelToken));
}

final buildingRepositoryProvider = Provider<BuildingRepository>((ref) =>
    DioBuildingRepository(BuildingApiClient(ref.watch(protectedDioProvider))));
