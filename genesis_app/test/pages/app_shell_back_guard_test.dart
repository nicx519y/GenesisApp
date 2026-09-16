import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/pages/app_shell_back_guard.dart';
import 'package:genesis_flutter_android/platform/channels/genesis_method_channels.dart';

const _prompt = 'Press back again to exit.';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GlobalKey<NavigatorState> navigatorKey;
  late ValueNotifier<int> tabIndex;
  late int backgroundCalls;
  late List<String> platformCalls;

  setUp(() {
    navigatorKey = GlobalKey<NavigatorState>();
    tabIndex = ValueNotifier(0);
    backgroundCalls = 0;
    platformCalls = [];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(GenesisMethodChannels.device, (
      call,
    ) async {
      expect(call.method, GenesisMethodChannels.moveAppToBackground);
      backgroundCalls += 1;
      return true;
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      platformCalls.add(call.method);
      return null;
    });
  });

  tearDown(() {
    // Leaving the main page must never finish the Flutter Activity.
    expect(platformCalls, isNot(contains('SystemNavigator.pop')));
    tabIndex.dispose();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(GenesisMethodChannels.device, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> pumpMainPage(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: ValueListenableBuilder<int>(
          valueListenable: tabIndex,
          builder: (context, index, _) => AppShellBackGuard(
            activeTabIndex: index,
            child: const Scaffold(body: Text('Main page')),
          ),
        ),
      ),
    );
  }

  void testBack(
    String description,
    WidgetTesterCallback callback, {
    TargetPlatform platform = TargetPlatform.android,
  }) {
    testWidgets(description, (tester) async {
      try {
        await callback(tester);
      } finally {
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }, variant: TargetPlatformVariant.only(platform));
  }

  Future<void> back(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pump();
  }

  Future<void> gesture(WidgetTester tester, {bool canceled = false}) async {
    for (final call in [
      const MethodCall('startBackGesture', {
        'touchOffset': [5.0, 300.0],
        'progress': 0.0,
        'swipeEdge': 0,
      }),
      MethodCall(canceled ? 'cancelBackGesture' : 'commitBackGesture'),
    ]) {
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/backgesture',
        const StandardMethodCodec().encodeMethodCall(call),
        (_) {},
      );
    }
    await tester.pump();
  }

  testBack('back closes a local menu before prompting to leave the app', (
    tester,
  ) async {
    await pumpMainPage(tester);
    var closed = false;
    ModalRoute.of(
      tester.element(find.text('Main page')),
    )!.addLocalHistoryEntry(LocalHistoryEntry(onRemove: () => closed = true));
    await tester.pump();
    await back(tester);
    expect(closed, isTrue);
    expect(find.text(_prompt), findsNothing);
    expect(backgroundCalls, 0);
    await back(tester);
    expect(find.text(_prompt), findsOneWidget);
    expect(backgroundCalls, 0);
  });

  testBack('first back prompts and second within two seconds backgrounds', (
    tester,
  ) async {
    await pumpMainPage(tester);
    final mainPageElement = tester.element(find.text('Main page'));
    await back(tester);
    expect(find.text(_prompt), findsOneWidget);
    expect(backgroundCalls, 0);

    await tester.pump(const Duration(milliseconds: 1999));
    await back(tester);
    expect(backgroundCalls, 1);
    expect(navigatorKey.currentState!.canPop(), isFalse);
    expect(tester.element(find.text('Main page')), same(mainPageElement));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await back(tester);
    expect(backgroundCalls, 1);
    expect(find.text(_prompt), findsOneWidget);
  });

  for (final elapsed in [2000, 2500]) {
    testBack('back after $elapsed ms starts a new confirmation window', (
      tester,
    ) async {
      await pumpMainPage(tester);
      await back(tester);
      await tester.pump(Duration(milliseconds: elapsed));
      expect(find.text(_prompt), findsNothing);
      await back(tester);
      expect(backgroundCalls, 0);
      expect(find.text(_prompt), findsOneWidget);
      await back(tester);
      expect(backgroundCalls, 1);
    });
  }

  testBack(
    'system edge gesture follows the same rule; canceled swipe does not',
    (tester) async {
      await pumpMainPage(tester);
      await gesture(tester, canceled: true);
      expect(find.text(_prompt), findsNothing);
      expect(backgroundCalls, 0);
      await gesture(tester);
      expect(find.text(_prompt), findsOneWidget);
      expect(backgroundCalls, 0);
      await back(tester);
      expect(backgroundCalls, 1);
    },
  );

  testBack('switching tabs or leaving the foreground clears confirmation', (
    tester,
  ) async {
    await pumpMainPage(tester);
    await back(tester);
    tabIndex.value = 4;
    await tester.pump();
    await back(tester);
    expect(backgroundCalls, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await back(tester);
    expect(backgroundCalls, 0);
    await back(tester);
    expect(backgroundCalls, 1);
  });

  testBack('detail back and dialog dismissal do not count as main page back', (
    tester,
  ) async {
    await pumpMainPage(tester);
    await back(tester);
    navigatorKey.currentState!.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Detail')),
      ),
    );
    await tester.pumpAndSettle();
    await back(tester);
    await tester.pumpAndSettle();
    expect(find.text('Detail'), findsNothing);
    expect(backgroundCalls, 0);
    await back(tester);
    expect(backgroundCalls, 0);

    showDialog<void>(
      context: tester.element(find.text('Main page')),
      builder: (_) => const PopScope<void>(
        canPop: false,
        child: AlertDialog(title: Text('Required dialog')),
      ),
    );
    await tester.pumpAndSettle();
    await back(tester);
    await back(tester);
    expect(find.text('Required dialog'), findsOneWidget);
    expect(backgroundCalls, 0);
    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    await back(tester);
    expect(backgroundCalls, 0);
    await back(tester);
    expect(backgroundCalls, 1);
  });

  testBack('a pushed main page returns normally instead of backgrounding', (
    tester,
  ) async {
    await pumpMainPage(tester);
    navigatorKey.currentState!.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const AppShellBackGuard(
          activeTabIndex: 4,
          child: Scaffold(body: Text('Pushed main page')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await back(tester);
    await tester.pumpAndSettle();
    expect(find.text('Pushed main page'), findsNothing);
    expect(find.text(_prompt), findsNothing);
    expect(backgroundCalls, 0);
  });

  testBack(
    'iOS retains normal navigation without the Android back guard',
    (tester) async {
      await pumpMainPage(tester);
      expect(
        tester.widget<PopScope<void>>(find.byType(PopScope<void>)).canPop,
        isTrue,
      );
      expect(backgroundCalls, 0);
    },
    platform: TargetPlatform.iOS,
  );

  testBack('native background failure never falls back to closing the app', (
    tester,
  ) async {
    await pumpMainPage(tester);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      GenesisMethodChannels.device,
      (_) async => throw PlatformException(code: 'background_failed'),
    );
    await back(tester);
    await back(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Main page'), findsOneWidget);
    await back(tester);
    expect(find.text(_prompt), findsOneWidget);
  });
}
