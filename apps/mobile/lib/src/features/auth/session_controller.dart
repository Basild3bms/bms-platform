import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/token_store.dart';
import 'auth_models.dart';
import 'auth_repository.dart';

enum SessionPhase {
  loading,
  unauthenticated,
  retry,
  chooseOrganization,
  noOrganizations,
  authenticated,
}

class SessionState {
  const SessionState(
      {required this.phase,
      this.user,
      this.organizations = const [],
      this.organization,
      this.failure,
      this.busy = false,
      this.revocationUnconfirmed = false,
      this.localRemovalFailed = false});

  final SessionPhase phase;
  final AuthUser? user;
  final List<OrganizationAccess> organizations;
  final OrganizationAccess? organization;
  final AuthFailure? failure;
  final bool busy;
  final bool revocationUnconfirmed;
  final bool localRemovalFailed;
}

class OrganizationContext {
  const OrganizationContext(this.userId, this.organizationId, this.generation);

  final int userId;
  final String organizationId;
  final int generation;
}

class SessionController extends Notifier<SessionState> {
  String? _token;
  DateTime? _expiresAt;
  String? _selectedId;
  int _generation = 0;
  CancelToken? _pending;
  Timer? _expiryTimer;
  Future<void> _storageTail = Future.value();

  @override
  SessionState build() {
    ref.onDispose(() {
      _pending?.cancel();
      _expiryTimer?.cancel();
    });
    return const SessionState(phase: SessionPhase.loading);
  }

  String? get token {
    if (_expiresAt != null && !DateTime.now().toUtc().isBefore(_expiresAt!)) {
      return null;
    }
    return _token;
  }

  OrganizationContext? captureOrganizationContext() {
    final selected = state.organization;
    final user = state.user;
    if (state.phase != SessionPhase.authenticated ||
        selected == null ||
        user == null ||
        token == null) {
      return null;
    }
    return OrganizationContext(user.id, selected.id, _generation);
  }

  bool isCurrentOrganizationContext(OrganizationContext? context) {
    final current = captureOrganizationContext();
    return context != null &&
        current != null &&
        context.generation == current.generation &&
        context.userId == current.userId &&
        context.organizationId == current.organizationId;
  }

  (int, CancelToken) _begin() {
    _generation++;
    _pending?.cancel();
    final cancel = CancelToken();
    _pending = cancel;
    return (_generation, cancel);
  }

  bool _current(int generation) => generation == _generation;

  Future<void> _store(Future<void> Function() operation) {
    final result = _storageTail.then((_) => operation());
    _storageTail = result.catchError((Object _) {});
    return result;
  }

  void _scheduleExpiry() {
    _expiryTimer?.cancel();
    final expiry = _expiresAt;
    if (expiry == null) return;
    final scheduledToken = _token;
    final remaining = expiry.difference(DateTime.now().toUtc());
    if (remaining <= Duration.zero) {
      unawaited(_expire());
    } else {
      _expiryTimer = Timer(remaining, () {
        if (_token == scheduledToken && _expiresAt == expiry) {
          unawaited(_expire());
        }
      });
    }
  }

  Future<void> _expire() async {
    final (generation, _) = _begin();
    _token = null;
    _expiresAt = null;
    _selectedId = null;
    state = const SessionState(phase: SessionPhase.unauthenticated);
    try {
      await _store(() => ref.read(tokenStoreProvider).clear());
    } catch (_) {
      if (_current(generation)) {
        state = const SessionState(
            phase: SessionPhase.unauthenticated, localRemovalFailed: true);
      }
    }
  }

  Future<void> _unauthorized(int generation) async {
    if (!_current(generation)) return;
    _token = null;
    _expiresAt = null;
    _selectedId = null;
    _expiryTimer?.cancel();
    state = const SessionState(phase: SessionPhase.unauthenticated);
    try {
      await _store(() => ref.read(tokenStoreProvider).clear());
    } catch (_) {
      if (_current(generation)) {
        state = const SessionState(
            phase: SessionPhase.unauthenticated, localRemovalFailed: true);
      }
    }
  }

  Future<void> _failure(Object error, int generation) async {
    if (!_current(generation)) return;
    if (error is DioException && error.type == DioExceptionType.cancel) return;
    final failure = error is AuthFailure
        ? error
        : const AuthFailure(AuthFailureKind.server);
    if (failure.kind == AuthFailureKind.unauthorized) {
      await _unauthorized(generation);
      return;
    }
    state = SessionState(
      phase: _token == null ? SessionPhase.unauthenticated : SessionPhase.retry,
      failure: failure,
    );
  }

