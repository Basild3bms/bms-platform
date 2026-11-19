import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_providers.dart';
import 'auth_api_client.dart';
import 'auth_models.dart';

abstract class AuthRepository {
  Future<LoginResult> login(String email, String password,
      {CancelToken? cancelToken});
  Future<AuthUser> me({CancelToken? cancelToken});
  Future<List<OrganizationAccess>> organizations({CancelToken? cancelToken});
  Future<void> logout(String token, {CancelToken? cancelToken});
}

class DioAuthRepository implements AuthRepository {
  const DioAuthRepository(this._client);

  final AuthApiClient _client;

  Future<T> _safe<T>(Future<T> Function() action, {bool login = false}) async {
    try {
      return await action();
    } on FormatException {
      throw const AuthFailure(AuthFailureKind.invalidResponse);
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) rethrow;
      final status = error.response?.statusCode;
      if (status == 401) {
        throw AuthFailure(login
            ? AuthFailureKind.invalidCredentials
            : AuthFailureKind.unauthorized);
      }
      if (status == 403) throw const AuthFailure(AuthFailureKind.forbidden);
      if (status == 404) throw const AuthFailure(AuthFailureKind.notFound);
      if (status == 422) throw const AuthFailure(AuthFailureKind.invalidInput);
      if (status == 429) throw const AuthFailure(AuthFailureKind.rateLimited);
      if (status != null && status >= 500) {
        throw const AuthFailure(AuthFailureKind.server);
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        throw const AuthFailure(AuthFailureKind.timeout);
      }
      throw const AuthFailure(AuthFailureKind.network);
    }
  }

  @override
  Future<LoginResult> login(String email, String password,
          {CancelToken? cancelToken}) =>
      _safe(
          () => _client.login(LoginRequest(email, password),
              cancelToken: cancelToken),
          login: true);

  @override
  Future<AuthUser> me({CancelToken? cancelToken}) =>
      _safe(() => _client.me(cancelToken: cancelToken));

  @override
  Future<List<OrganizationAccess>> organizations({CancelToken? cancelToken}) =>
      _safe(() => _client.organizations(cancelToken: cancelToken));

  @override
  Future<void> logout(String token, {CancelToken? cancelToken}) =>
      _safe(() => _client.logout(token, cancelToken: cancelToken));
}

final authRepositoryProvider =
    Provider<AuthRepository>((ref) => DioAuthRepository(
          AuthApiClient(
              ref.watch(dioProvider), ref.watch(protectedDioProvider)),
        ));
