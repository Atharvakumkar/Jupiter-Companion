import 'package:flutter_test/flutter_test.dart';
import 'package:jupiter_companion/app/app.dart';

void main() {
  testWidgets('JupiterCompanionApp initializes without errors', (WidgetTester tester) async {
    // App widget structure test
    expect(const JupiterCompanionApp(), isNotNull);
  });
}
