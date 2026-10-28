import 'package:genesis_flutter_android/network/mini_phone/mini_phone_models.dart';
import 'package:genesis_flutter_android/network/models/world.dart';
import 'package:genesis_flutter_android/pages/mini_phone/state/mini_phone_store.dart';
import '../../support/mini_phone_memory_cache.dart';
import 'dart:async';
import 'package:flutter/widgets.dart';
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
  test(
    'AI source enters local history only after asynchronous completion',
    () async {
      SharedPreferences.setMockInitialValues({});
      final backend = PhoneBackend();
      final storage = MemoryMiniPhoneCacheStorage();
      final store = backend.store(
        namespace: 'commit-after-reply',
        cacheStorage: storage,
      );
      await store.ready;
      await store.write('dm', 'c', 'draft body');
      final request = store.pending['dm:c']!.id;
      store.receive(
        phoneEvent('pending-source', [
          {
            ...phoneMessage(1, sender: 'user', requestId: request),
            'reply_status': 'pending',
          },
        ], requestId: request),
      );
      await store.messagesController.cacheSaved;
      final scope = store.messagesController.cacheScope!;
      expect((await storage.load(scope)).messages, isEmpty);
      store.receive(
        phoneEvent(
          'failed-source',
          [],
          requestId: request,
          failure: 'Insufficient balance',
          failureCode: 'insufficient_balance',
        ),
      );
      await store.messagesController.cacheSaved;
      expect((await storage.load(scope)).messages, isEmpty);
      expect(store.messagesController.displayHistory('c'), isEmpty);
      expect(store.drafts['c'], 'draft body');
      await store.write('dm', 'c', 'draft body');
      final next = store.pending['dm:c']!.id;
      store.receive(
        phoneEvent('completed-source', [
          {
            ...phoneMessage(2, sender: 'user', requestId: next),
            'reply_status': 'completed',
          },
        ], requestId: next),
      );
      await store.messagesController.cacheSaved;
      expect((await storage.load(scope)).messages.keys, [2]);
      store.dispose();
    },
  );

  test(
    'retry bubble identity survives store recreation and stays account scoped',
    () async {
      final backend = PhoneBackend();
      final cache = MemoryMiniPhoneCacheStorage();
      final first = backend.store(
        namespace: 'stable-retry',
        cacheStorage: cache,
      );
      await first.ready;
      first.receive(
        phoneEvent('original-source', [
          {
            ...phoneMessage(1, sender: 'user', requestId: 'original'),
            'reply_status': 'failed',
            'failure': {'code': 'insufficient_balance', 'message': 'failed'},
          },
        ], requestId: 'original'),
      );
      await first.write('dm', 'c', 'Message 1', retryRootId: 'original');
      final attempt = first.pending['dm:c']!.id;
      first.receive(
        phoneEvent('retry-source', [
          {
            ...phoneMessage(2, sender: 'user', requestId: attempt),
            'content': 'Message 1',
            'reply_status': 'completed',
          },
        ], requestId: attempt),
      );
      await first.messagesController.cacheSaved;
      await first.writesSaved;
      first.dispose();
      final restored = backend.store(
        namespace: 'stable-retry',
        cacheStorage: cache,
      );
      await restored.ready;
      expect(restored.messagesController.displayHistory('c'), hasLength(1));
      expect(
        restored.messagesController.displayHistory('c').single.replyStatus,
        'completed',
      );
      expect(restored.messagesController.bubbleRequestId(attempt), 'original');
      await restored.writesSaved;
      restored.dispose();
      backend.uid = 'another-user';
      final other = backend.store(
        namespace: 'stable-retry',
        cacheStorage: cache,
      );
      await other.ready;
      expect(other.messagesController.cache.retryRoots, isEmpty);
      other.dispose();
    },
  );

  test(
    'structured async balance failure retains code and suppresses ordinary toast',
    () async {
      final backend = PhoneBackend();
      final store = backend.store(namespace: 'async-balance-code');
      addTearDown(store.dispose);
      await store.ready;
      await store.write('dm', 'c', 'hello');
      final request = store.pending['dm:c']!.id;
      store.receive(
        phoneEvent('delivered', [
          phoneMessage(1, sender: 'user', requestId: request),
        ], requestId: request),
      );
      store.receive(
        phoneEvent(
          'failed',
          [],
          requestId: request,
          failure: 'Balance unavailable',
          failureCode: 'insufficient_balance',
        ),
      );
      expect(store.waiting('c'), isNull);
      expect(store.replyFailureNotice('c'), isNull);
      final message = store.messagesController.cache.messages[1]!;
      expect(message.replyStatus, 'failed');
      expect(message.failureCode, 'insufficient_balance');
      expect(
        PhoneMessage.fromJson(message.toJson()).failureCode,
        'insufficient_balance',
      );
      store.receive(
        phoneEvent('old-pending', [
          {
            ...phoneMessage(1, sender: 'user', requestId: request),
            'reply_status': 'pending',
          },
        ], requestId: request),
      );
      expect(
        store.messagesController.cache.messages[1]!.failureCode,
        'insufficient_balance',
      );
      expect(store.replyFailureNotice('c'), isNull);
    },
  );

  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('late balance failure cannot leak into a new account session', () async {
    final backend = PhoneBackend();
    final store = backend.store(namespace: 'balance-account');
    addTearDown(store.dispose);
    await store.ready;
    final response = Completer<Object?>();
    backend.respond = (r) =>
        r.uri.path.endsWith('/dm/send') ? response.future : null;
    final sending = store.write('dm', 'c', 'old account draft');
    while (backend.calls('dm/send').isEmpty) {
      await flush();
    }
    backend.revision.value++;
    await store.ready;
    response.complete({
      'err_no': 3001,
      'err_msg': 'Balance unavailable',
      'data': {},
    });
    await sending;
    expect(store.hasDmBalanceFailure('c'), isFalse);
    expect(store.drafts['c'], isNull);
  });

  for (final code in [3001, 21001]) {
    test(
      'DM balance error $code suppresses local toast and clears on retry',
      () async {
        final backend = PhoneBackend();
        final store = backend.store(namespace: 'balance-$code');
        addTearDown(store.dispose);
        await store.ready;
        backend.respond = (r) => r.uri.path.endsWith('/dm/send')
            ? {'err_no': code, 'err_msg': 'Balance unavailable', 'data': {}}
            : null;
        expect(await store.write('dm', 'c', 'hello'), isFalse);
        expect(store.hasDmBalanceFailure('c'), isTrue);
        expect(store.pending['dm:c']!.rejected, isTrue);
        expect(store.outgoingDm('c'), isEmpty);
        backend.respond = (r) => r.uri.path.endsWith('/dm/send')
            ? {'err_no': 2061, 'err_msg': 'Denied', 'data': {}}
            : null;
        expect(await store.write('dm', 'c', 'hello again'), isFalse);
        expect(store.hasDmBalanceFailure('c'), isFalse);
        expect(store.errors['dm:c'], 'Denied');
      },
    );
  }

  test(
    'map style follows existing world refresh and clears for historical worlds',
    () async {
      final backend = PhoneBackend();
      Map<String, dynamic>? style = {'era': 'steampunk', 'biome': 'urban'};
      var reads = 0;
      var failWorld = true;
      final store = MiniPhoneStore(
        api: backend.api,
        worldId: 'w',
        namespace: 'style-refresh',
        cacheStorage: MemoryMiniPhoneCacheStorage(),
        readUid: () async => 'u',
        accountRevision: backend.revision,
        loadWorld: () async {
          reads++;
          if (failWorld) throw StateError("world unavailable");
          return WorldDetail.fromJson({'world_id': 'w', 'map_style': style});
        },
      );
      addTearDown(store.dispose);
      expect(store.worldDetailLoaded, isFalse);
      await store.ready;
      expect(store.worldDetailLoaded, isFalse);
      failWorld = false;
      await store.refreshPeople();
      expect(store.worldDetailLoaded, isTrue);
      expect(store.mapStyle!.era, 'steampunk');
      final before = reads;
      style = null;
      await store.refreshPeople();
      expect(reads, before + 1);
      expect(store.mapStyle, isNull);
      expect(store.worldDetailLoaded, isTrue);
    },
  );

  test(
    'background recovery, foreground, notifications and writes do not refresh cached app lists',
    () async {
      final b = PhoneBackend(), s = b.store();
      addTearDown(s.dispose);
      await s.ready;
      b.respond = (r) => r.uri.path.endsWith('/album')
          ? ok(
              page([
                {'asset_id': 1, 'world_id': 'w', 'image_url': ''},
              ]),
            )
          : null;
      expect(b.calls('dm_sessions'), isEmpty);
      expect(b.calls('posts'), isEmpty);
      expect(b.calls('album'), isEmpty);
      await Future.wait([
        s.refreshSessions(),
        s.refreshPosts(),
        s.refreshAlbum(),
      ]);
      final counts = {
        for (final route in ['dm_sessions', 'posts', 'album', 'post/authors'])
          route: b.calls(route).length,
      };
      final unreadCount = b.calls('unread').length;
      s.phoneVisible = s.postsVisible = s.albumVisible = true;
      s.scheduleRefresh();
      s.didChangeAppLifecycleState(AppLifecycleState.resumed);
      s.receive(
        chatroomEventFromV2Message(
              ChatroomV2Message.fromJson({
                'type': 'phone.post.notification.created',
                'stream_type': '',
                'world_id': 'w',
                'err_no': 0,
                'payload': {...phoneNotification(), 'event_id': 'cached-lists'},
              }),
            )
            as ChatroomPhoneEvent,
      );
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await s.markSessionRead(9);
      await s.setLiked(8, true);
      await s.write('comment', '8', 'Comment');
      await s.write('post', 'new', 'New post');
      for (final entry in counts.entries) {
        expect(b.calls(entry.key).length, entry.value, reason: entry.key);
      }
      expect(b.calls('unread').length, greaterThan(unreadCount));
      expect(s.sessions.single.unreadCount, 0);
      expect(s.posts.single.id, 8);
      expect(s.album.single.id, 1);
    },
  );
  test(
    'Messages stays empty when the session API returns no conversations',
    () async {
      final b = PhoneBackend();
      b.respond = (r) =>
          r.uri.path.endsWith('/dm_sessions') ? ok(page([])) : null;
      final s = b.store();
      addTearDown(s.dispose);
      await s.ready;
      expect(s.sessions, isEmpty);
      expect(s.people.keys, containsAll(['c', 'player-char']));
      expect(s.conversations, isEmpty);
      expect(s.sessionFor('c'), isNull);
      expect(s.sessionFor('player-char'), isNull);
      s.unreadSessionsOnly = true;
      expect(s.conversations, isEmpty);
      s.unreadSessionsOnly = false;
      await s.refreshSessions();
      expect(s.conversations, isEmpty);
    },
  );
  test('Messages reorders cached sessions by latest delivery time', () async {
    const newerId = 9007199254740994;
    final b = PhoneBackend();
    b.respond = (r) => r.uri.path.endsWith('/dm_sessions')
        ? ok(
            page([
              {
                ...phoneSession(),
                'updated_at': '2026-10-12T12:00:00Z',
                'last_message': phoneMessage(newerId - 1),
              },
              {
                ...phoneSession(unread: 2),
                'dm_session_id': 10,
                'char_id': 'player-char',
                'char_name': 'Player',
                'last_message': {
                  ...phoneMessage(newerId, session: 10),
                  'sender_id': 'player-char',
                  'delivered_at': '2026-10-12T08:01:00Z',
                },
              },
            ]),
          )
        : null;
    final s = b.store();
    addTearDown(s.dispose);
    await s.ready;
    await s.refreshSessions();
    expect(s.conversations.map((c) => c.person.id), ['player-char', 'c']);
    expect(s.conversations.first.unreadCount, 2);
    final sessionRequests = b.calls('dm_sessions').length;
    s.phoneVisible = true;
    s.activeCharId = 'c';
    // Delivery time takes precedence even over a larger ID/world clock value.
    s.receive(
      phoneEvent('latest', [
        {
          ...phoneMessage(7),
          'delivered_at': '2026-10-12T08:02:00Z',
          'current_time': 'Day 1/01:00',
        },
      ]),
    );
    expect(s.conversations.map((c) => c.person.id), ['c', 'player-char']);
    expect(s.conversations.first.lastMessage!.content, 'Message 7');
    expect(b.calls('dm_sessions').length, sessionRequests);
    // An older batch, duplicate event and lagging HTTP snapshot cannot undo it.
    s.receive(phoneEvent('older', [phoneMessage(newerId + 3)]));
    s.receive(phoneEvent('latest', [phoneMessage(newerId + 2)]));
    await s.refreshSessions();
    expect(s.conversations.map((c) => c.person.id), ['c', 'player-char']);
    expect(s.conversations.first.lastMessage!.id, 7);
    s.unreadSessionsOnly = true;
    expect(s.conversations.map((c) => c.person.id), ['player-char']);
    expect(s.conversations.single.unreadCount, 2);
    await s.writesSaved;
  });
  test('Messages breaks delivery-time ties with full message IDs', () async {
    const largeId = 9007199254740994;
    final b = PhoneBackend();
    b.respond = (r) => r.uri.path.endsWith('/dm_sessions')
        ? ok(
            page([
              {...phoneSession(), 'last_message': phoneMessage(largeId)},
              {
                ...phoneSession(),
                'dm_session_id': 10,
                'char_id': 'player-char',
                'last_message': {
                  ...phoneMessage(largeId + 1, session: 10),
                  'sender_id': 'player-char',
                },
              },
            ]),
          )
        : null;
    final s = b.store();
    addTearDown(s.dispose);
    await s.ready;
    await s.refreshSessions();
    expect(s.conversations.map((c) => c.person.id), ['player-char', 'c']);
    s.receive(phoneEvent('tie', [phoneMessage(largeId + 2)]));
    expect(s.conversations.map((c) => c.person.id), ['c', 'player-char']);
    await s.writesSaved;
  });
  test(
    'chat history and first own delivery reorder existing virtual rows',
    () async {
      final b = PhoneBackend();
      b.respond = (r) {
        if (r.uri.path.endsWith('/dm_sessions')) {
          return ok(
            page([
              {...phoneSession(), 'dm_session_id': 0, 'char_id': 'empty-a'},
              {...phoneSession(), 'dm_session_id': 0, 'char_id': 'empty-b'},
              phoneSession(),
              {
                ...phoneSession(),
                'dm_session_id': 0,
                'char_id': 'player-char',
                'peer_uid': 'peer-user',
              },
            ]),
          );
        }
        if (r.uri.path.endsWith('/messages')) {
          return ok(page([phoneMessage(1)]));
        }
        return null;
      };
      final s = b.store();
      addTearDown(s.dispose);
      await s.ready;
      await s.refreshSessions();
      final sessionRequests = b.calls('dm_sessions').length;
      await s.refreshMessages('c');
      expect(s.conversations.map((c) => c.person.id), [
        'c',
        'empty-a',
        'empty-b',
        'player-char',
      ]);
      await s.write('dm', 'player-char', 'First message');
      final requestId = s.pending['dm:player-char']!.id;
      s.receive(
        phoneEvent(
          'own-delivery',
          [
            {
              ...phoneMessage(
                2,
                sender: 'user',
                session: 10,
                requestId: requestId,
              ),
              'delivered_at': '2026-10-12T08:01:00Z',
            },
          ],
          session: 10,
          requestId: requestId,
        ),
      );
      expect(s.conversations.map((c) => c.person.id), [
        'player-char',
        'c',
        'empty-a',
        'empty-b',
      ]);
      expect(s.conversations.first.lastMessage!.id, 2);
      expect(b.calls('dm_sessions').length, sessionRequests);
      await s.writesSaved;
    },
  );
  test(
    'new conversations appear only after the session API lists them',
    () async {
      final b = PhoneBackend();
      b.respond = (r) =>
          r.uri.path.endsWith('/dm_sessions') ? ok(page([])) : null;
      final s = b.store();
      addTearDown(s.dispose);
      await s.ready;
      s.receive(
        phoneEvent('first-player', [
          {...phoneMessage(7, session: 10), 'sender_id': 'player-char'},
        ], session: 10),
      );
      expect(s.conversations, isEmpty);
      expect(s.sessionFor('player-char'), 10);
      b.respond = (r) => r.uri.path.endsWith('/dm_sessions')
          ? {'err_no': 4004, 'err_msg': 'Sessions unavailable', 'data': {}}
          : null;
      expect(await s.refreshSessions(), isFalse);
      expect(s.errors['sessions'], 'Sessions unavailable');
      expect(s.conversations, isEmpty);
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
      expect(await s.refreshSessions(), isTrue);
      expect(s.conversations.map((c) => c.person.id), ['player-char']);
      expect(s.conversations.single.lastMessage!.id, 7);
      b.respond = (r) =>
          r.uri.path.endsWith('/dm_sessions') ? ok(page([])) : null;
      await s.refreshSessions();
      expect(s.conversations, isEmpty);
      await s.writesSaved;
      b.uid = null;
      b.revision.value++;
      await s.ready;
      expect(s.conversations, isEmpty);
    },
  );
  test(
    'authors include the world roster and supplement unknown endpoint IDs',
    () async {
      final b = PhoneBackend(), s = b.store();
      addTearDown(s.dispose);
      await s.ready;
      expect(s.authors.map((p) => p.id), ['c', 'player-char']);
      b.respond = (r) => r.uri.path.endsWith('/post/authors')
          ? ok({
              'list': ['player-char', 'unknown-char'],
            })
          : null;
      await s.refreshPosts();
      expect(s.authors.map((p) => p.id), ['c', 'player-char', 'unknown-char']);
      expect(s.authors.map((p) => p.name), [
        'Character',
        'Player',
        'unknown-char',
      ]);
      expect(s.posts.single.author.id, 'c'); // Feed does not add authors.
      await s.refreshPeople();
      expect(s.authors.map((p) => p.id), ['c', 'player-char', 'unknown-char']);
      b.respond = (r) =>
          r.uri.path.endsWith('/post/authors') ? ok({'list': []}) : null;
      await s.refreshPostAuthors();
      expect(s.authors.map((p) => p.id), ['c', 'player-char']);
    },
  );
  test(
    'switching authors resets pages and discards an old in-flight next page',
    () async {
      final b = PhoneBackend(), s = b.store(), gate = Completer<Object?>();
      addTearDown(s.dispose);
      await s.ready;
      b.respond = (r) {
        if (!r.uri.path.endsWith('/posts')) return null;
        final pn = int.parse(r.uri.queryParameters['pn']!);
        if (pn == 2) return gate.future;
        final player = r.uri.queryParameters['char_id'] == 'player-char';
        return ok(
          page([
            {
              ...phonePost(),
              'post_id': player ? 20 : 8,
              if (player) ...{'author_type': 1, 'author_id': 'u'},
            },
          ], total: player ? 1 : 20),
        );
      };
      await s.refreshPosts();
      final oldPage = s.refreshPosts(next: true);
      await flush();
      s.authorFilter = 'player-char';
      expect(s.posts, isEmpty);
      expect(s.hasMore['posts'], isNull);
      await s.refreshPosts();
      gate.complete(
        ok(
          page(
            [
              {...phonePost(), 'post_id': 9},
            ],
            pn: 2,
            total: 20,
          ),
        ),
      );
      expect(await oldPage, isFalse);
      expect(s.posts.map((p) => p.id), [20]);
      expect(s.pages['posts'], 1);
      expect(s.hasMore['posts'], isFalse);
      expect(b.calls('posts').last.uri.queryParameters, {
        'world_id': 'w',
        'char_id': 'player-char',
        'pn': '1',
        'rn': '10',
      });
      s.authorFilter = null;
      await s.refreshPosts();
      expect(
        b.calls('posts').last.uri.queryParameters.containsKey('char_id'),
        isFalse,
      );
      expect(s.posts.map((p) => p.id), [8]);
    },
  );
  test(
    'author errors retain server text and account changes discard pending author lists',
    () async {
      final b = PhoneBackend(), s = b.store(), gate = Completer<Object?>();
      addTearDown(s.dispose);
      await s.ready;
      b.respond = (r) => r.uri.path.endsWith('/post/authors')
          ? {'err_no': 4004, 'err_msg': 'Authors unavailable', 'data': {}}
          : null;
      expect(await s.refreshPosts(), isTrue);
      expect(s.errors['postAuthors'], 'Authors unavailable');
      expect(s.authors.map((p) => p.id), ['c', 'player-char']);
      b.respond = (r) =>
          r.uri.path.endsWith('/post/authors') ? gate.future : null;
      final old = s.refreshPostAuthors();
      await flush();
      s.authorFilter = 'c';
      b.uid = 'other';
      b.revision.value++;
      await s.ready;
      gate.complete(
        ok({
          'list': ['c'],
        }),
      );
      expect(await old, isFalse);
      expect(s.authors.map((p) => p.id), ['c', 'player-char']);
      expect(s.authorFilter, isNull);
    },
  );
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
  for (final lateResult in ['success', 'rejection', 'timeout']) {
    test('reply failure releases send before late HTTP $lateResult', () async {
      final backend = PhoneBackend();
      final firstResponse = Completer<Object?>();
      final secondResponse = Completer<Object?>();
      var sends = 0;
      backend.respond = (r) => r.uri.path.endsWith('/dm/send')
          ? (++sends == 1 ? firstResponse.future : secondResponse.future)
          : null;
      final store = backend.store();
      addTearDown(store.dispose);
      await store.ready;
      final first = store.write('dm', 'c', 'First');
      await flush();
      final firstRequest = store.waiting('c')!.id;
      expect(store.busy, contains('dm:c'));
      store.receive(
        phoneEvent(
          'failed',
          [],
          requestId: firstRequest,
          failure: 'Reply failed',
        ),
      );
      expect(store.waiting('c'), isNull);
      expect(store.busy, isNot(contains('dm:c')));
      expect(store.outgoingDm('c').single.content, 'First');
      expect(store.outgoingDm('c').single.accepted, isTrue);
      expect(sends, 1);

      final second = store.write('dm', 'c', 'Second');
      await flush();
      final secondRequest = store.waiting('c')!.id;
      expect(secondRequest, isNot(firstRequest));
      expect(sends, 2);
      store.receive(
        phoneEvent(
          'old-failure',
          [],
          requestId: firstRequest,
          failure: 'Old failure',
        ),
      );
      store.messagesController.applyReplyState(
        firstRequest,
        'generating',
        null,
        9,
      );
      if (lateResult == 'success') {
        firstResponse.complete(ok({}));
      } else if (lateResult == 'rejection') {
        firstResponse.complete({
          'err_no': 4004,
          'err_msg': 'Late rejection',
          'data': {},
        });
      } else {
        firstResponse.completeError(
          ApiException(message: 'Late timeout', kind: ApiExceptionKind.timeout),
        );
      }
      expect(
        await first,
        isTrue,
        reason: 'A server reply failure proves the original send was accepted.',
      );
      expect(store.waiting('c')!.id, secondRequest);
      expect(store.busy, contains('dm:c'));
      expect(store.errors['dm:c'], isNull);
      expect(store.replyFailureNotice('c'), isNull);
      expect(
        store.messagesController.replyStates[firstRequest]?.status,
        'failed',
      );
      secondResponse.complete(ok({}));
      expect(await second, isTrue);
      expect(store.busy, isNot(contains('dm:c')));
      store.receive(
        phoneEvent(
          'second-failed',
          [],
          requestId: secondRequest,
          failure: 'Reply failed',
        ),
      );
      expect(store.waiting('c'), isNull);
      expect(store.replyFailureNotice('c')?.requestId, secondRequest);
    });
  }

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
    'account switch clears album pages and confirmed viewport boundary',
    () async {
      final b = PhoneBackend(), s = b.store();
      addTearDown(s.dispose);
      await s.ready;
      b.respond = (r) {
        if (!r.uri.path.endsWith('/album')) return null;
        final pn = int.parse(r.uri.queryParameters['pn']!);
        return ok(
          page(
            [
              {
                'asset_id': pn,
                'world_id': 'w',
                'image_url': 'https://cdn.test/$pn',
              },
            ],
            pn: pn,
            rn: 100,
            total: 300,
          ),
        );
      };
      await s.refreshAlbum();
      await s.refreshAlbum(next: true);
      expect(s.album.map((p) => p.id), [1, 2]);
      b.uid = 'other';
      b.revision.value++;
      await s.ready;
      expect(s.album, isEmpty);
      expect(s.photosController.confirmedAlbum, isEmpty);
      await s.refreshAlbum();
      expect(s.album.map((p) => p.id), [1]);
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
      s.authorFilter = 'player-char';
      await s.refreshPosts();
      final authorCalls = b.calls('post/authors').length;
      b.respond = (r) => r.uri.path.endsWith('/post/authors')
          ? ok({
              'list': ['c', 'player-char'],
            })
          : null;
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
      expect(b.calls('post/authors').length, authorCalls);
      expect(s.postAuthorIds, ['c']);
      expect(s.authorFilter, 'player-char');
      expect(
        b.calls('posts').last.uri.queryParameters['char_id'],
        'player-char',
      );
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
    'delivery during Home refresh preserves the local inbox without refetching',
    () async {
      final b = PhoneBackend(), s = b.store();
      addTearDown(s.dispose);
      await s.ready;
      s.receive(phoneEvent('a', [phoneMessage(1)]));
      final gate = Completer<Object?>();
      var refreshes = 0;
      b.respond = (r) {
        if (!r.uri.path.endsWith('/home')) return null;
        refreshes++;
        return gate.future;
      };
      final refresh = s.refreshSummary();
      await flush();
      s.receive(phoneEvent('b', [phoneMessage(2)]));
      gate.complete(
        ok({
          'dms': {
            'unread_count': 1,
            'list': [phoneMessage(1)],
          },
          'posts': {'unread_count': 0, 'list': []},
        }),
      );
      await refresh;
      expect(refreshes, 1);
      expect(s.dmUnreadCount, 2);
      expect(s.unreadMessages.map((m) => m.id), [2, 1]);
      await s.cacheSaved;
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
    'pending first-send recovery discovers a real session without refreshing the app list',
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
      expect(b.calls('dm_sessions'), hasLength(2));
      expect(s.sessions, isEmpty);
      await s.refreshMessages('c');
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
      expect(s.clockTime, '');
      s.dispose();
    },
  );
}
