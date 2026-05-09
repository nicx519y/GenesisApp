import 'package:flutter_test/flutter_test.dart';

import 'package:genesis_flutter_android/main.dart';

void main() {
  testWidgets('Origin is default tab', (WidgetTester tester) async {
    await tester.pumpWidget(const GenesisApp());

    expect(find.text('Origin'), findsWidgets);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Create'), findsOneWidget);
    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('Me'), findsOneWidget);
  });
}
