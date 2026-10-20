import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/pages/mini_phone/mini_phone.dart';
import 'package:genesis_flutter_android/network/mini_phone/mini_phone_models.dart';
import 'package:genesis_flutter_android/pages/mini_phone/messages/mini_phone_live_chat.dart';
import 'package:genesis_flutter_android/ui/navigation/genesis_dark_page_route.dart';
import '../../support/mini_phone_chat_backend.dart';
import '../../support/mini_phone_collect_probe.dart';

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
    bool directChat = false,
    String entrySource = 'unknown',
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
      entrySource: entrySource,
      initialScreen: MiniPhoneScreen.messages,
      initialContact: directChat
          ? const PhonePerson('c0', 'Person 0', '')
          : null,
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

  for (final source in [
    'world_dock',
    'location_chat_dock',
    'location_chat_avatar',
    'location_chat_roster',
  ]) {
    testWidgets(
      'Collect direct chat from $source has no phantom Home or Messages',
      (tester) async {
        final collect = MiniPhoneCollectProbe();
        addTearDown(collect.dispose);
        final session = await mount(
          tester,
          TargetPlatform.android,
          directChat: true,
          entrySource: source,
        );
        final events = (await tester.runAsync(collect.take))!;
        expect(events.map((e) => e.action), [
          'mini_phone_open',
          'mini_phone_page',
        ]);
        expect(events.map((e) => e.object2), ['chat', 'chat']);
        expect(jsonDecode(events.first.extData)['source'], source);
        expect(jsonDecode(events.last.extData)['char_id'], 'c0');
        await tester.runAsync(() => session.data!.refreshPosts());
        await settle(tester);
        expect(await tester.runAsync(collect.take), isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'Collect page transitions count visits once and preserve open ID',
    (tester) async {
      final collect = MiniPhoneCollectProbe();
      addTearDown(collect.dispose);
      final session = await mount(
        tester,
        TargetPlatform.android,
        entrySource: 'world_dock',
      );
      final initial = (await tester.runAsync(collect.take))!;
      expect(initial.map((e) => e.action), [
        'mini_phone_open',
        'mini_phone_page',
      ]);
      final openId = jsonDecode(initial.first.extData)['open_id'];
      await tester.tap(
        find.byKey(const ValueKey('mini-phone-conversation-c0')),
      );
      await tester.pump();
      await settle(tester);
      var events = (await tester.runAsync(collect.take))!;
      expect(events.single.object2, 'chat');
      expect(jsonDecode(events.single.extData)['source'], 'messages_list');
      expect(jsonDecode(events.single.extData)['open_id'], openId);
      await tester.binding.handlePopRoute();
      await tester.pump();
      await settle(tester);
      events = (await tester.runAsync(collect.take))!;
      expect(events.single.object2, 'messages');
      expect(jsonDecode(events.single.extData)['navigation_type'], 'back');
      await tester.pumpWidget(const SizedBox.shrink());
      expect(session.data!.analytics.openId, isNull);
    },
  );

  testWidgets('content refresh leaves the shell Navigator unchanged', (
    tester,
  ) async {
    final session = await mount(tester, TargetPlatform.android);
    final navigator = find.descendant(
      of: find.byType(MiniPhonePage),
      matching: find.byType(Navigator),
    );
    final before = tester.widget<Navigator>(navigator);
    await tester.runAsync(() => session.data!.refreshPosts());
    await settle(tester);
    expect(session.data!.posts, isNotEmpty);
    expect(tester.widget<Navigator>(navigator), same(before));
    expect(find.text('Person 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('preview reply survives returning from chat to Messages', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = MiniPhoneSession();
    addTearDown(session.dispose);
    final person = session.resume.contact;
    final before = session.store.chats[person.id]!.length;
    await tester.pumpWidget(
      MaterialApp(
        home: MiniPhonePage(
          session: session,
          initialScreen: MiniPhoneScreen.chat,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Preview navigation');
    await tester.pump();
    await tester.tap(find.text('Send'));
    await tester.pump();
    expect(session.store.chats[person.id], hasLength(before + 1));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1200));
    expect(session.store.chats[person.id], hasLength(before + 2));
    expect(find.widgetWithText(TextButton, 'Messages'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

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

  testWidgets('iOS swipe back from a direct chat returns to its caller', (
    tester,
  ) async {
    final session = await mount(
      tester,
      TargetPlatform.iOS,
      outerRoute: true,
      directChat: true,
    );
    expect(find.byType(MiniPhoneLiveChat), findsOneWidget);
    await tester.dragFrom(const Offset(1, 400), const Offset(340, 0));
    await settle(tester);
    expect(find.byType(MiniPhonePage), findsNothing);
    expect(find.text('Open phone'), findsOneWidget);
    expect(session.isDisposed, isFalse);
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
