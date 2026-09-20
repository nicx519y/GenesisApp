import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_local_message_order.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_reply_card_switcher.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_scroll_coordinator.dart';

void main() {
  for (final mode in ['send', 'inspiration', 'go-on', 'regenerate']) {
    for (final keyboard in [0.0, 120.0]) {
      testWidgets(
        'failed local order preserves $mode anchor with keyboard $keyboard',
        (tester) async {
          final coordinator = LocationChatScrollCoordinator();
          addTearDown(coordinator.dispose);
          final order = LocationChatLocalMessageOrder();
          ChatMessageVm row(int i) => ChatMessageVm(
            localId: 'row-$i',
            locationMessageId: i + 1,
            globalMessageId: i + 1,
            senderId: 'peer',
            senderName: 'Peer',
            text: 'Message $i',
            isMe: false,
            status: 'sent',
          );
          final history = List.generate(20, row);
          final failed = ChatMessageVm(
            localId: 'failed',
            clientMsgId: 'failed-client',
            senderId: 'me',
            senderName: 'Me',
            text: 'Failed send',
            isMe: true,
            status: 'failed',
          );
          order.capture(failed, before: history.take(18).toList());
          final regenerate = mode == 'regenerate';
          final send = mode == 'send' || mode == 'inspiration';
          final anchor = regenerate ? failed : history.last;
          var waiting = false;
          var receiving = false;
          var promoted = false;
          final arrivals = <ChatMessageVm>[];
          Widget build() {
            final ordered = order.apply([...history, ...arrivals, failed]);
            expect(ordered.indexOf(failed), promoted ? ordered.length - 1 : 18);
            return MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  height: 360,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: keyboard),
                    child: LocationChatKeyboardInsetScope(
                      effectiveInset: keyboard,
                      child: LocationChatAnchoredMessageList(
                        coordinator: coordinator,
                        messages: ordered,
                        topTitle: '',
                        showDateDividers: false,
                        waitingPositionIdentity: waiting ? 'operation' : null,
                        preAckWaitingIdentity: waiting && send && !receiving
                            ? 'operation'
                            : null,
                        preAckWaitingAfterMessageLocalId:
                            waiting && send && !receiving
                            ? anchor.localId
                            : null,
                        goOnAwaitingContentIdentity:
                            waiting && mode == 'go-on' && !receiving
                            ? 'operation'
                            : null,
                        replyActionsIdentity: 'round',
                        replyCardBindingIdentity: 'round',
                        replyCurrentCardId: 1,
                        replyCards: regenerate
                            ? [
                                LocationChatReplyCard(
                                  id: 1,
                                  messages: history.sublist(18),
                                ),
                              ]
                            : const [],
                        replyRegenerationInProgress: regenerate && waiting,
                        replyRegenerationDispatchRevision: regenerate && waiting
                            ? 1
                            : 0,
                        style: ChatUiStyleConfig.standard.copyWith(
                          messageListPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }

          double anchorBottom() {
            final finder = find.byWidgetPredicate(
              (w) => w is ChatMessageRow && w.message.localId == anchor.localId,
            );
            return ChatBubbleGeometry.globalBoundsOf(
              tester.renderObject(finder),
            )!.bottom;
          }

          await tester.pumpWidget(build());
          await tester.pumpAndSettle();
          coordinator.prepareWaitingReplyPosition();
          waiting = true;
          await tester.pumpWidget(build());
          await tester.pump();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 240));
          await tester.pump();
          expect(anchorBottom(), closeTo(54, 1 / tester.view.devicePixelRatio));
          final heldPixels = coordinator.controller.position.pixels;
          final heldGeneration = coordinator.commandGeneration;
          // No new operation: loading disappears, more content/layout arrives,
          // and the old failed row must not migrate across the waiting anchor.
          receiving = true;
          for (var frame = 0; frame < 36; frame++) {
            if (frame % 12 == 0) arrivals.add(row(20 + arrivals.length));
            await tester.pumpWidget(build());
            await tester.pump(const Duration(milliseconds: 16));
            expect(
              anchorBottom(),
              closeTo(54, 1 / tester.view.devicePixelRatio),
            );
            expect(
              coordinator.controller.position.pixels,
              closeTo(heldPixels, .01),
            );
            expect(coordinator.commandGeneration, heldGeneration);
          }
          if (!regenerate) {
            // A successful retry now gets a server position AFTER the held
            // anchor. IDs have not disappeared: the prefix correction must also
            // recognize movement, while preserving the original anchor surface.
            promoted = true;
            failed.status = 'sent';
            failed.locationMessageId = 100;
            order.retain([...history, ...arrivals, failed]);
            await tester.pumpWidget(build());
            for (var frame = 0; frame < 12; frame++) {
              await tester.pump(const Duration(milliseconds: 16));
              expect(
                anchorBottom(),
                closeTo(54, 1 / tester.view.devicePixelRatio),
              );
              expect(coordinator.commandGeneration, heldGeneration);
            }
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }

  testWidgets(
    'empty card regeneration anchors above its retained local successor',
    (tester) async {
      final coordinator = LocationChatScrollCoordinator();
      addTearDown(coordinator.dispose);
      final order = LocationChatLocalMessageOrder();
      final history = List.generate(
        20,
        (i) => ChatMessageVm(
          localId: 'history-$i',
          senderId: 'peer',
          senderName: 'Peer',
          text: 'History $i',
          isMe: false,
          status: 'sent',
          locationMessageId: i + 1,
        ),
      );
      final oldCard = ChatMessageVm(
        localId: 'old-card',
        roundId: '7',
        senderId: 'peer',
        senderName: 'Peer',
        text: 'Old card',
        isMe: false,
        status: 'sent',
      );
      final failed = ChatMessageVm(
        localId: 'failed',
        clientMsgId: 'f',
        senderId: 'me',
        senderName: 'Me',
        text: 'Failed',
        isMe: true,
        status: 'failed',
      );
      order.capture(
        failed,
        before: [...history, oldCard],
        cardMessageIds: {'old-card'},
      );
      var waiting = false;
      Widget build() {
        final rows = order.apply([...history, failed]);
        return MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 360,
              child: LocationChatAnchoredMessageList(
                coordinator: coordinator,
                messages: rows,
                topTitle: '',
                showDateDividers: false,
                waitingPositionIdentity: waiting ? 'regen' : null,
                replyActionsIdentity: 'round-7',
                replyCardBindingIdentity: 'round-7',
                replyCurrentCardId: 1,
                replyCards: [LocationChatReplyCard(id: 1, messages: const [])],
                replyGroupBeforeMessageLocalId: order.firstLocalAfterRound(
                  '7',
                  rows,
                ),
                replyRegenerationInProgress: waiting,
                replyRegenerationDispatchRevision: waiting ? 1 : 0,
                style: ChatUiStyleConfig.standard.copyWith(
                  messageListPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(build());
      await tester.pumpAndSettle();
      coordinator.prepareWaitingReplyPosition();
      waiting = true;
      await tester.pumpWidget(build());
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 240));
      await tester.pump();
      final finder = find.byWidgetPredicate(
        (w) => w is ChatMessageRow && w.message.localId == history.last.localId,
      );
      expect(
        ChatBubbleGeometry.globalBoundsOf(tester.renderObject(finder))!.bottom,
        closeTo(54, 1 / tester.view.devicePixelRatio),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'reply group projects card members by identity without hiding interleaved rows',
    (tester) async {
      final coordinator = LocationChatScrollCoordinator();
      addTearDown(coordinator.dispose);
      ChatMessageVm message(
        String id, {
        String round = '',
        bool isMe = false,
        String status = 'sent',
      }) => ChatMessageVm(
        localId: id,
        roundId: round,
        senderId: isMe ? 'me' : 'peer',
        senderName: isMe ? 'Me' : 'Peer',
        text: id,
        isMe: isMe,
        status: status,
      );

      final before = message('before');
      final firstCardRow = message('card-a', round: '7');
      final failed = message('failed', isMe: true, status: 'failed');
      final secondCardRow = message('card-b', round: '7');
      final after = message('after');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 600,
              child: LocationChatAnchoredMessageList(
                coordinator: coordinator,
                messages: [before, firstCardRow, failed, secondCardRow, after],
                topTitle: '',
                showDateDividers: false,
                replyActionsIdentity: 'round-7',
                replyActionsVisible: false,
                replyGroupBeforeMessageLocalId: failed.localId,
                replyCardBindingIdentity: 'round-7',
                replyCurrentCardId: 1,
                replyCards: [
                  LocationChatReplyCard(
                    id: 1,
                    messages: [firstCardRow, secondCardRow],
                  ),
                ],
                replyCardCount: 2,
                style: ChatUiStyleConfig.standard.copyWith(
                  messageListPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final text in ['before', 'card-a', 'card-b', 'failed', 'after']) {
        expect(find.text(text), findsOneWidget);
      }
      expect(find.text('1 / 2'), findsOneWidget);
      expect(
        tester.getBottomLeft(find.text('1 / 2')).dy,
        lessThan(tester.getTopLeft(find.text('failed')).dy),
      );
      expect(
        tester.getTopLeft(find.text('failed')).dy,
        lessThan(tester.getTopLeft(find.text('after')).dy),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
