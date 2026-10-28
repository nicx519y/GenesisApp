import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/debug/location_chat_bubble_layout_settings.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_http_models.dart';
import 'package:genesis_flutter_android/network/chatroom/world_chatroom_service.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_scroll_coordinator.dart';
import 'package:genesis_flutter_android/utils/llm_generation.dart';

void main() {
  testWidgets(
    'HTTP backfill keeps partial reveal and never replays completion',
    (tester) async {
      final coordinator = LocationChatScrollCoordinator();
      addTearDown(coordinator.dispose);
      final text = 'A reply that is still appearing. ' * 10;
      var attempt = LlmAttempt(const LlmGenerationId('w', 'l', '1', 'r'), 1);
      var streaming = true;
      late BuildContext effectsContext;
      Widget view() => MaterialApp(
        home: Scaffold(
          body: ChatStreamingEffects(
            settings: LocationChatBubbleLayoutSettings.defaults,
            child: Builder(
              builder: (context) {
                effectsContext = context;
                return LocationChatAnchoredMessageList(
                  coordinator: coordinator,
                  topTitle: '',
                  showDateDividers: false,
                  messages: [
                    ChatMessageVm(
                      localId: 'message',
                      globalMessageId: 10,
                      roundId: '1',
                      llmAttempt: attempt,
                      senderId: 'c',
                      senderName: 'Character',
                      senderType: 'character',
                      text: text,
                      isMe: false,
                      status: streaming ? 'streaming' : 'sent',
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
      (Object, bool, bool?, bool?, bool?, double?, bool) task() =>
          ChatStreamingEffects.debugTasksOf(effectsContext).single
              as (Object, bool, bool?, bool?, bool?, double?, bool);
      void backfill() {
        final message = WorldChatroomMessage.fromHttpMessage(
          ChatroomHttpMessage.fromV2Json({
            'type': 'character',
            'stream_type': '',
            'world_id': 'w',
            'location_id': 'l',
            'conversation_round_id': 1,
            'global_message_id': 10,
            'message_id': 2,
            'location_message_id': 2,
            'gateway_request_id': 'r',
            'attempt_no': 1,
            'payload': {'content': text},
          }),
        );
        attempt = message.llmAttempt!;
        streaming = message.streaming;
      }

      await tester.pumpWidget(view());
      await tester.pump(const Duration(milliseconds: 120));
      final before = task();
      expect(before.$6, greaterThan(0));
      expect(before.$6, lessThan(text.length));
      backfill();
      await tester.pumpWidget(view());
      expect(task().$1, before.$1);
      expect(task().$6, closeTo(before.$6!, 0.001));
      await tester.pumpAndSettle(const Duration(milliseconds: 20));
      final complete = task();
      expect(complete.$3, isFalse);
      backfill();
      await tester.pumpWidget(view());
      expect(task().$1, complete.$1);
      expect(task().$6, complete.$6);
      expect(task().$3, isFalse);
      expect(ChatStreamingEffects.debugRetractionsOf(effectsContext), isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
