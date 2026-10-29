import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
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
            width: 350,
            child: LocationChatReplyActions(
              style: kLocationChatStyle,
              regenerateFeature: LocationChatRegenerateFeature(
                state: LocationChatReplyActionState.idle,
                onInvoke: () => regenerations++,
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
    expect(tester.getRect(action).right, 334);
    await tester.tap(action);
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
    testWidgets('camera follows regenerate state: ${state.name}', (
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
        expect(button.state, state);
        if (state == LocationChatReplyActionState.idle) {
          await tester.tap(camera);
          expect(captured, 1);
        } else {
          expect(button.onTap, isNull);
          expect(button.onDisabledTap, isNull);
          expect(captured, 0);
        }
      }
    });
  }
}
