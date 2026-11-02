import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/features/location_chat_reply/edit/edit.dart';
import 'package:genesis_flutter_android/features/location_chat_reply/go_on/go_on.dart';
import 'package:genesis_flutter_android/features/location_chat_reply/inspiration/inspiration.dart';
import 'package:genesis_flutter_android/features/location_chat_reply/regenerate/regenerate.dart';
import 'package:genesis_flutter_android/features/location_chat_reply/shared/reply_action_state.dart';
import 'package:genesis_flutter_android/features/location_chat_reply/shared/reply_feature_button.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_reply_actions.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_scroll_coordinator.dart';

void main() {
  testWidgets('camera cannot open a toolbar without a server reply identity', (
    tester,
  ) async {
    final coordinator = LocationChatScrollCoordinator();
    addTearDown(coordinator.dispose);
    var captured = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 350,
            height: 420,
            child: LocationChatAnchoredMessageList(
              coordinator: coordinator,
              topTitle: '',
              style: kLocationChatStyle,
              replyActionsVisible: false,
              messages: [
                ChatMessageVm(
                  localId: 'restored-scene',
                  senderId: 'char-1',
                  senderName: 'Character',
                  text: 'A restored scene.',
                  isMe: false,
                  status: 'sent',
                  senderType: 'char',
                ),
              ],
              onTakePhoto: () => captured++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final action = find.byKey(const ValueKey('location-chat-take-photo'));
    expect(action, findsNothing);
    expect(captured, 0);
    expect(
      find.byKey(const ValueKey('location-chat-regenerate')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('camera uses the latest reply toolbar callback without sending', (
    tester,
  ) async {
    var opens = 0;
    var regenerations = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: LocationChatReplyActions(
              style: kLocationChatStyle,
              regenerateFeature: LocationChatRegenerateFeature(
                state: LocationChatReplyActionState.idle,
                onInvoke: () => regenerations++,
              ),
              goOnFeature: LocationChatGoOnFeature(
                state: LocationChatReplyActionState.idle,
                onInvoke: () {},
              ),
              editFeature: LocationChatEditFeature(
                state: LocationChatReplyActionState.idle,
                onInvoke: () {},
              ),
              inspirationFeature: const LocationChatInspirationFeature(
                state: LocationChatReplyActionState.idle,
                messages: [],
              ),
              onTakePhoto: () => opens++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final action = find.byKey(const ValueKey('location-chat-take-photo'));
    expect(action, findsOneWidget);
    final regenerate = find.byKey(const ValueKey('location-chat-regenerate'));
    expect(tester.getCenter(action).dy, tester.getCenter(regenerate).dy);
    expect(tester.getRect(action).right, 304);
    expect(tester.getSize(action), const Size(32, 32));
    await tester.tapAt(tester.getTopLeft(action) + const Offset(2, 2));
    expect(opens, 1);
    expect(regenerations, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LocationChatReplyActions(style: kLocationChatStyle),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(action, findsNothing);
  });

  for (final state in LocationChatReplyActionState.values) {
    testWidgets('camera follows regenerate availability: ${state.name}', (
      tester,
    ) async {
      var captured = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LocationChatReplyActions(
              style: kLocationChatStyle,
              regenerateFeature: LocationChatRegenerateFeature(
                state: state,
                onInvoke: () {},
                onLimitReached: () {},
              ),
              onTakePhoto: () => captured++,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final camera = find.byKey(const ValueKey('location-chat-take-photo'));
      if (state == LocationChatReplyActionState.none) {
        expect(camera, findsNothing);
      } else {
        final button = tester.widget<LocationChatReplyFeatureButton>(camera);
        expect(
          button.state,
          state == LocationChatReplyActionState.busy
              ? LocationChatReplyActionState.disabled
              : state,
        );
        expect(
          find.descendant(
            of: camera,
            matching: find.byType(CircularProgressIndicator),
          ),
          findsNothing,
        );
        if (state == LocationChatReplyActionState.idle) {
          await tester.tap(camera);
          expect(captured, 1);
        } else {
          expect(button.onTap, isNull);
          expect(button.onDisabledTap, isNull);
          await tester.tap(camera);
          expect(captured, 0);
        }
      }
    });
  }

  for (final busyFeature in ['regenerate', 'goOn', 'edit', 'inspiration']) {
    testWidgets('camera is disabled while $busyFeature is busy and recovers', (
      tester,
    ) async {
      var captured = 0;
      Widget toolbar({required bool busy}) => MaterialApp(
        home: Scaffold(
          body: LocationChatReplyActions(
            style: kLocationChatStyle,
            regenerateFeature: LocationChatRegenerateFeature(
              state: busy && busyFeature == 'regenerate'
                  ? LocationChatReplyActionState.busy
                  : LocationChatReplyActionState.idle,
              onInvoke: () {},
            ),
            goOnFeature: LocationChatGoOnFeature(
              state: busy && busyFeature == 'goOn'
                  ? LocationChatReplyActionState.busy
                  : LocationChatReplyActionState.none,
              onInvoke: null,
            ),
            editFeature: LocationChatEditFeature(
              state: busy && busyFeature == 'edit'
                  ? LocationChatReplyActionState.busy
                  : LocationChatReplyActionState.none,
              onInvoke: null,
            ),
            inspirationFeature: LocationChatInspirationFeature(
              state: busy && busyFeature == 'inspiration'
                  ? LocationChatReplyActionState.busy
                  : LocationChatReplyActionState.none,
              messages: const [],
            ),
            onTakePhoto: () => captured++,
          ),
        ),
      );

      await tester.pumpWidget(toolbar(busy: true));
      await tester.pump(const Duration(milliseconds: 300));
      final camera = find.byKey(const ValueKey('location-chat-take-photo'));
      expect(
        tester.widget<LocationChatReplyFeatureButton>(camera).state,
        LocationChatReplyActionState.disabled,
      );
      expect(
        find.descendant(
          of: camera,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
      );
      await tester.tap(camera);
      expect(captured, 0);

      await tester.pumpWidget(toolbar(busy: false));
      await tester.pumpAndSettle();
      expect(
        tester.widget<LocationChatReplyFeatureButton>(camera).state,
        LocationChatReplyActionState.idle,
      );
      await tester.tap(camera);
      expect(captured, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
