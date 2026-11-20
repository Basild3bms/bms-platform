import 'package:bms_mobile/src/core/network/bearer_interceptor.dart';
import 'package:bms_mobile/src/features/buildings/building_models.dart';
import 'package:bms_mobile/src/features/floors/floor_api_client.dart';
import 'package:bms_mobile/src/features/floors/floor_models.dart';
import 'package:bms_mobile/src/features/floors/floor_repository.dart';
import 'package:bms_mobile/src/features/zones/zone_api_client.dart';
import 'package:bms_mobile/src/features/zones/zone_models.dart';
import 'package:bms_mobile/src/features/zones/zone_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

const org = '11111111-1111-4111-8111-111111111111';
const building = '22222222-2222-4222-8222-222222222222';
const floor = '33333333-3333-4333-8333-333333333333';
const zone = '44444444-4444-4444-8444-444444444444';

final floorJson = {
  'id': floor,
  'organization_id': org,
  'building_id': building,
  'name': 'Basement',
  'code': 'B1',
  'level': -1,
  'created_at': '2026-11-19T10:00:00Z',
  'updated_at': '2026-11-19T10:00:00Z',
};
final zoneJson = {
  'id': zone,
  'organization_id': org,
  'building_id': building,
  'floor_id': floor,
  'name': 'Plant',
  'code': 'P1',
  'zone_type': 'plant_room',
  'created_at': '2026-11-19T10:00:00Z',
  'updated_at': '2026-11-19T10:00:00Z',
};

Map<String, Object> page(Object record, int number) => {
      'data': [record],
      'meta': {
        'current_page': number,
        'per_page': 10,
        'total': 11,
        'last_page': 2
      },
    };

