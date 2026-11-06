import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/app/bootstrap/app_services_scope.dart';
import 'package:genesis_flutter_android/network/genesis_api.dart';
import 'package:genesis_flutter_android/network/mini_phone/mini_phone_models.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_scroll_coordinator.dart';
import 'package:genesis_flutter_android/pages/mini_phone/messages/mini_phone_live_chat.dart';

import '../../support/mini_phone_chat_backend.dart';
import '../../support/mini_phone_music_services.dart';
import 'mini_phone_chat_delivery_test.dart' as delivery;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  for (final senderType in ['char', 'user']) {
    testWidgets('$senderType peer can copy and report its real phone message', (
      tester,
    ) async {
      const messageId = 9007199254740993;
      final incoming = phoneMessage(messageId, sender: senderType)
        ..['sender_id'] = senderType == 'char' ? 'c' : 'peer-user';
      var rejectReport = senderType == 'user';
      final backend = PhoneBackend()
        ..respond = (request) {
          if (request.uri.path.endsWith('/messages')) {
            return ok(page([incoming, phoneMessage(1, sender: 'user')]));
          }
          if (request.uri.path.endsWith('/report/create')) {
            return rejectReport
                ? {'err_no': 4004, 'err_msg': 'Report rejected', 'data': {}}
                : ok({'report_id': 'report-phone'});
          }
          return null;
        };
      final previousPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      final services = musicTestServices(
        GenesisApi(useMock: false, apiClient: backend.api.client),
      );
      debugDefaultTargetPlatformOverride = previousPlatform;
      final store = (await tester.runAsync(() async {
        final value = backend.store(namespace: 'message-actions-$senderType');
        await value.ready;
        await value.refreshMessages('c');
        return value;
      }))!;
      store.phoneVisible = true;
      await tester.pumpWidget(
        AppServicesScope(
          services: services,
          child: MaterialApp(
            home: MiniPhoneLiveChat(
              store: store,
              person: const PhonePerson('c', 'Character', ''),
              header: const SizedBox(height: 56),
            ),
          ),
        ),
      );
      await delivery.flush(tester);
      await tester.pumpAndSettle();
      final rows = tester
          .widget<LocationChatAnchoredMessageList>(
            find.byType(LocationChatAnchoredMessageList),
          )
          .messages;
      final peer = rows.singleWhere((row) => row.messageId == messageId);
      expect(peer.senderType, senderType);
      expect(peer.globalMessageId, 0);

      await tester.longPress(find.text('Message 1'));
      await tester.pump();
      expect(find.text('Copy'), findsNothing);
      expect(find.text('Report'), findsNothing);

      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      await tester.longPress(find.text('Message $messageId'));
      await tester.pump();
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Report'), findsOneWidget);
      await tester.tap(find.text('Copy'));
      await tester.pump();
      expect(copied, 'Message $messageId');
      expect(find.text('Copied'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));

      await tester.longPress(find.text('Message $messageId'));
      await tester.pump();
      await tester.tap(find.text('Report'));
      await tester.pumpAndSettle();
      final reportInput = find.byKey(
        const ValueKey<String>('genesis-report-content-input'),
      );
      expect(reportInput, findsOneWidget);
      await tester.enterText(reportInput, 'Phone message reason');
      await tester.pump();
      await tester.tap(find.text('Submit'));
      await delivery.flush(tester);
      await tester.pumpAndSettle();
      if (rejectReport) {
        expect(find.text('Report rejected'), findsOneWidget);
        expect(reportInput, findsOneWidget);
        expect(
          tester.widget<TextField>(reportInput).controller!.text,
          'Phone message reason',
        );
        rejectReport = false;
        await tester.tap(find.text('Submit'));
        await delivery.flush(tester);
        await tester.pumpAndSettle();
      }
      expect(reportInput, findsNothing);
      expect(find.text('Report submitted'), findsOneWidget);
      expect(backend.body(backend.calls('report/create').last), {
        'target_type': 'message',
        'target_id': 'w_$messageId',
        'content': 'Phone message reason',
      });
      await delivery.closeChat(tester, store);
    });
  }

  testWidgets('local opening rows and disclaimer have no message menu', (
    tester,
  ) async {
    final store = await delivery.openChat(tester, PhoneBackend());
    await tester.pumpAndSettle();
    final list = tester.widget<LocationChatAnchoredMessageList>(
      find.byType(LocationChatAnchoredMessageList),
    );
    for (final row in list.messages) {
      await tester.longPress(find.text(row.text));
      await tester.pump();
      expect(find.text('Copy'), findsNothing);
      expect(find.text('Report'), findsNothing);
    }
    expect(list.oldestEdgeNotice, isNotNull);
    final disclaimer = find.text(list.oldestEdgeNotice!);
    expect(disclaimer, findsOneWidget);
    await tester.longPress(disclaimer);
    await tester.pump();
    expect(find.text('Copy'), findsNothing);
    expect(find.text('Report'), findsNothing);
    await delivery.closeChat(tester, store);
  });
}
