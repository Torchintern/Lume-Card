import 'package:flutter_test/flutter_test.dart';
import 'package:lume_student_app/main.dart';

void main() {
  testWidgets('App loads phone screen', (WidgetTester tester) async {
    // Build app
    await tester.pumpWidget(const LumeApp(initialRoute: "/phone"));

    // Wait for UI
    await tester.pumpAndSettle();

    // Verify first screen text exists
    expect(find.text('Enter your registered mobile number'), findsOneWidget);
  });
}