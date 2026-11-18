import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'status_client.dart';
import 'api_origin.dart';

final apiBaseUrlProvider = Provider<String>((ref) => ApiOrigin.resolve());

final dioProvider = Provider<Dio>((ref) => Dio(BaseOptions(
      baseUrl: ref.watch(apiBaseUrlProvider),
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Accept': 'application/json'},
    )));

final statusClientProvider = Provider<StatusClient>(
  (ref) => StatusClient(ref.watch(dioProvider)),
);
