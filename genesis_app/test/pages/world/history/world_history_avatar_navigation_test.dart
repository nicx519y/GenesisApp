import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';
import 'package:genesis_flutter_android/network/mini_phone/mini_phone_models.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_scroll_coordinator.dart';
import 'package:genesis_flutter_android/pages/mini_phone/mini_phone.dart';
import 'package:genesis_flutter_android/pages/mini_phone/messages/mini_phone_live_chat.dart';
import 'package:genesis_flutter_android/platform/channels/genesis_method_channels.dart';

import '../../../support/mini_phone_chat_backend.dart';
import 'history_fixtures.dart';
import 'world_history_widget_test.dart' show Backend, Harness, frames;

class _AvatarBackend extends Backend {
  @override
  Future<TransportResponse> send(TransportRequest request) async {
    if (request.uri.path.endsWith('/music/list')) {
      return TransportResponse(
        statusCode: 200,
        headers: const {},
        body: jsonEncode(ok({'pre_url': 'https://music.invalid/', 'list': []})),
      );
    }
    return super.send(request);
  }
}

void main() {
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          GenesisMethodChannels.device,
          (call) async => call.method == GenesisMethodChannels.getAppVersion
              ? {'versionName': '9.9.9', 'versionCode': 999}
              : null,
        );
  });

  for (final cachedSession in [false, true]) {
    testWidgets(
      'history avatar opens shared phone chat and returns to archive (cached: $cachedSession)',
      (tester) async {
        final h = Harness(_AvatarBackend());
        final world = historyWorld().copyWith(
          characters: [
            {
              'char_id': 'c1',
              'name': 'World character',
              if (cachedSession) 'player_uid': 'another-player',
            },
          ],
        );
        final backend = PhoneBackend()
          ..respond = (request) => request.uri.path.endsWith('/dm_sessions')
              ? ok(
                  page(
                    cachedSession
                        ? [
                            {...phoneSession(), 'char_id': 'c1'},
                          ]
                        : [],
                  ),
                )
              : null;
        final data = backend.store();
        final session = MiniPhoneSession(worldId: 'w', data: data);
        session.resume.screen = MiniPhoneScreen.chat;
        session.resume.liveContact = const PhonePerson('old', 'Old chat', '');
        await tester.runAsync(() async {
          await data.ready;
          if (cachedSession) await data.refreshSessions();
        });
        await tester.pumpWidget(
          MiniPhoneSessionScope(
            session: session,
            worldDetailReady: true,
            child: h.build(world),
          ),
        );
        await frames(tester);
        final list = tester.widget<LocationChatAnchoredMessageList>(
          find.byType(LocationChatAnchoredMessageList),
        );
        final readingId = h.cache.readingId;
        final offset = h.scroll.offset;
        final avatar = find.descendant(
          of: find.byType(ChatOtherMessageBubble),
          matching: find.byType(ChatAvatar),
        );
        await tester.tap(avatar);
        list.onAvatarTap!(list.messages.single);
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pumpAndSettle();
        // The history harness has no signed-in model account; let its unrelated
        // model toast finish before disposing the overlay.
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        expect(find.byType(MiniPhonePage), findsOneWidget);
        final phone = tester.widget<MiniPhonePage>(find.byType(MiniPhonePage));
        expect(phone.session, same(session));
        expect(phone.entrySource, 'world_history_avatar');
        final chat = tester.widget<MiniPhoneLiveChat>(
          find.byType(MiniPhoneLiveChat),
        );
        expect(chat.store, same(data));
        expect(chat.person.id, 'c1');
        expect(chat.person.name, 'World character');
        expect(data.sessions.every((row) => row.person.id != 'old'), isTrue);
        if (cachedSession) {
          expect(
            backend
                .calls('messages')
                .single
                .uri
                .queryParameters['dm_session_id'],
            '9',
          );
        } else {
          expect(backend.calls('messages'), isEmpty);
          expect(data.sessions, isEmpty);
        }
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(MiniPhonePage), findsNothing);
        expect(find.byType(LocationChatAnchoredMessageList), findsOneWidget);
        expect(h.cache.readingId, readingId);
        expect(h.scroll.offset, offset);
        expect(
          tester
              .widget<LocationChatAnchoredMessageList>(
                find.byType(LocationChatAnchoredMessageList),
              )
              .coordinator,
          same(list.coordinator),
        );
        expect(session.isDisposed, isFalse);
        expect(
          h.backend.requests.where(
            (request) => request.uri.path.endsWith('/world/history'),
          ),
          hasLength(1),
        );
        expect(tester.takeException(), isNull);
        await h.close(tester);
        session.dispose();
        debugDefaultTargetPlatformOverride = null;
      },
    );
  }

  testWidgets(
    'history ignores own role, unknown sender and inactive avatar taps',
    (tester) async {
      final backend = Backend()
        ..rows = [
          historyJson('mine'),
          {...historyJson('unknown'), 'sender_id': 'unknown'},
          {...historyJson('other'), 'sender_id': 'c2'},
        ];
      final h = Harness(backend);
      final world = historyWorld().copyWith(
        characters: [
          {'char_id': 'c1', 'name': 'My role', 'player_uid': 'me'},
          {'char_id': 'c2', 'name': 'Other role'},
        ],
      );
      await tester.pumpWidget(h.build(world));
      await frames(tester);
      final list = tester.widget<LocationChatAnchoredMessageList>(
        find.byType(LocationChatAnchoredMessageList),
      );
      final mine = list.messages.firstWhere(
        (message) => message.senderId == 'c1',
      );
      expect(
        mine.isMe,
        isFalse,
        reason: 'Character history still excludes the owned role.',
      );
      for (final id in ['c1', 'unknown']) {
        final avatar = find.descendant(
          of: find.byWidgetPredicate(
            (widget) =>
                widget is ChatOtherMessageBubble &&
                widget.message.senderId == id,
          ),
          matching: find.byType(ChatAvatar),
        );
        await tester.tap(avatar);
        await tester.pumpAndSettle();
        expect(find.byType(MiniPhonePage), findsNothing);
      }
      final other = list.messages.firstWhere(
        (message) => message.senderId == 'c2',
      );
      await tester.pumpWidget(h.build(world, active: false));
      await tester.pump();
      list.onAvatarTap!(other);
      await tester.pumpAndSettle();
      expect(find.byType(MiniPhonePage), findsNothing);
      expect(tester.takeException(), isNull);
      await h.close(tester);
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
