import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/debug_floating_button_visibility.dart';
import 'package:genesis_flutter_android/components/developer_debug_floating_button.dart';
import 'package:genesis_flutter_android/pages/me/developer_page.dart';

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

  testWidgets('opening debug sheet keeps the current status bar style', (
    tester,
  ) async {
    const transparentPageStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    );
    final navigatorKey = GlobalKey<NavigatorState>();
    final calls = <Map<dynamic, dynamic>>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'SystemChrome.setSystemUIOverlayStyle') {
            calls.add(Map<dynamic, dynamic>.from(call.arguments as Map));
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    showGenesisDebugFloatingButton();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: AnnotatedRegion<SystemUiOverlayStyle>(
          value: transparentPageStyle,
          child: DeveloperDebugFloatingButton(
            navigatorKey: navigatorKey,
            child: const Scaffold(),
          ),
        ),
      ),
    );
    await tester.pump();
    calls.clear();

    await tester.tap(find.text('debug'));
    await tester.pumpAndSettle();

    final sheetSize = tester.getSize(find.byType(DeveloperPageSheet));
    expect(sheetSize.height, closeTo(480, 0.01));

    expect(SystemChrome.latestStyle?.statusBarColor, Colors.transparent);
    expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.dark);
    expect(
      calls.where(
        (call) =>
            call['statusBarColor'] != null &&
            call['statusBarColor'] != Colors.transparent.toARGB32(),
      ),
      isEmpty,
    );

    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
  });
}
