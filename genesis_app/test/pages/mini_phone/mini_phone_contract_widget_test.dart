import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/app/bootstrap/app_services_scope.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/network/genesis_api.dart';
import 'package:genesis_flutter_android/network/mini_phone/mini_phone_models.dart';
import 'package:genesis_flutter_android/pages/mini_phone/mini_phone_page.dart';
import 'package:genesis_flutter_android/pages/mini_phone/mini_phone_live_chat.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_scroll_coordinator.dart';
import '../../support/mini_phone_chat_backend.dart';
import '../../support/mini_phone_music_services.dart';

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'API virtual rows render separately and open an empty chat without errors',
    (tester) async {
      final b = PhoneBackend();
      b.respond = (r) => r.uri.path.endsWith('/dm_sessions')
          ? ok(
              page([
                for (var i = 1; i <= 6; i++)
                  {
                    ...phoneSession(),
                    'dm_session_id': 0,
                    'char_id': 'char_$i',
                    'char_name': 'Person $i',
                  },
              ]),
            )
          : null;
      final s = (await tester.runAsync(() async {
        final s = b.store();
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
      for (var i = 1; i <= 6; i++) {
        expect(
          find.byKey(ValueKey('mini-phone-conversation-char_$i')),
          findsOneWidget,
        );
      }
      await tester.tap(
        find.byKey(const ValueKey('mini-phone-conversation-char_2')),
      );
      await tester.pump();
      await settle(tester);
      expect(find.byType(MiniPhoneLiveChat), findsOneWidget);
      expect(find.byType(ChatComposer), findsOneWidget);
      expect(b.calls('messages'), isEmpty);
      expect(b.calls('dm_session/read'), isEmpty);
      expect(find.textContaining('Unable to load'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      session.dispose();
    },
  );

  testWidgets(
    'player user messages use peer identity and never show AI typing',
    (tester) async {
      final b = PhoneBackend();
      b.respond = (r) => r.uri.path.endsWith('/dm_sessions')
          ? ok(
              page([
                {...phoneSession(), 'peer_uid': 'peer'},
              ]),
            )
          : null;
      final s = (await tester.runAsync(() async {
        final s = b.store();
        await s.ready;
        return s;
      }))!;
      await tester.pumpWidget(
        MaterialApp(
          home: MiniPhoneLiveChat(
            store: s,
            person: const PhonePerson('c', 'Character', ''),
            header: const SizedBox(height: 56),
          ),
        ),
      );
      await settle(tester);
      await tester.runAsync(() => s.write('dm', 'c', 'Hello player'));
      await tester.runAsync(() async {
        s.receive(
          phoneEvent('peer', [
            {...phoneMessage(2, sender: 'user'), 'sender_id': 'peer'},
          ]),
        );
        await s.writesSaved;
      });
      await tester.pump();
      final rows = tester
          .widget<LocationChatAnchoredMessageList>(
            find.byType(LocationChatAnchoredMessageList),
          )
          .messages;
      expect(rows.single.isMe, isFalse);
      expect(rows.single.senderName, 'Character');
      expect(find.textContaining('is typing'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      s.dispose();
    },
  );

  testWidgets(
    'local post photo uploads once and uncertain submission preserves the full URL',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final directory = Directory.systemTemp.createTempSync('mini-post-photo-');
      final file = File('${directory.path}/photo.png')
        ..writeAsBytesSync(
          base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+cN1sAAAAASUVORK5CYII=',
          ),
        );
      const picker = MethodChannel('plugins.flutter.io/image_picker');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(picker, (_) async => file.path);
      addTearDown(() {
        messenger.setMockMethodCallHandler(picker, null);
        directory.deleteSync(recursive: true);
      });
      final b = PhoneBackend();
      const image =
          'https://cdn.example/photo.png?x-oss-process=image/format,webp';
      var fail = true;
      b.respond = (r) {
        if (r.uri.path.endsWith('/upload/image')) {
          return ok({
            'xl_url': image,
            'sm_url': 'https://cdn.example/small.png',
          });
        }
        if (r.uri.path.endsWith('/post/create') && fail) {
          throw TimeoutException('Unknown outcome');
        }
        return null;
      };
      final previousPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      final services = musicTestServices(
        GenesisApi(useMock: false, apiClient: b.api.client),
      );
      debugDefaultTargetPlatformOverride = previousPlatform;
      final s = (await tester.runAsync(() async {
        final s = b.store();
        await s.ready;
        return s;
      }))!;
      final session = MiniPhoneSession(data: s);
      await tester.pumpWidget(
        AppServicesScope(
          services: services,
          child: MaterialApp(
            home: MiniPhonePage(
              session: session,
              initialScreen: MiniPhoneScreen.create,
            ),
          ),
        ),
      );
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'Local image post');
      await tester.ensureVisible(find.text('Choose photo'));
      await tester.tap(find.text('Choose photo'));
      for (var i = 0; i < 100; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
        if (b.calls('upload/image').isNotEmpty &&
            find.text('Replace photo').evaluate().isNotEmpty) {
          break;
        }
      }
      await settle(tester);
      expect(b.calls('upload/image'), hasLength(1));
      expect(b.calls('album'), isEmpty);
      expect(find.text('Replace photo'), findsOneWidget);
      await tester.ensureVisible(find.text('Post'));
      await tester.tap(find.text('Post'));
      await settle(tester);
      final first = b.body(b.calls('post/create').single);
      expect(first['image'], image);
      await tester.pump(const Duration(seconds: 3));
      fail = false;
      await tester.tap(find.text('Post'));
      await settle(tester);
      expect(b.body(b.calls('post/create').last), first);
      expect(b.calls('upload/image'), hasLength(1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      session.dispose();
    },
  );
}