  Future<void> restore() async {
    final (generation, cancel) = _begin();
    _expiryTimer?.cancel();
    _token = null;
    _expiresAt = null;
    _selectedId = null;
    state = const SessionState(phase: SessionPhase.loading);
    StoredSession? saved;
    try {
      await _storageTail;
      saved = await ref.read(tokenStoreProvider).read();
    } catch (_) {
      if (_current(generation)) {
        state = const SessionState(
            phase: SessionPhase.retry,
            failure: AuthFailure(AuthFailureKind.storage));
      }
      return;
    }
    if (!_current(generation)) return;
    if (saved == null) {
      state = const SessionState(phase: SessionPhase.unauthenticated);
      return;
    }
    if (!DateTime.now().toUtc().isBefore(saved.expiresAt)) {
      await _unauthorized(generation);
      return;
    }
    _token = saved.token;
    _expiresAt = saved.expiresAt;
    _selectedId = saved.selectedOrganizationId;
    _scheduleExpiry();
    try {
      final user =
          await ref.read(authRepositoryProvider).me(cancelToken: cancel);
      if (!_current(generation)) return;
      final organizations = await ref
          .read(authRepositoryProvider)
          .organizations(cancelToken: cancel);
      if (!_current(generation)) return;
      await _publishOrganizations(user, organizations, generation);
    } catch (error) {
      await _failure(error, generation);
    }
  }

  Future<void> login(String email, String password) async {
    final (generation, cancel) = _begin();
    _expiryTimer?.cancel();
    _token = null;
    _expiresAt = null;
    _selectedId = null;
    state = const SessionState(phase: SessionPhase.unauthenticated, busy: true);
    try {
      final result = await ref
          .read(authRepositoryProvider)
          .login(email, password, cancelToken: cancel);
      if (!_current(generation)) return;
      if (!DateTime.now().toUtc().isBefore(result.expiresAt)) {
        throw const AuthFailure(AuthFailureKind.invalidResponse);
      }
      _token = result.token;
      _expiresAt = result.expiresAt;
      await _store(() => ref
          .read(tokenStoreProvider)
          .write(StoredSession(result.token, result.expiresAt, null)));
      if (!_current(generation)) return;
      _scheduleExpiry();
      final organizations = await ref
          .read(authRepositoryProvider)
          .organizations(cancelToken: cancel);
      if (!_current(generation)) return;
      await _publishOrganizations(result.user, organizations, generation);
    } catch (error) {
      if (!_current(generation)) return;
      if (error is! AuthFailure && error is! DioException) {
        final issuedToken = _token;
        _token = null;
        _expiresAt = null;
        var removalFailed = false;
        var revocationUnconfirmed = false;
        try {
          await _store(() => ref.read(tokenStoreProvider).clear());
        } catch (_) {
          removalFailed = true;
        }
        if (issuedToken != null) {
          try {
            await ref.read(authRepositoryProvider).logout(issuedToken);
          } on AuthFailure catch (revokeError) {
            if (revokeError.kind != AuthFailureKind.unauthorized) {
              revocationUnconfirmed = true;
            }
          } catch (_) {
            revocationUnconfirmed = true;
          }
        }
        if (_current(generation)) {
          state = SessionState(
              phase: SessionPhase.unauthenticated,
              failure: const AuthFailure(AuthFailureKind.storage),
              localRemovalFailed: removalFailed,
              revocationUnconfirmed: revocationUnconfirmed);
        }
        return;
      }
      await _failure(error, generation);
    }
  }

  Future<void> _publishOrganizations(AuthUser user,
      List<OrganizationAccess> organizations, int generation) async {
    final selected =
        organizations.where((item) => item.id == _selectedId).firstOrNull;
    if (_selectedId != null && selected == null) {
      _selectedId = null;
      try {
        await _store(
            () => ref.read(tokenStoreProvider).setSelectedOrganization(null));
      } catch (_) {
        if (_current(generation)) {
          state = const SessionState(
              phase: SessionPhase.retry,
              failure: AuthFailure(AuthFailureKind.storage));
        }
        return;
      }
    }
    if (!_current(generation)) return;
    state = SessionState(
      phase: organizations.isEmpty
          ? SessionPhase.noOrganizations
          : selected == null
              ? SessionPhase.chooseOrganization
              : SessionPhase.authenticated,
      user: user,
      organizations: List.unmodifiable(organizations),
      organization: selected,
    );
  }

