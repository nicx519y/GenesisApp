import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/debug_floating_button_visibility.dart';
import 'package:genesis_flutter_android/components/developer_debug_floating_button.dart';

void main() {
  tearDown(() {
    hideGenesisDebugFloatingButton();
  });

  testWidgets('debug floating button handles zero-sized constraints', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    showGenesisDebugFloatingButton();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: Center(
          child: SizedBox(
            width: 0,
            height: 0,
            child: DeveloperDebugFloatingButton(
              navigatorKey: navigatorKey,
              child: const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
