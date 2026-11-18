import 'package:dio/dio.dart';

class StatusClient {
  StatusClient(this._dio);

  final Dio _dio;

  Future<bool> isResponding() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/status');
    final data = response.data;
    return response.statusCode == 200 &&
        data?['service'] == 'bms-api' &&
        data?['status'] == 'ok';
  }
}
