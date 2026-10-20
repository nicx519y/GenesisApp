import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_scroll_coordinator.dart';

class _CountedMessages extends ListBase<ChatMessageVm> {
  _CountedMessages(int count)
    : rows = List.generate(
        count,
        (i) => ChatMessageVm(
          localId: 'message-$i',
          text: 'Archive message $i',
          senderName: 'Speaker',
          senderId: 'speaker',
          isMe: false,
          status: 'sent',
        ),
      );

  final List<ChatMessageVm> rows;
  int reads = 0;
  @override
  int get length => rows.length;
  @override
  set length(int value) => throw UnsupportedError('immutable');
  @override
  ChatMessageVm operator [](int index) {
    reads++;
    return rows[index];
  }

  @override
  void operator []=(int index, ChatMessageVm value) =>
      throw UnsupportedError('immutable');
}

void main() {
  testWidgets('cached anchors follow mounted rows across distant jumps', (
    tester,
  ) async {
    final messages = _CountedMessages(600);
    final coordinator = LocationChatScrollCoordinator();
    final viewport = LocationChatViewportCache();
    addTearDown(coordinator.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LocationChatAnchoredMessageList(
            coordinator: coordinator,
            viewportCache: viewport,
            messages: messages,
            messageLayoutId: (message) => 'layout:${message.localId}',
            topTitle: '',
            replyActionsVisible: false,
            replyWaitingPositioningEnabled: false,
            restoreInitialCompletedContent: true,
            showDateDividers: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    String? previousAnchor;
    for (final fraction in [0.5, 0.8, 0.2]) {
      coordinator.beginHistoryNavigation();
      coordinator.controller.jumpTo(
        coordinator.controller.position.maxScrollExtent * fraction,
      );
      await tester.pumpAndSettle();
      final anchor = viewport.anchor!;
      expect(anchor.localId, isNot(previousAnchor));
      expect(
        coordinator.messageLocalIdsIntersectingViewport.map(
          (id) => 'layout:$id',
        ),
        contains(anchor.localId),
      );
      previousAnchor = anchor.localId;
      debugLocationChatMessageBoundsQueryCount = 0;
      coordinator.controller.jumpTo(coordinator.controller.offset - 1);
      await tester.pump();
      expect(debugLocationChatMessageBoundsQueryCount, lessThan(100));
      expect(viewport.anchor!.localId, anchor.localId);
      expect(
        viewport.anchor!.viewportOffset,
        closeTo(anchor.viewportOffset + 1, 0.1),
      );
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final count in [200, 600, 1200]) {
    testWidgets(
      'settled scrolling does not read every archived message ($count)',
      (tester) async {
        final messages = _CountedMessages(count);
        final coordinator = LocationChatScrollCoordinator();
        addTearDown(coordinator.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LocationChatAnchoredMessageList(
                coordinator: coordinator,
                messages: messages,
                topTitle: '',
                replyActionsVisible: false,
                replyWaitingPositioningEnabled: false,
                restoreInitialCompletedContent: true,
                showDateDividers: false,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        coordinator.beginHistoryNavigation();
        final before = coordinator.messageLocalIdsIntersectingViewport.toSet();
        expect(before, isNotEmpty);
        messages.reads = 0;
        debugLocationChatMessageBoundsQueryCount = 0;
        for (var i = 0; i < 3; i++) {
          coordinator.controller.jumpTo(coordinator.controller.offset - 1);
          await tester.pump();
        }
        expect(messages.reads, lessThan(100));
        expect(debugLocationChatMessageBoundsQueryCount, lessThan(250));
        expect(
          coordinator.messageLocalIdsIntersectingViewport.intersection(before),
          isNotEmpty,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
