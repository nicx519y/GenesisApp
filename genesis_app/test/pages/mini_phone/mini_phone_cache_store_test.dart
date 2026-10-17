import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/network/mini_phone/mini_phone_cache.dart';
import 'package:genesis_flutter_android/network/mini_phone/mini_phone_models.dart';
import '../../support/mini_phone_chat_backend.dart';
import '../../support/mini_phone_memory_cache.dart';

const scope = MiniPhoneCacheScope('test', 'u', 'w');
Future<void> seed(MemoryMiniPhoneCacheStorage storage, {int length = 1}) async {
  final cache = MiniPhoneCache();
  cache.mergeSessions(
    [PhoneSession.fromJson(phoneSession())],
    next: false,
    requestedRevision: 0,
  );
  cache.rebaseHome(
    PhoneHome(
      dmUnread: 1,
      messages: [PhoneMessage.fromJson(phoneMessage(length))],
    ),
    'u',
    0,
  );
  cache.merge([
    for (var i = 1; i < length; i++) PhoneMessage.fromJson(phoneMessage(i)),
  ]);
  await storage.save(scope, cache.toJson());
}

Object home(List<Map<String, dynamic>> messages, {int? count}) => ok({
  'dms': {'unread_count': count ?? messages.length, 'list': messages},
  'posts': {'unread_count': 0, 'list': []},
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'local ready restores inbox and conversations before a blocked Home request',
    () async {
      final storage = MemoryMiniPhoneCacheStorage();
      await seed(storage);
      final gate = Completer<Object?>(), b = PhoneBackend();
      b.respond = (r) => r.uri.path.endsWith('/home') ? gate.future : null;
      final s = b.store(cacheStorage: storage);
      addTearDown(s.dispose);
      await s.localReady;
      expect(s.history('c').single.id, 1);
      expect(s.unreadMessages.single.id, 1);
      expect(s.conversations.single.lastMessage!.id, 1);
      expect(s.dmUnreadCount, 1);
      gate.complete(home([]));
      await s.ready;
      expect(s.dmUnreadCount, 0);
      expect(s.history('c').single.id, 1);
      await s.cacheSaved;
    },
  );

  test(
    'offline reading persists and retries after reopening without restoring unread',
    () async {
      final storage = MemoryMiniPhoneCacheStorage();
      await seed(storage);
      final b = PhoneBackend()
        ..respond = (_) => throw TimeoutException('Offline');
      final s = b.store(cacheStorage: storage);
      await s.ready;
      final reading = s.markSessionRead(9);
      expect(s.dmUnreadCount, 0);
      expect(s.unreadMessages, isEmpty);
      await reading;
      await s.cacheSaved;
      expect((await storage.load(scope)).pendingReads, contains(9));
      s.dispose();
      final b2 = PhoneBackend();
      final reopened = b2.store(cacheStorage: storage);
      addTearDown(reopened.dispose);
      await reopened.localReady;
      expect(reopened.dmUnreadCount, 0);
      await reopened.ready;
      await reopened.cacheSaved;
      expect(b2.calls('dm_session/read'), hasLength(1));
      expect((await storage.load(scope)).pendingReads, isEmpty);
      expect(reopened.history('c').single.id, 1);
    },
  );

  test('a delayed Home response cannot undo an offline local read', () async {
    final storage = MemoryMiniPhoneCacheStorage();
    await seed(storage);
    final gate = Completer<Object?>(), b = PhoneBackend();
    b.respond = (r) {
      if (r.uri.path.endsWith('/home')) return gate.future;
      if (r.uri.path.endsWith('/dm_session/read')) {
        throw TimeoutException('Offline');
      }
      return null;
    };
    final s = b.store(cacheStorage: storage);
    addTearDown(s.dispose);
    await s.localReady;
    await s.markSessionRead(9);
    gate.complete(home([phoneMessage(1)]));
    await s.ready;
    expect(s.dmUnreadCount, 0);
    await s.cacheSaved;
    expect((await storage.load(scope)).unreadMessages, isEmpty);
  });

  test(
    'read acknowledgement after leaving chat preserves a newly delivered unread',
    () async {
      final b = PhoneBackend(), gate = Completer<Object?>();
      final s = b.store();
      addTearDown(s.dispose);
      await s.ready;
      s.receive(phoneEvent('first', [phoneMessage(1)]));
      b.respond = (r) =>
          r.uri.path.endsWith('/dm_session/read') ? gate.future : null;
      final read = s.markSessionRead(9);
      await s.cacheSaved;
      s.activeCharId = null;
      s.receive(phoneEvent('after-leaving', [phoneMessage(2)]));
      gate.complete(ok({}));
      await read;
      expect(s.unreadMessages.single.id, 2);
      expect(s.dmUnreadCount, 1);
      await s.cacheSaved;
    },
  );

  test(
    'account switch rejects old Home responses and clears the old projection',
    () async {
      final storage = MemoryMiniPhoneCacheStorage();
      await seed(storage);
      final b = PhoneBackend(), oldHome = Completer<Object?>();
      var oldRequest = true;
      b.respond = (r) =>
          r.uri.path.endsWith('/home') && oldRequest ? oldHome.future : null;
      final s = b.store(cacheStorage: storage);
      addTearDown(s.dispose);
      await s.localReady;
      final oldReady = s.ready;
      // Let initialization dispatch the old account's HTTP request.
      await Future<void>.delayed(Duration.zero);
      oldRequest = false;
      b.uid = 'other';
      b.revision.value++;
      await s.ready;
      oldHome.complete(home([phoneMessage(7)]));
      await oldReady;
      expect(s.uid, 'other');
      expect(s.unreadMessages, isEmpty);
      expect(s.history('c'), isEmpty);
      expect((await storage.load(scope)).messages.keys, contains(1));
      await s.cacheSaved;
    },
  );

  test(
    'failed persistence is visible and does not submit an undurable receipt',
    () async {
      final storage = MemoryMiniPhoneCacheStorage();
      final b = PhoneBackend(), s = b.store(cacheStorage: storage);
      addTearDown(s.dispose);
      await s.ready;
      await s.cacheSaved;
      storage.failWrites = true;
      s.receive(phoneEvent('unsaved', [phoneMessage(1)]));
      await s.cacheSaved;
      expect(s.dmUnreadCount, 1);
      expect(s.errors['cache'], contains('save'));
      await s.markSessionRead(9);
      expect(b.calls('dm_session/read'), isEmpty);
      expect((await storage.load(scope)).messages, isEmpty);
      storage.failWrites = false;
      s.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await s.cacheSaved;
      expect(b.calls('dm_session/read'), hasLength(1));
      expect(s.errors.containsKey('cache'), isFalse);
    },
  );

  test(
    'older cached history loads before HTTPS, then skips overlapping network pages',
    () async {
      final storage = MemoryMiniPhoneCacheStorage();
      await seed(storage, length: 120);
      final b = PhoneBackend();
      b.respond = (r) {
        if (r.uri.path.endsWith('/home')) throw TimeoutException('Offline');
        if (r.uri.path.endsWith('/messages')) return ok(page([]));
        return null;
      };
      final s = b.store(cacheStorage: storage);
      addTearDown(s.dispose);
      await s.ready;
      expect(s.history('c'), hasLength(50));
      await s.refreshMessages('c', next: true);
      expect(s.history('c'), hasLength(100));
      expect(b.calls('messages'), isEmpty);
      await s.refreshMessages('c', next: true);
      expect(s.history('c'), hasLength(120));
      expect(b.calls('messages'), isEmpty);
      await s.refreshMessages('c', next: true);
      expect(b.calls('messages'), hasLength(1));
      expect(s.hasMore['messages:9'], isFalse);
      await s.cacheSaved;
    },
  );
}
