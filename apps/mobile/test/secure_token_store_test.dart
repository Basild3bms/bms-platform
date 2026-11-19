import 'package:bms_mobile/src/core/storage/token_store.dart';
import 'package:bms_mobile/src/features/auth/auth_models.dart';
import 'package:bms_mobile/src/features/auth/auth_repository.dart';
import 'package:bms_mobile/src/features/auth/session_controller.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class FaultySecureStorage extends Fake implements FlutterSecureStorage {
  final values = <String, String>{};
  bool failTokenDelete = false;
  bool failTokenWrite = false;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final key = invocation.namedArguments[#key] as String;
    if (invocation.memberName == #read) {
      return Future<String?>.value(values[key]);
    }
    if (invocation.memberName == #write) {
      if (failTokenWrite && key == 'sanctum_bearer_token') {
        return Future<void>.error(StateError('token write failed'));
      }
      final value = invocation.namedArguments[#value] as String?;
      if (value == null) {
        values.remove(key);
      } else {
        values[key] = value;
      }
      return Future<void>.value();
    }
    if (invocation.memberName == #delete) {
      if (failTokenDelete && key == 'sanctum_bearer_token') {
        return Future<void>.error(StateError('token delete failed'));
      }
      values.remove(key);
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

class RestartRepository implements AuthRepository {
  int currentUserCalls = 0;

  @override
  Future<LoginResult> login(String email, String password,
          {CancelToken? cancelToken}) =>
      throw UnimplementedError();

  @override
  Future<AuthUser> me({CancelToken? cancelToken}) async {
    currentUserCalls++;
    return const AuthUser(
        id: 7, name: 'Operator', email: 'operator@example.test');
  }

  @override
  Future<List<OrganizationAccess>> organizations(
          {CancelToken? cancelToken}) async =>
      [
        const OrganizationAccess(
            id: 'north', name: 'North', role: 'viewer', permissions: [])
      ];

  @override
  Future<void> logout(String token, {CancelToken? cancelToken}) async =>
      throw const AuthFailure(AuthFailureKind.network);
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('secure storage writes token, expiry and selected organization',
      () async {
    const store = SecureTokenStore(FlutterSecureStorage());
    final expiry = DateTime.utc(2030, 1, 1, 12);
    await store.write(StoredSession('test-token', expiry, null));
    await store.setSelectedOrganization('north');
    final saved = await store.read();
    expect(saved?.token, 'test-token');
    expect(saved?.expiresAt, expiry);
    expect(saved?.selectedOrganizationId, 'north');
    await store.clear();
    expect(await store.read(), isNull);
  });

  test('incomplete stored session fails closed', () async {
    FlutterSecureStorage.setMockInitialValues({
      'sanctum_bearer_token': 'orphan-token',
    });
    const store = SecureTokenStore(FlutterSecureStorage());
    await expectLater(store.read(), throwsStateError);
  });

  test('failed token deletion cannot restore the old session after restart',
      () async {
    final storage = FaultySecureStorage();
    final store = SecureTokenStore(storage);
    await store.write(StoredSession('test-token',
        DateTime.now().toUtc().add(const Duration(hours: 1)), 'north'));
    storage.failTokenDelete = true;
    await expectLater(store.clear(), throwsStateError);
    final restartedStore = SecureTokenStore(storage);
    expect(await restartedStore.read(), isNull);
  });

  test('token deletion still clears session when invalidation write fails',
      () async {
    final storage = FaultySecureStorage();
    final store = SecureTokenStore(storage);
    await store.write(StoredSession('test-token',
        DateTime.now().toUtc().add(const Duration(hours: 1)), null));
    storage.failTokenWrite = true;
    await store.clear();
    expect(await SecureTokenStore(storage).read(), isNull);
  });

  test('simultaneous token write and delete failure is not recoverable locally',
      () async {
    final storage = FaultySecureStorage();
    final store = SecureTokenStore(storage);
    await store.write(StoredSession('test-token',
        DateTime.now().toUtc().add(const Duration(hours: 1)), null));
    storage.failTokenWrite = true;
    storage.failTokenDelete = true;
    await expectLater(store.clear(), throwsStateError);
    expect((await SecureTokenStore(storage).read())?.token, 'test-token');
  });

  test('restart after failed delete and repeated logout never opens shell',
      () async {
    final storage = FaultySecureStorage();
    final store = SecureTokenStore(storage);
    final repo = RestartRepository();
    await store.write(StoredSession('test-token',
        DateTime.now().toUtc().add(const Duration(hours: 1)), 'north'));
    final first = ProviderContainer(overrides: [
      tokenStoreProvider.overrideWithValue(store),
      authRepositoryProvider.overrideWithValue(repo),
    ]);
    final controller = first.read(sessionControllerProvider.notifier);
    await controller.restore();
    expect(first.read(sessionControllerProvider).phase,
        SessionPhase.authenticated);
    storage.failTokenDelete = true;
    final loggingOut = controller.logout();
    expect(first.read(sessionControllerProvider).phase,
        SessionPhase.unauthenticated);
    await loggingOut;
    await controller.logout();
    expect(first.read(sessionControllerProvider).revocationUnconfirmed, isTrue);
    expect(first.read(sessionControllerProvider).localRemovalFailed, isTrue);
    first.dispose();

    final second = ProviderContainer(overrides: [
      tokenStoreProvider.overrideWithValue(SecureTokenStore(storage)),
      authRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(second.dispose);
    await second.read(sessionControllerProvider.notifier).restore();
    expect(second.read(sessionControllerProvider).phase,
        SessionPhase.unauthenticated);
    expect(repo.currentUserCalls, 1);
  });
}
