import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/bootstrap/app_services_scope.dart';
import 'package:genesis_flutter_android/app/bootstrap/service_registry.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_theme.dart';
import 'package:genesis_flutter_android/app/debug_floating_button_visibility.dart';
import 'package:genesis_flutter_android/components/developer_debug_floating_button.dart';
import 'package:genesis_flutter_android/components/gems/purchase_options_sheet.dart';
import 'package:genesis_flutter_android/components/login_sheet.dart';
import 'package:genesis_flutter_android/pages/me/developer_page.dart';
import 'package:genesis_flutter_android/platform/session/memory_user_session_store.dart';

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

  testWidgets('debug Buy Gems opens login first and keeps the debug sheet', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final services = ServiceRegistry.build(
      sessionStoreOverride: MemoryUserSessionStore(),
    );
    showGenesisDebugFloatingButton();
    resetDeveloperPageTabForTesting();
    addTearDown(resetDeveloperPageTabForTesting);
    await tester.pumpWidget(
      AppServicesScope(
        services: services,
        child: MaterialApp(
          navigatorKey: navigatorKey,
          home: DeveloperDebugFloatingButton(
            navigatorKey: navigatorKey,
            child: const Scaffold(),
          ),
        ),
      ),
    );

    await tester.tap(find.text('debug'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('button'));
    await tester.pumpAndSettle();
    final buyGems = find.byKey(const ValueKey('developer-buy-gems'));
    await tester.scrollUntilVisible(
      buyGems,
      220,
      scrollable: find.descendant(
        of: find.byKey(
          const PageStorageKey<String>('developer-test-button-tab-scroll'),
        ),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(buyGems);
    await tester.pumpAndSettle();

    expect(find.byType(LoginSheet), findsOneWidget);
    expect(find.byType(PurchaseOptionsSheet), findsNothing);

    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.byType(LoginSheet), findsNothing);
    expect(buyGems.hitTestable(), findsOneWidget);
    expect(find.byType(PurchaseOptionsSheet), findsNothing);
  });

  testWidgets('debug check-in previews cover all four membership states', (
    tester,
  ) async {
    resetDeveloperPageTabForTesting();
    addTearDown(resetDeveloperPageTabForTesting);
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigatorKey, home: const DeveloperPage()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('button'));
    await tester.pumpAndSettle();

    final buttonList = find.descendant(
      of: find.byKey(
        const PageStorageKey<String>('developer-test-button-tab-scroll'),
      ),
      matching: find.byType(Scrollable),
    );
    final premiumOffer = find.byKey(
      const ValueKey('daily-check-in-offer-premium'),
    );
    final deluxeOffer = find.byKey(
      const ValueKey('daily-check-in-offer-deluxe'),
    );
    for (final (index, (reward, premium, deluxe)) in const [
      (50, true, true),
      (100, false, true),
      (300, true, false),
      (350, false, false),
    ].indexed) {
      final preview = find.byKey(
        ValueKey('developer-daily-check-in-${index + 1}'),
      );
      await tester.scrollUntilVisible(preview, 220, scrollable: buttonList);
      final label = find.descendant(of: preview, matching: find.byType(Text));
      expect(tester.getTopLeft(label).dx - tester.getTopLeft(preview).dx, 16);
      await tester.tap(preview);
      await tester.pumpAndSettle();
      expect(find.text('+$reward'), findsOneWidget);
      expect(premiumOffer, premium ? findsOneWidget : findsNothing);
      expect(deluxeOffer, deluxe ? findsOneWidget : findsNothing);

      await tester.tap(find.byKey(const ValueKey('daily-check-in-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('Check in successful!'), findsOneWidget);
      expect(find.text('+$reward'), findsOneWidget);
      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();

      if (index == 0) {
        await tester.tap(preview);
        await tester.pumpAndSettle();
        await tester.tap(premiumOffer);
        await tester.pumpAndSettle();
        expect(find.byType(PurchaseOptionsSheet), findsNothing);
      }
    }
  });
}
