import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/debug/location_chat_bubble_layout_settings.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_reply_card_switcher.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_scroll_coordinator.dart';
import 'package:genesis_flutter_android/utils/llm_generation.dart';

void main() {
  for (final send in [false, true]) {
    testWidgets(
      '${send ? 'Send' : 'Go On'} keeps completed card replies and outgoing bubble visible after promotion',
      (tester) async {
        final coordinator = LocationChatScrollCoordinator();
        addTearDown(coordinator.dispose);
        final attempt = LlmAttempt(
          const LlmGenerationId('w', 'l', '1', 'r'),
          1,
        );
        final reply = ChatMessageVm(
          localId: 'reply',
          globalMessageId: 10,
          locationMessageId: 1,
          roundId: '1',
          llmAttempt: attempt,
          senderId: 'c',
          senderName: 'Character',
          senderType: 'character',
          text: 'Already completed reply. ' * 4,
          isMe: false,
          status: 'sent',
        );
        final outgoing = ChatMessageVm(
          localId: 'outgoing',
          clientMsgId: 'send-2',
          senderId: 'self',
          senderName: 'Me',
          text: 'New outgoing message',
          isMe: true,
          status: 'sending',
        );
        var sending = false;
        var promoted = false;
        ChatMessageVm? incoming;
        late BuildContext effectsContext;
        Widget view() => MaterialApp(
          home: Scaffold(
            body: ChatStreamingEffects(
              settings: LocationChatBubbleLayoutSettings.defaults,
              deferIncomingMessages: true,
              operationIdentity: sending ? 2 : 1,
              child: Builder(
                builder: (context) {
                  effectsContext = context;
                  return LocationChatAnchoredMessageList(
                    coordinator: coordinator,
                    topTitle: '',
                    showDateDividers: false,
                    messages: [
                      reply,
                      if (sending && send) outgoing,
                      if (incoming != null) incoming,
                    ],
                    replyActionsIdentity: promoted ? null : 'w/l/1',
                    replyCardBindingIdentity: promoted ? null : 'w/l/1',
                    replyCurrentCardId: 0,
                    replyCards: promoted
                        ? const []
                        : [
                            LocationChatReplyCard(id: 0, messages: [reply]),
                          ],
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpWidget(view());
        await tester.pumpAndSettle(const Duration(milliseconds: 20));
        sending = true;
        await tester.pumpWidget(view());
        if (send) expect(find.text(outgoing.text), findsOneWidget);
        promoted = true;
        outgoing.globalMessageId = 11;
        outgoing.status = 'sent';
        await tester.pumpWidget(view());
        await tester.pump();
        final tasks = ChatStreamingEffects.debugTasksOf(effectsContext);
        final oldReply =
            tasks.first as (Object, bool, bool?, bool?, bool?, double?, bool);
        expect(
          oldReply.$3,
          isFalse,
          reason:
              'A completed prior reply must not restart its reveal during Send.',
        );
        if (send) expect(find.text(outgoing.text), findsOneWidget);
        incoming = ChatMessageVm(
          localId: 'next-reply',
          globalMessageId: 12,
          roundId: '2',
          llmAttempt: LlmAttempt(const LlmGenerationId('w', 'l', '2', 'r2'), 1),
          senderId: 'c',
          senderName: 'Character',
          text: 'New reply must animate. ' * 10,
          isMe: false,
          status: 'sent',
        );
        await tester.pumpWidget(view());
        await tester.pump(const Duration(milliseconds: 30));
        final next =
            ChatStreamingEffects.debugTasksOf(effectsContext).last
                as (Object, bool, bool?, bool?, bool?, double?, bool);
        expect(next.$3, isTrue);
        expect(next.$6, lessThan(incoming.text.length));
        expect(
          (ChatStreamingEffects.debugTasksOf(effectsContext).first
                  as (Object, bool, bool?, bool?, bool?, double?, bool))
              .$3,
          isFalse,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'ACK keeps a visible outgoing row while an earlier reply is revealing',
    (tester) async {
      final coordinator = LocationChatScrollCoordinator();
      addTearDown(coordinator.dispose);
      final reply = ChatMessageVm(
        localId: 'reply',
        globalMessageId: 10,
        roundId: '1',
        senderId: 'c',
        senderName: 'Character',
        text: 'Long reply ',
        isMe: false,
        status: 'sent',
      );
      final outgoing = ChatMessageVm(
        localId: 'outgoing',
        clientMsgId: 'client-1',
        senderId: 'self',
        senderName: 'Me',
        text: 'Visible outgoing message',
        isMe: true,
        status: 'sending',
      );
      Widget view() => MaterialApp(
        home: Scaffold(
          body: ChatStreamingEffects(
            settings: LocationChatBubbleLayoutSettings.defaults,
            deferIncomingMessages: true,
            child: LocationChatAnchoredMessageList(
              coordinator: coordinator,
              topTitle: '',
              showDateDividers: false,
              messages: [reply, outgoing],
            ),
          ),
        ),
      );
      await tester.pumpWidget(view());
      // A resumed stream precedes an already mounted optimistic row.
      await tester.pump(const Duration(milliseconds: 120));
      reply.status = 'streaming';
      reply.text = 'Long reply ' * 40;
      await tester.pumpWidget(view());
      expect(find.text(outgoing.text), findsOneWidget);
      outgoing.globalMessageId = 11;
      outgoing.status = 'sent';
      await tester.pumpWidget(view());
      await tester.pump();
      expect(find.text(outgoing.text), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
