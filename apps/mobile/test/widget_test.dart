import 'package:bms_mobile/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the M1 foundation screen', (tester) async {
    await tester.pumpWidget(const BmsApp());
    expect(find.text('BMS mobile — M1 foundation'), findsOneWidget);
  });
}
