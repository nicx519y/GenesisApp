import 'package:genesis_flutter_android/pages/chat/location_chat_reply_card_switcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/debug/location_chat_bubble_layout_settings.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_scroll_coordinator.dart';
import 'package:genesis_flutter_android/utils/llm_generation.dart';

void main() {
  for (final textAnimation in [false, true]) {
    for (final heightAnimation in [false, true]) {
      testWidgets(
        'candidate retry honors animation switches text=$textAnimation height=$heightAnimation and repeated attempts',
        (tester) async {
          final coordinator = LocationChatScrollCoordinator();
          addTearDown(coordinator.dispose);
          final generation = LlmGenerationState(
            const LlmGenerationId('w', 'l', '1', 'r', 102),
          );
          var attempt = generation.accept(1, 1, end: true)!;
          ChatMessageVm message(String text) => ChatMessageVm(
            localId: 'm',
            globalMessageId: 1,
            roundId: '1',
            llmAttempt: attempt,
            senderId: 'c',
            senderName: 'C',
            senderType: 'character',
            text: text,
            isMe: false,
            status: 'sent',
          );
          var messages = [message('Initial candidate')];
          Widget view() => MaterialApp(
            home: Scaffold(
              body: ChatStreamingEffects(
                settings: LocationChatBubbleLayoutSettings.defaults.copyWith(
                  streamingTextReveal: textAnimation,
                  animateStreamingHeight: heightAnimation,
                ),
                child: LocationChatAnchoredMessageList(
                  coordinator: coordinator,
                  topTitle: '',
                  showDateDividers: false,
                  messages: messages,
                  replyActionsIdentity: 'round1',
                  replyCurrentCardId: 102,
                  replyCardBindingIdentity: 'card',
                  replyCards: [
                    LocationChatReplyCard(id: 102, messages: messages),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpWidget(view());
          await tester.pumpAndSettle(const Duration(milliseconds: 20));
          for (var number = 2; number <= 3; number++) {
            final previous = attempt;
            generation.retract(number - 1, retrying: true, next: number);
            attempt = generation.accept(number, 1, end: true)!;
            messages = [message('Candidate $number')];
            await tester.pumpWidget(view());
            await tester.pumpAndSettle(const Duration(milliseconds: 20));
            expect(previous.presentationPending, isFalse);
            expect(find.text('Candidate $number'), findsOneWidget);
            expect(tester.takeException(), isNull);
          }
        },
      );
    }
  }

  testWidgets(
    'retry retracts bottom to top, then reveals buffered terminal output',
    (tester) async {
      final coordinator = LocationChatScrollCoordinator();
      addTearDown(coordinator.dispose);
      final generation = LlmGenerationState(
        const LlmGenerationId('w', 'l', '1', 'r'),
      );
      final first = generation.accept(1, 1, end: false)!;
      ChatMessageVm message(int id, String text, LlmAttempt attempt) =>
          ChatMessageVm(
            localId: 'm$id',
            globalMessageId: id,
            roundId: '1',
            llmAttempt: attempt,
            senderId: 'c',
            senderName: 'Character',
            senderType: 'character',
            text: text,
            isMe: false,
            status: 'sent',
          );
      final oldA = 'First bubble ' * 8;
      final oldB = 'Second bubble ' * 8;
      var messages = [message(1, oldA, first), message(2, oldB, first)];
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
                  messages: messages,
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpWidget(view());
      await tester.pumpAndSettle(const Duration(milliseconds: 20));
      expect(find.text(oldA), findsOneWidget);
      expect(find.text(oldB), findsOneWidget);
      generation.retract(1, retrying: true, next: 2);
      final second = generation.accept(2, 1, end: true)!;
      messages = [message(1, 'Replacement reply', second)];
      await tester.pumpWidget(view());
      expect(first.presentationPending, isTrue);
      expect(find.text('Replacement reply'), findsNothing);
      final tasks = ChatStreamingEffects.debugTasksOf(effectsContext);
      expect(tasks.length, 2);
      await tester.pump(const Duration(milliseconds: 20));
      final before = ChatStreamingEffects.debugRetractionsOf(effectsContext);
      expect(before.last.active, isTrue);
      final aReveal = before.first.revealed;
      final bReveal = before.last.revealed;
      final bHeight = before.last.height;
      await tester.pump(const Duration(milliseconds: 60));
      final shrinking = ChatStreamingEffects.debugRetractionsOf(effectsContext);
      expect(shrinking.first.revealed, aReveal);
      expect(bReveal - shrinking.last.revealed, closeTo(20, 1));
      expect(shrinking.last.height, bHeight);
      // Height may only collapse after the text has reached zero.
      for (
        var frame = 0;
        frame < 30 &&
            !ChatStreamingEffects.debugRetractionsOf(
              effectsContext,
            ).last.textDone;
        frame++
      ) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 80));
      final collapsing = ChatStreamingEffects.debugRetractionsOf(
        effectsContext,
      ).last;
      expect(collapsing.revealed, 0);
      expect(collapsing.height, greaterThan(0));
      expect(collapsing.height, lessThan(bHeight));
      expect(find.text(oldA), findsOneWidget);
      expect(find.text('Replacement reply'), findsNothing);
      await tester.pumpAndSettle(const Duration(milliseconds: 20));
      expect(first.presentationPending, isFalse);
      expect(find.text(oldA), findsNothing);
      expect(find.text(oldB), findsNothing);
      expect(find.text('Replacement reply'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unseen queued bubbles are removed without acquiring a presentation lease',
    (tester) async {
      final coordinator = LocationChatScrollCoordinator();
      addTearDown(coordinator.dispose);
      final generation = LlmGenerationState(
        const LlmGenerationId('w', 'l', '1', 'r'),
      );
      final attempt = generation.accept(1, 1, end: false)!;
      var messages = [
        for (var id = 1; id <= 3; id++)
          ChatMessageVm(
            localId: 'm$id',
            globalMessageId: id,
            llmAttempt: attempt,
            roundId: '1',
            senderId: 'c',
            senderName: 'C',
            senderType: 'character',
            text: 'Bubble $id ' * 20,
            isMe: false,
            status: 'streaming',
          ),
      ];
      Widget view() => MaterialApp(
        home: Scaffold(
          body: ChatStreamingEffects(
            settings: LocationChatBubbleLayoutSettings.defaults,
            child: LocationChatAnchoredMessageList(
              coordinator: coordinator,
              topTitle: '',
              showDateDividers: false,
              messages: messages,
            ),
          ),
        ),
      );
      await tester.pumpWidget(view());
      await tester.pump(const Duration(milliseconds: 80));
      generation.retract(1, retrying: true, next: 2);
      messages = [];
      await tester.pumpWidget(view());
      for (var frame = 0; frame < 100; frame++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(attempt.presentationPending, isFalse);
      expect(find.byType(ChatReplyWaitingBubble), findsOneWidget);
      expect(find.byType(ChatStreamingText), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
