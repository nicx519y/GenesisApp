import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/network/mini_phone/mini_phone_cache.dart';
import 'package:genesis_flutter_android/network/mini_phone/mini_phone_models.dart';
import 'package:genesis_flutter_android/pages/mini_phone/mini_phone_page.dart';
import 'package:genesis_flutter_android/pages/mini_phone/mini_phone_live_chat.dart';
import '../../support/mini_phone_chat_backend.dart';
import '../../support/mini_phone_memory_cache.dart';

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'Home renders cached inbox and badge while HTTP is blocked, then live changes',
    (tester) async {
      final storage = MemoryMiniPhoneCacheStorage();
      final b = PhoneBackend(), gate = Completer<Object?>();
      final cache = MiniPhoneCache();
      cache.mergeSessions(
        [PhoneSession.fromJson(phoneSession())],
        next: false,
        requestedRevision: 0,
      );
      cache.rebaseHome(
        PhoneHome(
          dmUnread: 23,
          messages: [PhoneMessage.fromJson(phoneMessage(1))],
        ),
        'u',
        0,
      );
      await storage.save(
        const MiniPhoneCacheScope('test', 'u', 'w'),
        cache.toJson(),
      );
      b.respond = (r) => r.uri.path.endsWith('/home') ? gate.future : null;
      final s = (await tester.runAsync(() async {
        final s = b.store(cacheStorage: storage);
        await s.localReady;
        return s;
      }))!;
      final session = MiniPhoneSession(data: s);
      await tester.pumpWidget(
        MaterialApp(home: MiniPhonePage(session: session)),
      );
      await settle(tester);
      expect(find.text('Message 1'), findsWidgets);
      expect(find.text('23'), findsWidgets);
      await tester.runAsync(() async {
        s.receive(phoneEvent('new', [phoneMessage(2)]));
        await s.cacheSaved;
      });
      await settle(tester);
      expect(find.text('Message 2'), findsWidgets);
      expect(find.text('24'), findsWidgets);
      expect(b.calls('home'), hasLength(1));
      gate.complete(
        ok({
          'dms': {
            'unread_count': 23,
            'list': [phoneMessage(1)],
          },
          'posts': {'unread_count': 0, 'list': []},
        }),
      );
      // Stop the screen before its normal entry refresh; inspect the completed
      // in-flight response against the already-rendered live delivery.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() => s.ready);
      expect(s.dmUnreadCount, 24);
      await tester.runAsync(() => s.cacheSaved);
      session.dispose();
    },
  );

  testWidgets('cached chat is readable and clears its inbox while offline', (
    tester,
  ) async {
    final storage = MemoryMiniPhoneCacheStorage();
    final cache = MiniPhoneCache();
    cache.mergeSessions(
      [PhoneSession.fromJson(phoneSession())],
      next: false,
      requestedRevision: 0,
    );
    cache.delivered([PhoneMessage.fromJson(phoneMessage(1))], 'u');
    await storage.save(
      const MiniPhoneCacheScope('test', 'u', 'w'),
      cache.toJson(),
    );
    final b = PhoneBackend()
      ..respond = (_) => throw TimeoutException('Offline');
    final s = (await tester.runAsync(() async {
      final s = b.store(cacheStorage: storage);
      await s.ready;
      return s;
    }))!;
    final session = MiniPhoneSession(data: s);
    await tester.pumpWidget(
      MaterialApp(
        home: MiniPhonePage(
          session: session,
          initialScreen: MiniPhoneScreen.messages,
        ),
      ),
    );
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('mini-phone-conversation-c')));
    await tester.pump();
    await settle(tester);
    expect(find.byType(MiniPhoneLiveChat), findsOneWidget);
    expect(find.text('Message 1'), findsOneWidget);
    expect(s.dmUnreadCount, 0);
    expect(s.unreadMessages, isEmpty);
    await tester.runAsync(() => s.cacheSaved);
    expect(
      (await storage.load(
        const MiniPhoneCacheScope('test', 'u', 'w'),
      )).pendingReads,
      contains(9),
    );
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox.shrink());
    session.dispose();
  });
}
