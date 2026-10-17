import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_models.dart';
import 'package:genesis_flutter_android/pages/mini_phone/mini_phone_page.dart';
import '../../support/mini_phone_chat_backend.dart';

Future<void> drain() async {
  for (var i = 0; i < 12; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Future<void> scheduled() =>
    Future<void>.delayed(const Duration(milliseconds: 260));
ChatroomPhoneEvent postEvent(String id) =>
    chatroomEventFromV2Message(
          ChatroomV2Message.fromJson({
            'type': 'phone.post.notification.created',
            'stream_type': '',
            'world_id': 'w',
            'err_no': 0,
            'payload': {...phoneNotification(), 'event_id': id},
          }),
        )
        as ChatroomPhoneEvent;
Object completed(String request) => ok(
  page([
    {
      ...phoneMessage(1, sender: 'user', requestId: request),
      'reply_status': 'completed',
    },
    phoneMessage(2, requestId: request),
  ]),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'restored pending send recovers while initial Home is blocked',
    () async {
      final original = PhoneBackend().store();
      await original.ready;
      await original.write('dm', 'c', 'Persisted send');
      final request = original.waiting('c')!.id;
      await original.writesSaved;
      original.dispose();
      final b = PhoneBackend(), home = Completer<Object?>();
      b.respond = (r) {
        if (r.uri.path.endsWith('/home')) return home.future;
        if (r.uri.path.endsWith('/messages')) return completed(request);
        return null;
      };
      final s = b.store();
      addTearDown(s.dispose);
      await s.localReady;
      await scheduled();
      expect(s.waiting('c'), isNull);
      expect(s.history('c').map((m) => m.id), [1, 2]);
      expect(b.calls('dm/send'), isEmpty);
      home.complete(b.defaultResponse(b.calls('home').single));
      await s.ready;
      await s.writesSaved;
    },
  );

  test('Post event inside pending DM never queries any DM endpoint', () async {
    final b = PhoneBackend(), s = b.store();
    addTearDown(s.dispose);
    await s.ready;
    await s.refreshSessions();
    s.phoneVisible = true;
    s.activeCharId = 'c';
    b.respond = (r) {
      if (r.uri.path.endsWith('/dm_session/read')) {
        throw TimeoutException('Offline read');
      }
      if (r.uri.path.endsWith('/post/notifications')) {
        return ok(page([phoneNotification()], rn: 20, total: 7));
      }
      return null;
    };
    await s.markSessionRead(9);
    await s.write('dm', 'c', 'Waiting');
    await scheduled();
    final before = b.requests.length, unread = s.dmUnreadCount;
    s.receive(postEvent('post-only'));
    await scheduled();
    final added = b.requests.skip(before).toList();
    expect(added.map((r) => r.uri.path), [
      '/aitown-chat/api/v1/phone/post/notifications',
    ]);
    expect(added.single.uri.queryParameters['unread_only'], 'true');
    expect(added.single.uri.queryParameters['rn'], '20');
    expect(s.home.postUnread, 7);
    expect(s.home.notifications, hasLength(1));
    expect(s.dmUnreadCount, unread);
    expect(s.waiting('c'), isNotNull);
    await s.writesSaved;
  });

  test(
    'late Home preserves newer independent Post summary and live DM',
    () async {
      final b = PhoneBackend(), s = b.store();
      addTearDown(s.dispose);
      await s.ready;
      final gate = Completer<Object?>();
      b.respond = (r) {
        if (r.uri.path.endsWith('/home')) return gate.future;
        if (r.uri.path.endsWith('/post/notifications')) {
          return ok(page([phoneNotification()], total: 3, rn: 20));
        }
        return null;
      };
      final refreshing = s.refreshSummary();
      await drain();
      await s.refreshPostSummary();
      s.receive(phoneEvent('dm-during-home', [phoneMessage(10)]));
      gate.complete(b.defaultResponse(b.calls('home').last));
      await refreshing;
      expect(s.home.postUnread, 3);
      expect(s.home.notifications, hasLength(1));
      expect(s.dmUnreadCount, 1);
      await s.cacheSaved;
    },
  );

  test(
    'Post summary flights coalesce and cannot replace a newer Home',
    () async {
      final b = PhoneBackend(), s = b.store();
      addTearDown(s.dispose);
      await s.ready;
      final gate = Completer<Object?>();
      b.respond = (r) {
        if (r.uri.path.endsWith('/post/notifications')) return gate.future;
        return null;
      };
      final first = s.refreshPostSummary(), second = s.refreshPostSummary();
      await drain();
      expect(b.calls('post/notifications'), hasLength(1));
      await s.refreshSummary();
      gate.complete(ok(page([phoneNotification()], total: 9, rn: 20)));
      await Future.wait([first, second]);
      expect(s.home.postUnread, 0);
      expect(s.home.notifications, isEmpty);
      // A later isolated Post query still applies normally.
      b.respond = (r) => r.uri.path.endsWith('/post/notifications')
          ? ok(page([phoneNotification()], total: 3, rn: 20))
          : null;
      await Future.wait([s.refreshPostSummary(), s.refreshPostSummary()]);
      expect(b.calls('post/notifications'), hasLength(2));
      expect(s.home.postUnread, 3);
    },
  );

  test(
    'send starts after local restore without waiting for remote initialization',
    () async {
      final b = PhoneBackend(), gate = Completer<Object?>();
      b.respond = (r) => r.uri.path.endsWith('/home') ? gate.future : null;
      final s = b.store();
      addTearDown(s.dispose);
      await s.localReady;
      expect(
        await s
            .write('dm', 'c', 'Send while Home is blocked')
            .timeout(const Duration(seconds: 1)),
        isTrue,
      );
      expect(b.calls('dm/send'), hasLength(1));
      gate.complete(b.defaultResponse(b.calls('home').single));
      await s.ready;
      await s.writesSaved;
    },
  );

  test('same read boundary skips duplicate receipt and summary', () async {
    final b = PhoneBackend(), s = b.store();
    addTearDown(s.dispose);
    await s.ready;
    await s.refreshSessions();
    s.receive(phoneEvent('cached', [phoneMessage(1)]));
    await s.markSessionRead(9);
    final before = b.requests.length;
    b.respond = (r) =>
        r.uri.path.endsWith('/messages') ? ok(page([phoneMessage(1)])) : null;
    s.phoneVisible = true;
    s.activeCharId = 'c';
    await Future.wait([
      s.markSessionRead(9),
      s.markSessionRead(9),
      s.refreshMessages('c'),
    ]);
    expect(b.requests.skip(before).map((r) => r.uri.path), [
      '/aitown-chat/api/v1/phone/messages',
    ]);
    s.phoneVisible = false;
    s.receive(phoneEvent('new', [phoneMessage(2)]));
    await s.markSessionRead(9);
    expect(b.calls('dm_session/read'), hasLength(2));
    await s.cacheSaved;
  });

  test(
    'summary shares flight and receipt requires exactly one fresh tail',
    () async {
      final b = PhoneBackend(), s = b.store();
      addTearDown(s.dispose);
      await s.ready;
      final gate = Completer<Object?>();
      var held = true;
      b.respond = (r) =>
          r.uri.path.endsWith('/home') && held ? gate.future : null;
      final homes = b.calls('home').length, unreads = b.calls('unread').length;
      final first = s.refreshSummary(), second = s.refreshSummary();
      await drain();
      expect(b.calls('home').length, homes + 1);
      expect(b.calls('unread').length, unreads + 1);
      final read = s.markSessionRead(9);
      await drain();
      expect(b.calls('dm_session/read'), hasLength(1));
      held = false;
      gate.complete(b.defaultResponse(b.calls('home').last));
      await Future.wait([first, second, read]);
      expect(b.calls('home').length, homes + 2);
      expect(b.calls('unread').length, unreads + 2);
      await s.cacheSaved;
    },
  );

  test(
    'identical concurrent session and history queries dispatch once',
    () async {
      final b = PhoneBackend(), s = b.store();
      addTearDown(s.dispose);
      await s.ready;
      final gate = Completer<Object?>();
      b.respond = (r) =>
          r.uri.path.endsWith('/dm_sessions') ? gate.future : null;
      final first = s.refreshSessions(), second = s.refreshSessions();
      await drain();
      expect(b.calls('dm_sessions'), hasLength(1));
      gate.complete(ok(page([phoneSession()])));
      await Future.wait([first, second]);
      final history = Completer<Object?>();
      b.respond = (r) =>
          r.uri.path.endsWith('/messages') ? history.future : null;
      final a = s.refreshMessages('c'), c = s.refreshMessages('c');
      await drain();
      expect(b.calls('messages'), hasLength(1));
      history.complete(ok(page([phoneMessage(1)])));
      await Future.wait([a, c]);
      await s.cacheSaved;
    },
  );

  test(
    'uncertain send recovers without a push or automatic resubmission',
    () async {
      final b = PhoneBackend(), s = b.store();
      addTearDown(s.dispose);
      await s.ready;
      await s.refreshSessions();
      String? request;
      b.respond = (r) {
        if (r.uri.path.endsWith('/dm/send')) {
          request = b.body(r)['client_request_id'] as String;
          throw TimeoutException('Response lost after acceptance');
        }
        if (r.uri.path.endsWith('/messages')) return completed(request!);
        return null;
      };
      expect(await s.write('dm', 'c', 'Original content'), isFalse);
      await scheduled();
      expect(s.waiting('c'), isNull);
      expect(s.history('c').map((m) => m.id), [1, 2]);
      expect(b.calls('dm/send'), hasLength(1));
      expect(
        b.calls('messages').single.uri.queryParameters['client_request_id'],
        request,
      );
      await s.writesSaved;
    },
  );

  test(
    'first send discovers session across pages without refreshing app rows',
    () async {
      final b = PhoneBackend(), s = b.store();
      addTearDown(s.dispose);
      await s.ready;
      String? request;
      b.respond = (r) {
        if (r.uri.path.endsWith('/dm/send')) {
          request = b.body(r)['client_request_id'] as String;
          return ok({});
        }
        if (r.uri.path.endsWith('/dm_sessions')) {
          final pn = int.parse(r.uri.queryParameters['pn']!);
          return ok(
            page(
              [
                {...phoneSession(), 'char_id': pn == 1 ? 'other' : 'c'},
              ],
              pn: pn,
              rn: 1,
              total: 2,
            ),
          );
        }
        if (r.uri.path.endsWith('/messages')) return completed(request!);
        return null;
      };
      await s.write('dm', 'c', 'First send');
      await scheduled();
      expect(b.calls('dm_sessions'), hasLength(2));
      expect(s.sessionFor('c'), 9);
      expect(s.sessions, isEmpty);
      expect(s.waiting('c'), isNull);
      expect(b.calls('dm/send'), hasLength(1));
      await s.writesSaved;
    },
  );

  test(
    'player send recovery ends on committed source without AI state',
    () async {
      final b = PhoneBackend(), s = b.store();
      addTearDown(s.dispose);
      await s.ready;
      String? request;
      b.respond = (r) {
        if (r.uri.path.endsWith('/dm/send')) {
          request = b.body(r)['client_request_id'] as String;
          return ok({});
        }
        if (r.uri.path.endsWith('/dm_sessions')) {
          return ok(
            page([
              {...phoneSession(), 'char_id': 'player-char', 'peer_uid': 'peer'},
            ]),
          );
        }
        if (r.uri.path.endsWith('/messages')) {
          return ok(
            page([phoneMessage(1, sender: 'user', requestId: request)]),
          );
        }
        return null;
      };
      await s.write('dm', 'player-char', 'Hello');
      await scheduled();
      expect(s.waiting('player-char'), isNull);
      expect(s.history('player-char').single.replyStatus, isNull);
      expect(b.calls('dm/send'), hasLength(1));
      await s.writesSaved;
    },
  );

  test(
    'background defers read receipts and Post refresh until foreground',
    () async {
      final b = PhoneBackend(), s = b.store();
      addTearDown(s.dispose);
      await s.ready;
      s.didChangeAppLifecycleState(AppLifecycleState.paused);
      final before = b.requests.length;
      s.receive(phoneEvent('offline-dm', [phoneMessage(1)]));
      await s.markSessionRead(9);
      s.receive(postEvent('offline-post'));
      s.scheduleRefresh();
      await scheduled();
      expect(b.requests.length, before);
      expect(s.dmUnreadCount, 0);
      s.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await scheduled();
      expect(b.calls('dm_session/read'), hasLength(1));
      expect(b.calls('post/notifications'), hasLength(1));
      await s.cacheSaved;
    },
  );

  test(
    'comment confirmation defers in background and resumes independently',
    () async {
      final b = PhoneBackend(), s = b.store();
      addTearDown(s.dispose);
      await s.ready;
      final gate = Completer<Object?>();
      b.respond = (r) =>
          r.uri.path.endsWith('/comment/create') ? gate.future : null;
      final writing = s.write('comment', '8', 'Comment');
      await drain();
      expect(b.calls('comment/create'), hasLength(1));
      s.didChangeAppLifecycleState(AppLifecycleState.paused);
      gate.complete(ok({}));
      expect(await writing, isTrue);
      expect(b.calls('post/detail'), isEmpty);
      expect(b.calls('comments'), isEmpty);
      s.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await drain();
      expect(b.calls('post/detail'), hasLength(1));
      expect(b.calls('comments'), hasLength(1));
      s.receive(postEvent('no-repeated-confirmation'));
      await scheduled();
      expect(b.calls('post/detail'), hasLength(1));
      expect(b.calls('comments'), hasLength(1));
      expect(b.calls('messages'), isEmpty);
    },
  );

  test(
    'timer and connection recovery never overlap a slow status query',
    () async {
      final b = PhoneBackend(), s = b.store();
      addTearDown(s.dispose);
      await s.ready;
      await s.refreshSessions();
      await s.write('dm', 'c', 'Waiting');
      await scheduled();
      final request = s.waiting('c')!.id, gate = Completer<Object?>();
      var active = 0, maxActive = 0;
      b.respond = (r) async {
        if (r.uri.queryParameters['client_request_id'] == request) {
          active++;
          if (active > maxActive) maxActive = active;
          final response = await gate.future;
          active--;
          return response;
        }
        return null;
      };
      final before = b.calls('messages').length;
      await Future<void>.delayed(const Duration(milliseconds: 2100));
      s.scheduleRefresh(refreshHome: false);
      await scheduled();
      expect(b.calls('messages').length, before + 1);
      expect(maxActive, 1);
      // Posts must finish independently while DM recovery is still blocked.
      s.receive(postEvent('post-during-blocked-dm'));
      await scheduled();
      expect(b.calls('post/notifications'), hasLength(1));
      expect(b.calls('messages').length, before + 1);
      gate.complete(completed(request));
      await drain();
      expect(s.waiting('c'), isNull);
      final after = b.requests.length;
      await Future<void>.delayed(const Duration(milliseconds: 2100));
      expect(b.requests.length, after);
      await s.writesSaved;
    },
  );

  testWidgets('lists load before blocked initialization Home completes', (
    tester,
  ) async {
    final b = PhoneBackend(), gate = Completer<Object?>();
    b.respond = (r) => r.uri.path.endsWith('/home') ? gate.future : null;
    final s = (await tester.runAsync(() async {
      final s = b.store();
      await s.localReady;
      return s;
    }))!;
    final session = MiniPhoneSession(data: s);
    await tester.pumpWidget(MaterialApp(home: MiniPhonePage(session: session)));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.runAsync(drain);
    await tester.pump();
    for (final endpoint in ['dm_sessions', 'posts', 'post/authors', 'album']) {
      expect(b.calls(endpoint), hasLength(1), reason: endpoint);
    }
    expect(b.calls('home'), hasLength(1));
    gate.complete(b.defaultResponse(b.calls('home').single));
    await tester.runAsync(() => s.ready);
    await tester.pumpWidget(const SizedBox.shrink());
    session.dispose();
  });
}
