import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/pages/mini_phone/mini_phone.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_models.dart';
import 'package:genesis_flutter_android/pages/mini_phone/entry/mini_phone_entry_artwork.dart';
import 'package:genesis_flutter_android/pages/mini_phone/shared/mini_phone_ui.dart';
import 'package:genesis_flutter_android/ui/animations/app_launch_transition/app_launch_transition.dart';

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

  test(
    'Post receipt coalesces and preserves notifications arriving afterward',
    () async {
      final backend = PhoneBackend(), store = backend.store();
      addTearDown(store.dispose);
      await store.ready;
      final receipt = Completer<Object?>();
      var newNotification = false;
      backend.respond = (request) {
        if (request.uri.path.endsWith('/post/notifications/read')) {
          return receipt.future;
        }
        if (request.uri.path.endsWith('/post/notifications')) {
          return ok(page(newNotification ? [phoneNotification()] : [], rn: 20));
        }
        return null;
      };
      final before = backend.requests.length;
      final first = store.markPostsRead(), second = store.markPostsRead();
      receipt.complete(ok({}));
      await Future.wait([first, second]);
      expect(store.totalUnreadCount, 0);
      newNotification = true;
      store.receive(
        chatroomEventFromV2Message(
              ChatroomV2Message.fromJson({
                'type': 'phone.post.notification.created',
                'stream_type': '',
                'world_id': 'w',
                'err_no': 0,
                'payload': {...phoneNotification(), 'event_id': 'after-read'},
              }),
            )
            as ChatroomPhoneEvent,
      );
      await Future<void>.delayed(const Duration(milliseconds: 260));
      expect(store.home.postUnread, 1);
      expect(backend.calls('post/notifications/read'), hasLength(1));
      expect(backend.requests.skip(before).map((request) => request.uri.path), [
        '/aitown-chat/api/v1/phone/post/notifications/read',
        '/aitown-chat/api/v1/phone/post/notifications',
        '/aitown-chat/api/v1/phone/post/notifications',
      ]);
      await store.cacheSaved;
    },
  );

  test(
    'failed Post summary retries on reopening without replaying the receipt',
    () async {
      final backend = PhoneBackend();
      var summaryFails = true;
      backend.respond = (request) {
        if (request.uri.path.endsWith('/home')) {
          return ok({
            'dms': {'unread_count': 0, 'list': []},
            'posts': {
              'unread_count': 1,
              'list': [phoneNotification()],
            },
          });
        }
        if (request.uri.path.endsWith('/post/notifications')) {
          if (summaryFails) throw TimeoutException('Offline summary');
          return ok(page([], rn: 20));
        }
        return null;
      };
      final store = backend.store();
      addTearDown(store.dispose);
      await store.ready;
      store.phoneVisible = true;
      expect(await store.markPostsRead(), isTrue);
      expect(store.home.postUnread, 1);
      expect(store.errors, contains('postSummary'));
      await Future<void>.delayed(const Duration(milliseconds: 260));
      expect(backend.calls('post/notifications'), hasLength(1));
      summaryFails = false;
      store.phoneVisible = false;
      store.phoneVisible = true;
      await Future<void>.delayed(const Duration(milliseconds: 260));
      expect(store.home.postUnread, 0);
      expect(store.home.notifications, isEmpty);
      expect(backend.calls('post/notifications'), hasLength(2));
      expect(backend.calls('post/notifications/read'), hasLength(1));
      expect(store.errors, isNot(contains('postSummary')));
    },
  );

  test(
    'failed Post receipt stays unread until another explicit read',
    () async {
      final backend = PhoneBackend();
      var receiptFails = true;
      backend.respond = (request) {
        if (request.uri.path.endsWith('/home')) {
          return ok({
            'dms': {'unread_count': 0, 'list': []},
            'posts': {
              'unread_count': 1,
              'list': [phoneNotification()],
            },
          });
        }
        if (request.uri.path.endsWith('/post/notifications/read') &&
            receiptFails) {
          return {'err_no': 5001, 'err_msg': 'Read unavailable', 'data': {}};
        }
        return null;
      };
      final store = backend.store();
      addTearDown(store.dispose);
      await store.ready;
      expect(await store.markPostsRead(), isFalse);
      expect(store.home.postUnread, 1);
      expect(store.errors['readPosts'], 'Read unavailable');
      expect(backend.calls('post/notifications'), isEmpty);
      store.phoneVisible = true;
      await Future<void>.delayed(const Duration(milliseconds: 260));
      expect(backend.calls('post/notifications/read'), hasLength(1));
      receiptFails = false;
      expect(await store.markPostsRead(), isTrue);
      expect(store.home.postUnread, 0);
      expect(backend.calls('post/notifications/read'), hasLength(2));
    },
  );

  test(
    'Post receipt completing in background defers only its summary',
    () async {
      final backend = PhoneBackend(), store = backend.store();
      addTearDown(store.dispose);
      await store.ready;
      final receipt = Completer<Object?>();
      backend.respond = (request) =>
          request.uri.path.endsWith('/post/notifications/read')
          ? receipt.future
          : null;
      final reading = store.markPostsRead();
      await Future<void>.delayed(Duration.zero);
      store.didChangeAppLifecycleState(AppLifecycleState.paused);
      receipt.complete(ok({}));
      expect(await reading, isTrue);
      expect(backend.calls('post/notifications'), isEmpty);
      store.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 260));
      expect(backend.calls('post/notifications'), hasLength(1));
      expect(backend.calls('post/notifications/read'), hasLength(1));
    },
  );

  test(
    'Post receipt from a previous account cannot refresh the new account',
    () async {
      final backend = PhoneBackend(), store = backend.store();
      addTearDown(store.dispose);
      await store.ready;
      final receipt = Completer<Object?>();
      backend.respond = (request) =>
          request.uri.path.endsWith('/post/notifications/read')
          ? receipt.future
          : null;
      final reading = store.markPostsRead();
      await Future<void>.delayed(Duration.zero);
      backend.uid = 'other';
      backend.revision.value++;
      await store.ready;
      receipt.complete(ok({}));
      expect(await reading, isFalse);
      expect(backend.calls('post/notifications'), isEmpty);
    },
  );

  for (final outcome in ['success', 'failure', 'closed']) {
    testWidgets('desktop Post notification detail $outcome read behavior', (
      tester,
    ) async {
      final backend = PhoneBackend();
      final detail = Completer<Object?>();
      final receipt = Completer<Object?>();
      var read = false;
      backend.respond = (request) {
        if (request.uri.path.endsWith('/home')) {
          return ok({
            'dms': {'unread_count': 0, 'list': []},
            'posts': {
              'unread_count': read ? 0 : 1,
              'list': read ? [] : [phoneNotification()],
            },
          });
        }
        if (request.uri.path.endsWith('/post/detail')) return detail.future;
        if (request.uri.path.endsWith('/post/notifications/read')) {
          return receipt.future;
        }
        if (request.uri.path.endsWith('/post/notifications')) {
          return ok(page(read ? [] : [phoneNotification()], rn: 20));
        }
        return null;
      };
      final store = (await tester.runAsync(() async {
        final store = backend.store();
        await store.ready;
        return store;
      }))!;
      final session = MiniPhoneSession(data: store);
      addTearDown(session.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: MiniPhoneEntry(
                  session: session,
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => MiniPhonePage(session: session),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await settle(tester);
      expect(
        tester
            .widget<MiniPhoneEntryBadge>(find.byType(MiniPhoneEntryBadge))
            .count,
        1,
      );
      await tester.tap(find.byType(MiniPhoneEntry));
      await settle(tester);
      final notification = find.byWidgetPredicate(
        (widget) => widget is AppLaunchSource && widget.id == ('post', '8:0'),
      );
      await tester.ensureVisible(notification);
      await tester.tap(notification);
      await settle(tester);
      expect(backend.calls('post/detail'), hasLength(1));
      expect(backend.calls('post/notifications/read'), isEmpty);

      if (outcome == 'closed') {
        await tester.tap(
          find.byWidgetPredicate(
            (widget) => widget is MiniIconButton && widget.icon == 'close',
          ),
        );
        await settle(tester);
      }
      detail.complete(
        outcome == 'failure'
            ? {'err_no': 5001, 'err_msg': 'Detail unavailable', 'data': {}}
            : ok(phoneDetail()),
      );
      await settle(tester);
      if (outcome == 'success') {
        expect(backend.calls('post/notifications/read'), hasLength(1));
        // Closing MiniPhone keeps the World-owned store and receipt alive.
        await tester.tap(
          find.byWidgetPredicate(
            (widget) => widget is MiniIconButton && widget.icon == 'close',
          ),
        );
        await settle(tester);
        expect(store.phoneVisible, isFalse);
        expect(
          tester
              .widget<MiniPhoneEntryBadge>(find.byType(MiniPhoneEntryBadge))
              .count,
          1,
        );
        read = true;
        receipt.complete(ok({}));
        await settle(tester);
        expect(store.home.notifications, isEmpty);
        expect(store.totalUnreadCount, 0);
        expect(find.byType(MiniPhoneEntryBadge), findsNothing);
        expect(backend.calls('post/notifications'), hasLength(1));
      } else {
        expect(backend.calls('post/notifications/read'), isEmpty);
        expect(store.home.postUnread, 1);
      }
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });
  }
}
