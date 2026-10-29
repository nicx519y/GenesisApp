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
          const LlmGenerationId('w', 'l', '1', 'r', 42),
          1,
        );
        var reply = ChatMessageVm(
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
                    waitingPositionIdentity: sending ? 'next-operation' : null,
                    showDateDividers: false,
                    messages: [
                      reply,
                      if (sending && send) outgoing,
                      if (incoming != null) incoming,
                    ],
                    replyActionsIdentity: promoted ? null : 'w/l/1',
                    replyCardBindingIdentity: promoted ? null : 'w/l/1',
                    replyCurrentCardId: 42,
                    replyCardsConfirmed: sending,
                    replyCards: promoted
                        ? const []
                        : [
                            LocationChatReplyCard(id: 42, messages: [reply]),
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
        coordinator.prepareWaitingReplyPosition();
        await tester.pumpWidget(view());
        // The outgoing Send indicator intentionally animates until its ACK.
        for (var frame = 0; frame < 25; frame++) {
          await tester.pump(const Duration(milliseconds: 20));
        }
        Rect replyRect() => tester.getRect(
          find.byWidgetPredicate(
            (w) => w is ChatMessageRow && w.message.localId == reply.localId,
          ),
        );
        final beforeRect = replyRect();
        final beforePixels = coordinator.controller.position.pixels;
        if (send) expect(find.text(outgoing.text), findsOneWidget);
        reply = ChatMessageVm(
          localId: 'formal-reply',
          globalMessageId: 10,
          locationMessageId: 1,
          roundId: '1',
          llmAttempt: LlmAttempt(const LlmGenerationId('w', 'l', '1', 'r'), 1),
          senderId: 'c',
          senderName: 'Character',
          senderType: 'character',
          text: reply.text,
          isMe: false,
          status: 'sent',
        );
        await tester.pumpWidget(view());
        await tester.pump();
        final progress =
            ChatStreamingEffects.debugTasksOf(effectsContext).first
                as (Object, bool, bool?, bool?, bool?, double?, bool);
        expect(
          progress.$3,
          isFalse,
          reason: 'Confirmed deck must not replay on formal backfill',
        );
        expect(replyRect().top, closeTo(beforeRect.top, 1));
        expect(replyRect().height, closeTo(beforeRect.height, 1));
        expect(
          coordinator.controller.position.pixels,
          closeTo(beforePixels, 1),
        );
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
  for (final scenario in [
    'atomic',
    'partial',
    'attempt',
    'request',
    'unconfirmed',
    'other-card',
  ]) {
    testWidgets('candidate promotion boundary: $scenario', (tester) async {
      final coordinator = LocationChatScrollCoordinator();
      addTearDown(coordinator.dispose);
      var confirmed = false;
      var cardId = 42;
      ChatMessageVm message(LlmAttempt attempt) => ChatMessageVm(
        localId: 'reply',
        globalMessageId: 10,
        roundId: '1',
        llmAttempt: attempt,
        senderId: 'c',
        senderName: 'Character',
        senderType: 'character',
        text: 'Long candidate reply. ' * 20,
        isMe: false,
        status: 'sent',
      );
      var reply = message(
        LlmAttempt(const LlmGenerationId('w', 'l', '1', 'r', 42), 1),
      );
      late BuildContext effects;
      Widget view() => MaterialApp(
        home: Scaffold(
          body: ChatStreamingEffects(
            settings: LocationChatBubbleLayoutSettings.defaults,
            child: Builder(
              builder: (context) {
                effects = context;
                return LocationChatAnchoredMessageList(
                  coordinator: coordinator,
                  topTitle: '',
                  messages: [reply],
                  showDateDividers: false,
                  restoreInitialCompletedContent: false,
                  replyActionsIdentity: 'deck',
                  replyCardBindingIdentity: 'deck',
                  replyCurrentCardId: cardId,
                  replyCardsConfirmed: confirmed,
                  // Even the OLD widget resolves to the latest reply: exercise the
                  // rendered snapshot fallback for atomic confirmation + backfill.
                  replyCards: [
                    LocationChatReplyCard.lazy(
                      id: cardId,
                      resolveMessages: () => [reply],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
      double progress() =>
          (ChatStreamingEffects.debugTasksOf(effects).single
                  as (Object, bool, bool?, bool?, bool?, double?, bool))
              .$6!;
      await tester.pumpWidget(view());
      if (scenario == 'partial') {
        await tester.pump(const Duration(milliseconds: 80));
      } else {
        await tester.pumpAndSettle(const Duration(milliseconds: 20));
      }
      final before = progress();
      expect(before, greaterThan(0));
      confirmed = scenario != 'unconfirmed' && scenario != 'other-card';
      if (scenario == 'other-card') cardId = 43;
      reply = message(
        LlmAttempt(
          LlmGenerationId(
            'w',
            'l',
            '1',
            scenario == 'request' ? 'different-request' : 'r',
            scenario == 'other-card' ? 43 : null,
          ),
          scenario == 'attempt' ? 2 : 1,
        ),
      );
      await tester.pumpWidget(view());
      await tester.pump();
      if (scenario == 'atomic' || scenario == 'partial') {
        expect(progress(), closeTo(before, 1));
      } else {
        expect(
          progress(),
          lessThan(before),
          reason:
              'Unconfirmed or different generations must not inherit reveal progress',
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
