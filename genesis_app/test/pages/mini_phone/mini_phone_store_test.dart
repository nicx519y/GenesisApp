import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/network/api_exception.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_models.dart';
import '../../support/mini_phone_chat_backend.dart';

Future<void> flush() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'delivery before HTTP, duplicate and out-of-order batches produce canonical messages once',
    () async {
      final b = PhoneBackend(), gate = Completer<Object?>();
      final s = b.store();
      await s.ready;
      b.respond = (r) => r.uri.path.endsWith('/dm/send') ? gate.future : null;
      final send = s.write('dm', 'c', 'Hello');
      await flush();
      final request = s.waiting('c')!.id;
      s.receive(
        phoneEvent('user', [
          phoneMessage(2, sender: 'user', requestId: request),
        ], requestId: request),
      );
      s.receive(
        phoneEvent('ai', [
          phoneMessage(4),
          phoneMessage(3),
        ], requestId: request),
      );
      s.receive(
        phoneEvent('ai', [
          phoneMessage(4),
          phoneMessage(3),
        ], requestId: request),
      );
      gate.complete(ok({}));
      expect(await send, isTrue);
      expect(s.history('c').map((m) => m.id), [2, 3, 4]);
      expect(s.waiting('c'), isNull);
      expect(s.unread.count, 0); // never inferred from received bubbles
      s.dispose();
    },
  );
  test(
    'final failure retains committed user bubble; unrelated automatic DM does not end wait',
    () async {
      final b = PhoneBackend(), s = PhoneBackend();
      final store = b.store();
      await store.ready;
      await store.write('dm', 'c', 'Hello');
      final request = store.waiting('c')!.id;
      store.receive(
        phoneEvent('self', [
          phoneMessage(1, sender: 'user', requestId: request),
        ], requestId: request),
      );
      store.receive(phoneEvent('auto', [phoneMessage(2)]));
      expect(store.waiting('c'), isNotNull);
      store.receive(
        phoneEvent('failed', [], requestId: request, failure: 'Reply failed'),
      );
      expect(store.waiting('c'), isNull);
      expect(store.replyFailures['c'], 'Reply failed');
      expect(store.history('c').first.senderType, 'user');
      expect(s.requests, isEmpty);
      store.dispose();
    },
  );
  test(
    'uncertain retries retain exact request across store recreation',
    () async {
      final b = PhoneBackend();
      b.respond = (r) {
        if (r.uri.path.endsWith('/dm/send')) {
          throw ApiException(
            message: 'Timeout',
            kind: ApiExceptionKind.timeout,
          );
        }
        return null;
      };
      final s = b.store();
      await s.ready;
      expect(await s.write('dm', 'c', 'Original'), isFalse);
      final id = s.waiting('c')!.id;
      s.dispose();
      final restored = b.store();
      await restored.ready;
      expect(restored.waiting('c')!.id, id);
      await restored.write('dm', 'c', 'Different draft', retry: true);
      final calls = b.calls('dm/send');
      expect(calls.length, 2);
      expect(b.body(calls.first), b.body(calls.last));
      expect(b.body(calls.last)['content'], 'Original');
      restored.dispose();
    },
  );
  test(
    'account switch discards stale HTTP result and account-owned writes',
    () async {
      final b = PhoneBackend(), gate = Completer<Object?>();
      final s = b.store();
      await s.ready;
      b.respond = (r) => r.uri.path.endsWith('/posts') ? gate.future : null;
      final old = s.refreshPosts();
      await flush();
      b.uid = 'other';
      b.revision.value++;
      await s.ready;
      gate.complete(ok(page([phonePost()])));
      await old;
      expect(s.posts, isEmpty);
      expect(s.uid, 'other');
      s.dispose();
    },
  );
  test(
    'history recovery crosses pages until known boundary; native IDs sort numerically',
    () async {
      final b = PhoneBackend(), s = PhoneBackend();
      final store = b.store();
      await store.ready;
      store.receive(phoneEvent('old', [phoneMessage(1)]));
      b.respond = (r) {
        if (!r.uri.path.endsWith('/messages')) return null;
        final pn = int.parse(r.uri.queryParameters['pn']!);
        return ok(
          page(
            [
              for (
                var id = 31 - (pn - 1) * 10;
                id > 21 - (pn - 1) * 10 && id > 0;
                id--
              )
                phoneMessage(id),
            ],
            pn: pn,
            total: 31,
          ),
        );
      };
      await store.refreshMessages('c');
      expect(store.history('c').length, 31);
      expect(store.history('c').first.id, 1);
      expect(store.history('c').last.id, 31);
      expect(s.requests, isEmpty);
      store.dispose();
    },
  );
  test(
    'post reads happen only on successful explicit entry, not incoming notification',
    () async {
      final b = PhoneBackend(), s = b.store();
      await s.ready;
      s.phoneVisible = true;
      s.postsVisible = true;
      await s.refreshPosts();
      expect(b.calls('post/notifications/read'), isEmpty);
      await s.refreshPosts(markRead: true);
      expect(b.calls('post/notifications/read').length, 1);
      s.receive(
        chatroomEventFromV2Message(
              ChatroomV2Message.fromJson({
                'type': 'phone.post.notification.created',
                'stream_type': '',
                'world_id': 'w',
                'err_no': 0,
                'payload': {...phoneNotification(), 'event_id': 'p'},
              }),
            )
            as ChatroomPhoneEvent,
      );
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(b.calls('post/notifications/read').length, 1);
      s.dispose();
    },
  );
  test(
    'notifications retain duplicate-looking facts and replace pages',
    () async {
      final b = PhoneBackend();
      b.respond = (r) => r.uri.path.endsWith('/post/notifications')
          ? ok(
              page(
                [phoneNotification(), phoneNotification()],
                pn: int.parse(r.uri.queryParameters['pn']!),
                total: 22,
              ),
            )
          : null;
      final s = b.store();
      await s.ready;
      await s.refreshNotifications();
      expect(s.notifications!.list.length, 2);
      await s.refreshNotifications(pn: 2);
      expect(s.notifications!.pn, 2);
      expect(s.notifications!.list.length, 2);
      s.dispose();
    },
  );
  test(
    'like/unlike serializes newer intent and queries state after each operation',
    () async {
      final b = PhoneBackend(), gate = Completer<Object?>();
      var liked = false;
      b.respond = (r) {
        if (r.uri.path.endsWith('/post/like')) {
          liked = true;
          return gate.future;
        }
        if (r.uri.path.endsWith('/post/unlike')) {
          liked = false;
          return ok({});
        }
        if (r.uri.path.endsWith('/post/detail')) {
          return ok(phoneDetail(liked: liked));
        }
        return null;
      };
      final s = b.store();
      await s.ready;
      final first = s.setLiked(8, true);
      await flush();
      await s.setLiked(8, false);
      expect(b.calls('post/unlike'), isEmpty);
      gate.complete(ok({}));
      await first;
      expect(b.calls('post/unlike').length, 1);
      expect(s.details[8]!.isLiked, isFalse);
      s.dispose();
    },
  );
  test(
    'a delivery during mark-read schedules a second read instead of losing it',
    () async {
      final b = PhoneBackend(), gate = Completer<Object?>();
      var reads = 0;
      b.respond = (r) {
        if (r.uri.path.endsWith('/dm_session/read') && ++reads == 1) {
          return gate.future;
        }
        return null;
      };
      final s = b.store();
      await s.ready;
      s.phoneVisible = true;
      s.activeCharId = 'c';
      final first = s.markSessionRead(9);
      await flush();
      s.receive(phoneEvent('during-read', [phoneMessage(1)]));
      gate.complete(ok({}));
      await first;
      expect(reads, 2);
      s.dispose();
    },
  );
  test(
    'events arriving during refresh retain a second authoritative query',
    () async {
      final b = PhoneBackend();
      final s = b.store();
      await s.ready;
      final gate = Completer<Object?>();
      var refreshes = 0;
      Object summary(int count) => ok({
        'dms': {'unread_count': count, 'list': []},
        'posts': {'unread_count': 0, 'list': []},
      });
      b.respond = (r) {
        if (!r.uri.path.endsWith('/home')) return null;
        refreshes++;
        return refreshes == 1 ? gate.future : summary(7);
      };
      s.receive(phoneEvent('a', [phoneMessage(1)]));
      await Future<void>.delayed(const Duration(milliseconds: 210));
      s.receive(phoneEvent('b', [phoneMessage(2)]));
      gate.complete(summary(1));
      await Future<void>.delayed(const Duration(milliseconds: 230));
      expect(refreshes, greaterThanOrEqualTo(2));
      expect(s.home.dmUnread, 7);
      s.dispose();
    },
  );
  test(
    'explicit rejection retains no committed bubble and failed Feed does not mark read',
    () async {
      final b = PhoneBackend();
      final s = b.store();
      await s.ready;
      b.respond = (r) =>
          r.uri.path.endsWith('/dm/send') || r.uri.path.endsWith('/posts')
          ? {'err_no': 4004, 'err_msg': 'Request rejected', 'data': {}}
          : null;
      expect(await s.write('dm', 'c', 'Keep draft'), isFalse);
      expect(s.waiting('c'), isNull);
      expect(s.history('c'), isEmpty);
      expect(s.errors['dm:c'], 'Request rejected');
      final originalRequest = s.pending['dm:c']!.id;
      await s.write('dm', 'c', 'Keep draft');
      expect(s.pending['dm:c']!.id, originalRequest);
      await s.write('dm', 'c', 'Edited draft');
      expect(s.pending['dm:c']!.id, isNot(originalRequest));
      s.phoneVisible = true;
      s.postsVisible = true;
      await s.refreshPosts(markRead: true);
      expect(b.calls('post/notifications/read'), isEmpty);
      s.dispose();
    },
  );

  test(
    'first-send recovery resolves older read sessions before querying history',
    () async {
      final b = PhoneBackend();
      b.respond = (r) =>
          r.uri.path.endsWith('/dm_sessions') ? ok(page([])) : null;
      final s = b.store();
      await s.ready;
      expect(s.sessionFor('c'), isNull);
      await s.write('dm', 'c', 'First send');
      final request = s.waiting('c')!.id;
      s.unreadSessionsOnly = true;
      b.respond = (r) {
        if (r.uri.path.endsWith('/dm_sessions')) {
          if (r.uri.queryParameters['unread_only'] == 'true') {
            return ok(page([]));
          }
          final pn = int.parse(r.uri.queryParameters['pn']!);
          return ok(
            page(
              pn == 1
                  ? [
                      {...phoneSession(), 'char_id': 'other'},
                    ]
                  : [phoneSession()],
              pn: pn,
              rn: 1,
              total: 2,
            ),
          );
        }
        if (r.uri.path.endsWith('/messages')) {
          return ok(
            page([phoneMessage(1, sender: 'user', requestId: request)]),
          );
        }
        return null;
      };
      s.scheduleRefresh();
      await Future<void>.delayed(const Duration(milliseconds: 260));
      expect(s.sessionFor('c'), 9);
      expect(s.history('c').map((m) => m.id), [1]);
      expect(
        s.waiting('c'),
        isNotNull,
      ); // history cannot prove AI terminal state
      expect(b.calls('dm/send').length, 1);
      s.dispose();
    },
  );
  test(
    'world clock reads time rather than the trailing calendar date',
    () async {
      final s = PhoneBackend().store();
      await s.ready;
      s.currentTime = 'Day 2, 05:15 / 850-01-02';
      expect(s.clockTime, '05:15');
      expect(s.worldDay, 'Day 2');
      s.currentTime = 'Day 2/10:00';
      expect(s.clockTime, '10:00');
      s.currentTime = '';
      expect(s.clockTime, '—');
      s.dispose();
    },
  );
}
