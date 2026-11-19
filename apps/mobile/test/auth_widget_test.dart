import 'dart:async';

import 'package:bms_mobile/src/app.dart';
import 'package:bms_mobile/src/core/routing/app_router.dart';
import 'package:bms_mobile/src/core/storage/token_store.dart';
import 'package:bms_mobile/src/features/auth/auth_models.dart';
import 'package:bms_mobile/src/features/auth/auth_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

class WidgetStore implements TokenStore {
  StoredSession? value;

  @override
  Future<StoredSession?> read() async => value;
  @override
  Future<void> write(StoredSession session) async => value = session;
  @override
  Future<void> setSelectedOrganization(String? id) async {
    final old = value;
    if (old != null) value = StoredSession(old.token, old.expiresAt, id);
  }

  @override
  Future<void> clear() async => value = null;
}

class WidgetRepo implements AuthRepository {
  AuthFailure? loginFailure;
  AuthFailure? logoutFailure;
  Future<AuthUser> Function()? onMe;
  List<OrganizationAccess> available = const [
    OrganizationAccess(
        id: 'north', name: 'North', role: 'viewer', permissions: []),
    OrganizationAccess(
        id: 'south', name: 'South', role: 'admin', permissions: ['users.view']),
  ];

  @override
  Future<LoginResult> login(String email, String password,
      {CancelToken? cancelToken}) async {
    if (loginFailure != null) throw loginFailure!;
    return LoginResult(
        token: 'widget-token',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        user: const AuthUser(
            id: 7, name: 'Operator', email: 'operator@example.test'));
  }

  @override
  Future<AuthUser> me({CancelToken? cancelToken}) =>
      onMe?.call() ??
      Future.value(const AuthUser(
          id: 7, name: 'Operator', email: 'operator@example.test'));

  @override
  Future<List<OrganizationAccess>> organizations(
          {CancelToken? cancelToken}) async =>
      available;

  @override
  Future<void> logout(String token, {CancelToken? cancelToken}) async {
    if (logoutFailure != null) throw logoutFailure!;
  }
}

Future<void> _pump(WidgetTester tester, WidgetRepo repo, WidgetStore store,
    {String? initialRoute}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(repo),
      tokenStoreProvider.overrideWithValue(store),
      if (initialRoute != null)
        initialRouteProvider.overrideWithValue(initialRoute),
    ],
    child: const BmsApp(),
  ));
  await tester.pumpAndSettle();
}

Future<void> _login(WidgetTester tester) async {
  await tester.enterText(
      find.byKey(const Key('login-email')), 'operator@example.test');
  await tester.enterText(
      find.byKey(const Key('login-password')), 'test-password');
  await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('startup with no token shows an accessible login form',
      (tester) async {
    await _pump(tester, WidgetRepo(), WidgetStore());
    expect(find.text('Sign in'), findsWidgets);
    expect(find.byKey(const Key('login-email')), findsOneWidget);
    expect(find.byKey(const Key('login-password')), findsOneWidget);
    expect(find.text('BMS mobile — M1 foundation'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
  });

  testWidgets('password visibility and French login text work', (tester) async {
    await _pump(tester, WidgetRepo(), WidgetStore());
    final field = find.byKey(const Key('login-password'));
    final password = tester.widget<TextField>(
        find.descendant(of: field, matching: find.byType(TextField)));
    expect(password.obscureText, isTrue);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(
        tester
            .widget<TextField>(
                find.descendant(of: field, matching: find.byType(TextField)))
            .obscureText,
        isFalse);
    await tester.tap(find.text('Français'));
    await tester.pumpAndSettle();
    expect(find.text('Se connecter'), findsWidgets);
    await tester.tap(find.byTooltip('Changer le thème'));
    await tester.pumpAndSettle();
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark);
  });

  for (final entry in <AuthFailureKind, String>{
    AuthFailureKind.invalidCredentials: 'Invalid email or password.',
    AuthFailureKind.invalidInput: 'Check the submitted fields.',
    AuthFailureKind.rateLimited: 'Too many attempts. Try again later.',
    AuthFailureKind.network: 'Network unavailable. Try again.',
    AuthFailureKind.server: 'Service unavailable. Try again.',
  }.entries) {
    testWidgets('login shows safe ${entry.key.name} feedback', (tester) async {
      final repo = WidgetRepo()..loginFailure = AuthFailure(entry.key);
      await _pump(tester, repo, WidgetStore());
      await _login(tester);
      expect(find.text(entry.value), findsOneWidget);
      expect(find.text('BMS mobile — M1 foundation'), findsNothing);
    });
  }

  testWidgets('deep link cannot show protected content before login',
      (tester) async {
    await _pump(tester, WidgetRepo(), WidgetStore(),
        initialRoute: '/buildings');
    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Buildings'), findsNothing);
  });

  testWidgets('restoration keeps a deep link behind loading until server check',
      (tester) async {
    final gate = Completer<AuthUser>();
    final repo = WidgetRepo()..onMe = () => gate.future;
    final store = WidgetStore()
      ..value = StoredSession('widget-token',
          DateTime.now().toUtc().add(const Duration(hours: 1)), 'north');
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(repo),
        tokenStoreProvider.overrideWithValue(store),
        initialRouteProvider.overrideWithValue('/buildings'),
      ],
      child: const BmsApp(),
    ));
    await tester.pump();
    expect(find.text('Checking session…'), findsOneWidget);
    expect(find.text('Buildings'), findsNothing);
    gate.complete(const AuthUser(
        id: 7, name: 'Operator', email: 'operator@example.test'));
    await tester.pumpAndSettle();
    expect(find.text('BMS mobile — M1 foundation'), findsOneWidget);
  });

  testWidgets('login selects an organization and shows protected shell',
      (tester) async {
    await _pump(tester, WidgetRepo(), WidgetStore());
    await _login(tester);
    expect(find.text('Choose organization'), findsOneWidget);
    expect(find.text('North'), findsOneWidget);
    expect(find.text('South'), findsOneWidget);
    await tester.tap(find.text('North'));
    await tester.pumpAndSettle();
    expect(find.text('BMS mobile — M1 foundation'), findsOneWidget);
    expect(find.text('North'), findsWidgets);
    await tester.tap(find.byTooltip('Switch organization'));
    await tester.pumpAndSettle();
    expect(find.text('Choose organization'), findsOneWidget);
    await tester.tap(find.text('South'));
    await tester.pumpAndSettle();
    expect(find.text('South'), findsWidgets);
  });

  testWidgets('empty memberships show no access and allow refresh',
      (tester) async {
    final repo = WidgetRepo()..available = [];
    await _pump(tester, repo, WidgetStore());
    await _login(tester);
    expect(find.text('No organizations available.'), findsOneWidget);
    expect(find.text('BMS mobile — M1 foundation'), findsNothing);
  });

  testWidgets('logout clears protected routes and reports failed revocation',
      (tester) async {
    final repo = WidgetRepo()
      ..logoutFailure = const AuthFailure(AuthFailureKind.network);
    final store = WidgetStore();
    await _pump(tester, repo, store);
    await _login(tester);
    await tester.tap(find.text('North'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Settings'), 200,
        scrollable: find.descendant(
            of: find.byType(Drawer), matching: find.byType(Scrollable)));
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsWidgets);
    expect(
        find.text('Server sign-out could not be confirmed.'), findsOneWidget);
    expect(store.value, isNull);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('BMS mobile — M1 foundation'), findsNothing);
  });
}
