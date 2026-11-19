import 'dart:async';

import 'package:bms_mobile/src/core/storage/token_store.dart';
import 'package:bms_mobile/src/features/auth/auth_models.dart';
import 'package:bms_mobile/src/features/auth/auth_repository.dart';
import 'package:bms_mobile/src/features/auth/session_controller.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _future = DateTime.now().toUtc().add(const Duration(hours: 1));
final _past = DateTime.now().toUtc().subtract(const Duration(minutes: 1));
const _user = AuthUser(id: 7, name: 'Operator', email: 'operator@example.test');
const _north = OrganizationAccess(
    id: 'north', name: 'North', role: 'viewer', permissions: []);
const _south = OrganizationAccess(
    id: 'south', name: 'South', role: 'admin', permissions: ['users.view']);

class MemoryTokenStore implements TokenStore {
  StoredSession? value;
  bool failRead = false;
  bool failWrite = false;
  bool failClear = false;

  @override
  Future<StoredSession?> read() async {
    if (failRead) throw StateError('storage read failed');
    return value;
  }

  @override
  Future<void> write(StoredSession session) async {
    if (failWrite) throw StateError('storage write failed');
    value = session;
  }

  @override
  Future<void> setSelectedOrganization(String? id) async {
    if (failWrite) throw StateError('storage write failed');
    final current = value;
    if (current != null) {
      value = StoredSession(current.token, current.expiresAt, id);
    }
  }

  @override
  Future<void> clear() async {
    if (failClear) throw StateError('storage clear failed');
    value = null;
  }
}

class DelayedWriteStore extends MemoryTokenStore {
  final gate = Completer<void>();

  @override
  Future<void> write(StoredSession session) async {
    await gate.future;
    await super.write(session);
  }
}

class DelayedSelectionStore extends MemoryTokenStore {
  final gate = Completer<void>();
  bool delay = false;

  @override
  Future<void> setSelectedOrganization(String? id) async {
    if (delay && id != null) await gate.future;
    await super.setSelectedOrganization(id);
  }
}

class FakeAuthRepository implements AuthRepository {
  Future<LoginResult> Function(String, String, CancelToken?)? onLogin;
  Future<AuthUser> Function(CancelToken?)? onMe;
  Future<List<OrganizationAccess>> Function(CancelToken?)? onOrganizations;
  Future<void> Function(String, CancelToken?)? onLogout;
  int meCalls = 0;

  @override
  Future<LoginResult> login(String email, String password,
          {CancelToken? cancelToken}) =>
      onLogin?.call(email, password, cancelToken) ??
      Future.value(
          LoginResult(token: 'test-token', expiresAt: _future, user: _user));

  @override
  Future<AuthUser> me({CancelToken? cancelToken}) {
    meCalls++;
    return onMe?.call(cancelToken) ?? Future.value(_user);
  }

  @override
  Future<List<OrganizationAccess>> organizations({CancelToken? cancelToken}) =>
      onOrganizations?.call(cancelToken) ?? Future.value([_north, _south]);

  @override
  Future<void> logout(String token, {CancelToken? cancelToken}) =>
      onLogout?.call(token, cancelToken) ?? Future.value();
}

ProviderContainer _container(FakeAuthRepository repo, MemoryTokenStore store) =>
    ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(repo),
      tokenStoreProvider.overrideWithValue(store),
    ]);

