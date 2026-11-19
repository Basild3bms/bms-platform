import 'package:bms_mobile/src/app.dart';
import 'package:bms_mobile/src/core/network/api_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/authenticated_session.dart';
import 'package:bms_mobile/src/features/auth/session_controller.dart';

void main() {
  testWidgets('overview checks the contracted API status on demand',
      (tester) async {
    final dio = Dio(BaseOptions(baseUrl: 'http://10.0.2.2:8000'));
    String? requestedPath;
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      requestedPath = options.path;
      handler.resolve(Response<Map<String, dynamic>>(
        requestOptions: options,
        statusCode: 200,
        data: {'service': 'bms-api', 'version': '0.1.0', 'status': 'ok'},
      ));
    }));

    await tester.pumpWidget(ProviderScope(
      overrides: [
        dioProvider.overrideWithValue(dio),
        sessionControllerProvider.overrideWith(AuthenticatedTestSession.new)
      ],
      child: const BmsApp(),
    ));
    await tester.pumpAndSettle();
    expect(requestedPath, isNull);

    await tester.tap(find.text('Check API connection'));
    await tester.pumpAndSettle();
    expect(requestedPath, '/api/v1/status');
    expect(find.text('API process reachable'), findsOneWidget);
  });

  testWidgets('overview handles a failed API connection', (tester) async {
    final dio = Dio(BaseOptions(baseUrl: 'http://10.0.2.2:8000'));
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      handler.reject(DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      ));
    }));

    await tester.pumpWidget(ProviderScope(
      overrides: [
        dioProvider.overrideWithValue(dio),
        sessionControllerProvider.overrideWith(AuthenticatedTestSession.new)
      ],
      child: const BmsApp(),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check API connection'));
    await tester.pumpAndSettle();
    expect(find.text('API connection unavailable'), findsOneWidget);
  });
}
