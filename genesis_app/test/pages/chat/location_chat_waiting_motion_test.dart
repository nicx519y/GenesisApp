import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_scroll_coordinator.dart';

void main() {
  for (final change in [
    'shrink',
    'grow',
    'resize',
    'repeated',
    'sameFrame',
    'sameFrameResize',
    'echo',
    'echoOnly',
    'replyGrowth',
    'removeAnchor',
  ]) {
    testWidgets('waiting motion keeps its trajectory through $change', (
      tester,
    ) async {
      final coordinator = LocationChatScrollCoordinator();
      addTearDown(coordinator.dispose);
      ChatMessageVm history(int i) => ChatMessageVm(
        localId: 'old-$i',
        senderId: 'peer',
        senderName: 'Peer',
        text: 'Earlier message $i',
        isMe: false,
        status: 'sent',
      );
      final outgoing = ChatMessageVm(
        localId: 'launch',
        clientMsgId: 'launch-client',
        senderId: 'me',
        senderName: 'Me',
        text: 'Launch message',
        isMe: true,
        status: 'sent',
      );
      var rows = [for (var i = 0; i < 30; i++) history(i), outgoing];
      var waiting = false;
      Widget build() => MaterialApp(
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
                waitingPositionIdentity: waiting ? 'operation-1' : null,
                waitingPositionClientMsgId: waiting ? 'launch-client' : null,
                style: ChatUiStyleConfig.standard.copyWith(
                  messageListPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ),
      );
      double bottom() => ChatBubbleGeometry.globalBoundsOf(
        tester.renderObject(
          find.byWidgetPredicate(
            (w) =>
                w is ChatMessageRow && w.message.clientMsgId == 'launch-client',
            skipOffstage: false,
          ),
        ),
      )!.bottom;
      await tester.pumpWidget(build());
      await tester.pumpAndSettle();
      waiting = true;
      await tester.pumpWidget(build());
      await tester.pump();
      await tester.pump();
      final start = bottom();
      double? heldAfterRemoval;
      for (var frame = 1; frame <= 11; frame++) {
        if (frame == 5 || (change == 'repeated' && frame == 8)) {
          final before = bottom();
          switch (change) {
            case 'shrink':
            case 'repeated':
            case 'sameFrame':
              rows = rows.sublist(3);
            case 'grow':
              rows = [history(31), history(32), history(33), ...rows];
            case 'resize':
            case 'sameFrameResize':
              rows[rows.length - 2].text += '\nExtra line' * 4;
              rows = [...rows];
            case 'echo':
            case 'echoOnly':
              rows = [
                ...rows
                    .skip(change == 'echo' ? 3 : 0)
                    .take(rows.length - (change == 'echo' ? 4 : 1)),
                ChatMessageVm(
                  localId: 'server-launch',
                  clientMsgId: 'launch-client',
                  senderId: 'me',
                  senderName: 'Me',
                  text: 'Launch message',
                  isMe: true,
                  status: 'sent',
                  messageId: 99,
                  locationMessageId: 100,
                ),
              ];
            case 'replyGrowth':
              rows = [...rows, history(99)..text = 'New reply\n' * 15];
            case 'removeAnchor':
              rows = rows.take(rows.length - 1).toList();
          }
          await tester.pumpWidget(
            build(),
            duration: change.startsWith('sameFrame')
                ? const Duration(milliseconds: 20)
                : null,
          );
          if (change == 'removeAnchor') {
            heldAfterRemoval = coordinator.controller.position.pixels;
          } else if (!change.startsWith('sameFrame')) {
            expect(
              bottom(),
              closeTo(before, 1),
              reason: 'Layout correction must be invisible in frame $frame.',
            );
          }
        }
        if (!(change.startsWith('sameFrame') && frame == 5)) {
          await tester.pump(const Duration(milliseconds: 20));
        }
        if (heldAfterRemoval != null) {
          expect(
            coordinator.controller.position.pixels,
            closeTo(heldAfterRemoval, 1),
          );
          continue;
        }
        final expected =
            start + (54 - start) * Curves.easeOut.transform(frame / 11);
        expect(
          bottom(),
          closeTo(expected, 1),
          reason: 'Frame $frame must continue the original timeline.',
        );
      }
      await tester.pump();
      if (heldAfterRemoval == null) expect(bottom(), closeTo(54, 1));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
