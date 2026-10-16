import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_scroll_coordinator.dart';
import 'package:genesis_flutter_android/pages/mini_phone/mini_phone_live_chat.dart';
import 'package:genesis_flutter_android/pages/mini_phone/mini_phone_page.dart';
import 'package:genesis_flutter_android/network/mini_phone/mini_phone_models.dart';
import '../../support/mini_phone_chat_backend.dart';

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('Messages renders only sessions returned by the API', (
    tester,
  ) async {
    final b = PhoneBackend();
    b.respond = (r) =>
        r.uri.path.endsWith('/dm_sessions') ? ok(page([])) : null;
    final s = (await tester.runAsync(() async {
      final s = b.store();
      await s.ready;
      return s;
    }))!;
    final session = MiniPhoneSession(data: s);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: MiniPhonePage(
          session: session,
          initialScreen: MiniPhoneScreen.messages,
        ),
      ),
    );
    await settle(tester);
    final character = find.byKey(const ValueKey('mini-phone-conversation-c'));
    final player = find.byKey(
      const ValueKey('mini-phone-conversation-player-char'),
    );
    expect(character, findsNothing);
    expect(player, findsNothing);
    expect(find.text('Nothing here yet.'), findsNothing);
    await tester.runAsync(() async {
      s.receive(
        phoneEvent('first', [
          {...phoneMessage(7, session: 10), 'sender_id': 'player-char'},
        ], session: 10),
      );
      await s.writesSaved;
    });
    await settle(tester);
    expect(character, findsNothing);
    expect(player, findsNothing);
    expect(find.text('Message 7'), findsNothing);
    b.respond = (r) => r.uri.path.endsWith('/dm_sessions')
        ? ok(
            page([
              {
                ...phoneSession(),
                'dm_session_id': 10,
                'char_id': 'player-char',
                'char_name': 'Player',
              },
            ]),
          )
        : null;
    await tester.runAsync(s.refreshSessions);
    await settle(tester);
    expect(character, findsNothing);
    expect(player, findsOneWidget);
    expect(find.text('Message 7'), findsOneWidget);
    await tester.tap(player);
    await tester.pump();
    await settle(tester);
    expect(find.byType(MiniPhoneLiveChat), findsOneWidget);
    expect(s.activeCharId, 'player-char');
    expect(s.sessionFor('player-char'), 10);
    expect(find.byType(ChatComposer), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    session.dispose();
  });
  testWidgets(
    'Posts authors retry and tapping the selected author restores all posts',
    (tester) async {
      final b = PhoneBackend();
      var failAuthors = true;
      b.respond = (r) {
        if (r.uri.path.endsWith('/post/authors')) {
          return failAuthors
              ? {'err_no': 4004, 'err_msg': 'Authors unavailable', 'data': {}}
              : ok({
                  'list': ['player-char'],
                });
        }
        if (r.uri.path.endsWith('/posts') &&
            r.uri.queryParameters['char_id'] != null) {
          return ok(
            page([
              {
                ...phonePost(),
                'text': 'Player post',
                'author_type': 1,
                'author_id': 'u',
              },
            ]),
          );
        }
        return null;
      };
      final s = (await tester.runAsync(() async {
        final s = b.store();
        await s.ready;
        return s;
      }))!;
      final session = MiniPhoneSession(data: s);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: MiniPhonePage(
            session: session,
            initialScreen: MiniPhoneScreen.posts,
          ),
        ),
      );
      await settle(tester);
      expect(find.text('Authors unavailable'), findsOneWidget);
      expect(find.text('Post body'), findsOneWidget);
      failAuthors = false;
      await tester.pump(const Duration(seconds: 3));
      await tester.drag(find.byType(ListView), const Offset(0, 350));
      await settle(tester);
      expect(find.text('Authors unavailable'), findsNothing);
      expect(
        find.byKey(const ValueKey('mini-phone-post-author-c')),
        findsNothing,
      );
      expect(find.text('Player'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('mini-phone-post-author-player-char')),
      );
      await settle(tester);
      expect(find.text('Player post'), findsOneWidget);
      expect(find.text('Post body'), findsNothing);
      expect(b.calls('posts').last.uri.queryParameters, {
        'world_id': 'w',
        'char_id': 'player-char',
        'pn': '1',
        'rn': '10',
      });
      await tester.tap(
        find.byKey(const ValueKey('mini-phone-post-author-player-char')),
      );
      await settle(tester);
      expect(find.text('Post body'), findsOneWidget);
      expect(
        b.calls('posts').last.uri.queryParameters.containsKey('char_id'),
        isFalse,
      );
      expect(b.calls('post/notifications/read').length, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      session.dispose();
    },
  );
  testWidgets(
    'send keeps keyboard, creates no optimistic bubble, shows and ends typing',
    (tester) async {
      final b = PhoneBackend();
      final s = (await tester.runAsync(() async {
        final s = b.store();
        await s.ready;
        return s;
      }))!;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.view.resetPadding);
      tester.view.viewPadding = const FakeViewPadding(bottom: 24);
      tester.view.padding = const FakeViewPadding(bottom: 24);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(platform: TargetPlatform.iOS),
          home: MiniPhoneLiveChat(
            store: s,
            person: const PhonePerson('c', 'Character', ''),
            header: const SizedBox(height: 56),
          ),
        ),
      );
      await settle(tester);
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Hello');
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      tester.view.padding = const FakeViewPadding();
      await settle(tester);
      final composer = tester.widget<ChatComposer>(find.byType(ChatComposer));
      expect(composer.focusNode!.hasFocus, isTrue);
      await tester.runAsync(composer.onSend);
      await tester.pump();
      expect(composer.focusNode!.hasFocus, isTrue);
      expect(tester.view.viewInsets.bottom, 300);
      expect(
        tester.getBottomRight(find.byType(ChatComposer)).dy,
        lessThanOrEqualTo(544),
      );
      expect(find.text('Character is typing…'), findsOneWidget);
      expect(
        tester
            .widget<LocationChatAnchoredMessageList>(
              find.byType(LocationChatAnchoredMessageList),
            )
            .replyWaitingPositioningEnabled,
        isFalse,
      );
      expect(s.history('c'), isEmpty);
      final id = s.waiting('c')!.id;
      await tester.runAsync(() async {
        s.receive(
          phoneEvent('user', [
            phoneMessage(1, sender: 'user', requestId: id),
          ], requestId: id),
        );
        s.receive(phoneEvent('reply', [phoneMessage(2)], requestId: id));
        await s.writesSaved;
      });
      await settle(tester);
      expect(find.text('Character is typing…'), findsNothing);
      expect(find.text('Message 1'), findsOneWidget);
      expect(find.text('Message 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() => s.writesSaved);
      s.dispose();
    },
  );
  testWidgets('history reader stays detached while new messages arrive', (
    tester,
  ) async {
    final b = PhoneBackend();
    b.respond = (r) => r.uri.path.endsWith('/messages')
        ? ok(page([for (var i = 40; i >= 1; i--) phoneMessage(i)], rn: 40))
        : null;
    final s = (await tester.runAsync(() async {
      final s = b.store();
      await s.ready;
      return s;
    }))!;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: MiniPhoneLiveChat(
          store: s,
          person: const PhonePerson('c', 'Character', ''),
          header: const SizedBox(height: 56),
        ),
      ),
    );
    await settle(tester);
    final list = tester.widget<LocationChatAnchoredMessageList>(
      find.byType(LocationChatAnchoredMessageList),
    );
    await tester.drag(
      find.byType(LocationChatAnchoredMessageList),
      const Offset(0, 400),
    );
    await settle(tester);
    final before = list.coordinator.controller.offset;
    expect(list.coordinator.isReadingHistory, isTrue);
    await tester.runAsync(() async {
      s.receive(phoneEvent('new', [phoneMessage(41)]));
      await s.writesSaved;
    });
    await settle(tester);
    expect(list.coordinator.controller.offset, closeTo(before, 1));
    expect(find.text('New messages ↓'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() => s.writesSaved);
    s.dispose();
  });
  testWidgets(
    'Posts entry reads once; feed and details use live content on a narrow large-text screen',
    (tester) async {
      final b = PhoneBackend();
      final s = (await tester.runAsync(() async {
        final s = b.store();
        await s.ready;
        return s;
      }))!;
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session = MiniPhoneSession(data: s);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: MiniPhonePage(
            session: session,
            initialScreen: MiniPhoneScreen.posts,
          ),
        ),
      );
      await settle(tester);
      expect(find.text('Post body'), findsOneWidget);
      expect(b.calls('post/notifications/read').length, 1);
      expect(find.text('Vivienne'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Be the first to comment'));
      await tester.tap(find.text('Be the first to comment'));
      await settle(tester);
      expect(find.text('Post body'), findsOneWidget);
      expect(b.calls('post/detail'), isNotEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      session.dispose();
    },
  );
}
