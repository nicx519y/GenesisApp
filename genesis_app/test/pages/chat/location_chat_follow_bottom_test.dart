import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/debug/location_chat_bubble_layout_settings.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_reply_card_switcher.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_scroll_coordinator.dart';

// Measure the real content boundary, before the artificial waiting tail.
void expectNaturalBottom(WidgetTester tester) {
  final end = find.descendant(
    of: find.byKey(
      const ValueKey('location-chat-layout-correction'),
      skipOffstage: false,
    ),
    matching: find.byType(SizedBox, skipOffstage: false),
    skipOffstage: false,
  );
  expect(
    tester.getBottomLeft(end).dy,
    closeTo(tester.getBottomLeft(find.byType(CustomScrollView)).dy, .5),
  );
}

List<ChatMessageVm> history() => List.generate(
  20,
  (i) => ChatMessageVm(
    localId: 'history-$i',
    senderId: 'peer',
    senderName: 'Peer',
    text: 'History $i',
    isMe: false,
    status: 'sent',
  ),
);

void main() {
  for (final inCard in [false, true]) {
    for (final pruneHistory in [false, true]) {
      testWidgets('following real bottom survives stream completion '
          '(card=$inCard, prune=$pruneHistory)', (tester) async {
        final coordinator = LocationChatScrollCoordinator();
        addTearDown(coordinator.dispose);
        var prefix = history();
        var complete = false;
        var lines = 8;
        Widget build() {
          final reply = ChatMessageVm(
            localId: 'reply',
            senderId: 'peer',
            senderName: 'Peer',
            text: List.filled(lines, 'Reply line').join('\n'),
            isMe: false,
            status: complete ? 'sent' : 'streaming',
          );
          return MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 360,
                child: NotificationListener<ScrollNotification>(
                  onNotification: coordinator.handleScrollNotification,
                  child: ChatStreamingEffects(
                    settings: LocationChatBubbleLayoutSettings.defaults,
                    child: LocationChatAnchoredMessageList(
                      coordinator: coordinator,
                      messages: [...prefix, reply],
                      topTitle: '',
                      showDateDividers: false,
                      replyActionsVisible: false,
                      replyActionsIdentity: inCard ? 'round' : null,
                      replyCardBindingIdentity: inCard ? 'round' : null,
                      replyCurrentCardId: inCard ? 1 : 0,
                      replyCards: inCard
                          ? [
                              LocationChatReplyCard(id: 1, messages: [reply]),
                            ]
                          : const [],
                      style: kLocationChatStyle.copyWith(
                        messageListPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        await tester.pumpWidget(build());
        await tester.pumpAndSettle(const Duration(milliseconds: 16));
        expectNaturalBottom(tester);
        // In the eviction case first complete without changing any height:
        // a stale absolute minimum must not turn into blank space later.
        complete = true;
        if (!pruneHistory) lines = 2;
        await tester.pumpWidget(build());
        if (pruneHistory) {
          await tester.pumpAndSettle(const Duration(milliseconds: 16));
          expectNaturalBottom(tester);
          prefix = prefix.sublist(4);
          await tester.pumpWidget(build());
        }
        for (var frame = 0; frame < 90; frame++) {
          expectNaturalBottom(tester);
          expect(coordinator.shouldFollowLatest, isTrue);
          await tester.pump(const Duration(milliseconds: 16));
        }
        await tester.pumpAndSettle();
        expectNaturalBottom(tester);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  for (final enter in [false, true]) {
    testWidgets('explicit bottom releases reserved tail (enter=$enter)', (
      tester,
    ) async {
      final coordinator = LocationChatScrollCoordinator();
      addTearDown(coordinator.dispose);
      final rows = history();
      if (enter) rows.last.text = List.filled(6, 'Enter context').join('\n');
      var waiting = false;
      Widget build() => MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 360,
            child: LocationChatAnchoredMessageList(
              coordinator: coordinator,
              messages: rows,
              topTitle: '',
              showDateDividers: false,
              waitingPositionIdentity: waiting && !enter ? 'send' : null,
              enterConversation: waiting && enter
                  ? (messageLocalId: rows.last.localId, identity: 'enter')
                  : null,
              style: kLocationChatStyle.copyWith(
                messageListPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(build());
      await tester.pumpAndSettle();
      if (!enter) coordinator.prepareWaitingReplyPosition();
      waiting = true;
      await tester.pumpWidget(build());
      await tester.pumpAndSettle();
      expect(coordinator.shouldFollowLatest, isFalse);
      if (enter) {
        // Make the held Enter viewport retain space before returning to latest.
        rows.last.text = 'Short';
      }
      coordinator.requestBottom(
        reason: LocationChatBottomReason.unseenMessageNotice,
        behavior: LocationChatBottomBehavior.jump,
      );
      await tester.pumpWidget(build());
      await tester.pumpAndSettle();
      expect(coordinator.shouldFollowLatest, isTrue);
      expectNaturalBottom(tester);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
