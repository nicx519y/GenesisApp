import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/network/mini_phone/mini_phone_models.dart';
import 'package:genesis_flutter_android/pages/mini_phone/messages/mini_phone_live_chat.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_models.dart';
import 'package:genesis_flutter_android/network/models/world.dart';
import 'package:genesis_flutter_android/pages/mini_phone/state/mini_phone_store.dart';

import '../../support/mini_phone_chat_backend.dart';
import '../../support/mini_phone_memory_cache.dart';

Future<void> until(bool Function() condition) async {
  for (var i = 0; i < 100 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
  expect(condition(), isTrue);
}

ChatroomPhoneEvent generating(String request, String event) =>
    chatroomEventFromV2Message(
          ChatroomV2Message.fromJson({
            'type': 'phone.reply.updated',
            'stream_type': '',
            'world_id': 'w',
            'ts': 1,
            'trigger_uid': '',
            'err_no': 0,
            'err_msg': '',
            'payload': {
              'event_id': event,
              'dm_session_id': 9,
              'message_id': 1,
              'client_request_id': request,
              'job_status': 'generating',
              'failure': null,
            },
          }),
        )
        as ChatroomPhoneEvent;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'accepted DM warns at 15s, unlocks at 20s and keeps recovery identity',
    () async {
      var now = DateTime(2026);
      final events = <Map<String, Object?>>[];
      final backend = PhoneBackend();
      final store = MiniPhoneStore(
        api: backend.api,
        worldId: 'w',
        namespace: 'wait',
        readUid: () async => 'u',
        loadWorld: () async => WorldDetail.fromJson({}),
        accountRevision: backend.revision,
        cacheStorage: MemoryMiniPhoneCacheStorage(),
        networkAvailabilityCheck: () async => true,
        chatConnectionReady: () => true,
        sendWaitClock: () => now,
        sendWaitReporter: events.add,
      );
      addTearDown(store.dispose);
      await store.ready;
      expect(await store.write('dm', 'c', 'First'), isTrue);
      final first = store.waiting('c')!;
      now = now.add(const Duration(seconds: 14));
      store.dmSendGate.reconcile();
      expect(events, isEmpty);
      expect(store.waiting('c'), same(first));
      now = now.add(const Duration(seconds: 1));
      store.dmSendGate.reconcile();
      expect(events.single['action'], 'mini_phone_send_lock_timeout');
      expect(
        jsonDecode(events.single['ext_data']! as String)['reason'],
        'wait_stalled',
      );
      expect(first.sendReleased, isFalse);
      now = now.add(const Duration(seconds: 5));
      store.dmSendGate.reconcile();
      expect(store.waiting('c'), isNull);
      expect(first.accepted, isTrue);
      expect(first.sendReleased, isTrue);
      expect(store.pending.values, contains(first));
      expect(store.busy, isNot(contains('dm:c')));
      expect(backend.calls('dm/send'), hasLength(1));
      store.receive(generating(first.id, 'late-generating'));
      expect(store.waiting('c'), isNull);
      expect(await store.write('dm', 'c', 'Second'), isTrue);
      expect(store.pending.values, hasLength(2));
      expect(store.waiting('c')!.id, isNot(first.id));
      expect(backend.body(backend.calls('dm/send').last)['content'], 'Second');
      await store.writesSaved;
    },
  );

  test(
    'real generating progress refreshes once; duplicates do not extend deadline',
    () async {
      var now = DateTime(2026);
      final backend = PhoneBackend();
      final store = MiniPhoneStore(
        api: backend.api,
        worldId: 'w',
        namespace: 'progress',
        readUid: () async => 'u',
        loadWorld: () async => WorldDetail.fromJson({}),
        accountRevision: backend.revision,
        cacheStorage: MemoryMiniPhoneCacheStorage(),
        networkAvailabilityCheck: () async => true,
        chatConnectionReady: () => true,
        sendWaitClock: () => now,
        sendWaitReporter: (_) {},
      );
      addTearDown(store.dispose);
      await store.ready;
      await store.write('dm', 'c', 'First');
      final first = store.waiting('c')!;
      now = now.add(const Duration(seconds: 10));
      store.receive(generating(first.id, 'generating-1'));
      now = now.add(const Duration(seconds: 10));
      store.receive(generating(first.id, 'generating-2'));
      store.dmSendGate.reconcile();
      expect(store.waiting('c'), same(first));
      now = now.add(const Duration(seconds: 10));
      store.dmSendGate.reconcile();
      expect(store.waiting('c'), isNull);
      await store.writesSaved;
    },
  );

  for (final lateFailure in [false, true]) {
    test(
      'late HTTP and terminal cannot unlock newer send (failure=$lateFailure)',
      () async {
        var now = DateTime(2026);
        final backend = PhoneBackend();
        final http = <Completer<Object?>>[];
        backend.respond = (r) {
          if (!r.uri.path.endsWith('/dm/send')) return null;
          final response = Completer<Object?>();
          http.add(response);
          return response.future;
        };
        final store = MiniPhoneStore(
          api: backend.api,
          worldId: 'w',
          namespace: 'late-$lateFailure',
          readUid: () async => 'u',
          loadWorld: () async => WorldDetail.fromJson({}),
          accountRevision: backend.revision,
          cacheStorage: MemoryMiniPhoneCacheStorage(),
          networkAvailabilityCheck: () async => true,
          chatConnectionReady: () => true,
          sendWaitClock: () => now,
          sendWaitReporter: (_) {},
        );
        addTearDown(store.dispose);
        await store.ready;
        final sending = store.write('dm', 'c', 'First');
        await until(() => http.length == 1);
        final first = store.pending['dm:c']!;
        now = now.add(const Duration(seconds: 20));
        store.dmSendGate.reconcile();
        expect(
          await sending,
          isTrue,
        ); // Dispatch occurred, do not restore its draft.
        final next = store.write('dm', 'c', 'Second');
        await until(() => http.length == 2);
        final second = store.pending['dm:c']!;
        expect(second.id, isNot(first.id));
        http.first.complete(
          lateFailure
              ? {'err_no': 5001, 'err_msg': 'Rejected', 'data': {}}
              : ok({}),
        );
        await until(() => lateFailure ? first.rejected : first.accepted);
        expect(store.busy, contains('dm:c'));
        expect(store.waiting('c'), same(second));
        store.receive(
          phoneEvent(
            'old-terminal',
            [phoneMessage(11, requestId: first.id)],
            requestId: first.id,
            failure: lateFailure ? 'Failed' : null,
          ),
        );
        expect(store.pending.values, isNot(contains(first)));
        expect(store.busy, contains('dm:c'));
        expect(store.waiting('c'), same(second));
        expect(store.drafts['c'], isNull);
        http.last.complete(ok({}));
        expect(await next, isTrue);
        await store.writesSaved;
      },
    );
  }

  test(
    'released journal entries survive reopen and each remains recoverable',
    () async {
      var now = DateTime(2026);
      final backend = PhoneBackend();
      final storage = MemoryMiniPhoneCacheStorage();
      MiniPhoneStore create() => MiniPhoneStore(
        api: backend.api,
        worldId: 'w',
        namespace: 'restore',
        readUid: () async => 'u',
        loadWorld: () async => WorldDetail.fromJson({}),
        accountRevision: backend.revision,
        cacheStorage: storage,
        networkAvailabilityCheck: () async => true,
        chatConnectionReady: () => true,
        sendWaitClock: () => now,
        sendWaitReporter: (_) {},
      );
      final original = create();
      await original.ready;
      await original.write('dm', 'c', 'First');
      final first = original.waiting('c')!;
      now = now.add(const Duration(seconds: 20));
      original.dmSendGate.reconcile();
      await original.write('dm', 'c', 'Second');
      final second = original.waiting('c')!;
      await original.writesSaved;
      original.dispose();
      final restored = create();
      addTearDown(restored.dispose);
      await restored.ready;
      expect(
        restored.pending.values.map((w) => w.id),
        containsAll([first.id, second.id]),
      );
      expect(restored.waiting('c')!.id, second.id);
      expect(
        restored.pending.values
            .singleWhere((w) => w.id == first.id)
            .sendReleased,
        isTrue,
      );
      await until(
        () => backend
            .calls('messages')
            .any((r) => r.uri.queryParameters['client_request_id'] == first.id),
      );
      restored.receive(
        phoneEvent('recovered-old', [
          phoneMessage(12, requestId: first.id),
        ], requestId: first.id),
      );
      expect(restored.pending.values.any((w) => w.id == first.id), isFalse);
      expect(restored.waiting('c')!.id, second.id);
      await restored.writesSaved;
    },
  );

  test(
    'preflight timeout releases busy and late completion cannot dispatch',
    () async {
      var now = DateTime(2026);
      final backend = PhoneBackend();
      final network = Completer<bool>();
      var firstCheck = true;
      final store = MiniPhoneStore(
        api: backend.api,
        worldId: 'w',
        namespace: 'preflight',
        readUid: () async => 'u',
        loadWorld: () async => WorldDetail.fromJson({}),
        accountRevision: backend.revision,
        cacheStorage: MemoryMiniPhoneCacheStorage(),
        networkAvailabilityCheck: () {
          if (firstCheck) {
            firstCheck = false;
            return network.future;
          }
          return Future.value(true);
        },
        chatConnectionReady: () => true,
        sendWaitClock: () => now,
        sendWaitReporter: (_) {},
      );
      addTearDown(store.dispose);
      await store.ready;
      final first = store.write('dm', 'c', 'Unsent');
      await until(() => store.busy.contains('dm:c'));
      now = now.add(const Duration(seconds: 20));
      store.dmSendGate.reconcile();
      expect(await first, isFalse);
      expect(store.busy, isEmpty);
      expect(store.pending, isEmpty);
      expect(await store.write('dm', 'c', 'New'), isTrue);
      network.complete(true);
      await Future<void>.delayed(Duration.zero);
      expect(backend.calls('dm/send'), hasLength(1));
      expect(backend.body(backend.calls('dm/send').single)['content'], 'New');
      await store.writesSaved;
    },
  );

  test(
    'foreground reconciliation releases overdue accepted request without restarting',
    () async {
      var now = DateTime(2026);
      final backend = PhoneBackend();
      final store = MiniPhoneStore(
        api: backend.api,
        worldId: 'w',
        namespace: 'resume',
        readUid: () async => 'u',
        loadWorld: () async => WorldDetail.fromJson({}),
        accountRevision: backend.revision,
        cacheStorage: MemoryMiniPhoneCacheStorage(),
        networkAvailabilityCheck: () async => true,
        chatConnectionReady: () => true,
        sendWaitClock: () => now,
        sendWaitReporter: (_) {},
      );
      addTearDown(store.dispose);
      await store.ready;
      await store.write('dm', 'c', 'First');
      store.didChangeAppLifecycleState(AppLifecycleState.paused);
      now = now.add(const Duration(seconds: 21));
      store.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(store.waiting('c'), isNull);
      expect(backend.calls('dm/send'), hasLength(1));
      await store.writesSaved;
    },
  );
  testWidgets(
    'composer unlocks after accepted timeout and sends the new draft',
    (tester) async {
      var now = DateTime(2026);
      final backend = PhoneBackend();
      final store = (await tester.runAsync(() async {
        final value = MiniPhoneStore(
          api: backend.api,
          worldId: 'w',
          namespace: 'composer',
          readUid: () async => 'u',
          loadWorld: () async => WorldDetail.fromJson({}),
          accountRevision: backend.revision,
          cacheStorage: MemoryMiniPhoneCacheStorage(),
          networkAvailabilityCheck: () async => true,
          chatConnectionReady: () => true,
          sendWaitClock: () => now,
          sendWaitReporter: (_) {},
        );
        await value.ready;
        return value;
      }))!;
      store.phoneVisible = true;
      await tester.pumpWidget(
        MaterialApp(
          home: MiniPhoneLiveChat(
            store: store,
            person: const PhonePerson('c', 'Character', ''),
            header: const SizedBox(height: 56),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
      ChatComposer composer() => tester.widget(find.byType(ChatComposer));
      await tester.enterText(find.byType(TextField), 'Old accepted message');
      await tester.runAsync(composer().onSend);
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'New draft');
      expect(composer().sendEnabled, isFalse);
      expect(find.textContaining('typing'), findsOneWidget);
      expect(
        tester
            .widgetList<ChatSelfMessageBubble>(
              find.byType(ChatSelfMessageBubble),
            )
            .any((bubble) => bubble.message.status == 'sending'),
        isTrue,
      );
      now = now.add(const Duration(seconds: 20));
      await tester.runAsync(() async {
        store.dmSendGate.reconcile();
        await store.writesSaved;
      });
      await tester.pump();
      expect(composer().sendEnabled, isTrue);
      expect(find.textContaining('typing'), findsNothing);
      expect(
        tester
            .widgetList<ChatSelfMessageBubble>(
              find.byType(ChatSelfMessageBubble),
            )
            .any((bubble) => bubble.message.status == 'sending'),
        isFalse,
      );
      expect(find.text('Old accepted message'), findsOneWidget);
      expect(composer().controller.text, 'New draft');
      await tester.runAsync(composer().onSend);
      await tester.pump();
      expect(backend.calls('dm/send'), hasLength(2));
      expect(
        backend.body(backend.calls('dm/send').last)['content'],
        'New draft',
      );
      expect(composer().controller.text, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() => store.writesSaved);
      store.dispose();
      await tester.pump(const Duration(seconds: 1));
    },
  );
  testWidgets(
    'archived timed-out retry remains manually retryable after late rejection',
    (tester) async {
      final backend = PhoneBackend();
      final store = (await tester.runAsync(() async {
        final value = backend.store(namespace: 'archived-retry');
        await value.ready;
        return value;
      }))!;
      final rejected =
          PhoneWrite(
              'late-retry',
              'dm',
              'c',
              'Original text',
              retryRootId: 'original',
            )
            ..sendReleased = true
            ..rejected = true;
      store.pending[rejected.recoveryKey] = rejected;
      store.messagesController.outgoing[rejected.id] = rejected;
      store.messagesController.cache.retryRoots[rejected.id] = 'original';
      store.phoneVisible = true;
      await tester.pumpWidget(
        MaterialApp(
          home: MiniPhoneLiveChat(
            store: store,
            person: const PhonePerson('c', 'Character', ''),
            header: const SizedBox(height: 56),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
      final bubble = tester.widget<ChatSelfMessageBubble>(
        find.byType(ChatSelfMessageBubble),
      );
      expect(bubble.message.status, 'failed');
      await tester.tap(
        find.byKey(const ValueKey('chat-message-retry-phone:request:original')),
      );
      for (var i = 0; i < 5 && store.waiting('c')?.accepted != true; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump();
      }
      expect(backend.calls('dm/send'), hasLength(1));
      expect(
        backend.body(backend.calls('dm/send').single)['content'],
        'Original text',
      );
      expect(store.waiting('c')!.retryRootId, 'original');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() => store.writesSaved);
      store.dispose();
      await tester.pump(const Duration(seconds: 1));
    },
  );
}
