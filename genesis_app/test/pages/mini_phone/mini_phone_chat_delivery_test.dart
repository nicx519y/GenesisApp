import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/network/mini_phone/mini_phone_models.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_scroll_coordinator.dart';
import 'package:genesis_flutter_android/pages/mini_phone/messages/mini_phone_live_chat.dart';
import 'package:genesis_flutter_android/pages/mini_phone/state/mini_phone_store.dart';
import '../../support/mini_phone_chat_backend.dart';

int _storeSequence = 0;

LocationChatAnchoredMessageList timeline(WidgetTester tester) =>
    tester.widget(find.byType(LocationChatAnchoredMessageList));
// Opening rows are display-only and persist above the delivery timeline.
List<ChatMessageVm> deliveryRows(WidgetTester tester) => timeline(tester)
    .messages
    .where(
      (m) =>
          !m.localId.startsWith('phone:empty-contact:') &&
          !m.localId.startsWith('phone:empty-introduction:'),
    )
    .toList();

ChatComposer composer(WidgetTester tester) =>
    tester.widget(find.byType(ChatComposer));

Future<void> flush(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pump();
}

Future<MiniPhoneStore> openChat(
  WidgetTester tester,
  PhoneBackend backend,
) async {
  final store = (await tester.runAsync(() async {
    final store = backend.store(namespace: 'delivery-test:${_storeSequence++}');
    await store.ready;
    return store;
  }))!;
  store.phoneVisible = true;
  await mountChat(tester, store);
  return store;
}

Future<void> mountChat(WidgetTester tester, MiniPhoneStore store) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(),
      home: MiniPhoneLiveChat(
        store: store,
        person: const PhonePerson('c', 'Character', ''),
        header: const SizedBox(height: 56),
      ),
    ),
  );
  await flush(tester);
}

