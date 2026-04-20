import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quickdeliver/app/quick_deliver_app.dart';

void main() {
  testWidgets('QuickDeliver app renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: QuickDeliverApp(),
      ),
    );

    expect(find.text('QuickDeliver'), findsOneWidget);
  });
}
