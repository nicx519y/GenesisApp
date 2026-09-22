import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/debug/debug_screen_translation_service.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_theme.dart';
import 'package:genesis_flutter_android/app/debug/screen_translation_debug_settings.dart';
import 'package:genesis_flutter_android/app/debug_floating_button_visibility.dart';
import 'package:genesis_flutter_android/components/developer_debug_floating_button.dart';
import 'package:genesis_flutter_android/pages/me/developer_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  tearDown(() {
    hideGenesisDebugFloatingButton();
    screenTranslationDebugSettings.resetForTesting();
  });

  testWidgets('hold-to-translate overlay disappears when pointer is released', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await screenTranslationDebugSettings.setEnabled(true);
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: DeveloperDebugFloatingButton(
          navigatorKey: navigatorKey,
          translateCurrentScreenOverride: () async {
            return const <DebugScreenTranslationLine>[
              DebugScreenTranslationLine(
                text: '订阅',
                left: 20,
                top: 30,
                right: 100,
                bottom: 52,
              ),
            ];
          },
          child: const Scaffold(body: Text('Subscription')),
        ),
      ),
    );

    expect(find.text('中/EN'), findsOneWidget);
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('中/EN')),
    );
    await tester.pump();
    for (var attempt = 0; attempt < 20; attempt += 1) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.text('订阅').evaluate().isNotEmpty) break;
    }

    expect(find.text('订阅'), findsOneWidget);

    await gesture.up();
    await tester.pump();

    expect(find.text('订阅'), findsNothing);
    expect(find.text('Subscription'), findsOneWidget);
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
        theme: GenesisTheme.dark(),
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

    final developerSheet = find.byType(DeveloperPageSheet);
    expect(
      Theme.of(tester.element(find.byType(DeveloperPageContent))).brightness,
      Brightness.dark,
    );
    final sheetSize = tester.getSize(developerSheet);
    expect(sheetSize.height, closeTo(600, 0.01));
    expect(tester.getTopLeft(developerSheet).dy, closeTo(0, 0.01));

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

  testWidgets('basic switch and button content can drag the debug sheet down', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    showGenesisDebugFloatingButton();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: DeveloperDebugFloatingButton(
          navigatorKey: navigatorKey,
          child: const Scaffold(),
        ),
      ),
    );

    Future<void> openSheet() async {
      await tester.tap(find.text('debug'));
      await tester.pumpAndSettle();
      expect(find.byType(DeveloperPageSheet), findsOneWidget);
    }

    await openSheet();
    await tester.fling(
      find.byKey(const PageStorageKey<String>('developer-info-tab-scroll')),
      const Offset(0, 500),
      2000,
    );
    await tester.pumpAndSettle();
    expect(find.byType(DeveloperPageSheet), findsNothing);

    await openSheet();
    await tester.tap(find.text('switch'));
    await tester.pumpAndSettle();
    await tester.fling(
      find.byKey(
        const PageStorageKey<String>('developer-test-switch-tab-scroll'),
      ),
      const Offset(0, 500),
      2000,
    );
    await tester.pumpAndSettle();
    expect(find.byType(DeveloperPageSheet), findsNothing);

    await openSheet();
    await tester.tap(find.text('button'));
    await tester.pumpAndSettle();
    await tester.fling(
      find.byKey(
        const PageStorageKey<String>('developer-test-button-tab-scroll'),
      ),
      const Offset(0, 500),
      2000,
    );
    await tester.pumpAndSettle();
    expect(find.byType(DeveloperPageSheet), findsNothing);
  });
}
