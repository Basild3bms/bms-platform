import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'status_client.dart';
import 'api_origin.dart';
import 'bearer_interceptor.dart';
import '../../features/auth/session_controller.dart';

final apiBaseUrlProvider = Provider<String>((ref) => ApiOrigin.resolve());

final dioProvider = Provider<Dio>((ref) => Dio(BaseOptions(
      baseUrl: ref.watch(apiBaseUrlProvider),
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Accept': 'application/json'},
    )));

final protectedDioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: ref.watch(apiBaseUrlProvider),
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'Accept': 'application/json'},
  ));
  dio.interceptors.add(BearerInterceptor(
      () => ref.read(sessionControllerProvider.notifier).token));
  ref.onDispose(() => dio.close(force: true));
  return dio;
});

final statusClientProvider = Provider<StatusClient>(
  (ref) => StatusClient(ref.watch(dioProvider)),
);
