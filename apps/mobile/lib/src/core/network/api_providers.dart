import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'status_client.dart';

const apiBaseUrl = String.fromEnvironment(
  'BMS_API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8000',
);

final dioProvider = Provider<Dio>((ref) => Dio(BaseOptions(
      baseUrl: apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Accept': 'application/json'},
    )));

final statusClientProvider = Provider<StatusClient>(
  (ref) => StatusClient(ref.watch(dioProvider)),
);
