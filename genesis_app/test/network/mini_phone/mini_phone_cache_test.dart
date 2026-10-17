import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:genesis_flutter_android/network/mini_phone/mini_phone_cache.dart';
import 'package:genesis_flutter_android/network/mini_phone/mini_phone_cache_storage.dart';
import 'package:genesis_flutter_android/network/mini_phone/mini_phone_models.dart';
import '../../support/mini_phone_chat_backend.dart';

PhoneMessage message(int id, {int session = 9, String sender = 'char'}) =>
    PhoneMessage.fromJson(phoneMessage(id, session: session, sender: sender));

void main() {
  test(
    'Home baseline preserves its unseen remainder and unique local changes',
    () {
      final cache = MiniPhoneCache();
      cache.rebaseHome(
        PhoneHome(dmUnread: 25, messages: [message(1), message(2)]),
        'u',
        0,
      );
      expect(cache.unknownUnread, 23);
      cache.delivered([
        message(2),
        message(3),
        message(4, sender: 'user'),
      ], 'u');
      cache.delivered([message(3)], 'u');
      expect(cache.unreadCount, 26);
      expect(cache.unreadMessages.map((m) => m.id), [3, 2, 1]);
      cache.markRead(9);
      expect(cache.unreadMessages, isEmpty);
      expect(cache.unreadCount, 23);
      cache.rebaseHome(const PhoneHome(), 'u', cache.revision);
      expect(cache.unreadCount, 0);
      expect(cache.messages, hasLength(4));
    },
  );

  test(
    'Home rebase retains concurrent delivery and suppresses concurrent reads',
    () {
      final cache = MiniPhoneCache();
      cache.rebaseHome(PhoneHome(dmUnread: 1, messages: [message(1)]), 'u', 0);
      final requestRevision = cache.revision;
      cache.markRead(9);
      cache.delivered([message(2, session: 10)], 'u');
      cache.rebaseHome(
        PhoneHome(dmUnread: 1, messages: [message(1)]),
        'u',
        requestRevision,
      );
      expect(cache.unreadMessages.map((m) => m.id), [2]);
      expect(cache.unreadCount, 1);
      cache.rebaseHome(
        PhoneHome(dmUnread: 2, messages: [message(1), message(2, session: 10)]),
        'u',
        requestRevision,
      );
      expect(cache.unreadCount, 1);
      expect(cache.messages, hasLength(2));
    },
  );

  test(
    'history and own messages never create unread; terminal state survives older HTTP',
    () {
      final cache = MiniPhoneCache();
      final source = PhoneMessage.fromJson({
        ...phoneMessage(1, sender: 'user'),
        'reply_status': 'completed',
      });
      cache.merge([source, message(2)]);
      expect(cache.unreadCount, 0);
      cache.delivered([message(2), message(3, sender: 'user')], 'u');
      cache.merge([
        PhoneMessage.fromJson({
          ...phoneMessage(1, sender: 'user'),
          'reply_status': 'pending',
        }),
      ]);
      expect(cache.unreadCount, 1);
      expect(cache.unreadMessages.single.id, 2);
      cache.delivered([message(2)], 'u');
      expect(cache.unreadCount, 1);
      expect(cache.messages[1]!.replyStatus, 'completed');
      cache.delivered([
        PhoneMessage.fromJson({
          ...phoneMessage(4, sender: 'user'),
          'sender_id': 'peer',
        }),
      ], 'u');
      expect(cache.unreadCount, 2);
    },
  );

  test('older read acknowledgements do not clear newer receipts or unread', () {
    final cache = MiniPhoneCache()..delivered([message(1)], 'u');
    final first = cache.markRead(9);
    cache.delivered([message(2)], 'u');
    final second = cache.markRead(9);
    cache.delivered([message(3)], 'u');
    cache.acknowledgeRead(9, first.revision);
    expect(cache.pendingReads[9]!.revision, second.revision);
    cache.acknowledgeRead(9, second.revision);
    expect(cache.pendingReads, isEmpty);
    expect(cache.unreadMessages.single.id, 3);
  });

  test(
    'HTTP session preview followed by WS adds inbox without doubling the session count',
    () {
      final cache = MiniPhoneCache();
      cache.mergeSessions(
        [
          PhoneSession.fromJson({
            ...phoneSession(unread: 1),
            'last_message': phoneMessage(1),
          }),
        ],
        next: false,
        requestedRevision: 0,
      );
      cache.delivered([message(1), message(1)], 'u');
      expect(cache.unreadMessages.single.id, 1);
      expect(cache.sessionCounts[9], 1);
      cache.delivered([message(2)], 'u');
      expect(cache.unreadCount, 2);
      expect(cache.sessionCounts[9], 2);
    },
  );

  test(
    'Home including a delivery after local read does not consume that delivery',
    () {
      final cache = MiniPhoneCache();
      cache.rebaseHome(PhoneHome(dmUnread: 1, messages: [message(1)]), 'u', 0);
      final revision = cache.revision;
      cache.markRead(9);
      cache.delivered([message(2)], 'u');
      cache.rebaseHome(
        PhoneHome(dmUnread: 2, messages: [message(1), message(2)]),
        'u',
        revision,
      );
      expect(cache.unreadMessages.single.id, 2);
      expect(cache.readThrough[9], 1);
      expect(cache.unreadCount, 1);
    },
  );

  test(
    'SQLite restores int64 messages, virtual sessions, inbox, receipts and scope isolation',
    () async {
      sqfliteFfiInit();
      final directory = await Directory.systemTemp.createTemp(
        'mini-phone-cache-',
      );
      final path = '${directory.path}/cache.db';
      var storage = SqliteMiniPhoneCacheStorage(
        factory: databaseFactoryFfi,
        path: path,
      );
      addTearDown(() async {
        await storage.close();
        await directory.delete(recursive: true);
      });
      const scope = MiniPhoneCacheScope('dev', 'u', 'w');
      const id = 9007199254740995;
      final cache = MiniPhoneCache();
      cache.mergeSessions(
        [
          PhoneSession.fromJson({
            ...phoneSession(),
            'dm_session_id': 0,
            'char_id': 'a',
          }),
          PhoneSession.fromJson({
            ...phoneSession(),
            'dm_session_id': 0,
            'char_id': 'b',
          }),
          PhoneSession.fromJson(phoneSession()),
        ],
        next: false,
        requestedRevision: 0,
      );
      cache.delivered([message(id)], 'u');
      cache.markRead(9);
      cache.delivered([message(id + 1)], 'u');
      cache.acceptEvent('persisted-event');
      await storage.save(scope, cache.toJson());
      await storage.close();
      storage = SqliteMiniPhoneCacheStorage(
        factory: databaseFactoryFfi,
        path: path,
      );
      final restored = await storage.load(scope);
      expect(restored.messages.keys, containsAll([id, id + 1]));
      expect(restored.unreadMessages.single.id, id + 1);
      expect(restored.pendingReads[9]!.throughId, id);
      expect(restored.acceptEvent('persisted-event'), isFalse);
      expect(restored.sessions.map((s) => s.person.id), ['a', 'b', 'c']);
      expect((await storage.loadBefore(scope, 9, id + 1, 50)).single.id, id);
      for (final other in [
        const MiniPhoneCacheScope('prod', 'u', 'w'),
        const MiniPhoneCacheScope('dev', 'other', 'w'),
        const MiniPhoneCacheScope('dev', 'u', 'other'),
      ]) {
        expect((await storage.load(other)).messages, isEmpty);
      }
    },
  );

  test(
    'SQLite rollback leaves the previous inbox and metadata together',
    () async {
      sqfliteFfiInit();
      final storage = SqliteMiniPhoneCacheStorage(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      addTearDown(storage.close);
      const scope = MiniPhoneCacheScope('dev', 'u', 'w');
      final cache = MiniPhoneCache()..delivered([message(1)], 'u');
      await storage.save(scope, cache.toJson());
      cache.markRead(9);
      final invalid = cache.toJson();
      invalid['sessions'] = [phoneSession(), phoneSession()];
      await expectLater(
        storage.save(scope, invalid),
        throwsA(isA<DatabaseException>()),
      );
      final restored = await storage.load(scope);
      expect(restored.unreadMessages.single.id, 1);
      expect(restored.pendingReads, isEmpty);
    },
  );

  test(
    'retention keeps 1000 ordinary rows plus unread, pending and latest',
    () async {
      sqfliteFfiInit();
      final storage = SqliteMiniPhoneCacheStorage(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      addTearDown(storage.close);
      const scope = MiniPhoneCacheScope('dev', 'u', 'w');
      final cache = MiniPhoneCache()
        ..merge([for (var i = 1; i <= 1200; i++) message(i)]);
      cache.rebaseHome(PhoneHome(dmUnread: 1, messages: [message(1)]), 'u', 0);
      cache.merge([
        PhoneMessage.fromJson({
          ...phoneMessage(2, sender: 'user'),
          'reply_status': 'pending',
        }),
      ]);
      cache.prune();
      expect(cache.messages, hasLength(1003));
      expect(cache.messages.keys, containsAll([1, 2, 1200]));
      expect(cache.messages.containsKey(3), isFalse);
      await storage.save(scope, cache.toJson());
      expect((await storage.load(scope)).messages, hasLength(1003));
      expect((await storage.load(scope)).unreadMessages.single.id, 1);
    },
  );
}
