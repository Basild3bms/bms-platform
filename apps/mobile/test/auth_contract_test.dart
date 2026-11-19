import 'package:bms_mobile/src/core/network/bearer_interceptor.dart';
import 'package:bms_mobile/src/features/auth/auth_api_client.dart';
import 'package:bms_mobile/src/features/auth/auth_models.dart';
import 'package:bms_mobile/src/features/auth/auth_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final expiry = DateTime.now().toUtc().add(const Duration(hours: 1));
  final loginPayload = {
    'token': 'test-token',
    'token_type': 'Bearer',
    'expires_at': expiry.toIso8601String(),
    'user': {'id': 7, 'name': 'Operator', 'email': 'operator@example.test'},
  };

  test('typed client uses only contracted paths and protects bearer requests',
      () async {
    final public = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    final protected = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    protected.interceptors.add(BearerInterceptor(() => 'test-token'));
    final calls = <String>[];
    for (final dio in [public, protected]) {
      dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
        calls.add('${options.method} ${options.path}');
        if (options.path == '/api/v1/auth/login') {
          expect(options.headers.containsKey('Authorization'), isFalse);
          expect(options.data, {
            'email': 'operator@example.test',
            'password': 'test-password',
          });
          handler.resolve(Response(
              requestOptions: options, statusCode: 200, data: loginPayload));
        } else if (options.path == '/api/v1/auth/me') {
          expect(options.headers['Authorization'], 'Bearer test-token');
          handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: loginPayload['user']));
        } else if (options.path == '/api/v1/auth/organizations') {
          expect(options.headers['Authorization'], 'Bearer test-token');
          handler.resolve(
              Response(requestOptions: options, statusCode: 200, data: {
            'data': [
              {
                'id': 'org-1',
                'name': 'North',
                'role': 'viewer',
                'permissions': <String>[]
              },
            ]
          }));
        } else if (options.path == '/api/v1/auth/logout') {
          expect(options.headers['Authorization'], 'Bearer test-token');
          handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {'message': 'Logged out.'}));
        } else {
          fail('Unexpected request: ${options.path}');
        }
      }));
    }
    final client = AuthApiClient(public, protected);
    final login = await client
        .login(const LoginRequest('operator@example.test', 'test-password'));
    expect(login.token, 'test-token');
    expect(login.user.id, 7);
    expect((await client.me()).email, 'operator@example.test');
    expect((await client.organizations()).single.name, 'North');
    await client.logout('test-token');
    expect(calls, [
      'POST /api/v1/auth/login',
      'GET /api/v1/auth/me',
      'GET /api/v1/auth/organizations',
      'POST /api/v1/auth/logout',
    ]);
  });

  test('strict response parsing rejects missing fields and wrong token type',
      () {
    expect(() => LoginResult.fromJson({...loginPayload, 'token_type': 'Basic'}),
        throwsFormatException);
    expect(() => LoginResult.fromJson({...loginPayload}..remove('expires_at')),
        throwsFormatException);
    expect(
        () => AuthUser.fromJson({'id': 1, 'name': 'A'}), throwsFormatException);
    expect(
        () => OrganizationAccess.fromJson({
              'id': 'org-1',
              'name': 'North',
              'role': 'owner',
              'permissions': [3],
            }),
        throwsFormatException);
  });

  for (final entry in <int, AuthFailureKind>{
    401: AuthFailureKind.invalidCredentials,
    422: AuthFailureKind.invalidInput,
    429: AuthFailureKind.rateLimited,
    500: AuthFailureKind.server,
  }.entries) {
    test('repository maps login HTTP ${entry.key} without exposing response',
        () async {
      final public = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
      public.interceptors
          .add(InterceptorsWrapper(onRequest: (options, handler) {
        handler.reject(DioException(
          requestOptions: options,
          response: Response(
              requestOptions: options,
              statusCode: entry.key,
              data: {'message': 'secret response detail'}),
          type: DioExceptionType.badResponse,
        ));
      }));
      final repository = DioAuthRepository(AuthApiClient(public, Dio()));
      await expectLater(
        repository.login('operator@example.test', 'wrong'),
        throwsA(isA<AuthFailure>().having((e) => e.kind, 'kind', entry.value)),
      );
    });
  }

  test('repository distinguishes timeout and offline failures', () async {
    for (final type in [
      DioExceptionType.connectionTimeout,
      DioExceptionType.connectionError
    ]) {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
      dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
        handler.reject(DioException(requestOptions: options, type: type));
      }));
      final repository = DioAuthRepository(AuthApiClient(dio, Dio()));
      await expectLater(
          repository.login('a@example.test', 'wrong'),
          throwsA(isA<AuthFailure>().having(
              (e) => e.kind,
              'kind',
              type == DioExceptionType.connectionTimeout
                  ? AuthFailureKind.timeout
                  : AuthFailureKind.network)));
    }
  });

  test('bearer interceptor rejects protected requests without a token',
      () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.interceptors.add(BearerInterceptor(() => null));
    final repository = DioAuthRepository(AuthApiClient(Dio(), dio));
    await expectLater(
        repository.me(),
        throwsA(isA<AuthFailure>()
            .having((e) => e.kind, 'kind', AuthFailureKind.unauthorized)));
  });
}