void main() {
  test('floor and zone models validate every hierarchy identifier and type',
      () {
    expect(FloorRecord.fromJson(floorJson, org, building).level, -1);
    expect(ZoneRecord.fromJson(zoneJson, org, building, floor).zoneType,
        ZoneType.plantRoom);
    for (final field in ['organization_id', 'building_id']) {
      expect(
          () => FloorRecord.fromJson(
              {...floorJson, field: 'foreign'}, org, building),
          throwsFormatException);
      expect(
          () => ZoneRecord.fromJson(
              {...zoneJson, field: 'foreign'}, org, building, floor),
          throwsFormatException);
    }
    expect(
        () => ZoneRecord.fromJson(
            {...zoneJson, 'floor_id': 'foreign'}, org, building, floor),
        throwsFormatException);
    expect(
        () => FloorRecord.fromJson(floorJson, org, building, floorId: 'wrong'),
        throwsFormatException);
    expect(
        () => ZoneRecord.fromJson(zoneJson, org, building, floor,
            zoneId: 'wrong'),
        throwsFormatException);
    expect(
        () => FloorRecord.fromJson({...floorJson, 'level': 1.5}, org, building),
        throwsFormatException);
    expect(
        () => ZoneRecord.fromJson(
            {...zoneJson, 'zone_type': 'unknown'}, org, building, floor),
        throwsFormatException);
    expect(
        () => FloorRecord.fromJson(
            {...floorJson, 'id': 'floor-1'}, org, building),
        throwsFormatException);
    expect(
        () => ZoneRecord.fromJson(
            {...zoneJson, 'floor_id': 'floor-1'}, org, building, floor),
        throwsFormatException);
  });

  test('clients reject malformed UUID paths before sending a request',
      () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    var sent = 0;
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      sent++;
      handler.next(options);
    }));
    await expectLater(
        DioFloorRepository(FloorApiClient(dio)).list('bad-org', building),
        throwsA(isA<BuildingFailure>().having(
            (e) => e.kind, 'kind', BuildingFailureKind.invalidResponse)));
    await expectLater(
        DioZoneRepository(ZoneApiClient(dio))
            .get(org, building, floor, 'bad-zone'),
        throwsA(isA<BuildingFailure>().having(
            (e) => e.kind, 'kind', BuildingFailureKind.invalidResponse)));
    expect(sent, 0);
  });

  test('duplicate IDs and inconsistent totals are rejected', () {
    FloorRecord parse(Object? item) =>
        FloorRecord.fromJson(item, org, building);
    expect(
        () => FloorPage.fromJson({
              'data': [floorJson, floorJson],
              'meta': {
                'current_page': 1,
                'per_page': 2,
                'total': 2,
                'last_page': 1
              },
            }, parse, idOf: (item) => item.id),
        throwsFormatException);
    expect(
        () => FloorPage.fromJson({
              'data': [floorJson],
              'meta': {
                'current_page': 1,
                'per_page': 10,
                'total': 1,
                'last_page': 3
              },
            }, parse, idOf: (item) => item.id),
        throwsFormatException);
  });

  test('pagination parser rejects malformed or inconsistent responses', () {
    expect(
        () => FloorPage.fromJson({
              'data': [floorJson]
            }, (item) => FloorRecord.fromJson(item, org, building)),
        throwsFormatException);
    expect(
        () => ZonePage.fromJson({
              'data': [zoneJson],
              'meta': {
                'current_page': 3,
                'per_page': 1,
                'total': 1,
                'last_page': 2
              }
            }, (item) => ZoneRecord.fromJson(item, org, building, floor)),
        throwsFormatException);
  });

  test('protected clients use exact GET paths and bearer for list and detail',
      () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.interceptors.add(BearerInterceptor(() => 'test-token'));
    final calls = <String>[];
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      calls.add('${options.method} ${options.path}');
      expect(options.method, 'GET');
      expect(options.headers['Authorization'], 'Bearer test-token');
      final isZone = options.path.contains('/zones');
      final item = isZone ? zoneJson : floorJson;
      if (options.queryParameters.isNotEmpty) {
        expect(options.queryParameters, {'page': 2, 'per_page': 10});
        handler.resolve(Response(requestOptions: options, data: page(item, 2)));
      } else {
        handler
            .resolve(Response(requestOptions: options, data: {'data': item}));
      }
    }));
    final floors = FloorApiClient(dio);
    final zones = ZoneApiClient(dio);
    expect(
        (await floors.list(org, building, page: 2, perPage: 10))
            .data
            .single
            .level,
        -1);
    expect((await floors.get(org, building, floor)).id, floor);
    expect(
        (await zones.list(org, building, floor, page: 2, perPage: 10))
            .data
            .single
            .zoneType,
        ZoneType.plantRoom);
    expect((await zones.get(org, building, floor, zone)).id, zone);
    expect(calls, [
      'GET /api/v1/organizations/$org/buildings/$building/floors',
      'GET /api/v1/organizations/$org/buildings/$building/floors/$floor',
      'GET /api/v1/organizations/$org/buildings/$building/floors/$floor/zones',
      'GET /api/v1/organizations/$org/buildings/$building/floors/$floor/zones/$zone',
    ]);
  });

  test('repositories map invalid responses and authorization errors safely',
      () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      if (options.path.endsWith('/zones')) {
        handler.reject(DioException(
            requestOptions: options,
            response: Response(
                requestOptions: options,
                statusCode: 403,
                data: {'message': 'private token'}),
            type: DioExceptionType.badResponse));
      } else {
        handler.resolve(Response(
            requestOptions: options,
            data: page({...floorJson, 'building_id': 'foreign'}, 1)));
      }
    }));
    await expectLater(
        DioFloorRepository(FloorApiClient(dio)).list(org, building),
        throwsA(isA<BuildingFailure>().having(
            (e) => e.kind, 'kind', BuildingFailureKind.invalidResponse)));
    await expectLater(
        DioZoneRepository(ZoneApiClient(dio)).list(org, building, floor),
        throwsA(isA<BuildingFailure>()
            .having((e) => e.kind, 'kind', BuildingFailureKind.forbidden)));
  });
}
