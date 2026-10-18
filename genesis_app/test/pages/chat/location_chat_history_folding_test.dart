import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_scroll_coordinator.dart';

void main() {
  late LocationChatScrollCoordinator coordinator;
  late List<ChatMessageVm> messages;
  var expanded = false;
  ({int generation, String localId})? reveal;

  setUp(() {
    coordinator = LocationChatScrollCoordinator();
    messages = List.generate(
      50,
      (i) => ChatMessageVm(
        localId: 'row-$i',
        senderId: 'peer',
        senderName: 'Peer',
        text: 'Message $i',
        isMe: false,
        status: 'sent',
      ),
    );
    expanded = false;
    reveal = null;
  });
  tearDown(() => coordinator.dispose());

  Widget tree() => MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 390,
          height: 500,
          child: NotificationListener<ScrollNotification>(
            onNotification: coordinator.handleScrollNotification,
            child: LocationChatAnchoredMessageList(
              coordinator: coordinator,
              messages: messages,
              topTitle: '',
              showDateDividers: false,
              replyActionsVisible: false,
              hiddenMessageIds: {
                if (!expanded)
                  for (var i = 11; i < 30; i++) 'row-$i',
              },
              historyReveal: reveal,
              messageDecorationVersion: (m, _) =>
                  (m.localId == 'row-10', expanded),
              messageDecorator: (m, _, child) {
                final index = int.parse(m.localId.split('-').last);
                return SizedBox(
                  key: ValueKey('body-${m.localId}'),
                  height: index == 10 && !expanded
                      ? 48
                      : 100.0 + index % 7 * 23,
                  child: Text(m.text),
                );
              },
              style: kLocationChatStyle.copyWith(
                messageListPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> toggle(WidgetTester tester) async {
    reveal = (
      generation: coordinator.beginHistoryNavigation(),
      localId: 'row-10',
    );
    expanded = !expanded;
    await tester.pumpWidget(tree());
    await tester.pumpAndSettle();
  }

  testWidgets(
    'expand aligns section start and repeated collapse stays stable',
    (tester) async {
      await tester.pumpWidget(tree());
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        await toggle(tester);
        expect(
          tester.getTopLeft(find.byKey(const ValueKey('body-row-10'))).dy,
          closeTo(0, 1),
          reason: 'expanded segment starts at viewport top',
        );
        expect(tester.takeException(), isNull);
        await toggle(tester);
        expect(find.byKey(const ValueKey('body-row-11')), findsNothing);
        expect(
          tester.getTopLeft(find.byKey(const ValueKey('body-row-10'))).dy,
          closeTo(0, 1),
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'manual scrolling cancels reveal; history prepend preserves reading position',
    (tester) async {
      await tester.pumpWidget(tree());
      await tester.pumpAndSettle();
      await toggle(tester);
      final before = coordinator.controller.offset;
      await tester.timedDrag(
        find.byType(CustomScrollView),
        const Offset(0, -200),
        const Duration(milliseconds: 700),
      );
      await tester.pumpAndSettle();
      expect(coordinator.controller.offset, greaterThan(before + 100));
      final key = find.byKey(const ValueKey('body-row-12'));
      final y = tester.getTopLeft(key).dy;
      messages = [
        ChatMessageVm(
          localId: 'row--1',
          senderId: 'peer',
          senderName: 'Peer',
          text: 'Earlier',
          isMe: false,
          status: 'sent',
        ),
        ...messages,
      ];
      await tester.pumpWidget(tree());
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(key).dy, closeTo(y, 1));
      expect(tester.takeException(), isNull);
    },
  );
}
