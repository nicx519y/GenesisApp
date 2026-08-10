import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_scroll_coordinator.dart';

void main() {
  List<ChatMessageVm> messages(int count) {
    return [
      for (var id = 1; id <= count; id += 1)
        ChatMessageVm(
          localId: 'message-$id',
          senderId: 'peer',
          senderName: 'Peer',
          text: 'message $id',
          isMe: false,
          status: 'sent',
        ),
    ];
  }

  Widget viewport(LocationChatScrollCoordinator coordinator) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 360,
          child: AnimatedBuilder(
            animation: coordinator,
            builder: (context, _) {
              return NotificationListener<ScrollNotification>(
                onNotification: coordinator.handleScrollNotification,
                child: LocationChatAnchoredMessageList(
                  coordinator: coordinator,
                  messages: messages(30),
                  topTitle: '',
                  showDateDividers: false,
                  style: ChatUiStyleConfig.standard.copyWith(
                    messageListPadding: EdgeInsets.zero,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  testWidgets('every enter positions the viewport at the latest message', (
    tester,
  ) async {
    final coordinator = LocationChatScrollCoordinator();
    addTearDown(coordinator.dispose);

    await tester.pumpWidget(viewport(coordinator));
    await tester.pumpAndSettle();
    expect(coordinator.mode, LocationChatViewportMode.followingLatest);
    expect(
      coordinator.controller.position.pixels,
      closeTo(coordinator.controller.position.maxScrollExtent, 0.1),
    );

    coordinator.controller.jumpTo(
      coordinator.controller.position.maxScrollExtent - 240,
    );
    coordinator.deactivate();
    await tester.pump();
    expect(coordinator.mode, LocationChatViewportMode.detached);

    coordinator.enter();
    await tester.pumpAndSettle();
    expect(coordinator.mode, LocationChatViewportMode.followingLatest);
    expect(
      coordinator.controller.position.pixels,
      closeTo(coordinator.controller.position.maxScrollExtent, 0.1),
    );
  });

  testWidgets('detaching cancels a queued explicit bottom request', (
    tester,
  ) async {
    final coordinator = LocationChatScrollCoordinator();
    addTearDown(coordinator.dispose);
    await tester.pumpWidget(viewport(coordinator));
    await tester.pumpAndSettle();

    coordinator.controller.jumpTo(
      coordinator.controller.position.maxScrollExtent - 240,
    );
    coordinator.deactivate();
    await tester.pump();
    final pixelsBefore = coordinator.controller.position.pixels;

    coordinator.requestBottom(
      reason: LocationChatBottomReason.unseenMessageNotice,
      behavior: LocationChatBottomBehavior.jump,
    );
    coordinator.deactivate();
    await tester.pump();

    expect(coordinator.mode, LocationChatViewportMode.detached);
    expect(coordinator.controller.position.pixels, closeTo(pixelsBefore, 0.1));
  });

  testWidgets('real user scrolling owns detached and following transitions', (
    tester,
  ) async {
    final coordinator = LocationChatScrollCoordinator();
    addTearDown(coordinator.dispose);
    await tester.pumpWidget(viewport(coordinator));
    await tester.pumpAndSettle();
    final notificationContext = tester.element(find.byType(Scrollable));

    coordinator.controller.jumpTo(
      coordinator.controller.position.maxScrollExtent - 240,
    );
    coordinator.handleScrollNotification(
      UserScrollNotification(
        metrics: coordinator.controller.position,
        context: notificationContext,
        direction: ScrollDirection.forward,
      ),
    );
    expect(coordinator.mode, LocationChatViewportMode.detached);

    coordinator.controller.jumpTo(
      coordinator.controller.position.maxScrollExtent,
    );
    coordinator.handleScrollNotification(
      UserScrollNotification(
        metrics: coordinator.controller.position,
        context: notificationContext,
        direction: ScrollDirection.reverse,
      ),
    );
    expect(coordinator.mode, LocationChatViewportMode.followingLatest);
  });

  testWidgets('a newer enter invalidates the previous entry callback', (
    tester,
  ) async {
    final coordinator = LocationChatScrollCoordinator();
    addTearDown(coordinator.dispose);
    await tester.pumpWidget(viewport(coordinator));
    await tester.pumpAndSettle();
    coordinator.controller.jumpTo(
      coordinator.controller.position.maxScrollExtent - 240,
    );
    coordinator.deactivate();
    await tester.pump();
    final generationBefore = coordinator.commandGeneration;
    final observedOffsets = <double>[];
    void recordOffset() {
      observedOffsets.add(coordinator.controller.position.pixels);
    }

    coordinator.controller.addListener(recordOffset);
    coordinator.enter();
    coordinator.enter();
    expect(coordinator.commandGeneration, generationBefore + 2);
    await tester.pump();
    coordinator.controller.removeListener(recordOffset);

    expect(observedOffsets, hasLength(1));
    expect(coordinator.mode, LocationChatViewportMode.followingLatest);
  });

  testWidgets(
    'dispose invalidates an entry callback without owning controller',
    (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final coordinator = LocationChatScrollCoordinator(controller: controller);
      await tester.pumpWidget(viewport(coordinator));
      await tester.pumpAndSettle();
      controller.jumpTo(controller.position.maxScrollExtent - 240);
      coordinator.deactivate();
      await tester.pump();
      final pixelsBefore = controller.position.pixels;

      coordinator.enter();
      coordinator.dispose();
      await tester.pump();

      expect(controller.position.pixels, closeTo(pixelsBefore, 0.1));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('one explicit request produces one bottom position change', (
    tester,
  ) async {
    final coordinator = LocationChatScrollCoordinator();
    addTearDown(coordinator.dispose);
    await tester.pumpWidget(viewport(coordinator));
    await tester.pumpAndSettle();

    coordinator.controller.jumpTo(
      coordinator.controller.position.maxScrollExtent - 240,
    );
    coordinator.deactivate();
    await tester.pump();
    final observedOffsets = <double>[];
    void recordOffset() {
      observedOffsets.add(coordinator.controller.position.pixels);
    }

    coordinator.controller.addListener(recordOffset);
    coordinator.requestBottom(
      reason: LocationChatBottomReason.unseenMessageNotice,
      behavior: LocationChatBottomBehavior.jump,
    );
    await tester.pump();
    coordinator.controller.removeListener(recordOffset);

    expect(observedOffsets, hasLength(1));
    expect(
      observedOffsets.single,
      closeTo(coordinator.controller.position.maxScrollExtent, 0.1),
    );
  });
}
