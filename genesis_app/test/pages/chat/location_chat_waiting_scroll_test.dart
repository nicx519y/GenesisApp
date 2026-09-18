import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/debug/location_chat_bubble_layout_settings.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/features/location_chat_reply/regenerate/regenerate.dart';
import 'package:genesis_flutter_android/features/location_chat_reply/shared/reply_action_state.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_reply_card_switcher.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_scroll_coordinator.dart';

double messageBubbleBottom(WidgetTester tester, String id) {
  final row = find.byWidgetPredicate(
    (widget) => widget is ChatMessageRow && widget.message.localId == id,
  );
  return ChatBubbleGeometry.globalBoundsOf(tester.renderObject(row))!.bottom;
}

double waitingPredecessorBottom(WidgetTester tester) {
  final list = tester.widget<LocationChatAnchoredMessageList>(
    find.byType(LocationChatAnchoredMessageList),
  );
  return messageBubbleBottom(
    tester,
    list.preAckWaitingAfterMessageLocalId ??
        list.loadingAfterMessageLocalId ??
        list.messages.last.localId,
  );
}

void main() {
  testWidgets('Send promotes old card without replaying above the user row', (
    tester,
  ) async {
    final coordinator = LocationChatScrollCoordinator();
    addTearDown(coordinator.dispose);
    Widget build(int phase) {
      final old = ChatMessageVm(
        localId: phase == 2 ? 'formal-42' : 'card-42',
        globalMessageId: 42,
        senderId: 'peer',
        senderName: 'Peer',
        isMe: false,
        text: 'old reply already displayed',
        status: 'sent',
      );
      final sent = ChatMessageVm(
        localId: 'new-send',
        senderId: 'me',
        senderName: 'Me',
        isMe: true,
        text: 'new user message',
        status: 'sent',
      );
      final fresh = ChatMessageVm(
        localId: 'new-reply',
        globalMessageId: 43,
        senderId: 'peer',
        senderName: 'Peer',
        isMe: false,
        text: 'new reply below the user',
        status: 'sent',
      );
      return MaterialApp(
        home: Scaffold(
          body: ChatStreamingEffects(
            settings: LocationChatBubbleLayoutSettings.defaults.copyWith(
              animateStreamingHeight: false,
            ),
            presentationRevision: phase,
            child: LocationChatAnchoredMessageList(
              coordinator: coordinator,
              topTitle: '',
              showDateDividers: false,
              messages: [old, if (phase > 0) sent, if (phase == 2) fresh],
              waitingPositionIdentity: phase == 0 ? null : 'send-operation',
              replyWaitingPositioningEnabled: false,
              replyActionsIdentity: 'round',
              replyCardBindingIdentity: 'round',
              replyCurrentCardId: phase + 1,
              replyCards: [
                LocationChatReplyCard(
                  id: phase + 1,
                  messages: [phase == 2 ? fresh : old],
                ),
              ],
              style: kLocationChatStyle,
            ),
          ),
        ),
      );
    }

    Finder row(String id) => find.byWidgetPredicate(
      (w) => w is ChatMessageRow && w.message.localId == id,
    );
    double progress(String id) => ChatStreamingBody.revealedGraphemesOf(
      tester.element(
        find.descendant(of: row(id), matching: find.byType(ChatStreamingBody)),
      ),
    );
    await tester.pumpWidget(build(0));
    await tester.pumpAndSettle();
    expect(progress('card-42'), 'old reply already displayed'.length);
    await tester.pumpWidget(build(1));
    expect(progress('card-42'), 'old reply already displayed'.length);
    await tester.pumpWidget(build(2));
    expect(progress('formal-42'), 'old reply already displayed'.length);
    expect(progress('new-reply'), 0);
    await tester.pump(const Duration(milliseconds: 12));
    expect(progress('new-reply'), closeTo(2, .001));
    expect(progress('formal-42'), 'old reply already displayed'.length);
    expect(row('formal-42'), findsOneWidget);
    expect(row('new-reply'), findsOneWidget);
    expect(
      tester.getTopLeft(row('formal-42')).dy,
      lessThan(tester.getTopLeft(row('new-send')).dy),
    );
    expect(
      tester.getTopLeft(row('new-reply')).dy,
      greaterThan(tester.getTopLeft(row('new-send')).dy),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final mode in ['send', 'go-on', 'regenerate', 'regenerate-terminal']) {
    final regenerate = mode.startsWith('regenerate');
    final terminal = mode == 'regenerate-terminal';
    final goOn = mode == 'go-on';
    testWidgets(
      'loading to large serial stream preserves held pixels ($mode)',
      (tester) async {
        final coordinator = LocationChatScrollCoordinator();
        addTearDown(coordinator.dispose);
        var phase = 0;
        final history = [
          for (var i = 0; i < 70; i++)
            ChatMessageVm(
              localId: 'h-$i',
              senderId: 'p',
              senderName: 'P',
              text: ('history $i\n' * (i % 5 + 1)).trim(),
              isMe: false,
              status: 'sent',
            ),
        ];
        final oldReply = ChatMessageVm(
          localId: 'old',
          senderId: 'p',
          senderName: 'P',
          text: 'Old reply\n' * 20,
          isMe: false,
          status: 'sent',
        );
        Widget build() {
          final incoming = [
            for (var i = 0; i < 3; i++)
              ChatMessageVm(
                localId: 'new-$i',
                senderId: 'p-$i',
                senderName: 'P',
                text: 'Large incoming chunk\n' * 100,
                isMe: false,
                status: terminal ? 'sent' : 'streaming',
              ),
          ];
          return MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 360,
                child: ChatStreamingEffects(
                  settings: LocationChatBubbleLayoutSettings.defaults,
                  presentationRevision: phase,
                  child: LocationChatAnchoredMessageList(
                    coordinator: coordinator,
                    topTitle: '',
                    showDateDividers: false,
                    messages: [
                      ...history,
                      if (phase < 2 || !regenerate) oldReply,
                      if (phase == 2) ...incoming,
                    ],
                    waitingPositionIdentity: phase == 0 ? null : 'operation',
                    loadingAfterMessageLocalId: phase == 1 && !regenerate
                        ? 'old'
                        : null,
                    loadingIdentity: phase == 1 ? 'operation' : null,
                    replyActionsIdentity: regenerate || goOn
                        ? 'round-${goOn && phase == 2 ? 2 : 1}'
                        : null,
                    replyCardBindingIdentity: regenerate || goOn
                        ? 'round-${goOn && phase == 2 ? 2 : 1}'
                        : null,
                    goOnAwaitingContentIdentity: goOn && phase == 1
                        ? 'go-on'
                        : null,
                    replyRegenerationInProgress:
                        regenerate && phase > 0 && !(terminal && phase == 2),
                    replyRegenerationDispatchRevision: phase == 0 ? 0 : 1,
                    replyCurrentCardId: phase < 2 ? 1 : 2,
                    replyCards: regenerate || goOn
                        ? [
                            if (!goOn || phase < 2)
                              LocationChatReplyCard(
                                id: 1,
                                messages: [oldReply],
                              ),
                            if (phase > 0 && (regenerate || phase == 2))
                              LocationChatReplyCard(
                                id: 2,
                                messages: phase == 2 ? incoming : const [],
                              ),
                          ]
                        : const [],
                    style: kLocationChatStyle,
                  ),
                ),
              ),
            ),
          );
        }

        await tester.pumpWidget(build());
        await tester.pumpAndSettle();
        coordinator.prepareWaitingReplyPosition();
        phase = 1;
        await tester.pumpWidget(build());
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();
        final held = coordinator.controller.position.pixels;
        phase = 2;
        await tester.pumpWidget(build());
        for (var frame = 0; frame < 150; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(
            coordinator.controller.position.pixels,
            closeTo(held, .01),
            reason: 'frame=$frame',
          );
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final inCard in [false, true]) {
    testWidgets(
      'actual message rows reveal one bubble at a time (card=$inCard)',
      (tester) async {
        final coordinator = LocationChatScrollCoordinator();
        addTearDown(coordinator.dispose);
        Widget build({bool complete = false}) {
          final rows = [
            for (var i = 0; i < 2; i++)
              ChatMessageVm(
                localId: 'serial-$i',
                senderId: 'peer-$i',
                senderName: 'Peer',
                isMe: false,
                text: 'a' * 20,
                status: complete ? 'sent' : 'streaming',
              ),
          ];
          return MaterialApp(
            home: Scaffold(
              body: ChatStreamingEffects(
                settings: LocationChatBubbleLayoutSettings.defaults.copyWith(
                  animateStreamingHeight: false,
                ),
                child: LocationChatAnchoredMessageList(
                  coordinator: coordinator,
                  topTitle: '',
                  showDateDividers: false,
                  messages: rows,
                  replyActionsIdentity: inCard ? 'round' : null,
                  replyCardBindingIdentity: inCard ? 'round' : null,
                  replyCurrentCardId: inCard ? 1 : 0,
                  replyCards: inCard
                      ? [LocationChatReplyCard(id: 1, messages: rows)]
                      : const [],
                  style: kLocationChatStyle,
                ),
              ),
            ),
          );
        }

        double progress(int index) => ChatStreamingBody.revealedGraphemesOf(
          tester.element(
            find.descendant(
              of: find.byWidgetPredicate(
                (w) =>
                    w is ChatMessageRow && w.message.localId == 'serial-$index',
              ),
              matching: find.byType(ChatStreamingBody),
            ),
          ),
        );
        await tester.pumpWidget(build());
        await tester.pump(const Duration(milliseconds: 30));
        expect(progress(0), closeTo(5, .001));
        expect(progress(1), 0);
        await tester.pumpWidget(build(complete: true));
        await tester.pump(const Duration(milliseconds: 30));
        expect(progress(0), closeTo(10, .001));
        expect(progress(1), 0);
        await tester.pumpAndSettle(const Duration(milliseconds: 16));
        expect(progress(0), 20);
        expect(progress(1), 20);
        expect(tester.takeException(), isNull);
      },
    );
  }

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
    ChatUiStyleConfig? bubbleStyle,
    TextScaler textScaler = TextScaler.noScaling,
    String? operation,
    String? clientMsgId,
  }) => MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: child!,
    ),
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
              waitingPositionIdentity: operation,
              waitingPositionClientMsgId: clientMsgId,
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
              style: (bubbleStyle ?? ChatUiStyleConfig.standard).copyWith(
                messageListPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      ),
    ),
  );

  test(
    'reply position uses a common reference height but visible scroll bounds',
    () {
      for (final viewportHeight in [60.0, 160.0, 260.0, 360.0]) {
        final result = locationChatWaitingPosition(
          pixels: 120,
          bubbleBottom: 340,
          viewportTop: 40,
          viewportHeight: viewportHeight,
          referenceViewportHeight: 360,
          reserveFraction: 0.75,
        );
        expect(420 - result.offset, viewportHeight < 90 ? viewportHeight : 90);
        expect(result.minExtent, result.offset + viewportHeight);
      }
    },
  );

  test(
    'position formula accounts for boundaries without bubble dimensions',
    () {
      final result = locationChatWaitingPosition(
        pixels: 120,
        bubbleBottom: 340,
        viewportTop: 40,
        viewportHeight: 360,
        reserveFraction: 0.75,
      );
      expect(result.offset, 330);
      expect(result.minExtent, 690);
      expect(result.preparationExtent, 690);
      final short = locationChatWaitingPosition(
        pixels: 0,
        bubbleBottom: 45,
        viewportTop: 10,
        viewportHeight: 360,
        reserveFraction: 0.75,
      );
      expect(short.offset, 0);
      expect(short.minExtent, 360);
    },
  );

  for (final goOn in [false, true]) {
    for (final secondScroll in [false, true]) {
      testWidgets(
        'actual bubble edge survives layout changes: goOn=$goOn second=$secondScroll',
        (tester) async {
          final coordinator = LocationChatScrollCoordinator();
          addTearDown(coordinator.dispose);
          for (var variant = 0; variant < 3; variant++) {
            final style = ChatUiStyleConfig.standard.copyWith(
              avatarSize: 45 + variant * 45,
              rowBottomPadding: 7 + variant * 19,
              bubblePadding: EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8 + variant * 7,
              ),
            );
            Widget build({String? waiting}) => tree(
              coordinator,
              waiting: waiting,
              goOn: goOn,
              secondScroll: secondScroll,
              operation: waiting,
              bubbleStyle: style,
              textScaler: TextScaler.linear(1 + variant * 0.3),
            );
            await tester.pumpWidget(build());
            await tester.pumpAndSettle();
            coordinator.prepareWaitingReplyPosition();
            await tester.pumpWidget(build(waiting: 'operation-$variant'));
            await tester.pump();
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 240));
            await tester.pump();
            expect(
              waitingPredecessorBottom(tester),
              closeTo(90, 1 / tester.view.devicePixelRatio),
            );
          }
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }

  for (final enabled in [true, false]) {
    testWidgets(
      'same-frame send ACK and final reply retain the client bubble anchor (positioning=$enabled)',
      (tester) async {
        final coordinator = LocationChatScrollCoordinator();
        addTearDown(coordinator.dispose);
        var rows = messages(20);
        String? operation;
        Widget build() => MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 360,
              child: ChatStreamingEffects(
                settings: LocationChatBubbleLayoutSettings.defaults,
                child: LocationChatAnchoredMessageList(
                  coordinator: coordinator,
                  messages: rows,
                  topTitle: '',
                  showDateDividers: false,
                  waitingPositionIdentity: operation,
                  replyWaitingPositioningEnabled: enabled,
                  waitingPositionClientMsgId: operation == null
                      ? null
                      : 'send-client',
                  style: ChatUiStyleConfig.standard.copyWith(
                    messageListPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpWidget(build());
        await tester.pump();
        if (enabled) coordinator.prepareWaitingReplyPosition();
        operation = 'send-1';
        rows = [
          ...rows,
          ChatMessageVm(
            localId: 'canonical-send',
            clientMsgId: 'send-client',
            senderId: 'me',
            senderName: 'Me',
            isMe: true,
            text: 'Sent from composer or inspiration',
            status: 'sent',
          ),
          ChatMessageVm(
            localId: 'terminal-reply',
            senderId: 'peer',
            senderName: 'Peer',
            isMe: false,
            text: 'large terminal reply ' * 30,
            status: 'sent',
          ),
        ];
        await tester.pumpWidget(build());
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 240));
        await tester.pump();
        if (enabled) {
          expect(
            messageBubbleBottom(tester, 'canonical-send'),
            closeTo(54, 0.01),
          );
        }
        final held = coordinator.controller.position.pixels;
        final terminalBody = find.descendant(
          of: find.byWidgetPredicate(
            (w) => w is ChatMessageRow && w.message.localId == 'terminal-reply',
          ),
          matching: find.byType(ChatStreamingBody),
        );
        expect(
          ChatStreamingBody.revealedGraphemesOf(tester.element(terminalBody)),
          lessThanOrEqualTo(
            240 /
                LocationChatBubbleLayoutSettings
                    .defaults
                    .effectiveStreamingTextDurationMs,
          ),
        );
        await tester.pump(const Duration(milliseconds: 240));
        if (enabled) {
          expect(coordinator.controller.position.pixels, closeTo(held, 0.01));
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'Go On then same-frame terminal Regenerate keeps the old snapshot through collapse',
    (tester) async {
      final coordinator = LocationChatScrollCoordinator();
      addTearDown(coordinator.dispose);
      final history = messages(19);
      final original = messages(20).last;
      final replacement = ChatMessageVm(
        localId: 'regenerated',
        senderId: 'peer',
        senderName: 'Peer',
        isMe: false,
        text: 'Fast complete regenerated message ' * 20,
        status: 'sent',
      );
      String? operation;
      var goOnWaiting = false;
      var revision = 0;
      Widget build() => MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 360,
            child: ChatStreamingEffects(
              settings: LocationChatBubbleLayoutSettings.defaults,
              child: NotificationListener<ScrollNotification>(
                onNotification: coordinator.handleScrollNotification,
                child: LocationChatAnchoredMessageList(
                  coordinator: coordinator,
                  messages: [
                    ...history,
                    if (revision == 0) original else replacement,
                  ],
                  topTitle: '',
                  showDateDividers: false,
                  replyViewportReserveFraction: 0.5,
                  waitingPositionIdentity: operation,
                  goOnAwaitingContentIdentity: goOnWaiting ? 'go-on' : null,
                  replyActionsIdentity: 'round',
                  replyCardBindingIdentity: 'round',
                  replyCurrentCardId: revision == 0 ? 1 : 2,
                  replyRegenerationDispatchRevision: revision,
                  // The terminal reply already arrived before this build.
                  replyRegenerationInProgress: false,
                  replyActionsMessageId: revision == 0
                      ? original.localId
                      : replacement.localId,
                  replyCards: [
                    LocationChatReplyCard(id: 1, messages: [original]),
                    if (revision != 0)
                      LocationChatReplyCard(id: 2, messages: [replacement]),
                  ],
                  style: ChatUiStyleConfig.standard.copyWith(
                    rowBottomPadding: 19,
                    messageListPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(build());
      await tester.pumpAndSettle();
      coordinator.prepareWaitingReplyPosition();
      operation = 'go-on';
      goOnWaiting = true;
      await tester.pumpWidget(build());
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 240));
      await tester.pump();
      expect(messageBubbleBottom(tester, original.localId), closeTo(180, 0.01));
      goOnWaiting = false;
      await tester.pumpWidget(build());
      await tester.pump();
      final deck = find.byType(
        LocationChatReplyCardSwitcher,
        skipOffstage: false,
      );
      final beforeTop = tester.getTopLeft(deck).dy;
      coordinator.prepareWaitingReplyPosition();
      operation = 'regenerate';
      revision++;
      await tester.pumpWidget(build());
      expect(tester.getTopLeft(deck).dy, closeTo(beforeTop, 0.01));
      expect(find.text(replacement.text), findsNothing);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 240));
      await tester.pump();
      expect(
        messageBubbleBottom(tester, history.last.localId),
        closeTo(180, 0.01),
      );
      final held = coordinator.controller.position.pixels;
      final alignedTop = tester.getTopLeft(deck).dy;
      var revealFrames = 0;
      for (var frame = 0; frame < 75; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        if (find.text(replacement.text).evaluate().isNotEmpty) revealFrames++;
        expect(coordinator.controller.position.pixels, closeTo(held, 0.01));
        expect(tester.getTopLeft(deck).dy, closeTo(alignedTop, 0.01));
      }
      expect(find.text(replacement.text), findsOneWidget);
      final body = find.descendant(
        of: find.byWidgetPredicate(
          (w) =>
              w is ChatMessageRow && w.message.localId == replacement.localId,
        ),
        matching: find.byType(ChatStreamingBody),
      );
      expect(
        ChatStreamingBody.revealedGraphemesOf(tester.element(body)),
        lessThanOrEqualTo(
          revealFrames *
              16 /
              LocationChatBubbleLayoutSettings
                  .defaults
                  .effectiveStreamingTextDurationMs,
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final variant in ['large-layout', 'empty-card', 'no-predecessor']) {
    testWidgets('regenerate measures the outside predecessor: $variant', (
      tester,
    ) async {
      final coordinator = LocationChatScrollCoordinator();
      addTearDown(coordinator.dispose);
      final history = variant == 'no-predecessor'
          ? <ChatMessageVm>[]
          : messages(15);
      final card = variant == 'empty-card'
          ? <ChatMessageVm>[]
          : [
              ChatMessageVm(
                localId: 'card-only',
                senderId: 'peer',
                senderName: 'Peer',
                isMe: false,
                text: 'Old card',
                status: 'sent',
              ),
            ];
      var revision = 0;
      Widget build() => MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 360,
            child: MediaQuery(
              data: MediaQueryData.fromView(
                tester.view,
              ).copyWith(textScaler: const TextScaler.linear(1.6)),
              child: LocationChatAnchoredMessageList(
                coordinator: coordinator,
                messages: [...history, if (revision == 0) ...card],
                topTitle: '',
                showDateDividers: false,
                replyActionsIdentity: 'round',
                replyCardBindingIdentity: 'round',
                replyCurrentCardId: revision == 0 ? 1 : 2,
                replyRegenerationInProgress: revision > 0,
                replyRegenerationDispatchRevision: revision,
                replyCards: [
                  LocationChatReplyCard(id: 1, messages: card),
                  if (revision > 0)
                    const LocationChatReplyCard(id: 2, messages: []),
                ],
                style: ChatUiStyleConfig.standard.copyWith(
                  avatarSize: 110,
                  rowBottomPadding: 31,
                  bubblePadding: const EdgeInsets.all(19),
                  messageListPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(build());
      await tester.pumpAndSettle();
      revision++;
      await tester.pumpWidget(build());
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 240));
      await tester.pump();
      if (history.isEmpty) {
        expect(
          coordinator.isDetached,
          isFalse,
          reason:
              'No card-internal bubble may substitute for the missing predecessor.',
        );
      } else {
        expect(
          messageBubbleBottom(tester, history.last.localId),
          closeTo(54, 1 / tester.view.devicePixelRatio),
        );
      }
      final held = coordinator.controller.position.pixels;
      for (var frame = 0; frame < 55; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        if (history.isNotEmpty) {
          expect(coordinator.controller.position.pixels, closeTo(held, .01));
          expect(
            messageBubbleBottom(tester, history.last.localId),
            closeTo(54, .01),
          );
        }
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final secondScroll in [false, true]) {
    testWidgets(
      'keyboard consumes waiting tail before moving bubbles (second=$secondScroll)',
      (tester) async {
        final coordinator = LocationChatScrollCoordinator();
        addTearDown(coordinator.dispose);
        final rows = messages(20);
        var started = false;
        Widget build(double height) => MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: height,
              child: NotificationListener<ScrollNotification>(
                onNotification: coordinator.handleScrollNotification,
                child: LocationChatAnchoredMessageList(
                  coordinator: coordinator,
                  messages: rows,
                  topTitle: secondScroll ? 'Start' : '',
                  oldestEdgeNoticeRequiresSecondScroll: secondScroll,
                  showDateDividers: false,
                  waitingPositionIdentity: started ? 'waiting' : null,
                  style: ChatUiStyleConfig.standard.copyWith(
                    messageListPadding: const EdgeInsets.fromLTRB(7, 9, 11, 13),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpWidget(build(500));
        await tester.pumpAndSettle();
        final position = coordinator.controller.position;
        final naturalExtent =
            position.maxScrollExtent + position.viewportDimension;
        coordinator.prepareWaitingReplyPosition();
        started = true;
        await tester.pumpWidget(build(500));
        await tester.pumpAndSettle();
        final held = position.pixels;
        final bubbleBottom = messageBubbleBottom(tester, rows.last.localId);
        // A tap and focus notification can both request focus in one frame.
        for (var request = 0; request < 2; request++) {
          coordinator.requestBottom(
            reason: LocationChatBottomReason.composerFocus,
            behavior: LocationChatBottomBehavior.jump,
          );
        }
        await tester.pump();
        expect(position.pixels, closeTo(held, .01));
        final generation = coordinator.commandGeneration;
        for (final height in [460.0, 400.0, 320.0, 220.0, 140.0]) {
          await tester.pumpWidget(build(height));
          await tester.pump(const Duration(milliseconds: 16));
          final expected = (naturalExtent - height).clamp(
            held,
            double.infinity,
          );
          expect(
            position.pixels,
            closeTo(expected, .01),
            reason: 'height=$height',
          );
          expect(
            messageBubbleBottom(tester, rows.last.localId),
            closeTo(bubbleBottom - (expected - held), .01),
          );
          expect(coordinator.commandGeneration, generation);
        }
        // Dismissal restores the available space without a second positioning.
        await tester.pumpWidget(build(500));
        await tester.pump();
        expect(position.pixels, closeTo(held, .01));
        expect(
          messageBubbleBottom(tester, rows.last.localId),
          closeTo(bubbleBottom, .01),
        );
        await tester.drag(
          find.byType(LocationChatAnchoredMessageList),
          const Offset(0, 80),
        );
        await tester.pumpAndSettle();
        final manualPixels = position.pixels;
        expect(coordinator.isReadingHistory, isTrue);
        await tester.pumpWidget(build(460));
        await tester.pump();
        expect(
          position.pixels,
          closeTo(manualPixels, .01),
          reason: 'A manual drag retires the keyboard consumption anchor.',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final mode in ['send', 'go-on', 'regenerate']) {
    for (final scenario in [
      (inset: 80.0, closing: false, secondScroll: false),
      (inset: 160.0, closing: false, secondScroll: false),
      (inset: 160.0, closing: true, secondScroll: false),
      (inset: 160.0, closing: true, secondScroll: true),
    ]) {
      final inset = scenario.inset;
      testWidgets('$mode keeps the closed-keyboard position ($scenario)', (
        tester,
      ) async {
        final coordinator = LocationChatScrollCoordinator();
        addTearDown(coordinator.dispose);
        final rows = messages(20);
        final regenerate = mode == 'regenerate';
        final anchorId = rows[regenerate ? 17 : 19].localId;
        var started = false;
        Widget build(double keyboard) => MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 360,
              child: Padding(
                padding: EdgeInsets.only(bottom: keyboard),
                child: LocationChatKeyboardInsetScope(
                  effectiveInset: keyboard,
                  child: LocationChatAnchoredMessageList(
                    coordinator: coordinator,
                    messages: rows,
                    topTitle: scenario.secondScroll ? 'Start' : '',
                    oldestEdgeNoticeRequiresSecondScroll: scenario.secondScroll,
                    showDateDividers: false,
                    waitingPositionIdentity: started ? 'operation' : null,
                    preAckWaitingIdentity: started && mode == 'send'
                        ? 'operation'
                        : null,
                    preAckWaitingAfterMessageLocalId: started && mode == 'send'
                        ? anchorId
                        : null,
                    goOnAwaitingContentIdentity: started && mode == 'go-on'
                        ? 'operation'
                        : null,
                    replyActionsIdentity: 'round',
                    replyCardBindingIdentity: 'round',
                    replyCurrentCardId: 1,
                    replyCards: regenerate
                        ? [
                            LocationChatReplyCard(
                              id: 1,
                              messages: rows.sublist(18),
                            ),
                          ]
                        : const [],
                    replyRegenerationInProgress: regenerate && started,
                    replyRegenerationDispatchRevision: regenerate && started
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
        await tester.pumpWidget(build(inset));
        await tester.pumpAndSettle();
        coordinator.prepareWaitingReplyPosition();
        started = true;
        await tester.pumpWidget(build(inset));
        await tester.pump();
        await tester.pump();
        if (scenario.closing) {
          // Grow the viewport before animateTo reaches its destination.
          // The tail must preserve the target, not just the current pixels.
          for (var keyboard = inset - 20; keyboard >= 0; keyboard -= 20) {
            await tester.pumpWidget(build(keyboard));
            await tester.pump(const Duration(milliseconds: 16));
          }
        }
        await tester.pump(const Duration(milliseconds: 240));
        await tester.pump();
        const expectedPosition = 360 * .15;
        expect(
          messageBubbleBottom(tester, anchorId),
          closeTo(expectedPosition, 1 / tester.view.devicePixelRatio),
        );
        final held = coordinator.controller.position.pixels;
        final generation = coordinator.commandGeneration;
        // Keyboard dismissal must not trigger a second positioning command.
        for (final keyboard in scenario.closing ? [0.0] : [inset / 2, 0.0]) {
          await tester.pumpWidget(build(keyboard));
          await tester.pump(const Duration(milliseconds: 16));
          expect(coordinator.controller.position.pixels, closeTo(held, .01));
          expect(
            messageBubbleBottom(tester, anchorId),
            closeTo(expectedPosition, .01),
          );
          expect(coordinator.commandGeneration, generation);
        }
        // Go On's waiting dots intentionally keep ticking until a reply arrives.
        await tester.pump(const Duration(milliseconds: 900));
        expect(coordinator.controller.position.pixels, closeTo(held, .01));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets(
    'pre-ACK Send uses the common reference and ACK reveals in place',
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
      expect(waitingPredecessorBottom(tester), closeTo(90, 1));
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
      expect(waitingPredecessorBottom(tester), closeTo(90, 1));
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
      expect(waitingPredecessorBottom(tester), closeTo(90, 1));
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
        await tester.pumpWidget(
          tree(coordinator, count: count, preAckWaiting: identity),
        );

        // The transaction lays out the actual target without first jumping to
        // the end of the old artificial tail, even from a history viewport.
        expect(coordinator.isDetached, isTrue);
        await tester.pump();
        expect(coordinator.isDetached, isTrue);
        expect(coordinator.isReadingHistory, isFalse);
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(waitingPredecessorBottom(tester), closeTo(90, 1));
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
    final waitingTop = tester
        .getTopLeft(find.byType(ChatReplyWaitingBubble))
        .dy;
    expect(waitingPredecessorBottom(tester), closeTo(90, 1));

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
      closeTo(waitingTop, 1),
      reason:
          'The reply uses the actual layout spacing after the anchored bubble.',
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
          expect(waitingBubble, findsOneWidget);
          expect(waitingPredecessorBottom(tester), closeTo(90, 1));
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
      expect(waitingPredecessorBottom(tester), closeTo(180, 1));
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
                        LocationChatReplyCard(
                          id: 1,
                          messages: rows.sublist(18),
                        ),
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
        await tester.pump(); // Start the positioning animation's first tick.
        await tester.pump(const Duration(milliseconds: 240));
        await tester.pump();
        final deck = find.byType(
          LocationChatReplyCardSwitcher,
          skipOffstage: false,
        );
        final alignedTop = tester.getTopLeft(deck).dy;
        final alignedPixels = position.pixels;
        if (positioningEnabled) {
          expect(
            messageBubbleBottom(tester, rows[17].localId),
            closeTo(360 * (1 - scenario.reserve), 0.1),
            reason: 'Regenerate aligns the bubble immediately above the card.',
          );
          expect(coordinator.isDetached, isTrue);
          expect(coordinator.isReadingHistory, isFalse);
        }
        for (var frame = 0; frame < 52; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          if (positioningEnabled) {
            expect(position.pixels, closeTo(alignedPixels, 0.01));
            expect(tester.getTopLeft(deck).dy, closeTo(alignedTop, 0.01));
          }
        }
        expect(tester.getSize(deck).height, 0);
        if (!positioningEnabled) {
          expect(position.pixels, closeTo(position.maxScrollExtent, 0.1));
          expect(coordinator.isDetached, isFalse);
        }
        final held = position.pixels;
        update(() {
          currentCardId = 2;
          renderedRows = [
            ...rows.take(18),
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
      expect(waitingPredecessorBottom(tester), lessThanOrEqualTo(91));
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
      expect(waitingPredecessorBottom(tester), closeTo(90, 1));
      final held = coordinator.controller.position.pixels;
      await tester.pumpWidget(tree(coordinator, count: 21 + round));
      await tester.pump(const Duration(milliseconds: 300));
      expect(coordinator.controller.position.pixels, closeTo(held, 1));
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