Future<void> closeChat(WidgetTester tester, MiniPhoneStore store) async {
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpWidget(const SizedBox.shrink());
  await flush(tester);
  await flush(tester);
  await tester.runAsync(() => store.writesSaved);
  store.dispose();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'late balance rejection restores draft after the chat was closed',
    (tester) async {
      final backend = PhoneBackend();
      final response = Completer<Object?>();
      backend.respond = (r) =>
          r.uri.path.endsWith('/dm/send') ? response.future : null;
      final store = await openChat(tester, backend);
      await tester.enterText(find.byType(TextField), 'Keep this draft');
      final sending = composer(tester).onSend();
      await flush(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async {
        response.complete({
          'err_no': 21001,
          'err_msg': 'Balance unavailable',
          'data': {},
        });
        await sending;
      });
      expect(store.drafts['c'], 'Keep this draft');
      await mountChat(tester, store);
      expect(composer(tester).controller.text, 'Keep this draft');
      await closeChat(tester, store);
    },
  );

  testWidgets(
    'shown reply failure does not replay on reentry or history refresh; a new failure still shows',
    (tester) async {
      const failure = 'Reply generation failed.';
      final failedMessage = {
        ...phoneMessage(1, sender: 'user', requestId: 'failed-request'),
        'reply_status': 'failed',
        'failure': {'message': failure},
      };
      final backend = PhoneBackend();
      backend.respond = (r) =>
          r.uri.path.endsWith('/messages') ? ok(page([failedMessage])) : null;
      final store = await openChat(tester, backend);
      await tester.pump();
      expect(find.text(failure), findsOneWidget);
      expect(store.history('c').single.replyStatus, 'failed');
      expect(store.replyFailures['c'], failure);
      expect(store.replyFailureNotice('c'), isNull);
      expect(store.waiting('c'), isNull);

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox.shrink());
      await mountChat(tester, store);
      await tester.pump();
      expect(find.text(failure), findsNothing);
      await tester.runAsync(() async {
        store.receive(
          phoneEvent(
            'duplicate-failure',
            [],
            requestId: 'failed-request',
            failure: failure,
          ),
        );
        await store.writesSaved;
      });
      await tester.pump();
      await tester.pump();
      expect(find.text(failure), findsNothing);
      await tester.runAsync(() => store.refreshMessages('c'));
      await tester.pump();
      await tester.pump();
      expect(find.text(failure), findsNothing);
      expect(store.history('c').single.replyStatus, 'failed');
      await tester.enterText(find.byType(TextField), 'Next message');
      await tester.pump();
      expect(composer(tester).sendEnabled, isTrue);

      await tester.runAsync(composer(tester).onSend);
      final request = store.waiting('c')!.id;
      final nextFailure = {
        ...phoneMessage(2, sender: 'user', requestId: request),
        'reply_status': 'failed',
        'failure': {'message': failure},
      };
      backend.respond = (r) => r.uri.path.endsWith('/messages')
          ? ok(page([nextFailure, failedMessage]))
          : null;
      await tester.runAsync(() => store.refreshMessages('c'));
      await tester.pump();
      await tester.pump();
      expect(find.text(failure), findsOneWidget);
      expect(store.waiting('c'), isNull);
      expect(store.history('c').map((m) => m.replyStatus), [
        'failed',
        'failed',
      ]);
      await closeChat(tester, store);
    },
  );

  testWidgets('a reply failure while the phone is hidden remains unconsumed', (
    tester,
  ) async {
    const failure = 'Reply generation failed.';
    final store = await openChat(tester, PhoneBackend());
    store.phoneVisible = false;
    store.receive(
      phoneEvent('hidden-failure', [], requestId: 'hidden', failure: failure),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text(failure), findsNothing);
    store.phoneVisible = true;
    await tester.runAsync(() => store.refreshMessages('c'));
    await tester.pump();
    await tester.pump();
    expect(find.text(failure), findsOneWidget);
    await closeChat(tester, store);
  });

  testWidgets(
    'uncertain send retains one bubble and retries the original operation',
    (tester) async {
      final backend = PhoneBackend();
      final response = Completer<Object?>();
      backend.respond = (r) =>
          r.uri.path.endsWith('/dm/send') ? response.future : null;
      final store = await openChat(tester, backend);
      await tester.enterText(find.byType(TextField), 'Original');
      late Future<void> sending;
      await tester.runAsync(() async {
        sending = composer(tester).onSend();
        await Future<void>.delayed(const Duration(milliseconds: 30));
        response.completeError(TimeoutException('No response'));
        await sending;
      });
      await tester.pump();
      expect(deliveryRows(tester).single.text, 'Original');
      expect(store.waiting('c')!.uncertain, isTrue);
      expect(composer(tester).controller.text, 'Original');
      await tester.enterText(find.byType(TextField), 'Newer draft');
      backend.respond = null;
      await tester.runAsync(composer(tester).onSend);
      await tester.pump();
      expect(deliveryRows(tester).single.text, 'Original');
      expect(composer(tester).controller.text, 'Newer draft');
      final calls = backend.calls('dm/send');
      expect(calls, hasLength(2));
      expect(backend.body(calls.last), backend.body(calls.first));
      await closeChat(tester, store);
    },
  );

  testWidgets(
    'first virtual chat retains its user bubble when AI arrives before the source echo',
    (tester) async {
      final backend = PhoneBackend();
      final response = Completer<Object?>();
      backend.respond = (r) {
        if (r.uri.path.endsWith('/dm_sessions')) {
          return ok(
            page([
              {...phoneSession(), 'dm_session_id': 0},
            ]),
          );
        }
        if (r.uri.path.endsWith('/dm/send')) return response.future;
        return null;
      };
      final store = await openChat(tester, backend);
      expect(backend.calls('messages'), isEmpty);
      await tester.enterText(find.byType(TextField), 'First hello');
      late Future<void> sending;
      await tester.runAsync(() async {
        sending = composer(tester).onSend();
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await tester.pump();
      final localId = deliveryRows(tester).single.localId;
      final request = store.waiting('c')!.id;
      await tester.runAsync(() async {
        store.receive(
          phoneEvent('reply-first', [
            phoneMessage(2, requestId: request),
          ], requestId: request),
        );
        response.complete(ok({}));
        await sending;
      });
      await tester.pump();
      expect(store.waiting('c'), isNull);
      expect(deliveryRows(tester).map((m) => m.text), [
        'First hello',
        'Message 2',
      ]);
      await tester.runAsync(() async {
        store.receive(
          phoneEvent('source-later', [
            {
              ...phoneMessage(1, sender: 'user', requestId: request),
              'content': 'First hello',
            },
          ], requestId: request),
        );
        await store.writesSaved;
      });
      await tester.pump();
      expect(deliveryRows(tester).first.localId, localId);
      expect(deliveryRows(tester), hasLength(2));
      expect(store.outgoingDm('c'), isEmpty);
      await closeChat(tester, store);
    },
  );

  testWidgets(
    'send is visible before HTTP and delivery before HTTP never duplicates it',
    (tester) async {
      final backend = PhoneBackend();
      final response = Completer<Object?>();
      backend.respond = (r) =>
          r.uri.path.endsWith('/dm/send') ? response.future : null;
      final store = await openChat(tester, backend);
      await tester.enterText(find.byType(TextField), 'Hello now');
      late Future<void> sending;
      await tester.runAsync(() async {
        sending = composer(tester).onSend();
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await tester.pump();
      final localId = deliveryRows(tester).single.localId;
      expect(deliveryRows(tester).single.text, 'Hello now');
      expect(
        timeline(
          tester,
        ).messages.where((m) => m.localId.startsWith('phone:empty-')),
        hasLength(2),
      );
      expect(composer(tester).controller.text, isEmpty);
      expect(composer(tester).sending, isFalse);
      expect(composer(tester).sendEnabled, isFalse);
      expect(store.history('c'), isEmpty);
      final request = store.waiting('c')!.id;
      await tester.runAsync(() async {
        store.receive(
          phoneEvent('echo', [
            {
              ...phoneMessage(1, sender: 'user', requestId: request),
              'content': 'Hello now',
            },
          ], requestId: request),
        );
        await store.writesSaved;
      });
      await tester.pump();
      expect(deliveryRows(tester).single.localId, localId);
      expect(store.outgoingDm('c'), isEmpty);
      await tester.runAsync(() async {
        // An HTTP error arriving after committed delivery cannot undo the bubble.
        response.complete({
          'err_no': 4004,
          'err_msg': 'Late error',
          'data': {},
        });
        await sending;
      });
      await tester.pump();
      expect(deliveryRows(tester).single.text, 'Hello now');
      expect(composer(tester).controller.text, isEmpty);
      expect(find.text('Late error'), findsNothing);
      await closeChat(tester, store);
    },
  );

  testWidgets(
    'rejected send rolls back bubble and restores draft without replacing newer edits',
    (tester) async {
      final backend = PhoneBackend();
      var response = Completer<Object?>();
      backend.respond = (r) =>
          r.uri.path.endsWith('/dm/send') ? response.future : null;
      final store = await openChat(tester, backend);
      Future<void> start(String text) async {
        await tester.enterText(find.byType(TextField), text);
        unawaited(composer(tester).onSend());
        await flush(tester);
        expect(deliveryRows(tester).single.text, text);
      }

      Future<void> reject() async {
        await tester.runAsync(() async {
          response.complete({
            'err_no': 4004,
            'err_msg': 'Original rejection',
            'data': {},
          });
          await Future<void>.delayed(const Duration(milliseconds: 30));
        });
        await tester.pump();
        await tester.pump();
      }

      await start('Restore me');
      await reject();
      expect(deliveryRows(tester), isEmpty);
      expect(composer(tester).controller.text, 'Restore me');
      expect(find.text('Original rejection'), findsOneWidget);
      response = Completer<Object?>();
      await start('Second send');
      await tester.enterText(find.byType(TextField), 'Newer draft');
      await reject();
      expect(deliveryRows(tester), isEmpty);
      expect(composer(tester).controller.text, 'Newer draft');
      await closeChat(tester, store);
    },
  );

  testWidgets(
    'live replies reveal one per second; refresh and duplicates cannot bypass the queue',
    (tester) async {
      final backend = PhoneBackend();
      final store = await openChat(tester, backend);
      final batch = [phoneMessage(3), phoneMessage(1), phoneMessage(2)];
      store.receive(phoneEvent('batch', batch));
      store.receive(phoneEvent('batch-duplicate', batch));
      await tester.pump();
      expect(deliveryRows(tester).map((m) => m.text), ['Message 1']);
      expect(find.text('Character is typing…'), findsOneWidget);
      backend.respond = (r) =>
          r.uri.path.endsWith('/messages') ? ok(page(batch)) : null;
      await tester.runAsync(() => store.refreshMessages('c'));
      await tester.pump();
      expect(deliveryRows(tester), hasLength(1));
      await tester.pump(const Duration(milliseconds: 999));
      expect(deliveryRows(tester), hasLength(1));
      await tester.pump(const Duration(milliseconds: 1));
      expect(deliveryRows(tester).map((m) => m.text), [
        'Message 1',
        'Message 2',
      ]);
      await tester.pump(const Duration(seconds: 1));
      expect(deliveryRows(tester).map((m) => m.text), [
        'Message 1',
        'Message 2',
        'Message 3',
      ]);
      expect(find.textContaining('is typing'), findsNothing);
      await closeChat(tester, store);
    },
  );

  testWidgets(
    'initial history is immediate and background refresh has no history spinner or displacement',
    (tester) async {
      final backend = PhoneBackend();
      backend.respond = (r) => r.uri.path.endsWith('/messages')
          ? ok(page([phoneMessage(3), phoneMessage(2), phoneMessage(1)]))
          : null;
      final store = await openChat(tester, backend);
      await tester.pumpAndSettle();
      expect(deliveryRows(tester), hasLength(3));
      final before = tester.getTopLeft(find.text('Message 1'));
      final response = Completer<Object?>();
      backend.respond = (r) =>
          r.uri.path.endsWith('/messages') ? response.future : null;
      late Future<bool> refresh;
      await tester.runAsync(() async {
        refresh = store.refreshMessages('c');
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await tester.pump();
      expect(store.busy, contains('messages:9'));
      expect(timeline(tester).oldestEdgeLoading, isFalse);
      expect(tester.getTopLeft(find.text('Message 1')), before);
      await tester.runAsync(() async {
        response.complete(ok(page([])));
        await refresh;
      });
      await closeChat(tester, store);
    },
  );

  testWidgets('disposing a chat cancels pending reveals', (tester) async {
    final store = await openChat(tester, PhoneBackend());
    store.receive(phoneEvent('batch', [phoneMessage(1), phoneMessage(2)]));
    await tester.pump();
    expect(deliveryRows(tester), hasLength(1));
    await closeChat(tester, store);
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });
}
