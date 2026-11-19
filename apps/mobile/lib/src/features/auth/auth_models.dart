enum AuthFailureKind {
  invalidCredentials,
  invalidInput,
  rateLimited,
  unauthorized,
  forbidden,
  notFound,
  server,
  timeout,
  network,
  invalidResponse,
  storage,
}

class AuthFailure implements Exception {
  const AuthFailure(this.kind);

  final AuthFailureKind kind;
}

Map<String, dynamic> _object(Object? value) {
  if (value is Map<String, dynamic>) return value;
  throw const FormatException('Invalid API response.');
}

String _text(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  throw const FormatException('Invalid API response.');
}

class LoginRequest {
  const LoginRequest(this.email, this.password);

  final String email;
  final String password;

  Map<String, String> toJson() => {'email': email, 'password': password};
}

class AuthUser {
  const AuthUser({required this.id, required this.name, required this.email});

  final int id;
  final String name;
  final String email;

  factory AuthUser.fromJson(Object? value) {
    final json = _object(value);
    final id = json['id'];
    if (id is! int || id < 1) {
      throw const FormatException('Invalid API response.');
    }
    return AuthUser(
        id: id, name: _text(json, 'name'), email: _text(json, 'email'));
  }
}

class LoginResult {
  const LoginResult(
      {required this.token, required this.expiresAt, required this.user});

  final String token;
  final DateTime expiresAt;
  final AuthUser user;

  factory LoginResult.fromJson(Object? value) {
    final json = _object(value);
    if (json['token_type'] != 'Bearer') {
      throw const FormatException('Invalid API response.');
    }
    final expiry = DateTime.tryParse(_text(json, 'expires_at'));
    if (expiry == null) {
      throw const FormatException('Invalid API response.');
    }
    return LoginResult(
        token: _text(json, 'token'),
        expiresAt: expiry.toUtc(),
        user: AuthUser.fromJson(json['user']));
  }
}

class OrganizationAccess {
  const OrganizationAccess(
      {required this.id,
      required this.name,
      required this.role,
      required this.permissions});

  final String id;
  final String name;
  final String role;
  final List<String> permissions;

  factory OrganizationAccess.fromJson(Object? value) {
    final json = _object(value);
    final role = _text(json, 'role');
    if (!const {'viewer', 'operator', 'admin', 'owner'}.contains(role)) {
      throw const FormatException('Invalid API response.');
    }
    final rawPermissions = json['permissions'];
    if (rawPermissions is! List ||
        rawPermissions.any((item) => item is! String)) {
      throw const FormatException('Invalid API response.');
    }
    return OrganizationAccess(
        id: _text(json, 'id'),
        name: _text(json, 'name'),
        role: role,
        permissions: List.unmodifiable(rawPermissions.cast<String>()));
  }
}
