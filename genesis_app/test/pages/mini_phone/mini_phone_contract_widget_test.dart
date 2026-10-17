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
import 'package:genesis_flutter_android/ui/components/genesis_primary_button.dart';
import 'package:genesis_flutter_android/components/common/genesis_upload_progress_overlay.dart';
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
      final peer = rows.singleWhere((row) => !row.isMe);
      expect(peer.senderName, 'Character');
      expect(rows.where((row) => row.isMe).single.text, 'Hello player');
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
      var pickerCalls = 0;
      messenger.setMockMethodCallHandler(picker, (_) async {
        pickerCalls++;
        return file.path;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(picker, null);
        directory.deleteSync(recursive: true);
      });
      final b = PhoneBackend();
      const image =
          'https://cdn.example/photo.png?x-oss-process=image/format,webp';
      var fail = true;
      final upload = Completer<Object?>();
      b.respond = (r) {
        if (r.uri.path.endsWith('/upload/image')) {
          return upload.future;
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
      final app = AppServicesScope(
        services: services,
        child: MaterialApp(
          home: MiniPhonePage(
            session: session,
            initialScreen: MiniPhoneScreen.create,
          ),
        ),
      );
      await tester.pumpWidget(app);
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'Local image post');
      await tester.ensureVisible(find.text('Choose photo'));
      await tester.tap(find.text('Choose photo'));
      for (var i = 0; i < 100; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
        if (find.text('Replace photo').evaluate().isNotEmpty) {
          break;
        }
      }
      await settle(tester);
      expect(b.calls('upload/image'), isEmpty);
      expect(find.byType(GenesisUploadProgressOverlay), findsNothing);
      expect(b.calls('album'), hasLength(1)); // Phone-entry warm-up only.
      expect(find.text('Replace photo'), findsOneWidget);
      await tester.ensureVisible(find.text('Post'));
      await tester.tap(find.text('Post'));
      await tester.pump();
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
      expect(b.calls('upload/image'), hasLength(1));
      expect(b.calls('post/create'), isEmpty);
      expect(
        tester
            .widget<GenesisPrimaryButton>(find.byType(GenesisPrimaryButton))
            .isLoading,
        isTrue,
      );
      expect(
        tester
            .widget<GenesisPrimaryButton>(find.byType(GenesisPrimaryButton))
            .showLoadingIndicator,
        isTrue,
      );
      expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
      await tester.ensureVisible(find.text('Replace photo'));
      await tester.tap(find.text('Replace photo'));
      await tester.tap(find.text('Remove photo'));
      final preview = find.byWidgetPredicate(
        (w) => w is Image && w.image is MemoryImage,
      );
      await tester.tap(preview);
      await tester.pump();
      expect(pickerCalls, 1);
      expect(find.text('Remove photo'), findsOneWidget);
      // Returning to Posts remains available during the upload.
      await tester.ensureVisible(find.text('Create post'));
      await tester.tap(find.text('Create post'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Posts'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('mini-phone-post-author-create')),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
      await tester.pumpWidget(
        AppServicesScope(services: services, child: const SizedBox.shrink()),
      );
      upload.complete(
        ok({'xl_url': image, 'sm_url': 'https://cdn.example/small.png'}),
      );
      await settle(tester);
      final first = b.body(b.calls('post/create').single);
      expect(first['image'], image);
      await tester.pumpWidget(app);
      await settle(tester);
      expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
      expect(find.text('Local image post'), findsOneWidget);
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
