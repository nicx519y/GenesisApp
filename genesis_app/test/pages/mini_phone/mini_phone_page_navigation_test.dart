import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/pages/mini_phone/mini_phone_page.dart';
import 'package:genesis_flutter_android/pages/mini_phone/mini_phone_live_chat.dart';
import 'package:genesis_flutter_android/ui/navigation/genesis_dark_page_route.dart';
import '../../support/mini_phone_chat_backend.dart';

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<MiniPhoneSession> mount(
    WidgetTester tester,
    TargetPlatform platform, {
    bool outerRoute = false,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final b = PhoneBackend();
    b.respond = (r) => r.uri.path.endsWith('/dm_sessions')
        ? ok(
            page([
              for (var i = 0; i < 20; i++)
                {
                  ...phoneSession(),
                  'dm_session_id': 0,
                  'char_id': 'c$i',
                  'char_name': 'Person $i',
                },
            ]),
          )
        : null;
    final s = (await tester.runAsync(() async {
      final s = b.store();
      await s.ready;
      return s;
    }))!;
    final session = MiniPhoneSession(data: s);
    addTearDown(session.dispose);
    Widget phone() => MiniPhonePage(
      session: session,
      initialScreen: MiniPhoneScreen.messages,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark().copyWith(platform: platform),
        home: outerRoute
            ? Builder(
                builder: (context) => TextButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).push(GenesisDarkPageRoute<void>(builder: (_) => phone())),
                  child: const Text('Open phone'),
                ),
              )
            : phone(),
      ),
    );
    if (outerRoute) {
      await tester.tap(find.text('Open phone'));
      await tester.pump();
    }
    await settle(tester);
    return session;
  }

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform list-to-chat uses the shared route and back preserves the list',
      (tester) async {
        await mount(tester, platform);
        final list = find.byType(ListView);
        final listElement = tester.element(list);
        await tester.drag(list, const Offset(0, -350));
        await tester.pumpAndSettle();
        final scrollable = find.descendant(
          of: list,
          matching: find.byType(Scrollable),
        );
        final scroll = tester.state<ScrollableState>(scrollable).position;
        final offset = scroll.pixels;
        expect(offset, greaterThan(0));
        await tester.tap(
          find.byKey(const ValueKey('mini-phone-conversation-c8')),
        );
        await tester.pump();
        final chat = find.byType(MiniPhoneLiveChat);
        final route = ModalRoute.of(tester.element(chat))!;
        expect(route, isA<GenesisDarkPageRoute<void>>());
        expect(route.animation!.value, lessThan(1));
        await tester.pump(const Duration(milliseconds: 80));
        expect(route.animation!.value, greaterThan(0));
        expect(route.animation!.value, lessThan(1));
        await settle(tester);
        expect(route.animation!.isCompleted, isTrue);
        if (platform == TargetPlatform.android) {
          await tester.binding.handlePopRoute();
        } else {
          await tester.tap(find.widgetWithText(TextButton, 'Person 8'));
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        expect(route.animation!.value, greaterThan(0));
        expect(route.animation!.value, lessThan(1));
        await settle(tester);
        expect(chat, findsNothing);
        expect(tester.element(find.byType(ListView)), same(listElement));
        expect(scroll.pixels, closeTo(offset, .01));
        expect(find.widgetWithText(TextButton, 'Messages'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('iOS swipe back removes the chat and keeps the phone open', (
    tester,
  ) async {
    await mount(tester, TargetPlatform.iOS);
    await tester.tap(find.byKey(const ValueKey('mini-phone-conversation-c0')));
    await tester.pump();
    await settle(tester);
    await tester.dragFrom(const Offset(1, 400), const Offset(340, 0));
    await settle(tester);
    expect(find.byType(MiniPhoneLiveChat), findsNothing);
    expect(find.byType(MiniPhonePage), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Messages'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('close during internal navigation exits the entire phone', (
    tester,
  ) async {
    await mount(tester, TargetPlatform.android, outerRoute: true);
    await tester.tap(find.byKey(const ValueKey('mini-phone-conversation-c0')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(MiniPhonePage), findsNothing);
    expect(find.text('Open phone'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'repeated close before the next frame preserves the parent route',
    (tester) async {
      await mount(tester, TargetPlatform.android, outerRoute: true);
      await tester.tap(find.byTooltip('Close'));
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(MiniPhonePage), findsNothing);
      expect(find.text('Open phone'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('system back after close does not pop the parent route twice', (
    tester,
  ) async {
    await mount(tester, TargetPlatform.android, outerRoute: true);
    await tester.tap(find.byTooltip('Close'));
    // The close callback is waiting for the next frame; emulate a competing pop.
    final context = tester.element(find.byType(MiniPhonePage));
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    expect(find.byType(MiniPhonePage), findsNothing);
    expect(find.text('Open phone'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
