import 'package:bms_mobile/src/core/localization/app_strings.dart';
import 'package:bms_mobile/src/core/network/bearer_interceptor.dart';
import 'package:bms_mobile/src/features/buildings/building_models.dart';
import 'package:bms_mobile/src/features/equipment/equipment_api_client.dart';
import 'package:bms_mobile/src/features/equipment/equipment_models.dart';
import 'package:bms_mobile/src/features/equipment/equipment_repository.dart';
import 'package:bms_mobile/src/features/equipment/equipment_scope.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

const org = '11111111-1111-4111-8111-111111111111';
const building = '22222222-2222-4222-8222-222222222222';
const floor = '33333333-3333-4333-8333-333333333333';
const zone = '44444444-4444-4444-8444-444444444444';
const equipment = '55555555-5555-4555-8555-555555555555';

Map<String, Object?> equipmentJson({String? floorId, String? zoneId}) => {
      'id': equipment,
      'organization_id': org,
      'building_id': building,
      'floor_id': floorId,
      'zone_id': zoneId,
      'code': 'AHU-01',
      'name': 'Main AHU',
      'description': null,
      'type_code': 'ahu',
      'manufacturer': null,
      'model': null,
      'serial_number': null,
      'lifecycle_status': 'retired',
      'installed_on': '2026-11-19',
      'commissioned_on': null,
      'specifications': {'design_airflow_m3_h': 1250},
      'spec_schema_version': 1,
      'created_at': '2026-11-19T10:00:00Z',
      'updated_at': '2026-11-19T10:00:00Z',
    };

Map<String, Object?> page(Map<String, Object?> item) => {
      'data': [item],
      'meta': {'current_page': 1, 'per_page': 25, 'total': 1, 'last_page': 1}
    };

void main() {
  test(
      'nullable location, unknown codes and versioned specifications parse safely',
      () {
    final item = EquipmentRecord.fromJson(equipmentJson(), org, building);
    expect(item.floorId, isNull);
    expect(item.zoneId, isNull);
    expect(item.lifecycleStatus, 'retired');
    expect(item.specifications!.values['design_airflow_m3_h'], 1250);
    final future = EquipmentRecord.fromJson({
      ...equipmentJson(),
      'type_code': 'future_type',
      'lifecycle_status': 'future_status',
      'specifications': {'new_value': 5},
      'spec_schema_version': 2
    }, org, building);
    expect(future.typeCode, 'future_type');
    expect(future.specifications!.supported, isFalse);
    expect(const AppStrings('en').equipmentStatusLabel('future_status'),
        'future_status');
    expect(const AppStrings('fr').equipmentStatusLabel('retired'), 'Retiré');
    expect(const AppStrings('fr').equipmentDate('2026-11-19'), '19/11/2026');
    expect(
        () => EquipmentRecord.fromJson(
            {...equipmentJson(), 'zone_id': zone}, org, building),
        throwsFormatException);
    expect(
        () => EquipmentRecord.fromJson({
              ...equipmentJson(),
              'specifications': {'design_airflow_m3_h': -1}
            }, org, building),
        throwsFormatException);
  });

  test('list parser checks scope and pagination', () {
    expect(
        EquipmentListResponse.fromJson(page(equipmentJson()), org, building, 1)
            .data
            .single
            .code,
        'AHU-01');
    expect(
        () => EquipmentListResponse.fromJson(
            page(equipmentJson()), org, building, 1,
            floorId: floor),
        throwsFormatException);
    expect(
        () => EquipmentListResponse.fromJson(
            page(equipmentJson(floorId: floor)), org, building, 1,
            floorId: floor, zoneId: zone),
        throwsFormatException);
    expect(
        () => EquipmentListResponse.fromJson(
            page(equipmentJson()), org, building, 2),
        throwsFormatException);
    expect(
        () => EquipmentListResponse.fromJson({
              'data': [equipmentJson(), equipmentJson()],
              'meta': {
                'current_page': 1,
                'per_page': 25,
                'total': 2,
                'last_page': 1
              }
            }, org, building, 1),
        throwsFormatException);
  });

  test('client uses only exact GET routes and location filters', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.interceptors.add(BearerInterceptor(() => 'test-token'));
    final calls = <String>[];
    final filters = <Map<String, dynamic>>[];
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      calls.add('${options.method} ${options.path}');
      expect(options.headers['Authorization'], 'Bearer test-token');
      if (options.queryParameters.isEmpty) {
        handler.resolve(
            Response(requestOptions: options, data: {'data': equipmentJson()}));
      } else {
        final params = options.queryParameters;
        filters.add(Map<String, dynamic>.from(params));
        expect(params['page'], 1);
        expect(params['per_page'], 25);
        handler.resolve(Response(
            requestOptions: options,
            data: page(equipmentJson(
                floorId: params['floor_id'] as String?,
                zoneId: params['zone_id'] as String?))));
      }
    }));
    final client = EquipmentApiClient(dio);
    await client.list(org, EquipmentScope(building));
    await client.list(org, EquipmentScope(building, floorId: floor));
    await client.list(
        org, EquipmentScope(building, floorId: floor, zoneId: zone));
    await client.get(org, building, equipment);
    expect(calls, [
      for (var i = 0; i < 3; i++)
        'GET /api/v1/organizations/$org/buildings/$building/equipment',
      'GET /api/v1/organizations/$org/buildings/$building/equipment/$equipment'
    ]);
    expect(filters[0], {'page': 1, 'per_page': 25});
    expect(filters[1], {'page': 1, 'per_page': 25, 'floor_id': floor});
    expect(filters[2],
        {'page': 1, 'per_page': 25, 'floor_id': floor, 'zone_id': zone});
    expect(() => EquipmentScope(building, zoneId: zone), throwsFormatException);
    await expectLater(
        client.list(org, EquipmentScope(building, floorId: 'bad')),
        throwsFormatException);
    expect(calls.length, 4);
  });

  test('repository maps auth and offline failures', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    var status = 401;
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      handler.reject(DioException(
          requestOptions: options,
          response: Response(requestOptions: options, statusCode: status),
          type: DioExceptionType.badResponse));
    }));
    final repository = DioEquipmentRepository(EquipmentApiClient(dio));
    for (final pair in [
      (401, BuildingFailureKind.unauthorized),
      (403, BuildingFailureKind.forbidden),
      (404, BuildingFailureKind.notFound),
      (422, BuildingFailureKind.invalidInput),
      (429, BuildingFailureKind.rateLimited),
      (503, BuildingFailureKind.server),
    ]) {
      status = pair.$1;
      await expectLater(
          repository.list(org, EquipmentScope(building)),
          throwsA(
              isA<BuildingFailure>().having((e) => e.kind, 'kind', pair.$2)));
    }
  });
}
