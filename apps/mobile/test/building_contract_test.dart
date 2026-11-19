import 'package:bms_mobile/src/core/network/bearer_interceptor.dart';
import 'package:bms_mobile/src/features/buildings/building_api_client.dart';
import 'package:bms_mobile/src/features/buildings/building_models.dart';
import 'package:bms_mobile/src/features/buildings/building_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const north = '11111111-1111-4111-8111-111111111111';
  const buildingId = '22222222-2222-4222-8222-222222222222';
  final record = {
    'id': buildingId,
    'organization_id': north,
    'name': 'North Office',
    'code': 'N-001',
    'address': '1 Example Street',
    'timezone': 'Europe/Paris',
    'created_at': '2026-11-19T10:00:00.000000Z',
    'updated_at': '2026-11-19T10:00:00.000000Z',
  };

  test('typed client uses selected organization, bearer, and exact GET paths',
      () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.interceptors.add(BearerInterceptor(() => 'test-token'));
    final calls = <String>[];
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      calls.add('${options.method} ${options.path}');
      expect(options.headers['Authorization'], 'Bearer test-token');
      expect(options.method, 'GET');
      if (options.path.endsWith('/buildings')) {
        expect(options.queryParameters, {'page': 2, 'per_page': 10});
        handler.resolve(Response(requestOptions: options, data: {
          'data': [record],
          'meta': {
            'current_page': 2,
            'per_page': 10,
            'total': 11,
            'last_page': 2,
          },
        }));
      } else {
        handler
            .resolve(Response(requestOptions: options, data: {'data': record}));
      }
    }));

    final client = BuildingApiClient(dio);
    final page = await client.list(north, page: 2, perPage: 10);
    expect(page.data.single.name, 'North Office');
    expect(page.hasMore, isFalse);
    expect(page.total, 11);
    expect((await client.get(north, buildingId)).code, 'N-001');
    expect(calls, [
      'GET /api/v1/organizations/$north/buildings',
      'GET /api/v1/organizations/$north/buildings/$buildingId',
    ]);
  });

  test('strict parsing rejects foreign organization and malformed pagination',
      () {
    expect(
        () => BuildingRecord.fromJson(
            {...record, 'organization_id': 'foreign'}, north),
        throwsFormatException);
    expect(
        () => BuildingRecord.fromJson({...record}..remove('timezone'), north),
        throwsFormatException);
    expect(
        () => BuildingPage.fromJson({
              'data': [record],
              'meta': {
                'current_page': 1,
                'per_page': 0,
                'total': 1,
                'last_page': 1
              }
            }, north),
        throwsFormatException);
  });

  test('client rejects a page from a different pagination position', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      handler.resolve(Response(requestOptions: options, data: {
        'data': [record],
        'meta': {
          'current_page': 1,
          'per_page': 10,
          'total': 11,
          'last_page': 2
        },
      }));
    }));
    await expectLater(
      DioBuildingRepository(BuildingApiClient(dio)).list(north, page: 2),
      throwsA(isA<BuildingFailure>().having((failure) => failure.kind, 'kind',
          BuildingFailureKind.invalidResponse)),
    );
  });

  for (final entry in <int, BuildingFailureKind>{
    401: BuildingFailureKind.unauthorized,
    403: BuildingFailureKind.forbidden,
    404: BuildingFailureKind.notFound,
    422: BuildingFailureKind.invalidInput,
    429: BuildingFailureKind.rateLimited,
    500: BuildingFailureKind.server,
  }.entries) {
    test('repository maps ${entry.key} without leaking response details',
        () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
      dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
        handler.reject(DioException(
          requestOptions: options,
          response: Response(
              requestOptions: options,
              statusCode: entry.key,
              data: {'message': 'private server detail test-token'}),
          type: DioExceptionType.badResponse,
        ));
      }));
      final repository = DioBuildingRepository(BuildingApiClient(dio));
      try {
        await repository.list(north);
        fail('Expected a safe building failure');
      } on BuildingFailure catch (error) {
        expect(error.kind, entry.value);
        expect(error.toString(), isNot(contains('private server detail')));
        expect(error.toString(), isNot(contains('test-token')));
      }
    });
  }

  test('repository maps timeout and connectivity failures safely', () async {
    for (final type in [
      DioExceptionType.connectionTimeout,
      DioExceptionType.connectionError,
    ]) {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
      dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
        handler.reject(DioException(requestOptions: options, type: type));
      }));
      final repository = DioBuildingRepository(BuildingApiClient(dio));
      await expectLater(
        repository.list(north),
        throwsA(isA<BuildingFailure>().having(
          (failure) => failure.kind,
          'kind',
          type == DioExceptionType.connectionTimeout
              ? BuildingFailureKind.timeout
              : BuildingFailureKind.network,
        )),
      );
    }
  });
}
