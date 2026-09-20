import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/network/chatroom/location_message_retention.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_scroll_coordinator.dart';

ChatMessageVm _message(int id) => ChatMessageVm(
  localId: 'history-$id',
  globalMessageId: id + 1,
  senderId: 'narrator',
  senderName: '',
  senderType: 'narrator',
  text: 'Paragraph $id. ${'Long history text. ' * (1 + id % 17)}',
  isMe: false,
  status: 'sent',
);

Widget _tree(
  LocationChatScrollCoordinator coordinator,
  List<ChatMessageVm> messages,
) => MaterialApp(
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 390,
        height: 500,
        child: NotificationListener<ScrollNotification>(
          onNotification: coordinator.handleScrollNotification,
          child: AnimatedBuilder(
            animation: coordinator,
            builder: (_, _) => LocationChatAnchoredMessageList(
              coordinator: coordinator,
              messages: messages,
              topTitle: '',
              showDateDividers: false,
              style: kLocationChatStyle,
            ),
          ),
        ),
      ),
    ),
  ),
);

int _firstVisible(LocationChatScrollCoordinator coordinator) => coordinator
    .messageLocalIdsIntersectingViewport
    .map((id) => int.parse(id.split('-').last))
    .reduce((a, b) => a < b ? a : b);

Finder _row(String id) => find.byKey(ValueKey('location-chat-message-row:$id'));

Future<void> _dragOlder(WidgetTester tester) async {
  await tester.timedDrag(
    find.byType(CustomScrollView),
    const Offset(0, 300),
    const Duration(milliseconds: 500),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final fling in [false, true]) {
    testWidgets(
      '30 upward gestures progress through variable-height cached history (fling=$fling)',
      (tester) async {
        final coordinator = LocationChatScrollCoordinator();
        addTearDown(coordinator.dispose);
        await tester.pumpWidget(
          _tree(coordinator, List.generate(240, _message)),
        );
        await tester.pumpAndSettle();
        var previous = _firstVisible(coordinator);
        final initial = previous;
        for (var drag = 0; drag < 30; drag++) {
          if (fling) {
            await tester.fling(
              find.byType(CustomScrollView),
              const Offset(0, 300),
              1400,
            );
            await tester.pumpAndSettle();
          } else {
            await _dragOlder(tester);
          }
          final current = _firstVisible(coordinator);
          // With a trailing correction sentinel, the third slow drag applied
          // one +144 correction repeatedly and jumped from row 234 to 236.
          expect(
            current,
            lessThanOrEqualTo(previous),
            reason: 'gesture $drag: $previous -> $current',
          );
          expect(coordinator.isReadingHistory, isTrue);
          expect(tester.takeException(), isNull);
          previous = current;
        }
        expect(previous, lessThan(initial - 20));
      },
    );
  }

  testWidgets(
    'lazy height corrections preserve finger movement frame by frame',
    (tester) async {
      final coordinator = LocationChatScrollCoordinator();
      addTearDown(coordinator.dispose);
      await tester.pumpWidget(_tree(coordinator, List.generate(240, _message)));
      await tester.pumpAndSettle();
      await _dragOlder(tester);
      for (var drag = 0; drag < 8; drag++) {
        final gesture = await tester.startGesture(const Offset(150, 80));
        // Cross the drag slop before measuring exact pointer deltas.
        await gesture.moveBy(const Offset(0, 40));
        await tester.pump(const Duration(milliseconds: 16));
        for (var frame = 0; frame < 18; frame++) {
          final ids = coordinator.messageLocalIdsIntersectingViewport.toList();
          final anchor = _row(ids[ids.length ~/ 2]);
          final before = tester.getTopLeft(anchor).dy;
          await gesture.moveBy(const Offset(0, 16));
          await tester.pump(const Duration(milliseconds: 16));
          expect(
            tester.getTopLeft(anchor).dy - before,
            closeTo(16, 1 / tester.view.devicePixelRatio),
            reason:
                'drag $drag, frame $frame: layout must not add another jump',
          );
        }
        await gesture.up();
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('repeated older-page merges and retention preserve the reader', (
    tester,
  ) async {
    final coordinator = LocationChatScrollCoordinator();
    addTearDown(coordinator.dispose);
    var messages = List.generate(240, (i) => _message(200 + i));
    await tester.pumpWidget(_tree(coordinator, messages));
    await tester.pumpAndSettle();
    var trimmed = 0;
    for (var page = 0; page < 7; page++) {
      for (var drag = 0; drag < 3; drag++) {
        final before = _firstVisible(coordinator);
        await _dragOlder(tester);
        expect(_firstVisible(coordinator), lessThanOrEqualTo(before));
      }
      final visible = coordinator.messageLocalIdsIntersectingViewport.toList();
      final anchorId = visible[visible.length ~/ 2];
      final before = tester.getTopLeft(_row(anchorId)).dy;
      final older = List.generate(20, (i) => _message(180 - page * 20 + i));
      final merged = [...older, ...messages];
      messages = const LocationMessageRetention().select(
        merged,
        identity: (message) => message.localId,
        protected: {
          ...coordinator.retainedMessageLocalIds,
          ...older.map((m) => m.localId),
        },
        focus: anchorId,
      );
      if (messages.length < merged.length) trimmed++;
      await tester.pumpWidget(_tree(coordinator, messages));
      // Check the first paint, not only the final settled position.
      expect(tester.getTopLeft(_row(anchorId)).dy, closeTo(before, .5));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(_row(anchorId)).dy, closeTo(before, .5));
      expect(coordinator.isReadingHistory, isTrue);
      expect(tester.takeException(), isNull);
    }
    expect(trimmed, greaterThanOrEqualTo(2));
  });
}
