import 'package:bms_mobile/src/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('shows the M1 foundation screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: BmsApp()));
    await tester.pumpAndSettle();
    expect(find.text('BMS mobile — M1 foundation'), findsOneWidget);
    expect(find.text('No live building data is available.'), findsOneWidget);
  });

  testWidgets('navigation marks unavailable features', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: BmsApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buildings'));
    await tester.pumpAndSettle();
    expect(find.text('Feature unavailable'), findsOneWidget);
  });

  testWidgets('language selection translates the shell', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: BmsApp()));
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
