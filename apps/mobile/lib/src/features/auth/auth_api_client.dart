import 'package:dio/dio.dart';

import 'auth_models.dart';

class AuthApiClient {
  const AuthApiClient(this._publicDio, this._protectedDio);

  final Dio _publicDio;
  final Dio _protectedDio;

  Future<LoginResult> login(LoginRequest request,
      {CancelToken? cancelToken}) async {
    final response = await _publicDio.post<dynamic>('/api/v1/auth/login',
        data: request.toJson(), cancelToken: cancelToken);
    return LoginResult.fromJson(response.data);
  }

  Future<AuthUser> me({CancelToken? cancelToken}) async {
    final response = await _protectedDio.get<dynamic>('/api/v1/auth/me',
        cancelToken: cancelToken);
    return AuthUser.fromJson(response.data);
  }

  Future<List<OrganizationAccess>> organizations(
      {CancelToken? cancelToken}) async {
    final response = await _protectedDio
        .get<dynamic>('/api/v1/auth/organizations', cancelToken: cancelToken);
    final data = response.data;
    if (data is! Map<String, dynamic> || data['data'] is! List) {
      throw const FormatException('Invalid API response.');
    }
    return (data['data'] as List)
        .map(OrganizationAccess.fromJson)
        .toList(growable: false);
  }

  Future<void> logout(String token, {CancelToken? cancelToken}) async {
    await _publicDio.post<dynamic>('/api/v1/auth/logout',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
        cancelToken: cancelToken);
  }
}
