import 'package:bms_mobile/src/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'support/authenticated_session.dart';
import 'package:bms_mobile/src/features/auth/session_controller.dart';

void main() {
  testWidgets('shows the buildings overview entry', (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      sessionControllerProvider.overrideWith(AuthenticatedTestSession.new),
    ], child: const BmsApp()));
    await tester.pumpAndSettle();
    expect(find.text('Browse buildings'), findsOneWidget);
    expect(find.text('No live building data is available.'), findsOneWidget);
  });

  testWidgets('navigation keeps future features unavailable', (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      sessionControllerProvider.overrideWith(AuthenticatedTestSession.new),
    ], child: const BmsApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Live monitoring'));
    await tester.pumpAndSettle();
    expect(find.text('Feature unavailable'), findsOneWidget);
  });

  testWidgets('language selection translates the shell', (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      sessionControllerProvider.overrideWith(AuthenticatedTestSession.new),
    ], child: const BmsApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Settings'),
      200,
      scrollable: find.descendant(
        of: find.byType(Drawer),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Français'));
    await tester.pumpAndSettle();
    expect(find.text('Paramètres'), findsOneWidget);
    expect(find.text('Apparence'), findsOneWidget);
  });
}
