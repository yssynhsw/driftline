import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:driftline/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sign in screen shows Driftline', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(const DriftlineApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('DRIFTLINE'), findsWidgets);
  });
}
