import 'package:genesis_flutter_android/pages/chat/location_chat_reply_card_switcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/debug/location_chat_bubble_layout_settings.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_scroll_coordinator.dart';
import 'package:genesis_flutter_android/utils/llm_generation.dart';

void main() {
  for (final manual in [false, true]) {
    testWidgets(
      'Regenerate hides entry waiting during and after retraction manual=$manual',
      (tester) async {
        final coordinator = LocationChatScrollCoordinator();
        addTearDown(coordinator.dispose);
        final generation = LlmGenerationState(
          const LlmGenerationId('w', 'l', '1', 'regenerate', 102),
        );
        final attempt = generation.accept(1, 1, end: true)!;
        final entry = ChatMessageVm(
          localId: 'entry',
          senderId: 'user',
          senderName: 'User',
          text: 'Entered location',
          isMe: false,
          status: 'sent',
        );
        final reply = ChatMessageVm(
          localId: 'reply',
          globalMessageId: 1,
          roundId: '1',
          llmAttempt: attempt,
          senderId: 'c',
          senderName: 'Character',
          senderType: 'character',
          text: 'Visible candidate reply ' * 15,
          isMe: false,
          status: 'sent',
        );
        var retracting = false;
        var generating = false;
        var nextOperation = false;
        var replacement = <ChatMessageVm>[];
        Widget view() => MaterialApp(
          home: Scaffold(
            body: ChatStreamingEffects(
              settings: LocationChatBubbleLayoutSettings.defaults,
              child: LocationChatAnchoredMessageList(
                coordinator: coordinator,
                topTitle: '',
                showDateDividers: false,
                replyWaitingPositioningEnabled: false,
                waitingPositionIdentity: nextOperation
                    ? 'next-go-on'
                    : 'regenerate',
                messages: [entry, if (!retracting) reply, ...replacement],
                replyActionsIdentity: 'round1',
                replyCardBindingIdentity: 'round1',
                replyCurrentCardId: manual && retracting ? 103 : 102,
                replyRegenerationInProgress: generating,
                replyRegenerationDispatchRevision: manual && retracting ? 1 : 0,
                replyCards: [
                  LocationChatReplyCard(
                    id: manual && retracting ? 103 : 102,
                    messages: retracting ? replacement : [reply],
                  ),
                ],
                enterWaitingAfterMessageLocalId: retracting && !nextOperation
                    ? entry.localId
                    : null,
                enterWaitingIdentity: retracting && !nextOperation
                    ? 'enter-round1'
                    : null,
                goOnAwaitingContentIdentity: nextOperation
                    ? 'next-go-on'
                    : null,
              ),
            ),
          ),
        );
        await tester.pumpWidget(view());
        await tester.pumpAndSettle(const Duration(milliseconds: 20));
        if (!manual) generation.retract(1, retrying: true, next: 2);
        retracting = true;
        generating = true;
        await tester.pumpWidget(view());
        expect(find.byType(ChatReplyWaitingBubble), findsNothing);
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text(reply.text), findsOneWidget);
        expect(find.byType(ChatReplyWaitingBubble), findsNothing);
        for (var frame = 0; frame < 100; frame++) {
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(find.byType(ChatReplyWaitingBubble), findsNothing);
        expect(attempt.presentationPending, isFalse);
        replacement = [
          ChatMessageVm(
            localId: 'replacement',
            globalMessageId: 2,
            roundId: '1',
            llmAttempt: manual
                ? LlmAttempt(
                    const LlmGenerationId('w', 'l', '1', 'new', 103),
                    1,
                  )
                : generation.accept(2, 2, end: true),
            senderId: 'c',
            senderName: 'Character',
            senderType: 'character',
            text: 'Replacement candidate reply ' * 15,
            isMe: false,
            status: 'sent',
          ),
        ];
        await tester.pumpWidget(view());
        for (var frame = 0; frame < 100; frame++) {
          await tester.pump(const Duration(milliseconds: 20));
          expect(find.byType(ChatReplyWaitingBubble), findsNothing);
        }
        expect(find.text(replacement.single.text), findsOneWidget);
        generating = false;
        await tester.pumpWidget(view());
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(ChatReplyWaitingBubble), findsNothing);
        nextOperation = true;
        await tester.pumpWidget(view());
        expect(find.byType(ChatReplyWaitingBubble), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final replacesOriginalDeck in [false, true]) {
    testWidgets(
      'Go On retraction stays below the source card 0 replacesDeck=$replacesOriginalDeck',
      (tester) async {
        final coordinator = LocationChatScrollCoordinator();
        addTearDown(coordinator.dispose);
        final generation = LlmGenerationState(
          const LlmGenerationId('w', 'l', '2', 'go-on'),
        );
        final attempt = generation.accept(1, 1, end: true)!;
        ChatMessageVm message(int id, String text, LlmAttempt? attempt) =>
            ChatMessageVm(
              localId: 'm$id',
              globalMessageId: id,
              roundId: attempt == null ? '1' : '2',
              llmAttempt: attempt,
              senderId: 'c',
              senderName: 'Character',
              senderType: 'character',
              text: text,
              isMe: false,
              status: 'sent',
            );
        final source = message(100, 'Previous round', null);
        final oldA = 'First Go On reply ' * 5;
        final oldB = 'Second Go On reply ' * 5;
        var replies = [message(1, oldA, attempt), message(2, oldB, attempt)];
        var retrying = false;
        Widget view() {
          final showNewRoundInDeck = replacesOriginalDeck && !retrying;
          return MaterialApp(
            home: Scaffold(
              body: ChatStreamingEffects(
                settings: LocationChatBubbleLayoutSettings.defaults,
                deferIncomingMessages: true,
                child: LocationChatAnchoredMessageList(
                  coordinator: coordinator,
                  topTitle: '',
                  showDateDividers: false,
                  messages: [source, ...replies],
                  replyActionsIdentity: showNewRoundInDeck
                      ? 'round2'
                      : 'round1',
                  replyCurrentCardId: 0,
                  replyCardBindingIdentity: showNewRoundInDeck
                      ? 'round2'
                      : 'round1',
                  replyCards: [
                    LocationChatReplyCard(
                      id: 0,
                      messages: showNewRoundInDeck ? replies : [source],
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        await tester.pumpWidget(view());
        await tester.pumpAndSettle(const Duration(milliseconds: 20));
        final upperY = tester.getTopLeft(find.text(oldA)).dy;
        final lowerY = tester.getTopLeft(find.text(oldB)).dy;
        expect(
          upperY,
          greaterThan(tester.getTopLeft(find.text(source.text)).dy),
        );

        generation.retract(1, retrying: true, next: 2);
        retrying = true;
        replies = [];
        await tester.pumpWidget(view());
        expect(attempt.presentationPending, isTrue);
        expect(tester.getTopLeft(find.text(oldA)).dy, closeTo(upperY, 1));
        expect(tester.getTopLeft(find.text(oldB)).dy, closeTo(lowerY, 1));
        for (var frame = 0; frame < 100; frame++) {
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(find.text(oldA), findsNothing);
        expect(find.text(oldB), findsNothing);
        expect(find.text(source.text), findsOneWidget);
        expect(attempt.presentationPending, isFalse);
      },
    );
  }

  for (final startsInCard in [false, true]) {
    testWidgets(
      'Go On retracts sequentially across source card changes startsInCard=$startsInCard',
      (tester) async {
        final coordinator = LocationChatScrollCoordinator();
        addTearDown(coordinator.dispose);
        final generation = LlmGenerationState(
          const LlmGenerationId('w', 'l', '2', 'go-on'),
        );
        final first = generation.accept(1, 1, end: true)!;
        ChatMessageVm message(int id, String text, LlmAttempt? attempt) =>
            ChatMessageVm(
              localId: 'm$id',
              globalMessageId: id,
              roundId: attempt == null ? '1' : '2',
              llmAttempt: attempt,
              senderId: 'c',
              senderName: 'Character',
              senderType: 'character',
              text: text,
              isMe: false,
              status: 'sent',
            );
        final source = message(100, 'Source reply', null);
        final oldA = 'First Go On bubble ' * 8;
        final oldB = 'Second Go On bubble ' * 8;
        var replies = [message(1, oldA, first), message(2, oldB, first)];
        var cardId = startsInCard ? 0 : 501;
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
                    messages: [source, ...replies],
                    replyActionsIdentity: 'source',
                    replyCurrentCardId: cardId,
                    replyCardBindingIdentity: cardId == 0 ? 'round2' : 'round1',
                    replyCards: [
                      LocationChatReplyCard(
                        id: cardId,
                        messages: cardId == 0 ? replies : [source],
                      ),
                    ],
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
        replies = [message(1, 'Buffered replacement', second)];
        cardId = 502;
        await tester.pumpWidget(view());
        expect(first.presentationPending, isTrue);
        expect(find.text(oldA), findsOneWidget);
        expect(find.text(oldB), findsOneWidget);
        expect(find.text('Buffered replacement'), findsNothing);

        // Card-0 and timeline identities can alias the same animation record.
        // Inspect the timeline identities used after this source-card switch.
        final firstIdentity = ('timeline', (first.identity, 1));
        final secondIdentity = ('timeline', (first.identity, 2));
        await tester.pump(const Duration(milliseconds: 20));
        final before = ChatStreamingEffects.debugRetractionsOf(effectsContext);
        final upper = before.singleWhere(
          (row) => row.identity == firstIdentity,
        );
        final lower = before.singleWhere(
          (row) => row.identity == secondIdentity,
        );
        expect(lower.active, isTrue);
        await tester.pump(const Duration(milliseconds: 60));
        final after = ChatStreamingEffects.debugRetractionsOf(effectsContext);
        expect(
          after.singleWhere((row) => row.identity == firstIdentity).revealed,
          upper.revealed,
        );
        final shrinking = after.singleWhere(
          (row) => row.identity == secondIdentity,
        );
        expect(lower.revealed - shrinking.revealed, closeTo(60 / 2.25, 1));
        expect(shrinking.height, lower.height);
        expect(find.text('Buffered replacement'), findsNothing);
        await tester.pumpAndSettle(const Duration(milliseconds: 20));
        expect(first.presentationPending, isFalse);
        expect(find.text(oldA), findsNothing);
        expect(find.text(oldB), findsNothing);
        expect(find.text('Buffered replacement'), findsOneWidget);
        expect(find.text('Source reply'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('leaving a regenerating candidate releases its retraction', (
    tester,
  ) async {
    final coordinator = LocationChatScrollCoordinator();
    addTearDown(coordinator.dispose);
    final generation = LlmGenerationState(
      const LlmGenerationId('w', 'l', '1', 'regenerate', 102),
    );
    final attempt = generation.accept(1, 1, end: true)!;
    final candidate = ChatMessageVm(
      localId: 'candidate',
      globalMessageId: 1,
      roundId: '1',
      llmAttempt: attempt,
      senderId: 'c',
      senderName: 'Character',
      senderType: 'character',
      text: 'Candidate output ' * 8,
      isMe: false,
      status: 'sent',
    );
    var selected = true;
    Widget view() => MaterialApp(
      home: Scaffold(
        body: ChatStreamingEffects(
          settings: LocationChatBubbleLayoutSettings.defaults,
          child: LocationChatAnchoredMessageList(
            coordinator: coordinator,
            topTitle: '',
            showDateDividers: false,
            messages: selected ? [candidate] : const [],
            replyCurrentCardId: selected ? 102 : 101,
            replyCardBindingIdentity: 'round1',
            replyCards: selected
                ? [
                    LocationChatReplyCard(id: 102, messages: [candidate]),
                  ]
                : const [],
          ),
        ),
      ),
    );
    await tester.pumpWidget(view());
    await tester.pumpAndSettle(const Duration(milliseconds: 20));
    generation.retract(1, retrying: true, next: 2);
    expect(attempt.presentationPending, isTrue);
    selected = false;
    await tester.pumpWidget(view());
    expect(attempt.presentationPending, isFalse);
    expect(find.text(candidate.text), findsNothing);
    expect(find.byType(ChatReplyWaitingBubble), findsNothing);
    expect(tester.takeException(), isNull);
  });

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
      expect(bReveal - shrinking.last.revealed, closeTo(60 / 2.25, 1));
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
