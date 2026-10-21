import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_scroll_coordinator.dart';

void main() {
  for (final scenario in [
    'send',
    'ackOnly',
    'goOn',
    'middle',
    'fastReply',
    'failure',
    'disabled',
  ]) {
    testWidgets('waiting indicator follows positioning: $scenario', (
      tester,
    ) async {
      final coordinator = LocationChatScrollCoordinator();
      addTearDown(coordinator.dispose);
      final rows = List.generate(
        30,
        (i) => ChatMessageVm(
          localId: 'row-$i',
          clientMsgId: 'client-$i',
          senderId: 'peer',
          senderName: 'Peer',
          text: 'Message $i',
          isMe: false,
          status: 'sent',
        ),
      );
      var sending = false;
      var loading = false;
      var reset = 0;
      final anchor = scenario == 'middle' ? rows[28] : rows.last;
      Widget tree() => MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 360,
            child: NotificationListener<ScrollNotification>(
              onNotification: coordinator.handleScrollNotification,
              child: LocationChatAnchoredMessageList(
                coordinator: coordinator,
                messages: rows,
                topTitle: '',
                showDateDividers: false,
                replyWaitingPositioningEnabled: scenario != 'disabled',
                waitingPositionIdentity: sending ? 'send-1' : null,
                waitingPositionClientMsgId: sending ? anchor.clientMsgId : null,
                waitingPositionResetRevision: reset,
                preAckWaitingIdentity:
                    sending &&
                        loading &&
                        scenario != 'ackOnly' &&
                        scenario != 'goOn'
                    ? 'send-1'
                    : null,
                preAckWaitingAfterMessageLocalId:
                    sending &&
                        loading &&
                        scenario != 'ackOnly' &&
                        scenario != 'goOn'
                    ? anchor.localId
                    : null,
                loadingIdentity: loading && scenario != 'goOn'
                    ? 'send-1'
                    : null,
                loadingAfterMessageLocalId: loading && scenario != 'goOn'
                    ? anchor.localId
                    : null,
                goOnAwaitingContentIdentity: loading && scenario == 'goOn'
                    ? 'go-on-1'
                    : null,
                style: ChatUiStyleConfig.standard.copyWith(
                  messageListPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ),
      );
      final dots = find.byKey(
        const ValueKey<String>('location-chat-ack-loading-dots'),
      );
      await tester.pumpWidget(tree());
      await tester.pumpAndSettle();
      sending = loading = true;
      await tester.pumpWidget(tree());
      if (scenario == 'disabled') {
        expect(dots, findsOneWidget);
      } else {
        expect(
          dots,
          findsNothing,
          reason: 'Do not reveal before measuring the move.',
        );
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          dots,
          findsNothing,
          reason: 'Do not reveal midway through the move.',
        );
        if (scenario == 'fastReply' || scenario == 'failure') {
          loading = false;
          if (scenario == 'failure') reset++;
          await tester.pumpWidget(tree());
        }
        await tester.pump(const Duration(milliseconds: 120));
        await tester.pump(const Duration(milliseconds: 20));
        expect(dots, loading ? findsOneWidget : findsNothing);
        final held = coordinator.controller.position.pixels;
        await tester.pump(const Duration(milliseconds: 40));
        expect(coordinator.controller.position.pixels, closeTo(held, 1));
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
