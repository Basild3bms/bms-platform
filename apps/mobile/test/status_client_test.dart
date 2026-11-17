import 'package:bms_mobile/src/core/network/status_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('status client uses the contracted public endpoint', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    String? requestedPath;
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        requestedPath = options.path;
        handler.resolve(Response<Map<String, dynamic>>(
          requestOptions: options,
          statusCode: 200,
          data: {'service': 'bms-api', 'version': '0.1.0', 'status': 'ok'},
        ));
      },
    ));

    expect(await StatusClient(dio).isResponding(), isTrue);
    expect(requestedPath, '/api/v1/status');
  });

  test('status client rejects an unexpected status payload', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) => handler.resolve(
        Response<Map<String, dynamic>>(
          requestOptions: options,
          statusCode: 200,
          data: {'service': 'other', 'status': 'ok'},
        ),
      ),
    ));

    expect(await StatusClient(dio).isResponding(), isFalse);
  });
}
