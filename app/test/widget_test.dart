import 'package:flutter_test/flutter_test.dart';
import 'package:app_manager_mobile/main.dart';

void main() {
  testWidgets('App builds without error', (WidgetTester tester) async {
    await tester.pumpWidget(const AppManagerMobile());
    expect(find.text('Dashboard'), findsWidgets);
  });
}