  Future<void> refreshOrganizations() async {
    final user = state.user;
    if (_token == null || user == null) {
      await restore();
      return;
    }
    final (generation, cancel) = _begin();
    state = SessionState(
        phase: SessionPhase.loading,
        user: user,
        organizations: state.organizations);
    try {
      if (_selectedId == null) {
        await _store(
            () => ref.read(tokenStoreProvider).setSelectedOrganization(null));
        if (!_current(generation)) return;
      }
      final organizations = await ref
          .read(authRepositoryProvider)
          .organizations(cancelToken: cancel);
      if (_current(generation)) {
        await _publishOrganizations(user, organizations, generation);
      }
    } catch (error) {
      await _failure(error, generation);
    }
  }

  Future<void> selectOrganization(String id) async {
    final user = state.user;
    final organizations = state.organizations;
    final selected = organizations.where((item) => item.id == id).firstOrNull;
    if (user == null || selected == null || _token == null) {
      state = SessionState(
          phase: SessionPhase.chooseOrganization,
          user: user,
          organizations: organizations,
          failure: const AuthFailure(AuthFailureKind.forbidden));
      return;
    }
    final (generation, _) = _begin();
    _selectedId = null;
    state = SessionState(
        phase: SessionPhase.chooseOrganization,
        user: user,
        organizations: organizations,
        busy: true);
    try {
      await _store(() async {
        if (_current(generation)) {
          await ref.read(tokenStoreProvider).setSelectedOrganization(id);
        }
      });
      if (!_current(generation)) return;
      _selectedId = id;
      state = SessionState(
          phase: SessionPhase.authenticated,
          user: user,
          organizations: organizations,
          organization: selected);
    } catch (_) {
      if (_current(generation)) {
        state = SessionState(
            phase: SessionPhase.retry,
            failure: const AuthFailure(AuthFailureKind.storage),
            user: user);
      }
    }
  }

  Future<void> switchOrganization(String id) => selectOrganization(id);

  Future<void> chooseAnotherOrganization() async {
    final user = state.user;
    final organizations = state.organizations;
    final (generation, _) = _begin();
    _selectedId = null;
    state = SessionState(
        phase: SessionPhase.chooseOrganization,
        user: user,
        organizations: organizations);
    try {
      await _store(
          () => ref.read(tokenStoreProvider).setSelectedOrganization(null));
      if (_current(generation)) {
        await refreshOrganizations();
      }
    } catch (_) {
      if (_current(generation)) {
        state = const SessionState(
            phase: SessionPhase.retry,
            failure: AuthFailure(AuthFailureKind.storage));
      }
    }
  }

  Future<void> organizationAccessLost() async {
    final user = state.user;
    final organizations = state.organizations;
    final (generation, _) = _begin();
    _selectedId = null;
    state = SessionState(
        phase: SessionPhase.chooseOrganization,
        user: user,
        organizations: organizations);
    try {
      await _store(
          () => ref.read(tokenStoreProvider).setSelectedOrganization(null));
      if (!_current(generation)) return;
      await refreshOrganizations();
    } catch (_) {
      if (_current(generation)) {
        state = const SessionState(
            phase: SessionPhase.retry,
            failure: AuthFailure(AuthFailureKind.storage));
      }
    }
  }

  Future<void> logout() async {
    final (generation, _) = _begin();
    final earlierRevocationUnconfirmed = state.revocationUnconfirmed;
    final storageWasUnreadable = state.phase == SessionPhase.retry &&
        state.failure?.kind == AuthFailureKind.storage;
    final oldToken = _token;
    _token = null;
    _expiresAt = null;
    _selectedId = null;
    _expiryTimer?.cancel();
    state = const SessionState(phase: SessionPhase.unauthenticated, busy: true);
    var removalFailed = false;
    var revocationUnconfirmed = earlierRevocationUnconfirmed ||
        (storageWasUnreadable && oldToken == null);
    try {
      await _store(() => ref.read(tokenStoreProvider).clear());
    } catch (_) {
      removalFailed = true;
    }
    if (oldToken != null) {
      try {
        await ref.read(authRepositoryProvider).logout(oldToken);
      } on AuthFailure catch (error) {
        if (error.kind != AuthFailureKind.unauthorized) {
          revocationUnconfirmed = true;
        }
      } catch (_) {
        revocationUnconfirmed = true;
      }
    }
    if (_current(generation)) {
      state = SessionState(
          phase: SessionPhase.unauthenticated,
          revocationUnconfirmed: revocationUnconfirmed,
          localRemovalFailed: removalFailed);
    }
  }
}

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(
  SessionController.new,
);
