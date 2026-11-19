import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StoredSession {
  const StoredSession(this.token, this.expiresAt, this.selectedOrganizationId);

  final String token;
  final DateTime expiresAt;
  final String? selectedOrganizationId;
}

abstract class TokenStore {
  Future<StoredSession?> read();
  Future<void> write(StoredSession session);
  Future<void> setSelectedOrganization(String? id);
  Future<void> clear();
}

class SecureTokenStore implements TokenStore {
  const SecureTokenStore(this._storage);

  static const _tokenKey = 'sanctum_bearer_token';
  static const _invalidatedToken = '__bms_locally_invalidated__';
  static const _expiryKey = 'sanctum_bearer_expiry';
  static const _organizationKey = 'selected_organization_id';
  final FlutterSecureStorage _storage;

  @override
  Future<StoredSession?> read() async {
    final token = await _storage.read(key: _tokenKey);
    if (token == null || token == _invalidatedToken) return null;
    final expiry = await _storage.read(key: _expiryKey);
    final parsed = expiry == null ? null : DateTime.tryParse(expiry);
    if (token.isEmpty || parsed == null) {
      throw StateError('Stored session is incomplete.');
    }
    final organization = await _storage.read(key: _organizationKey);
    return StoredSession(token, parsed.toUtc(), organization);
  }

  @override
  Future<void> write(StoredSession session) async {
    await _storage.write(
        key: _expiryKey, value: session.expiresAt.toUtc().toIso8601String());
    await setSelectedOrganization(session.selectedOrganizationId);
    await _storage.write(key: _tokenKey, value: session.token);
  }

  @override
  Future<void> setSelectedOrganization(String? id) async {
    if (id == null) {
      await _storage.delete(key: _organizationKey);
    } else {
      await _storage.write(key: _organizationKey, value: id);
    }
  }

  @override
  Future<void> clear() async {
    Object? overwriteFailure;
    Object? deleteFailure;
    try {
      await _storage.write(key: _tokenKey, value: _invalidatedToken);
    } catch (error) {
      overwriteFailure = error;
    }
    try {
      await _storage.delete(key: _tokenKey);
    } catch (error) {
      deleteFailure = error;
    }
    if (overwriteFailure != null && deleteFailure != null) {
      throw StateError('Unable to invalidate stored session.');
    }
    await _storage.delete(key: _expiryKey);
    await _storage.delete(key: _organizationKey);
    if (deleteFailure != null) {
      throw StateError('Stored session invalidated, but deletion failed.');
    }
  }
}

final tokenStoreProvider = Provider<TokenStore>(
  (ref) => const SecureTokenStore(FlutterSecureStorage()),
);
