import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/features/location_chat_reply/regenerate/regenerate.dart';
import 'package:genesis_flutter_android/features/location_chat_reply/shared/reply_action_state.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_reply_card_switcher.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_scroll_coordinator.dart';

void main() {
  testWidgets('stream end compact gap does not pull bottom bubbles down', (
    tester,
  ) async {
    final coordinator = LocationChatScrollCoordinator();
    addTearDown(coordinator.dispose);
    Widget tree({required bool complete, String extra = ''}) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 360,
          child: LocationChatAnchoredMessageList(
            coordinator: coordinator,
            topTitle: '',
            showDateDividers: false,
            replyActionsIdentity: 'round-1',
            replyActionsMessageId: complete ? 'stream' : null,
            messages: [
              for (var i = 0; i < 20; i++)
                ChatMessageVm(
                  localId: 'history-$i',
                  senderId: 'peer',
                  senderName: 'Peer',
                  text: 'History $i',
                  isMe: false,
                  status: 'sent',
                ),
              ChatMessageVm(
                localId: 'stream',
                senderId: 'peer',
                senderName: 'Peer',
                text: 'Stream body$extra',
                isMe: false,
                status: complete ? 'sent' : 'streaming',
              ),
            ],
            style: ChatUiStyleConfig.standard.copyWith(
              rowBottomPadding: 14,
              messageListPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(tree(complete: false));
    await tester.pump();
    final before = tester.getTopLeft(find.text('Stream body')).dy;
    final pixels = coordinator.controller.position.pixels;
    await tester.pumpWidget(tree(complete: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      tester.getTopLeft(find.text('Stream body')).dy,
      closeTo(before, 0.01),
    );
    expect(coordinator.controller.position.pixels, closeTo(pixels, 0.01));
    expect(coordinator.shouldFollowLatest, isTrue);
    await tester.pumpWidget(
      tree(complete: false, extra: '\nNext streamed line' * 8),
    );
    await tester.pump();
    expect(coordinator.controller.position.pixels, greaterThan(pixels));
    expect(coordinator.isAtBottom, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  List<ChatMessageVm> messages(
    int count, {
    String suffix = '',
    int? suffixIndex,
  }) => [
    for (var i = 0; i < count; i++)
      ChatMessageVm(
        localId: 'message-$i',
        senderId: 'peer',
        senderName: 'Peer',
        text: 'Message $i${i == (suffixIndex ?? count - 1) ? suffix : ''}',
        isMe: false,
        status: 'sent',
      ),
  ];

  Widget tree(
    LocationChatScrollCoordinator coordinator, {
    int count = 20,
    String? waiting,
    String? preAckWaiting,
    bool goOn = false,
    bool secondScroll = false,
    bool active = true,
    bool positioningEnabled = true,
    String suffix = '',
    int? suffixIndex,
    double reserveFraction = 0.75,
    double viewportHeight = 360,
    double effectiveKeyboardInset = 0,
    int waitingPositionResetRevision = 0,
    bool showReplyActions = false,
    int replyPresentationRevision = 0,
  }) => MaterialApp(
    home: Scaffold(
      body: SizedBox(
        height: viewportHeight,
        child: LocationChatKeyboardInsetScope(
          effectiveInset: effectiveKeyboardInset,
          child: NotificationListener<ScrollNotification>(
            onNotification: coordinator.handleScrollNotification,
            child: LocationChatAnchoredMessageList(
              active: active,
              coordinator: coordinator,
              replyWaitingPositioningEnabled: positioningEnabled,
              replyViewportReserveFraction: reserveFraction,
              messages: messages(
                count,
                suffix: suffix,
                suffixIndex: suffixIndex,
              ),
              topTitle: secondScroll ? 'Start' : '',
              oldestEdgeNoticeRequiresSecondScroll: secondScroll,
              loadingAfterMessageLocalId: waiting != null && !goOn
                  ? 'message-${count - 1}'
                  : null,
              loadingIdentity: goOn ? null : waiting,
              preAckWaitingAfterMessageLocalId: preAckWaiting == null
                  ? null
                  : 'message-${count - 1}',
              preAckWaitingIdentity: preAckWaiting,
              waitingPositionResetRevision: waitingPositionResetRevision,
              goOnAwaitingContentIdentity: goOn ? waiting : null,
              replyActionsIdentity: showReplyActions ? 'round-1' : null,
              replyActionsMessageId: showReplyActions
                  ? 'message-${count - 1}'
                  : null,
              replyActionsVisible: showReplyActions,
              replyPresentationRevision: replyPresentationRevision,
              regenerateFeature: showReplyActions
                  ? LocationChatRegenerateFeature(
                      state: LocationChatReplyActionState.idle,
                      onInvoke: () {},
                    )
                  : const LocationChatRegenerateFeature.disabled(),
              showDateDividers: false,
              style: ChatUiStyleConfig.standard.copyWith(
                messageListPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      ),
    ),
  );

  test('stable reply viewport includes the applied keyboard inset', () {
    for (final geometry in [
      (viewport: 60.0, inset: 300.0),
      (viewport: 160.0, inset: 200.0),
      (viewport: 260.0, inset: 100.0),
      (viewport: 360.0, inset: 0.0),
    ]) {
      expect(
        locationChatStableReplyViewportHeightForTesting(
          currentViewportHeight: geometry.viewport,
          effectiveKeyboardInset: geometry.inset,
        ),
        360,
      );
    }
  });

  testWidgets(
    'pre-ACK Send uses the closed-keyboard viewport and ACK reveals in place',
    (tester) async {
      final coordinator = LocationChatScrollCoordinator();
      addTearDown(coordinator.dispose);
      await tester.pumpWidget(
        tree(coordinator, viewportHeight: 200, effectiveKeyboardInset: 160),
      );
      await tester.pump();
      await tester.pumpWidget(
        tree(
          coordinator,
          preAckWaiting: 'send-1',
          viewportHeight: 200,
          effectiveKeyboardInset: 160,
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final waitingBubble = find.byType(ChatReplyWaitingBubble);
      const dots = ValueKey<String>('location-chat-ack-loading-dots');
      expect(waitingBubble, findsOneWidget);
      expect(find.byKey(dots), findsNothing);
      expect(tester.getTopLeft(waitingBubble).dy, closeTo(90, 1));
      final heldPixels = coordinator.controller.position.pixels;
      expect(coordinator.isDetached, isTrue);
      expect(coordinator.isReadingHistory, isFalse);

      await tester.pumpWidget(
        tree(
          coordinator,
          preAckWaiting: 'send-1',
          viewportHeight: 280,
          effectiveKeyboardInset: 80,
        ),
      );
      await tester.pump();
      expect(tester.getTopLeft(waitingBubble).dy, closeTo(90, 1));
      expect(coordinator.controller.position.pixels, closeTo(heldPixels, 0.1));

      await tester.pumpWidget(
        tree(
          coordinator,
          waiting: 'send-1',
          preAckWaiting: 'send-1',
          viewportHeight: 360,
        ),
      );
      await tester.pump();
      expect(find.byKey(dots), findsOneWidget);
      expect(tester.getTopLeft(waitingBubble).dy, closeTo(90, 1));
      expect(coordinator.controller.position.pixels, closeTo(heldPixels, 0.1));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'consecutive pre-ACK Sends wait for bottom layout and replace the old tail',
    (tester) async {
      final coordinator = LocationChatScrollCoordinator();
      addTearDown(coordinator.dispose);
      await tester.pumpWidget(tree(coordinator, count: 30));
      await tester.pump();

      await tester.drag(find.byType(Scrollable).first, const Offset(0, 180));
      await tester.pumpAndSettle();
      expect(coordinator.isReadingHistory, isTrue);

      Future<void> send({
        required int count,
        required String identity,
        required bool expectLatestMessageReveal,
      }) async {
        final needsLatestMessageReveal = coordinator
            .prepareWaitingReplyPosition();
        expect(needsLatestMessageReveal, expectLatestMessageReveal);
        if (needsLatestMessageReveal) {
          coordinator.requestBottom(
            reason: LocationChatBottomReason.sentMessage,
            behavior: LocationChatBottomBehavior.jump,
          );
        }
        await tester.pumpWidget(
          tree(coordinator, count: count, preAckWaiting: identity),
        );

        // Waiting positioning owns the viewport before the optimistic row is
        // laid out. A history reader may need one latest-message reveal, but a
        // prior reply hold must never jump to the end of its artificial tail.
        expect(coordinator.isDetached, !needsLatestMessageReveal);
        await tester.pump();
        expect(coordinator.isDetached, isTrue);
        expect(coordinator.isReadingHistory, isFalse);
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          tester.getTopLeft(find.byType(ChatReplyWaitingBubble)).dy,
          closeTo(90, 1),
        );
      }

      await send(
        count: 31,
        identity: 'send-1',
        expectLatestMessageReveal: true,
      );
      final firstHeldPixels = coordinator.controller.position.pixels;
      await tester.pumpWidget(
        tree(
          coordinator,
          count: 31,
          preAckWaiting: 'send-1',
          suffixIndex: 30,
          suffix: '\nGrowing reply' * 20,
        ),
      );
      await tester.pump();
      expect(
        coordinator.controller.position.pixels,
        closeTo(firstHeldPixels, 0.1),
      );
      expect(
        coordinator.controller.position.maxScrollExtent,
        greaterThan(firstHeldPixels),
      );

      // The second Send starts from a held viewport with a reserved tail. It
      // must replace that reserve instead of compounding a stale extent.
      await send(
        count: 32,
        identity: 'send-2',
        expectLatestMessageReveal: false,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('first AI content replaces loading without moving the viewport', (
    tester,
  ) async {
    final coordinator = LocationChatScrollCoordinator();
    addTearDown(coordinator.dispose);
    await tester.pumpWidget(tree(coordinator, count: 31));
    await tester.pump();

    coordinator.prepareWaitingReplyPosition();
    await tester.pumpWidget(
      tree(coordinator, count: 31, waiting: 'send-1', preAckWaiting: 'send-1'),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final heldMessage = find.text('Message 30');
    final heldMessageTop = tester.getTopLeft(heldMessage).dy;
    final heldPixels = coordinator.controller.position.pixels;
    expect(
      tester.getTopLeft(find.byType(ChatReplyWaitingBubble)).dy,
      closeTo(90, 1),
    );

    // The first rendered AI chunk removes both the ACK loading state and the
    // pre-ACK placeholder in the same rebuild while adding the reply row.
    await tester.pumpWidget(tree(coordinator, count: 32));
    await tester.pump();

    expect(find.byType(ChatReplyWaitingBubble), findsNothing);
    expect(tester.getTopLeft(heldMessage).dy, closeTo(heldMessageTop, 0.1));
    expect(coordinator.controller.position.pixels, closeTo(heldPixels, 0.1));
    expect(find.text('Message 31'), findsOneWidget);
    expect(
      tester
          .getTopLeft(
            find.byKey(
              const ValueKey<String>('location-chat-message-row:message-31'),
            ),
          )
          .dy,
      closeTo(90, 1),
      reason:
          'The first rendered reply must start at the same top anchor as its waiting placeholder.',
    );

    // Subsequent stream growth must consume the reserved tail. If the loading
    // transition released the hold, following the growing real bottom would
    // keep increasing pixels and push the sent bubble above the viewport.
    await tester.pumpWidget(
      tree(
        coordinator,
        count: 32,
        suffixIndex: 31,
        suffix: '\nGrowing AI reply' * 20,
      ),
    );
    await tester.pump();
    expect(tester.getTopLeft(heldMessage).dy, closeTo(heldMessageTop, 0.1));
    expect(coordinator.controller.position.pixels, closeTo(heldPixels, 0.1));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('fast ACK before first waiting layout positions only once', (
    tester,
  ) async {
    final coordinator = LocationChatScrollCoordinator();
    addTearDown(coordinator.dispose);
    await tester.pumpWidget(tree(coordinator));
    await tester.pump();
    final generationBeforeAck = coordinator.commandGeneration;

    await tester.pumpWidget(
      tree(
        coordinator,
        waiting: 'fast-send',
        preAckWaiting: 'fast-send',
        viewportHeight: 200,
        effectiveKeyboardInset: 160,
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const ValueKey<String>('location-chat-ack-loading-dots')),
      findsOneWidget,
    );
    expect(coordinator.commandGeneration, generationBeforeAck + 1);
    expect(coordinator.isDetached, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('pre-ACK failure reset removes the waiting tail', (tester) async {
    final coordinator = LocationChatScrollCoordinator();
    addTearDown(coordinator.dispose);
    await tester.pumpWidget(tree(coordinator));
    await tester.pump();
    await tester.pumpWidget(tree(coordinator, preAckWaiting: 'failed-send'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(coordinator.isDetached, isTrue);

    await tester.pumpWidget(tree(coordinator, waitingPositionResetRevision: 1));
    await tester.pump();
    expect(find.byType(ChatReplyWaitingBubble), findsNothing);
    expect(coordinator.isDetached, isFalse);
    expect(
      coordinator.controller.position.pixels,
      closeTo(coordinator.controller.position.maxScrollExtent, 0.1),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final goOn in [false, true]) {
    for (final secondScroll in [false, true]) {
      testWidgets(
        '${goOn ? 'Go On' : 'Send'} reserves three quarters and holds incoming replies (second scroll: $secondScroll)',
        (tester) async {
          final coordinator = LocationChatScrollCoordinator();
          addTearDown(coordinator.dispose);
          await tester.pumpWidget(
            tree(coordinator, secondScroll: secondScroll),
          );
          await tester.pump();
          await tester.pumpWidget(
            tree(
              coordinator,
              waiting: 'round-1',
              goOn: goOn,
              secondScroll: secondScroll,
            ),
          );
          await tester.pump();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          final waitingBubble = find.byType(ChatReplyWaitingBubble);
          expect(tester.getTopLeft(waitingBubble).dy, closeTo(90, 1));
          final position = coordinator.controller.position;
          final held = position.pixels;
          expect(coordinator.isDetached, isTrue);
          expect(coordinator.isReadingHistory, isFalse);

          await tester.pumpWidget(
            tree(coordinator, count: 21, secondScroll: secondScroll),
          );
          await tester.pump(const Duration(milliseconds: 300));
          expect(position.pixels, closeTo(held, 1));
          await tester.pumpWidget(
            tree(
              coordinator,
              count: 21,
              suffix: '\nStreaming reply' * 15,
              secondScroll: secondScroll,
            ),
          );
          await tester.pump();
          expect(position.pixels, closeTo(held, 1));
          await tester.pumpWidget(
            tree(coordinator, count: 40, secondScroll: secondScroll),
          );
          await tester.pump();
          expect(position.pixels, closeTo(held, 1));
          expect(position.maxScrollExtent, greaterThan(held + 200));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }

  testWidgets(
    'held Go On does not anchor a lower message while an earlier stream grows',
    (tester) async {
      final coordinator = LocationChatScrollCoordinator();
      addTearDown(coordinator.dispose);
      await tester.pumpWidget(tree(coordinator));
      await tester.pump();
      await tester.pumpWidget(
        tree(coordinator, waiting: 'round-1', goOn: true),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final position = coordinator.controller.position;
      final held = position.pixels;
      expect(coordinator.isDetached, isTrue);
      expect(coordinator.isReadingHistory, isFalse);

      // The real Go On response can contain several bubbles. Once a lower
      // bubble is nearest the viewport center, growth in the earlier bubble
      // must consume the waiting tail instead of preserving that lower row.
      await tester.pumpWidget(tree(coordinator, count: 22));
      await tester.pump();
      await tester.pump();
      expect(position.pixels, closeTo(held, 0.1));
      expect(find.text('Message 21'), findsOneWidget);

      await tester.pumpWidget(
        tree(
          coordinator,
          count: 22,
          suffixIndex: 20,
          suffix: '\nStreaming reply' * 15,
        ),
      );
      await tester.pump();

      expect(position.pixels, closeTo(held, 0.1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('turning positioning off releases an active waiting hold', (
    tester,
  ) async {
    final coordinator = LocationChatScrollCoordinator();
    addTearDown(coordinator.dispose);
    await tester.pumpWidget(tree(coordinator));
    await tester.pump();
    await tester.pumpWidget(tree(coordinator, waiting: 'round-1'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(coordinator.isDetached, isTrue);

    await tester.pumpWidget(
      tree(coordinator, waiting: 'round-1', positioningEnabled: false),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final position = coordinator.controller.position;
    expect(position.pixels, closeTo(position.maxScrollExtent, 0.1));
    expect(coordinator.isDetached, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('positioning off does not move a manually detached reader', (
    tester,
  ) async {
    final coordinator = LocationChatScrollCoordinator();
    addTearDown(coordinator.dispose);
    await tester.pumpWidget(tree(coordinator, positioningEnabled: false));
    await tester.pump();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 200));
    await tester.pumpAndSettle();
    final held = coordinator.controller.position.pixels;
    expect(coordinator.isReadingHistory, isTrue);
    await tester.pumpWidget(
      tree(coordinator, waiting: 'round-1', positioningEnabled: false),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(coordinator.controller.position.pixels, closeTo(held, 0.1));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final goOn in [false, true]) {
    for (final secondScroll in [false, true]) {
      testWidgets(
        '${goOn ? 'Go On' : 'Send'} follows the real bottom when waiting positioning is off (second scroll: $secondScroll)',
        (tester) async {
          final coordinator = LocationChatScrollCoordinator();
          addTearDown(coordinator.dispose);
          await tester.pumpWidget(
            tree(
              coordinator,
              positioningEnabled: false,
              secondScroll: secondScroll,
            ),
          );
          await tester.pump();
          await tester.pumpWidget(
            tree(
              coordinator,
              waiting: 'round-1',
              goOn: goOn,
              positioningEnabled: false,
              secondScroll: secondScroll,
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          final position = coordinator.controller.position;
          expect(
            tester.getBottomLeft(find.byType(ChatReplyWaitingBubble)).dy,
            greaterThan(300),
          );
          expect(position.pixels, closeTo(position.maxScrollExtent, 0.1));
          expect(coordinator.isDetached, isFalse);

          await tester.pumpWidget(
            tree(
              coordinator,
              count: 21,
              positioningEnabled: false,
              secondScroll: secondScroll,
            ),
          );
          await tester.pump();
          expect(position.pixels, closeTo(position.maxScrollExtent, 0.1));
          await tester.pumpWidget(
            tree(
              coordinator,
              count: 21,
              suffix: '\nStreaming reply' * 15,
              positioningEnabled: false,
              secondScroll: secondScroll,
            ),
          );
          await tester.pump(const Duration(milliseconds: 300));
          expect(position.pixels, closeTo(position.maxScrollExtent, 0.1));
          expect(coordinator.isDetached, isFalse);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }

  for (final goOn in [false, true]) {
    testWidgets('custom reserve applies to ${goOn ? 'Go On' : 'Send'}', (
      tester,
    ) async {
      final coordinator = LocationChatScrollCoordinator();
      addTearDown(coordinator.dispose);
      await tester.pumpWidget(tree(coordinator, reserveFraction: 0.5));
      await tester.pump();
      await tester.pumpWidget(
        tree(coordinator, waiting: 'custom', goOn: goOn, reserveFraction: 0.5),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        tester.getTopLeft(find.byType(ChatReplyWaitingBubble)).dy,
        closeTo(180, 1),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'only message body crossing the viewport counts as content below',
    (tester) async {
      final coordinator = LocationChatScrollCoordinator();
      addTearDown(coordinator.dispose);
      await tester.pumpWidget(tree(coordinator));
      await tester.pump();
      final bubble = find.ancestor(
        of: find.text('Message 19'),
        matching: find.byType(ChatMessageBubble),
      );
      final position = coordinator.controller.position;
      position.jumpTo(position.pixels + tester.getBottomLeft(bubble).dy - 360);
      await tester.pump();
      await tester.pump();
      expect(position.maxScrollExtent - position.pixels, greaterThan(0));
      expect(coordinator.hasMessageContentBelowViewport, isFalse);
      position.jumpTo(position.pixels - 2);
      await tester.pump();
      await tester.pump();
      expect(coordinator.hasMessageContentBelowViewport, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final secondScroll in [false, true]) {
    testWidgets(
      'manual pull consumes temporary tail permanently (second scroll: $secondScroll)',
      (tester) async {
        final coordinator = LocationChatScrollCoordinator();
        addTearDown(coordinator.dispose);
        await tester.pumpWidget(tree(coordinator, secondScroll: secondScroll));
        await tester.pump();
        final naturalExtent = coordinator.controller.position.maxScrollExtent;
        await tester.pumpWidget(
          tree(coordinator, waiting: 'round-1', secondScroll: secondScroll),
        );
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        final position = coordinator.controller.position;
        final reservedExtent = position.maxScrollExtent;
        final bubble = find.byType(ChatReplyWaitingBubble);
        final bubbleTop = tester.getTopLeft(bubble).dy;
        final gesture = await tester.startGesture(const Offset(200, 160));
        await gesture.moveBy(const Offset(0, 80));
        await tester.pump();
        await tester.pump();
        final reducedExtent = position.maxScrollExtent;
        expect(reducedExtent, lessThan(reservedExtent - 40));
        expect(tester.getTopLeft(bubble).dy, greaterThan(bubbleTop + 40));
        expect(coordinator.isDetached, isTrue);

        // Reverse this same gesture: the consumed space cannot be pulled back.
        await gesture.moveBy(const Offset(0, -60));
        await tester.pump();
        expect(position.maxScrollExtent, closeTo(reducedExtent, 0.1));
        await gesture.up();
        await tester.pump(const Duration(seconds: 1));
        expect(
          position.maxScrollExtent,
          lessThanOrEqualTo(reducedExtent + 0.1),
        );

        await tester.pumpWidget(tree(coordinator, secondScroll: secondScroll));
        await tester.pump();
        await tester.drag(find.byType(Scrollable).first, const Offset(0, 400));
        await tester.pumpAndSettle();
        // After all space is consumed, the genuine timeline is still intact.
        expect(position.maxScrollExtent, closeTo(naturalExtent, 0.1));
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -800));
        await tester.pumpAndSettle();
        expect(position.maxScrollExtent, closeTo(naturalExtent, 0.1));
        expect(find.text('Message 19'), findsOneWidget);
        expect(coordinator.isAtBottom, isTrue);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final scenario in [
    (secondScroll: false, reserve: 0.75, positioningEnabled: true),
    (secondScroll: true, reserve: 0.75, positioningEnabled: true),
    (secondScroll: false, reserve: 0.5, positioningEnabled: true),
    (secondScroll: true, reserve: 0.5, positioningEnabled: true),
    (secondScroll: false, reserve: 0.75, positioningEnabled: false),
    (secondScroll: true, reserve: 0.75, positioningEnabled: false),
  ]) {
    final secondScroll = scenario.secondScroll;
    final positioningEnabled = scenario.positioningEnabled;
    testWidgets(
      'regenerate ${positioningEnabled ? 'shares reply positioning' : 'follows the real bottom'} (second scroll: $secondScroll, reserve: ${scenario.reserve})',
      (tester) async {
        final coordinator = LocationChatScrollCoordinator();
        addTearDown(coordinator.dispose);
        var waiting = false;
        var regenerating = false;
        var regenerationDispatchRevision = 0;
        var currentCardId = 1;
        late StateSetter update;
        final rows = messages(20, suffix: '\nOriginal reply line' * 4);
        var renderedRows = rows;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 390,
                height: 360,
                child: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return LocationChatAnchoredMessageList(
                      coordinator: coordinator,
                      replyWaitingPositioningEnabled: positioningEnabled,
                      replyViewportReserveFraction: scenario.reserve,
                      messages: renderedRows,
                      topTitle: secondScroll ? 'Start' : '',
                      oldestEdgeNoticeRequiresSecondScroll: secondScroll,
                      showDateDividers: false,
                      goOnAwaitingContentIdentity: waiting
                          ? 'waiting-round'
                          : null,
                      replyActionsIdentity: 'round',
                      replyCurrentCardId: currentCardId,
                      replyCards: [
                        LocationChatReplyCard(id: 1, messages: [rows.last]),
                        if (currentCardId == 2)
                          LocationChatReplyCard(
                            id: 2,
                            messages: [renderedRows.last],
                          ),
                      ],
                      replyRegenerationInProgress: regenerating,
                      replyRegenerationDispatchRevision:
                          regenerationDispatchRevision,
                      regenerateFeature: LocationChatRegenerateFeature(
                        state: regenerating
                            ? LocationChatReplyActionState.busy
                            : LocationChatReplyActionState.idle,
                        onInvoke: () => update(() {
                          regenerating = true;
                          regenerationDispatchRevision++;
                        }),
                      ),
                      style: ChatUiStyleConfig.standard.copyWith(
                        messageListPadding: EdgeInsets.zero,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final position = coordinator.controller.position;
        final naturalExtent = position.maxScrollExtent;
        update(() => waiting = true);
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        update(() => waiting = false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        if (positioningEnabled) {
          expect(position.maxScrollExtent, greaterThan(naturalExtent + 100));
        } else {
          expect(position.pixels, closeTo(position.maxScrollExtent, 0.1));
        }
        await tester.tap(find.bySemanticsLabel('Regenerate'));
        await tester.pump();
        await tester.pump();
        for (final duration in [80, 80, 800]) {
          await tester.pump(Duration(milliseconds: duration));
        }
        expect(
          tester.getSize(find.byType(LocationChatReplyCardSwitcher)).height,
          0,
        );
        if (positioningEnabled) {
          expect(
            tester.getTopLeft(find.byType(LocationChatReplyCardSwitcher)).dy,
            closeTo(360 * (1 - scenario.reserve), 0.1),
            reason:
                'Regenerate must use the same top anchor as Send and Go On.',
          );
          expect(coordinator.isDetached, isTrue);
          expect(coordinator.isReadingHistory, isFalse);
        } else {
          expect(position.pixels, closeTo(position.maxScrollExtent, 0.1));
          expect(coordinator.isDetached, isFalse);
        }
        final held = position.pixels;
        update(() {
          currentCardId = 2;
          renderedRows = [
            ...rows.take(19),
            ChatMessageVm(
              localId: 'candidate',
              senderId: 'peer',
              senderName: 'Peer',
              text: 'New candidate\n' * 30,
              isMe: false,
              status: 'streaming',
            ),
          ];
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        if (positioningEnabled) {
          expect(
            position.pixels,
            closeTo(held, 0.1),
            reason:
                'Changing candidate IDs and growing the reply must not reposition.',
          );
          expect(position.maxScrollExtent, greaterThan(held + 100));
        } else {
          expect(position.pixels, closeTo(position.maxScrollExtent, 0.1));
          expect(position.pixels, greaterThan(held));
        }
        update(() => regenerating = false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        if (positioningEnabled) {
          expect(position.pixels, closeTo(held, 0.1));
        } else {
          expect(position.pixels, closeTo(position.maxScrollExtent, 0.1));
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('manual scroll interrupts waiting animation and later arrivals', (
    tester,
  ) async {
    final coordinator = LocationChatScrollCoordinator();
    addTearDown(coordinator.dispose);
    await tester.pumpWidget(tree(coordinator));
    await tester.pump();
    await tester.pumpWidget(tree(coordinator, waiting: 'round-1'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 140));
    await tester.pump(const Duration(milliseconds: 400));
    final held = coordinator.controller.position.pixels;
    expect(coordinator.isReadingHistory, isTrue);
    await tester.pumpWidget(tree(coordinator, count: 23));
    await tester.pump(const Duration(milliseconds: 300));
    expect(coordinator.controller.position.pixels, closeTo(held, 1));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('waiting does not move a manually detached reader', (
    tester,
  ) async {
    final coordinator = LocationChatScrollCoordinator();
    addTearDown(coordinator.dispose);
    await tester.pumpWidget(tree(coordinator));
    await tester.pump();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 200));
    await tester.pumpAndSettle();
    final held = coordinator.controller.position.pixels;
    await tester.pumpWidget(tree(coordinator, waiting: 'round-1'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(coordinator.controller.position.pixels, closeTo(held, 1));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'visible reply controls do not pull a detached viewport during output',
    (tester) async {
      final coordinator = LocationChatScrollCoordinator();
      addTearDown(coordinator.dispose);
      await tester.pumpWidget(tree(coordinator, showReplyActions: true));
      await tester.pumpAndSettle();

      final position = coordinator.controller.position;
      coordinator.deactivate();
      position.jumpTo(position.maxScrollExtent - 30);
      await tester.pump();

      final viewport = find.byType(LocationChatAnchoredMessageList);
      final replyControls = find.byKey(
        const ValueKey<String>('location-chat-reply-control:round-1'),
        skipOffstage: false,
      );
      expect(replyControls, findsOneWidget);
      expect(
        tester.getRect(replyControls).overlaps(tester.getRect(viewport)),
        isTrue,
      );
      final visibleMessage = find.text('Message 18');
      expect(visibleMessage, findsOneWidget);
      final visibleTop = tester.getTopLeft(visibleMessage).dy;
      final heldPixels = position.pixels;

      await tester.pumpWidget(
        tree(
          coordinator,
          showReplyActions: true,
          replyPresentationRevision: 1,
          suffix: '\nStreaming reply' * 12,
        ),
      );
      await tester.pump();

      expect(position.pixels, closeTo(heldPixels, 0.1));
      expect(tester.getTopLeft(visibleMessage).dy, closeTo(visibleTop, 0.1));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'short history keeps loading in upper quarter without overscroll',
    (tester) async {
      final coordinator = LocationChatScrollCoordinator();
      addTearDown(coordinator.dispose);
      await tester.pumpWidget(tree(coordinator, count: 1));
      await tester.pump();
      await tester.pumpWidget(tree(coordinator, count: 1, waiting: 'round-1'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        tester.getTopLeft(find.byType(ChatReplyWaitingBubble)).dy,
        lessThanOrEqualTo(91),
      );
      expect(coordinator.controller.position.pixels, greaterThanOrEqualTo(0));
      final held = coordinator.controller.position.pixels;
      await tester.pumpWidget(tree(coordinator, count: 1));
      await tester.pump(const Duration(milliseconds: 300));
      expect(coordinator.controller.position.pixels, closeTo(held, 1));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('leaving and reentering clears the previous waiting space', (
    tester,
  ) async {
    final coordinator = LocationChatScrollCoordinator();
    addTearDown(coordinator.dispose);
    await tester.pumpWidget(tree(coordinator));
    await tester.pump();
    await tester.pumpWidget(tree(coordinator, waiting: 'round-1'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    coordinator.deactivate();
    await tester.pumpWidget(tree(coordinator, active: false));
    coordinator.enter();
    await tester.pumpWidget(tree(coordinator));
    await tester.pump();
    expect(coordinator.shouldFollowLatest, isTrue);
    final lastMessageBottom = tester.getBottomLeft(find.text('Message 19')).dy;
    expect(lastMessageBottom, greaterThan(280));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('next Go On positions once again after a held reply', (
    tester,
  ) async {
    final coordinator = LocationChatScrollCoordinator();
    addTearDown(coordinator.dispose);
    await tester.pumpWidget(tree(coordinator));
    await tester.pump();
    for (final round in [1, 2]) {
      await tester.pumpWidget(
        tree(
          coordinator,
          count: 20 + round,
          waiting: 'round-$round',
          goOn: true,
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        tester.getTopLeft(find.byType(ChatReplyWaitingBubble)).dy,
        closeTo(90, 1),
      );
      final held = coordinator.controller.position.pixels;
      await tester.pumpWidget(tree(coordinator, count: 21 + round));
      await tester.pump(const Duration(milliseconds: 300));
      expect(coordinator.controller.position.pixels, closeTo(held, 1));
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