void main() {
  test('empty storage opens login without a protected dashboard', () async {
    final store = MemoryTokenStore();
    final repo = FakeAuthRepository();
    final container = _container(repo, store);
    addTearDown(container.dispose);
    await container.read(sessionControllerProvider.notifier).restore();
    expect(container.read(sessionControllerProvider).phase,
        SessionPhase.unauthenticated);
    expect(repo.meCalls, 0);
  });

  test('restore validates server and previously selected active organization',
      () async {
    final store = MemoryTokenStore()
      ..value = StoredSession('test-token', _future, 'south');
    final repo = FakeAuthRepository();
    final container = _container(repo, store);
    addTearDown(container.dispose);
    await container.read(sessionControllerProvider.notifier).restore();
    final state = container.read(sessionControllerProvider);
    expect(repo.meCalls, 1);
    expect(state.phase, SessionPhase.authenticated);
    expect(state.organization?.id, 'south');
    expect(state.user?.id, 7);
  });

  test('expired token is cleared without a server request', () async {
    final store = MemoryTokenStore()
      ..value = StoredSession('expired-token', _past, 'north');
    final repo = FakeAuthRepository();
    final container = _container(repo, store);
    addTearDown(container.dispose);
    await container.read(sessionControllerProvider.notifier).restore();
    expect(repo.meCalls, 0);
    expect(store.value, isNull);
    expect(container.read(sessionControllerProvider).phase,
        SessionPhase.unauthenticated);
  });

  test('revoked or disabled bearer token clears local access', () async {
    for (final reason in ['revoked', 'disabled']) {
      final store = MemoryTokenStore()
        ..value = StoredSession('$reason-token', _future, 'north');
      final repo = FakeAuthRepository()
        ..onMe =
            (_) async => throw const AuthFailure(AuthFailureKind.unauthorized);
      final container = _container(repo, store);
      await container.read(sessionControllerProvider.notifier).restore();
      expect(container.read(sessionControllerProvider).phase,
          SessionPhase.unauthenticated);
      expect(store.value, isNull);
      container.dispose();
    }
  });

  test('network failure retains token but never grants protected access',
      () async {
    final store = MemoryTokenStore()
      ..value = StoredSession('test-token', _future, 'north');
    final repo = FakeAuthRepository()
      ..onMe = (_) async => throw const AuthFailure(AuthFailureKind.network);
    final container = _container(repo, store);
    addTearDown(container.dispose);
    await container.read(sessionControllerProvider.notifier).restore();
    expect(container.read(sessionControllerProvider).phase, SessionPhase.retry);
    expect(container.read(sessionControllerProvider).organization, isNull);
    expect(store.value?.token, 'test-token');
  });

  test('storage read failure fails closed with a retry state', () async {
    final store = MemoryTokenStore()..failRead = true;
    final container = _container(FakeAuthRepository(), store);
    addTearDown(container.dispose);
    await container.read(sessionControllerProvider.notifier).restore();
    expect(container.read(sessionControllerProvider).phase, SessionPhase.retry);
    expect(container.read(sessionControllerProvider).failure?.kind,
        AuthFailureKind.storage);
  });

  test('login discovers organizations and requires explicit selection',
      () async {
    final store = MemoryTokenStore();
    final container = _container(FakeAuthRepository(), store);
    addTearDown(container.dispose);
    final controller = container.read(sessionControllerProvider.notifier);
    await controller.login('operator@example.test', 'test-password');
    expect(container.read(sessionControllerProvider).phase,
        SessionPhase.chooseOrganization);
    expect(store.value?.token, 'test-token');
    await controller.selectOrganization('north');
    expect(container.read(sessionControllerProvider).phase,
        SessionPhase.authenticated);
    expect(store.value?.selectedOrganizationId, 'north');
  });

  test('no organizations and revoked selected membership stay outside shell',
      () async {
    final store = MemoryTokenStore()
      ..value = StoredSession('test-token', _future, 'revoked');
    final repo = FakeAuthRepository()..onOrganizations = (_) async => [];
    final container = _container(repo, store);
    addTearDown(container.dispose);
    await container.read(sessionControllerProvider.notifier).restore();
    expect(container.read(sessionControllerProvider).phase,
        SessionPhase.noOrganizations);
    expect(store.value?.selectedOrganizationId, isNull);
  });

  test('switching clears old context and ignores late organization responses',
      () async {
    final store = MemoryTokenStore()
      ..value = StoredSession('test-token', _future, 'north');
    final repo = FakeAuthRepository();
    final container = _container(repo, store);
    addTearDown(container.dispose);
    final controller = container.read(sessionControllerProvider.notifier);
    await controller.restore();
    final late = Completer<List<OrganizationAccess>>();
    repo.onOrganizations = (_) => late.future;
    final pending = controller.refreshOrganizations();
    await controller.switchOrganization('south');
    late.complete([_north]);
    await pending;
    expect(container.read(sessionControllerProvider).organization?.id, 'south');
    expect(store.value?.selectedOrganizationId, 'south');
  });

  test('late login response cannot restore a logged-out session', () async {
    final store = MemoryTokenStore();
    final late = Completer<LoginResult>();
    final repo = FakeAuthRepository()..onLogin = (_, __, ___) => late.future;
    final container = _container(repo, store);
    addTearDown(container.dispose);
    final controller = container.read(sessionControllerProvider.notifier);
    final pending = controller.login('operator@example.test', 'test-password');
    await controller.logout();
    late.complete(
        LoginResult(token: 'late-token', expiresAt: _future, user: _user));
    await pending;
    expect(container.read(sessionControllerProvider).phase,
        SessionPhase.unauthenticated);
    expect(store.value, isNull);
  });

  test('latest concurrent login wins and earlier response stays discarded',
      () async {
    final store = MemoryTokenStore();
    final late = Completer<LoginResult>();
    final repo = FakeAuthRepository()
      ..onLogin = (email, _, __) => email.startsWith('first')
          ? late.future
          : Future.value(LoginResult(
              token: 'second-token', expiresAt: _future, user: _user));
    final container = _container(repo, store);
    addTearDown(container.dispose);
    final controller = container.read(sessionControllerProvider.notifier);
    final first = controller.login('first@example.test', 'password');
    await controller.login('second@example.test', 'password');
    late.complete(
        LoginResult(token: 'first-token', expiresAt: _future, user: _user));
    await first;
    expect(store.value?.token, 'second-token');
  });

  test('successful logout revokes remotely and clears local access', () async {
    final store = MemoryTokenStore()
      ..value = StoredSession('test-token', _future, 'north');
    var revoked = false;
    final repo = FakeAuthRepository()
      ..onLogout = (token, _) async {
        revoked = token == 'test-token';
      };
    final container = _container(repo, store);
    addTearDown(container.dispose);
    final controller = container.read(sessionControllerProvider.notifier);
    await controller.restore();
    await controller.logout();
    expect(revoked, isTrue);
    expect(store.value, isNull);
    expect(container.read(sessionControllerProvider).phase,
        SessionPhase.unauthenticated);
  });

  test('failed remote logout terminates local access and reports uncertainty',
      () async {
    final store = MemoryTokenStore()
      ..value = StoredSession('test-token', _future, 'north');
    final repo = FakeAuthRepository()
      ..onLogout =
          (_, __) async => throw const AuthFailure(AuthFailureKind.network);
    final container = _container(repo, store);
    addTearDown(container.dispose);
    final controller = container.read(sessionControllerProvider.notifier);
    await controller.restore();
    await controller.logout();
    expect(store.value, isNull);
    expect(container.read(sessionControllerProvider).phase,
        SessionPhase.unauthenticated);
    expect(container.read(sessionControllerProvider).revocationUnconfirmed,
        isTrue);
  });

  test('storage clear failure never leaves protected UI available', () async {
    final store = MemoryTokenStore()
      ..value = StoredSession('test-token', _future, 'north');
    final container = _container(FakeAuthRepository(), store);
    addTearDown(container.dispose);
    final controller = container.read(sessionControllerProvider.notifier);
    await controller.restore();
    store.failClear = true;
    await controller.logout();
    expect(container.read(sessionControllerProvider).phase,
        SessionPhase.unauthenticated);
    expect(
        container.read(sessionControllerProvider).localRemovalFailed, isTrue);
  });

  test('restored session expires while the app remains open', () async {
    final soon = DateTime.now().toUtc().add(const Duration(milliseconds: 250));
    final store = MemoryTokenStore()
      ..value = StoredSession('test-token', soon, 'north');
    final container = _container(FakeAuthRepository(), store);
    addTearDown(container.dispose);
    await container.read(sessionControllerProvider.notifier).restore();
    expect(container.read(sessionControllerProvider).phase,
        SessionPhase.authenticated);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    expect(container.read(sessionControllerProvider).phase,
        SessionPhase.unauthenticated);
    expect(store.value, isNull);
  });

  test('delayed secure write cannot leave a token after logout', () async {
    final store = DelayedWriteStore();
    final container = _container(FakeAuthRepository(), store);
    addTearDown(container.dispose);
    final controller = container.read(sessionControllerProvider.notifier);
    final login = controller.login('operator@example.test', 'password');
    await Future<void>.delayed(Duration.zero);
    final logout = controller.logout();
    store.gate.complete();
    await Future.wait([login, logout]);
    expect(store.value, isNull);
    expect(container.read(sessionControllerProvider).phase,
        SessionPhase.unauthenticated);
  });

  test('late restoration cannot reopen the shell after logout', () async {
    final store = MemoryTokenStore()
      ..value = StoredSession('test-token', _future, 'north');
    final late = Completer<AuthUser>();
    final repo = FakeAuthRepository()..onMe = (_) => late.future;
    final container = _container(repo, store);
    addTearDown(container.dispose);
    final controller = container.read(sessionControllerProvider.notifier);
    final restore = controller.restore();
    await Future<void>.delayed(Duration.zero);
    await controller.logout();
    late.complete(_user);
    await restore;
    expect(container.read(sessionControllerProvider).phase,
        SessionPhase.unauthenticated);
    expect(store.value, isNull);
  });

  test('401 during organization refresh invalidates token and selection',
      () async {
    final store = MemoryTokenStore()
      ..value = StoredSession('test-token', _future, 'north');
    final repo = FakeAuthRepository();
    final container = _container(repo, store);
    addTearDown(container.dispose);
    final controller = container.read(sessionControllerProvider.notifier);
    await controller.restore();
    repo.onOrganizations =
        (_) async => throw const AuthFailure(AuthFailureKind.unauthorized);
    await controller.refreshOrganizations();
    expect(container.read(sessionControllerProvider).phase,
        SessionPhase.unauthenticated);
    expect(store.value, isNull);
  });

  test('canceled selection cannot persist after access refresh', () async {
    final store = DelayedSelectionStore()
      ..value = StoredSession('test-token', _future, 'north');
    final repo = FakeAuthRepository();
    final container = _container(repo, store);
    addTearDown(container.dispose);
    final controller = container.read(sessionControllerProvider.notifier);
    await controller.restore();
    store.delay = true;
    final selecting = controller.selectOrganization('south');
    await Future<void>.delayed(Duration.zero);
    final refreshing = controller.refreshOrganizations();
    store.gate.complete();
    await Future.wait([selecting, refreshing]);
    expect(container.read(sessionControllerProvider).phase,
        SessionPhase.chooseOrganization);
    expect(store.value?.selectedOrganizationId, isNull);
  });

  test('failed secure write revokes the newly issued bearer token', () async {
    final store = MemoryTokenStore()..failWrite = true;
    String? revoked;
    final repo = FakeAuthRepository()
      ..onLogout = (token, _) async {
        revoked = token;
      };
    final container = _container(repo, store);
    addTearDown(container.dispose);
    await container
        .read(sessionControllerProvider.notifier)
        .login('operator@example.test', 'password');
    expect(container.read(sessionControllerProvider).phase,
        SessionPhase.unauthenticated);
    expect(revoked, 'test-token');
  });

  test('failed secure write reports unconfirmed revocation when offline',
      () async {
    final store = MemoryTokenStore()..failWrite = true;
    final repo = FakeAuthRepository()
      ..onLogout =
          (_, __) async => throw const AuthFailure(AuthFailureKind.network);
    final container = _container(repo, store);
    addTearDown(container.dispose);
    await container
        .read(sessionControllerProvider.notifier)
        .login('operator@example.test', 'password');
    expect(container.read(sessionControllerProvider).revocationUnconfirmed,
        isTrue);
  });

  test('logout after unreadable storage reports unconfirmed revocation',
      () async {
    final store = MemoryTokenStore()
      ..value = StoredSession('unreadable-token', _future, 'north')
      ..failRead = true;
    final container = _container(FakeAuthRepository(), store);
    addTearDown(container.dispose);
    final controller = container.read(sessionControllerProvider.notifier);
    await controller.restore();
    await controller.logout();
    expect(store.value, isNull);
    expect(container.read(sessionControllerProvider).revocationUnconfirmed,
        isTrue);
  });

  test('opening organization picker refreshes revoked memberships', () async {
    final store = MemoryTokenStore()
      ..value = StoredSession('test-token', _future, 'north');
    final repo = FakeAuthRepository();
    final container = _container(repo, store);
    addTearDown(container.dispose);
    final controller = container.read(sessionControllerProvider.notifier);
    await controller.restore();
    repo.onOrganizations = (_) async => [_south];
    await controller.chooseAnotherOrganization();
    expect(container.read(sessionControllerProvider).phase,
        SessionPhase.chooseOrganization);
    expect(
        container
            .read(sessionControllerProvider)
            .organizations
            .map((organization) => organization.id),
        ['south']);
    expect(store.value?.selectedOrganizationId, isNull);
  });

  test('organization context snapshots expire on switch and logout', () async {
    final store = MemoryTokenStore()
      ..value = StoredSession('test-token', _future, 'north');
    final container = _container(FakeAuthRepository(), store);
    addTearDown(container.dispose);
    final controller = container.read(sessionControllerProvider.notifier);
    await controller.restore();
    final north = controller.captureOrganizationContext();
    expect(north?.organizationId, 'north');
    expect(controller.isCurrentOrganizationContext(north), isTrue);
    await controller.switchOrganization('south');
    expect(controller.isCurrentOrganizationContext(north), isFalse);
    final south = controller.captureOrganizationContext();
    expect(south?.organizationId, 'south');
    await controller.logout();
    expect(controller.isCurrentOrganizationContext(south), isFalse);
  });

  test('lost organization access clears context and refreshes memberships',
      () async {
    final store = MemoryTokenStore()
      ..value = StoredSession('test-token', _future, 'north');
    final repo = FakeAuthRepository();
    final container = _container(repo, store);
    addTearDown(container.dispose);
    final controller = container.read(sessionControllerProvider.notifier);
    await controller.restore();
    final prior = controller.captureOrganizationContext();
    repo.onOrganizations = (_) async => [_south];
    await controller.organizationAccessLost();
    expect(controller.isCurrentOrganizationContext(prior), isFalse);
    expect(container.read(sessionControllerProvider).phase,
        SessionPhase.chooseOrganization);
    expect(container.read(sessionControllerProvider).organizations, [_south]);
    expect(store.value?.selectedOrganizationId, isNull);
  });

  test('organization refresh request is canceled on switch', () async {
    final store = MemoryTokenStore()
      ..value = StoredSession('test-token', _future, 'north');
    final repo = FakeAuthRepository();
    final container = _container(repo, store);
    addTearDown(container.dispose);
    final controller = container.read(sessionControllerProvider.notifier);
    await controller.restore();
    final late = Completer<List<OrganizationAccess>>();
    CancelToken? refreshCancel;
    repo.onOrganizations = (token) {
      refreshCancel = token;
      return late.future;
    };
    final pending = controller.refreshOrganizations();
    await Future<void>.delayed(Duration.zero);
    await controller.switchOrganization('south');
    expect(refreshCancel?.isCancelled, isTrue);
    late.complete([_north]);
    await pending;
    expect(controller.captureOrganizationContext()?.organizationId, 'south');
  });
}
