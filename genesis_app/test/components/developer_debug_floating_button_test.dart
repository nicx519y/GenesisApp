import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/debug_floating_button_visibility.dart';
import 'package:genesis_flutter_android/app/theme/genesis_theme_mode_controller.dart';
import 'package:genesis_flutter_android/app/theme/genesis_theme_mode_scope.dart';
import 'package:genesis_flutter_android/components/developer_debug_floating_button.dart';
import 'package:genesis_flutter_android/pages/me/developer_page.dart';
import 'package:genesis_flutter_android/ui/components/genesis_tab_bar.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_semantic_colors.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_theme.dart';

void main() {
  tearDown(() {
    hideGenesisDebugFloatingButton();
    resetDeveloperPageTabForTesting();
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

  testWidgets('debug floating button defaults to the right center', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
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

    final position = tester.widget<Positioned>(
      find.ancestor(of: find.text('debug'), matching: find.byType(Positioned)),
    );
    expect(position.left, 350);
    expect(position.top, 379);
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

    final developerSheet = find.byType(DeveloperPageSheet);
    final sheetSize = tester.getSize(developerSheet);
    expect(sheetSize.height, closeTo(600, 0.01));
    expect(tester.getTopLeft(developerSheet).dy, closeTo(0, 0.01));
    expect(
      tester
          .widget<GenesisTabBar>(find.byType(GenesisTabBar))
          .indicatorMatchesLabelWidth,
      isTrue,
    );

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

  testWidgets('basic and test content can drag the debug sheet down', (
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
    await tester.tap(find.text('test'));
    await tester.pumpAndSettle();
    await tester.fling(
      find.byKey(const PageStorageKey<String>('developer-test-tab-scroll')),
      const Offset(0, 500),
      2000,
    );
    await tester.pumpAndSettle();
    expect(find.byType(DeveloperPageSheet), findsNothing);
  });

  testWidgets('switching to basic does not reattach the sheet controller', (
    tester,
  ) async {
    resetDeveloperPageTabForTesting();
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

    await tester.tap(find.text('debug'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('test'));
    await tester.pumpAndSettle();

    final testList = find.byKey(
      const PageStorageKey<String>('developer-test-tab-scroll'),
    );
    final sheetController = tester.widget<ListView>(testList).controller;
    expect(sheetController, isNotNull);
    final attachedSheetController = sheetController!;
    final basicList = find.byKey(
      const PageStorageKey<String>('developer-info-tab-scroll'),
      skipOffstage: false,
    );
    expect(basicList, findsOneWidget);
    expect(
      tester.widget<ListView>(basicList).controller,
      same(attachedSheetController),
    );
    expect(attachedSheetController.positions, hasLength(2));

    await tester.tap(find.text('basic'));
    await tester.pump(const Duration(milliseconds: 80));

    expect(
      tester.widget<ListView>(testList).controller,
      same(attachedSheetController),
    );
    expect(tester.getTopLeft(find.byType(DeveloperPageSheet)).dy, 0);

    await tester.pumpAndSettle();

    expect(
      tester.widget<ListView>(basicList).controller,
      same(attachedSheetController),
    );
    expect(attachedSheetController.positions, hasLength(2));
  });

  testWidgets(
    'main-style debug sheet switches theme without changing its layout',
    (tester) async {
      tester.binding.platformDispatcher.platformBrightnessTestValue =
          Brightness.dark;
      addTearDown(
        tester.binding.platformDispatcher.clearPlatformBrightnessTestValue,
      );
      final navigatorKey = GlobalKey<NavigatorState>();
      final controller = GenesisThemeModeController();
      addTearDown(controller.dispose);
      showGenesisDebugFloatingButton();

      await tester.pumpWidget(
        _ThemeModeTestApp(navigatorKey: navigatorKey, controller: controller),
      );
      await tester.tap(find.text('debug'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('test'));
      await tester.pumpAndSettle();

      final developerSheet = find.byType(DeveloperPageSheet);
      expect(
        find.byKey(const ValueKey<String>('developer-theme-mode-panel')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('developer-theme-mode-panel')),
          matching: find.byKey(
            const ValueKey<String>('developer-design-system-gallery-button'),
          ),
        ),
        findsOneWidget,
      );
      final galleryButton = find.byKey(
        const ValueKey<String>('developer-design-system-gallery-button'),
      );
      var galleryButtonWidget = tester.widget<OutlinedButton>(galleryButton);
      expect(
        galleryButtonWidget.style?.foregroundColor?.resolve(
          const <WidgetState>{},
        ),
        GenesisSemanticColors.worldoDark().textPrimary,
      );
      expect(
        galleryButtonWidget.style?.side?.resolve(const <WidgetState>{})?.color,
        GenesisSemanticColors.worldoDark().border,
      );
      expect(tester.getSize(developerSheet).height, closeTo(600, 0.01));
      expect(tester.getTopLeft(developerSheet).dy, closeTo(0, 0.01));
      expect(
        Theme.of(tester.element(find.byType(DeveloperPageContent))).brightness,
        Brightness.dark,
      );
      final telemetrySwitch = find.byKey(
        const ValueKey<String>('developer-telemetry-collect-switch'),
      );
      expect(
        GenesisSemanticColors.worldoDark().switchInactiveThumb,
        GenesisSemanticColors.worldoLight().iconMuted,
      );
      expect(
        GenesisSemanticColors.worldoLight().switchInactiveThumb,
        GenesisSemanticColors.worldoDark().iconMuted,
      );
      expect(
        tester.widget<Switch>(telemetrySwitch).inactiveThumbColor,
        GenesisSemanticColors.worldoDark().switchInactiveThumb,
      );

      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();

      expect(controller.value, ThemeMode.light);
      expect(find.byType(DeveloperPageSheet), findsOneWidget);
      expect(tester.getSize(developerSheet).height, closeTo(600, 0.01));
      expect(
        Theme.of(tester.element(find.byType(DeveloperPageContent))).brightness,
        Brightness.light,
      );
      expect(
        tester.widget<Switch>(telemetrySwitch).inactiveThumbColor,
        GenesisSemanticColors.worldoLight().switchInactiveThumb,
      );
      galleryButtonWidget = tester.widget<OutlinedButton>(galleryButton);
      expect(
        galleryButtonWidget.style?.foregroundColor?.resolve(
          const <WidgetState>{},
        ),
        GenesisSemanticColors.worldoLight().textPrimary,
      );
      expect(
        galleryButtonWidget.style?.side?.resolve(const <WidgetState>{})?.color,
        GenesisSemanticColors.worldoLight().border,
      );

      await tester.tap(find.text('System'));
      await tester.pumpAndSettle();

      expect(controller.value, ThemeMode.system);
      expect(find.byType(DeveloperPageSheet), findsOneWidget);
      expect(tester.getSize(developerSheet).height, closeTo(600, 0.01));
      expect(
        Theme.of(tester.element(find.byType(DeveloperPageContent))).brightness,
        Brightness.dark,
      );
    },
  );
}

class _ThemeModeTestApp extends StatelessWidget {
  const _ThemeModeTestApp({
    required this.navigatorKey,
    required this.controller,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final GenesisThemeModeController controller;

  @override
  Widget build(BuildContext context) {
    return GenesisThemeModeScope(
      controller: controller,
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: controller,
        builder: (context, mode, _) => MaterialApp(
          theme: GenesisTheme.worldoLight(),
          darkTheme: GenesisTheme.worldoDark(),
          themeMode: mode,
          navigatorKey: navigatorKey,
          home: DeveloperDebugFloatingButton(
            navigatorKey: navigatorKey,
            child: const Scaffold(),
          ),
        ),
      ),
    );
  }
}
