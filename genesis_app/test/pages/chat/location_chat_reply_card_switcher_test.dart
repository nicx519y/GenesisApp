import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/features/location_chat_reply/edit/edit.dart';
import 'package:genesis_flutter_android/features/location_chat_reply/go_on/go_on.dart';
import 'package:genesis_flutter_android/features/location_chat_reply/inspiration/inspiration.dart';
import 'package:genesis_flutter_android/features/location_chat_reply/regenerate/regenerate.dart';
import 'package:genesis_flutter_android/features/location_chat_reply/shared/reply_action_state.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_reply_actions.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_reply_card_switcher.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_reply_layout_bridge.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_scroll_coordinator.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';

void main() {
  testWidgets('stable rows still render in-place message mutations', (
    tester,
  ) async {
    final coordinator = LocationChatScrollCoordinator();
    addTearDown(coordinator.dispose);
    final historyMessage = _message('history-mutable', 1);
    final replyMessage = _message('reply-mutable', 1);
    final messages = [historyMessage, replyMessage];
    final cards = [
      LocationChatReplyCard(id: 1, messages: [replyMessage]),
    ];
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return LocationChatAnchoredMessageList(
                coordinator: coordinator,
                topTitle: '',
                messages: messages,
                replyCards: cards,
                replyCurrentCardId: 1,
                replyActionsIdentity: 'mutable-round',
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    update(() {
      historyMessage.text = 'Changed history content';
      replyMessage.text = 'Changed reply content';
    });
    await tester.pumpAndSettle();
    expect(
      find.text('Changed history content', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.text('Changed reply content', findRichText: true),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'single reply updates retain unaffected rows and invalidate date and tail neighbors',
    (tester) async {
      final coordinator = LocationChatScrollCoordinator();
      addTearDown(coordinator.dispose);
      ChatMessageVm message(String id, DateTime createdAt) => ChatMessageVm(
        localId: id,
        senderId: 'role',
        senderName: 'Role',
        text: id,
        isMe: false,
        status: 'sent',
        createdAt: createdAt,
      );
      final history = message('reuse-history', DateTime(2026, 9, 13, 22));
      var replies = [
        message('reuse-first', DateTime(2026, 9, 13, 23)),
        message('reuse-middle', DateTime(2026, 9, 14)),
        message('reuse-last', DateTime(2026, 9, 14, 0, 10)),
      ];
      var messages = [history, ...replies];
      var cards = [LocationChatReplyCard(id: 1, messages: replies)];
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return LocationChatAnchoredMessageList(
                  coordinator: coordinator,
                  topTitle: '',
                  messages: messages,
                  replyCards: cards,
                  replyCurrentCardId: 1,
                  replyActionsIdentity: 'reuse-round',
                  replyActionsMessageId: 'reuse-last',
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      ChatMessageRow row(String id) =>
          tester.widget<ChatMessageRow>(find.byKey(ValueKey(id)));
      final originalHistory = row('reuse-history');
      final originalFirst = row('reuse-first');
      final originalMiddle = row('reuse-middle');
      final originalLast = row('reuse-last');
      expect(originalMiddle.showDateDivider, isTrue);
      expect(originalLast.showDateDivider, isFalse);
      expect(
        originalLast.style!.rowBottomPadding,
        LocationChatReplyActions.contentBottomGap,
      );

      // The reconciler updates the existing VM during a streaming reply.
      update(() => replies[1].text = 'A newly streamed middle message');
      await tester.pumpAndSettle();
      final streamedMiddle = row('reuse-middle');
      expect(streamedMiddle, isNot(same(originalMiddle)));
      expect(streamedMiddle.message.text, 'A newly streamed middle message');
      expect(row('reuse-history'), same(originalHistory));
      expect(row('reuse-first'), same(originalFirst));
      expect(row('reuse-last'), same(originalLast));

      // Dividers use a gap greater than 30 minutes. Correcting the middle
      // timestamp changes its gap from 60 to 20, and the next gap from 10 to 50.
      update(() {
        replies = [
          replies.first,
          message('reuse-middle', DateTime(2026, 9, 13, 23, 20))
            ..text = replies[1].text,
          replies.last,
        ];
        cards = [LocationChatReplyCard(id: 1, messages: replies)];
        messages = [history, ...replies];
      });
      await tester.pumpAndSettle();
      final correctedMiddle = row('reuse-middle');
      final dateNeighbor = row('reuse-last');
      expect(correctedMiddle, isNot(same(streamedMiddle)));
      expect(correctedMiddle.showDateDivider, isFalse);
      expect(dateNeighbor, isNot(same(originalLast)));
      expect(dateNeighbor.showDateDivider, isTrue);
      expect(row('reuse-history'), same(originalHistory));
      expect(row('reuse-first'), same(originalFirst));

      // Inserting a live tail restores only the card's final normal row gap.
      update(() {
        messages = [
          history,
          ...replies,
          ChatMessageVm(
            localId: 'reuse-live-tail',
            senderId: 'me',
            senderName: 'Me',
            text: 'Live tail',
            isMe: true,
            status: 'sent',
            createdAt: DateTime(2026, 9, 14, 2),
          ),
        ];
      });
      await tester.pumpAndSettle();
      final tailNeighbor = row('reuse-last');
      expect(tailNeighbor, isNot(same(dateNeighbor)));
      expect(
        tailNeighbor.style!.rowBottomPadding,
        ChatUiStyleConfig.standard.rowBottomPadding,
      );
      expect(row('reuse-first'), same(originalFirst));
      expect(row('reuse-middle'), same(correctedMiddle));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('regenerate freezes mutable messages until the snapshot leaves', (
    tester,
  ) async {
    final key = GlobalKey<LocationChatReplyCardSwitcherState>();
    final original = _message('snapshot', 1)..text = 'Original text';
    final cards = [
      LocationChatReplyCard(id: 1, messages: [original]),
    ];
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return Align(
                alignment: Alignment.topLeft,
                child: LocationChatReplyCardSwitcher(
                  key: key,
                  identity: 'snapshot-round',
                  cards: cards,
                  currentCardId: 1,
                  regenerationInProgress: true,
                  cardBuilderIdentity: 'stable',
                  cardBuilder: (card) => SizedBox(
                    height: 200,
                    child: Text(card.messages.single.text),
                  ),
                  onCommit: (_) => true,
                  onBusyChanged: (_) {},
                  onWillChangeLayout: () {},
                ),
              );
            },
          ),
        ),
      ),
    );
    key.currentState!.beginRegenerateCollapse();
    await tester.pump();
    update(() => original.text = 'Mutated source');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Original text'), findsOneWidget);
    expect(find.text('Mutated source'), findsNothing);
    await tester.pump(const Duration(milliseconds: 500));
    // Deliver the terminal vsync as well as the nominal duration boundary.
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('Original text'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('child relayout during a switch uses its actual new height', (
    tester,
  ) async {
    final bridge = LocationChatReplyLayoutBridge();
    final scroll = ScrollController();
    final height = ValueNotifier<double>(400);
    final switcherKey = GlobalKey<LocationChatReplyCardSwitcherState>();
    final toolbarKey = GlobalKey();
    addTearDown(scroll.dispose);
    addTearDown(height.dispose);
    var current = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, update) => SingleChildScrollView(
              controller: scroll,
              physics: LocationChatBottomAnchoringScrollPhysics(
                shouldFollowLatest: () => false,
                takePresentationLayoutCorrection: () => bridge.correction,
              ),
              child: Column(
                children: [
                  const SizedBox(height: 1000),
                  LocationChatReplyCardSwitcher(
                    key: switcherKey,
                    identity: 'child-relayout',
                    currentCardId: current,
                    cards: const [
                      LocationChatReplyCard(id: 1, messages: []),
                      LocationChatReplyCard(id: 2, messages: []),
                    ],
                    layoutBridge: bridge,
                    cardBuilderIdentity: 'stable-child-layout',
                    cardBuilder: (card) => card.id == 1
                        ? const SizedBox(height: 120)
                        : ValueListenableBuilder<double>(
                            valueListenable: height,
                            builder: (context, value, _) =>
                                SizedBox(height: value),
                          ),
                    onWillChangeLayout: () => bridge.begin(
                      position: scroll.position,
                      commandGeneration: 1,
                      currentGeneration: () => 1,
                    ),
                    onCommit: (id) {
                      update(() => current = id);
                      return true;
                    },
                    onBusyChanged: (busy) {
                      if (!busy) {
                        WidgetsBinding.instance.addPostFrameCallback(
                          (_) => bridge.cancel(),
                        );
                      }
                    },
                  ),
                  SizedBox(key: toolbarKey, height: 48),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    scroll.jumpTo(scroll.position.maxScrollExtent);
    await tester.pumpAndSettle();
    final initialY = tester.getTopLeft(find.byKey(toolbarKey)).dy;
    switcherKey.currentState!.switchBy(1);
    await tester.pump();
    for (var frame = 0; frame < 36; frame++) {
      // Models an image finishing its layout without rebuilding the card body.
      if (frame == 10) height.value = 650;
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        tester.getTopLeft(find.byKey(toolbarKey)).dy,
        closeTo(initialY, 1),
        reason: 'child relayout at frame $frame',
      );
      expect(tester.takeException(), isNull);
    }
    expect(current, 2);
  });

  testWidgets(
    'vertical dragging during a card switch keeps control after commit',
    (tester) async {
      final coordinator = LocationChatScrollCoordinator();
      addTearDown(coordinator.dispose);
      final history = List.generate(30, (i) => _message('drag-history-$i', 3));
      final cards = [
        LocationChatReplyCard(id: 1, messages: [_message('drag-short', 3)]),
        LocationChatReplyCard(id: 2, messages: [_message('drag-long', 18)]),
      ];
      var current = 1;
      var revision = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, update) =>
                  NotificationListener<ScrollNotification>(
                    onNotification: coordinator.handleScrollNotification,
                    child: LocationChatAnchoredMessageList(
                      coordinator: coordinator,
                      topTitle: '',
                      messages: [...history, ...cards[current - 1].messages],
                      replyCards: cards,
                      replyCurrentCardId: current,
                      replyActionsIdentity: 'drag-round',
                      replyCardCount: 2,
                      replyCardIndex: current - 1,
                      replyPresentationRevision: revision,
                      onReplyCardSelected: (id) {
                        update(() {
                          current = id;
                          revision++;
                        });
                        return true;
                      },
                    ),
                  ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('location-chat-reply-next-card')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));
      final gesture = await tester.startGesture(const Offset(200, 120));
      await gesture.moveBy(const Offset(0, 100));
      await tester.pump();
      expect(coordinator.isDetached, isTrue);
      final visibleHistory =
          find
                  .byWidgetPredicate(
                    (widget) =>
                        widget is ChatMessageRow &&
                        widget.message.localId.startsWith('drag-history-'),
                  )
                  .evaluate()
                  .where((element) {
                    final y = tester
                        .getTopLeft(find.byWidget(element.widget))
                        .dy;
                    return y >= 0 && y < 500;
                  })
                  .first
                  .widget
              as ChatMessageRow;
      final row = find.byKey(ValueKey(visibleHistory.message.localId));
      final top = tester.getTopLeft(row).dy;
      for (var frame = 0; frame < 36; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(
          tester.getTopLeft(row).dy,
          closeTo(top, 1),
          reason: 'user drag owns the viewport at frame $frame',
        );
        expect(tester.takeException(), isNull);
      }
      expect(current, 2);
      await gesture.up();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('switch and regenerate frames reuse mounted card bodies', (
    tester,
  ) async {
    final key = GlobalKey<LocationChatReplyCardSwitcherState>();
    final builds = <int, int>{};
    var current = 1;
    var regenerating = false;
    late StateSetter update;
    final cards = [
      LocationChatReplyCard(id: 1, messages: [_message('one', 1)]),
      LocationChatReplyCard(id: 2, messages: [_message('two', 2)]),
      LocationChatReplyCard(id: 3, messages: [_message('three', 3)]),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 390,
                  child: LocationChatReplyCardSwitcher(
                    key: key,
                    identity: 'body-counts',
                    cards: cards,
                    currentCardId: current,
                    regenerationInProgress: regenerating,
                    cardBuilderIdentity: 'fixed-environment',
                    cardBuilder: (card) {
                      builds.update(
                        card.id,
                        (value) => value + 1,
                        ifAbsent: () => 1,
                      );
                      return SizedBox(
                        height: card.id * 100,
                        child: Text(card.messages.single.text),
                      );
                    },
                    onCommit: (id) {
                      update(() => current = id);
                      return true;
                    },
                    onBusyChanged: (_) {},
                    onWillChangeLayout: () {},
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    expect(builds, {1: 1});
    key.currentState!.switchBy(1);
    await tester.pump();
    final mountedBuilds = Map<int, int>.of(builds);
    for (var frame = 0; frame < 30; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(builds, mountedBuilds, reason: 'switch frame $frame');
      expect(find.byKey(const ValueKey('reply-card-page-3')), findsNothing);
    }
    await tester.pumpAndSettle();
    expect(current, 2);
    update(() => regenerating = true);
    key.currentState!.beginRegenerateCollapse();
    await tester.pump();
    final collapseBuilds = Map<int, int>.of(builds);
    for (var frame = 0; frame < 48; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(builds, collapseBuilds, reason: 'collapse frame $frame');
    }
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final historyCount in [100, 1000]) {
    testWidgets('switch retains lazy history with $historyCount rows', (
      tester,
    ) async {
      final coordinator = LocationChatScrollCoordinator();
      addTearDown(coordinator.dispose);
      final history = List.generate(
        historyCount,
        (i) => _message('history-$i', 3),
      );
      final cards = [
        LocationChatReplyCard(id: 1, messages: [_message('short', 3)]),
        LocationChatReplyCard(id: 2, messages: [_message('long', 18)]),
      ];
      var current = 1;
      var revision = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 390,
              child: StatefulBuilder(
                builder: (context, update) {
                  final selected = cards.firstWhere(
                    (card) => card.id == current,
                  );
                  return NotificationListener<ScrollNotification>(
                    onNotification: coordinator.handleScrollNotification,
                    child: LocationChatAnchoredMessageList(
                      coordinator: coordinator,
                      topTitle: '',
                      messages: [...history, ...selected.messages],
                      replyCards: cards,
                      replyCurrentCardId: current,
                      replyActionsIdentity: 'large-history',
                      replyCardCount: 2,
                      replyCardIndex: current - 1,
                      replyPresentationRevision: revision,
                      onReplyCardSelected: (id) {
                        update(() {
                          current = id;
                          revision++;
                        });
                        return true;
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      var historyBuilds = 0;
      final previousBuildCallback = debugOnRebuildDirtyWidget;
      debugOnRebuildDirtyWidget = (element, builtOnce) {
        previousBuildCallback?.call(element, builtOnce);
        final widget = element.widget;
        if (widget is ChatMessageRow &&
            widget.message.localId.startsWith('history-')) {
          historyBuilds++;
        }
      };
      addTearDown(() => debugOnRebuildDirtyWidget = previousBuildCallback);
      final controls = find.byKey(
        const ValueKey('reply-actions-large-history'),
      );
      final initialY = tester.getTopLeft(controls).dy;
      if (historyCount == 1000) coordinator.deactivate();
      for (final direction in ['next', 'previous', 'next', 'previous']) {
        await tester.tap(
          find.byKey(ValueKey('location-chat-reply-$direction-card')),
        );
        await tester.pump();
        for (var frame = 0; frame < 36; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(
            tester.getTopLeft(controls).dy,
            closeTo(initialY, 1),
            reason: '$historyCount rows, $direction, frame $frame',
          );
          expect(find.byKey(const ValueKey('history-0')), findsNothing);
          expect(tester.takeException(), isNull);
        }
      }
      expect(
        historyBuilds,
        lessThan(40),
        reason: 'animation must not rebuild the loaded history',
      );
    });
  }

  testWidgets(
    'a short fast swipe advances and ordinary vertical scrolling and long press remain available',
    (tester) async {
      final key = GlobalKey<LocationChatReplyCardSwitcherState>();
      final commits = <int>[];
      var longPresses = 0;
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: SingleChildScrollView(
                controller: scroll,
                child: Column(
                  children: [
                    LocationChatReplyCardSwitcher(
                      key: key,
                      identity: 'r',
                      currentCardId: 1,
                      cards: const [
                        LocationChatReplyCard(id: 1, messages: []),
                        LocationChatReplyCard(id: 2, messages: []),
                      ],
                      cardBuilder: (card) => GestureDetector(
                        onLongPress: () => longPresses++,
                        child: SizedBox(
                          height: 300,
                          child: Center(child: Text('Card ${card.id}')),
                        ),
                      ),
                      onCommit: (id) {
                        commits.add(id);
                        return true;
                      },
                      onBusyChanged: (_) {},
                      onWillChangeLayout: () {},
                    ),
                    const SizedBox(height: 700),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.longPress(find.text('Card 1'));
      expect(longPresses, 1);
      await tester.drag(find.text('Card 1'), const Offset(0, -90));
      await tester.pumpAndSettle();
      expect(scroll.offset, greaterThan(0));
      expect(commits, isEmpty);
      scroll.jumpTo(0);
      await tester.pump();
      await tester.fling(find.text('Card 1'), const Offset(-80, 0), 1000);
      await tester.pumpAndSettle();
      expect(commits, [2]);
    },
  );

  testWidgets(
    'arrows move whole pages in both directions and commit only once on settle',
    (tester) async {
      expect(replyCardSwitchDuration, const Duration(milliseconds: 500));
      final key = GlobalKey<LocationChatReplyCardSwitcherState>();
      final commits = <int>[];
      final busy = <bool>[];
      await tester.pumpWidget(_host(key, commits, busy));
      final first = find.byKey(const ValueKey('body-1'));
      final origin = tester.getTopLeft(first).dx;
      key.currentState!.switchBy(1);
      key.currentState!.switchBy(1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(commits, isEmpty);
      expect(tester.getTopLeft(first).dx, lessThan(origin));
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('body-2'))).dx,
        greaterThan(origin),
      );
      await tester.pump(const Duration(milliseconds: 399));
      expect(commits, isEmpty);
      await tester.pump(const Duration(milliseconds: 16));
      expect(commits, [2]);
      expect(busy, [true, false]);
      expect(first, findsNothing);
      key.currentState!.switchBy(-1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('body-2'))).dx,
        greaterThan(origin),
      );
      await tester.pumpAndSettle();
      expect(commits, [2, 1]);
      expect(find.byKey(const ValueKey('body-2')), findsNothing);
    },
  );

  testWidgets(
    'drag follows the finger, cancels below threshold and commits beyond threshold',
    (tester) async {
      final key = GlobalKey<LocationChatReplyCardSwitcherState>();
      final commits = <int>[];
      final busy = <bool>[];
      await tester.pumpWidget(_host(key, commits, busy));
      final area = find.byKey(const ValueKey('reply-card-gesture'));
      var gesture = await tester.startGesture(tester.getCenter(area));
      await gesture.moveBy(const Offset(-30, 0));
      await gesture.moveBy(const Offset(-35, 0));
      await tester.pump();
      expect(find.byKey(const ValueKey('body-2')), findsOneWidget);
      expect(commits, isEmpty);
      await tester.pump(const Duration(milliseconds: 200));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(commits, isEmpty);
      expect(find.byKey(const ValueKey('body-2')), findsNothing);
      gesture = await tester.startGesture(tester.getCenter(area));
      await gesture.moveBy(const Offset(-30, 0));
      await gesture.moveBy(const Offset(-130, 0));
      await tester.pump();
      expect(commits, isEmpty);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(commits, [2]);
    },
  );

  testWidgets(
    'outward drags and pointer cancellation rebound without a commit',
    (tester) async {
      final key = GlobalKey<LocationChatReplyCardSwitcherState>();
      final commits = <int>[];
      await tester.pumpWidget(_host(key, commits, []));
      final area = find.byKey(const ValueKey('reply-card-gesture'));
      var gesture = await tester.startGesture(tester.getCenter(area));
      await gesture.moveBy(const Offset(180, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(commits, isEmpty);
      gesture = await tester.startGesture(tester.getCenter(area));
      await gesture.moveBy(const Offset(-30, 0));
      await gesture.moveBy(const Offset(-140, 0));
      await tester.pump();
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(commits, isEmpty);
    },
  );

  testWidgets(
    'changing round or disabling the deck cancels an in-flight switch',
    (tester) async {
      for (final disable in [true, false]) {
        final key = GlobalKey<LocationChatReplyCardSwitcherState>();
        final commits = <int>[];
        final busy = <bool>[];
        await tester.pumpWidget(_host(key, commits, busy));
        key.currentState!.switchBy(1);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 90));
        await tester.pumpWidget(
          _host(
            key,
            commits,
            busy,
            enabled: !disable,
            identity: disable ? 'round' : 'next-round',
          ),
        );
        await tester.pumpAndSettle();
        expect(commits, isEmpty);
        expect(busy.last, false);
        expect(find.byKey(const ValueKey('body-1')), findsOneWidget);
        expect(find.byKey(const ValueKey('body-2')), findsNothing);
      }
    },
  );

  testWidgets(
    'disabling during drag cancels without commit and re-enable allows switching',
    (tester) async {
      final key = GlobalKey<LocationChatReplyCardSwitcherState>();
      final commits = <int>[];
      final busy = <bool>[];
      await tester.pumpWidget(_host(key, commits, busy));
      final area = find.byKey(const ValueKey('reply-card-gesture'));
      final gesture = await tester.startGesture(tester.getCenter(area));
      await gesture.moveBy(const Offset(-170, 0));
      await tester.pump();
      expect(find.byKey(const ValueKey('body-2')), findsOneWidget);

      await tester.pumpWidget(_host(key, commits, busy, enabled: false));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(commits, isEmpty);
      expect(busy.last, isFalse);
      expect(find.byKey(const ValueKey('body-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('body-2')), findsNothing);

      await tester.pumpWidget(_host(key, commits, busy));
      key.currentState!.switchBy(1);
      await tester.pumpAndSettle();
      expect(commits, [2]);
    },
  );

  testWidgets('disabled animations commit immediately', (tester) async {
    final key = GlobalKey<LocationChatReplyCardSwitcherState>();
    final commits = <int>[];
    await tester.pumpWidget(_host(key, commits, [], reducedMotion: true));
    key.currentState!.switchBy(1);
    await tester.pump();
    expect(commits, [2]);
    expect(find.byKey(const ValueKey('body-1')), findsNothing);
  });

  testWidgets('regenerate card preview keeps its vertical position on switch', (
    tester,
  ) async {
    final coordinator = LocationChatScrollCoordinator();
    addTearDown(coordinator.dispose);
    final cards = [
      LocationChatReplyCard(id: 1, messages: [_message('first', 1)]),
      LocationChatReplyCard(id: 2, messages: [_message('second', 1)]),
    ];
    var current = 1;
    var revision = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            height: 600,
            child: StatefulBuilder(
              builder: (context, update) {
                final selected = cards.firstWhere((card) => card.id == current);
                return LocationChatAnchoredMessageList(
                  coordinator: coordinator,
                  topTitle: '',
                  style: kLocationChatStyle,
                  messages: selected.messages,
                  replyCards: cards,
                  replyCurrentCardId: current,
                  replyActionsIdentity: 'regenerated-round',
                  replyPresentationRevision: revision,
                  replyCardCount: cards.length,
                  replyCardIndex: current - 1,
                  onReplyCardSelected: (id) {
                    update(() {
                      current = id;
                      revision++;
                    });
                    return true;
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('reply-card-gesture'))),
    );
    await gesture.moveBy(const Offset(-30, 0));
    await gesture.moveBy(const Offset(-170, 0));
    await tester.pump();
    final previewRow = tester.widget<ChatMessageRow>(
      find.byWidgetPredicate(
        (widget) =>
            widget is ChatMessageRow && widget.message.localId == 'second',
      ),
    );
    expect(
      previewRow.style?.rowBottomPadding,
      LocationChatReplyActions.contentBottomGap,
    );
    final secondBubble = find.byKey(
      const ValueKey('chat-message-bubble-second'),
    );
    final firstY = tester.getTopLeft(secondBubble).dy;
    expect(
      firstY,
      closeTo(
        tester
            .getTopLeft(find.byKey(const ValueKey('chat-message-bubble-first')))
            .dy,
        0.1,
      ),
    );
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.getTopLeft(secondBubble).dy, closeTo(firstY, 0.1));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(secondBubble).dy, closeTo(firstY, 0.1));
  });

  testWidgets(
    'regenerate keeps the old card visible behind a shrinking alpha edge until replacement',
    (tester) async {
      final key = GlobalKey<LocationChatReplyCardSwitcherState>();
      final busy = <bool>[];
      var currentCardId = 1;
      var regenerationInProgress = false;
      late StateSetter update;
      final cards = [
        LocationChatReplyCard(id: 1, messages: [_message('old', 2)]),
        LocationChatReplyCard(id: 2, messages: [_message('new', 2)]),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return MediaQuery(
                  data: const MediaQueryData(disableAnimations: false),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: 400,
                      child: LocationChatReplyCardSwitcher(
                        key: key,
                        identity: 'regenerate-round',
                        currentCardId: currentCardId,
                        cards: cards,
                        regenerationInProgress: regenerationInProgress,
                        cardBuilder: (card) => SizedBox(
                          key: ValueKey('regenerate-body-${card.id}'),
                          height: card.id == 1 ? 180 : 120,
                        ),
                        onCommit: (_) => true,
                        onBusyChanged: busy.add,
                        onWillChangeLayout: () {},
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

      key.currentState!.beginRegenerateCollapse();
      expect(busy, [true]);
      await tester.pump();
      update(() {
        currentCardId = 2;
        regenerationInProgress = true;
      });
      await tester.pump(const Duration(milliseconds: 16));

      expect(find.byKey(const ValueKey('regenerate-body-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('regenerate-body-2')), findsNothing);
      expect(
        find.byKey(const ValueKey('reply-card-regenerate-gradient')),
        findsOneWidget,
      );
      final firstHeight = tester
          .getSize(
            find.byKey(
              const ValueKey('reply-card-regenerate-collapse-viewport'),
            ),
          )
          .height;
      expect(firstHeight, lessThan(180));
      expect(firstHeight, greaterThan(0));

      await tester.pump(const Duration(milliseconds: 80));
      final secondHeight = tester
          .getSize(
            find.byKey(
              const ValueKey('reply-card-regenerate-collapse-viewport'),
            ),
          )
          .height;
      expect(secondHeight, lessThan(firstHeight));
      expect(find.byKey(const ValueKey('regenerate-body-2')), findsNothing);

      await tester.pump(const Duration(milliseconds: 720));
      expect(find.byKey(const ValueKey('regenerate-body-1')), findsNothing);
      expect(find.byKey(const ValueKey('regenerate-body-2')), findsOneWidget);
      expect(busy, [true, false]);

      update(() => regenerationInProgress = false);
      await tester.pump();
      expect(find.byKey(const ValueKey('regenerate-body-2')), findsOneWidget);
    },
  );

  testWidgets('regenerate failure reverses the partial collapse', (
    tester,
  ) async {
    final key = GlobalKey<LocationChatReplyCardSwitcherState>();
    final busy = <bool>[];
    var currentCardId = 1;
    var regenerationInProgress = false;
    late StateSetter update;
    final cards = [
      LocationChatReplyCard(id: 1, messages: [_message('old', 2)]),
      LocationChatReplyCard(id: -1, messages: []),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return MediaQuery(
                data: const MediaQueryData(disableAnimations: false),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 400,
                    child: LocationChatReplyCardSwitcher(
                      key: key,
                      identity: 'failed-regenerate-round',
                      currentCardId: currentCardId,
                      cards: cards,
                      regenerationInProgress: regenerationInProgress,
                      cardBuilder: (card) => SizedBox(
                        key: ValueKey('failed-regenerate-body-${card.id}'),
                        height: card.id == 1 ? 180 : 0,
                      ),
                      onCommit: (_) => true,
                      onBusyChanged: busy.add,
                      onWillChangeLayout: () {},
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    key.currentState!.beginRegenerateCollapse();
    expect(busy, [true]);
    await tester.pump();
    update(() {
      currentCardId = -1;
      regenerationInProgress = true;
    });
    await tester.pump(const Duration(milliseconds: 96));
    final collapsedHeight = tester
        .getSize(
          find.byKey(const ValueKey('reply-card-regenerate-collapse-viewport')),
        )
        .height;

    update(() {
      currentCardId = 1;
      regenerationInProgress = false;
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 48));
    await tester.pump(const Duration(milliseconds: 48));
    final recoveringHeight = tester
        .getSize(
          find.byKey(const ValueKey('reply-card-regenerate-collapse-viewport')),
        )
        .height;
    expect(recoveringHeight, greaterThan(collapsedHeight));

    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('failed-regenerate-body-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('failed-regenerate-body--1')),
      findsNothing,
    );
    expect(busy, [true, false]);
  });

  testWidgets('reduced motion skips the regenerate collapse', (tester) async {
    final key = GlobalKey<LocationChatReplyCardSwitcherState>();
    var currentCardId = 1;
    late StateSetter update;
    final cards = [
      LocationChatReplyCard(id: 1, messages: [_message('old', 2)]),
      LocationChatReplyCard(id: 2, messages: [_message('new', 2)]),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return MediaQuery(
                data: const MediaQueryData(disableAnimations: true),
                child: LocationChatReplyCardSwitcher(
                  key: key,
                  identity: 'reduced-motion-regenerate',
                  currentCardId: currentCardId,
                  cards: cards,
                  cardBuilder: (card) => SizedBox(
                    key: ValueKey('reduced-motion-body-${card.id}'),
                    height: 120,
                  ),
                  onCommit: (_) => true,
                  onBusyChanged: (_) {},
                  onWillChangeLayout: () {},
                ),
              );
            },
          ),
        ),
      ),
    );

    key.currentState!.beginRegenerateCollapse();
    update(() => currentCardId = 2);
    await tester.pump();
    expect(find.byKey(const ValueKey('reduced-motion-body-1')), findsNothing);
    expect(find.byKey(const ValueKey('reduced-motion-body-2')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('reply-card-regenerate-gradient')),
      findsNothing,
    );
  });

  testWidgets(
    'card transition preserves action visuals while blocking repeated taps',
    (tester) async {
      final coordinator = LocationChatScrollCoordinator();
      addTearDown(coordinator.dispose);
      var current = 1;
      var revision = 0;
      var regenerateCalls = 0;
      final cards = [
        LocationChatReplyCard(id: 1, messages: [_message('one', 2)]),
        LocationChatReplyCard(id: 2, messages: [_message('two', 2)]),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 390,
              height: 500,
              child: StatefulBuilder(
                builder: (context, update) {
                  final selected = cards.firstWhere(
                    (card) => card.id == current,
                  );
                  return LocationChatAnchoredMessageList(
                    coordinator: coordinator,
                    topTitle: '',
                    messages: selected.messages,
                    replyCards: cards,
                    replyCurrentCardId: current,
                    replyActionsIdentity: 'round',
                    replyPresentationRevision: revision,
                    replyCardCount: 2,
                    replyCardIndex: current - 1,
                    regenerateFeature: LocationChatRegenerateFeature(
                      onInvoke: () => regenerateCalls++,
                      state: LocationChatReplyActionState.idle,
                    ),
                    goOnFeature: const LocationChatGoOnFeature(
                      onInvoke: null,
                      state: LocationChatReplyActionState.idle,
                    ),
                    editFeature: const LocationChatEditFeature(
                      onInvoke: null,
                      state: LocationChatReplyActionState.idle,
                    ),
                    inspirationFeature: const LocationChatInspirationFeature(
                      messages: [],
                      state: LocationChatReplyActionState.idle,
                    ),
                    onReplyCardSelected: (id) {
                      update(() {
                        current = id;
                        revision++;
                      });
                      return true;
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('location-chat-reply-next-card')),
      );
      await tester.pump(const Duration(milliseconds: 80));

      final actions = tester.widget<LocationChatReplyActions>(
        find.byType(LocationChatReplyActions),
      );
      expect(actions.regenerateFeature.enabled, isTrue);
      expect(actions.goOnFeature.enabled, isTrue);
      expect(actions.editFeature.enabled, isTrue);
      expect(actions.inspirationFeature.enabled, isTrue);
      expect(actions.onPreviousCard, isNotNull);
      expect(actions.onNextCard, isNotNull);
      expect(
        tester
            .widget<IgnorePointer>(
              find.byKey(const ValueKey('reply-actions-input-blocker-round')),
            )
            .ignoring,
        isTrue,
      );
      await tester.tap(
        find.bySemanticsLabel('Regenerate'),
        warnIfMissed: false,
      );
      expect(regenerateCalls, 0);

      await tester.pumpAndSettle();
      expect(
        tester
            .widget<IgnorePointer>(
              find.byKey(const ValueKey('reply-actions-input-blocker-round')),
            )
            .ignoring,
        isFalse,
      );
      await tester.tap(find.bySemanticsLabel('Regenerate'));
      expect(regenerateCalls, 1);
    },
  );

  testWidgets('empty pending card adds no invisible gap before pagination', (
    tester,
  ) async {
    final coordinator = LocationChatScrollCoordinator();
    addTearDown(coordinator.dispose);
    final message = ChatMessageVm(
      localId: 'message-before-pending-card',
      senderId: 'user',
      senderName: 'User',
      text: 'Message before pending candidate',
      isMe: true,
      status: 'sent',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            height: 600,
            child: LocationChatAnchoredMessageList(
              coordinator: coordinator,
              topTitle: '',
              messages: [message],
              replyCards: const [LocationChatReplyCard(id: -1, messages: [])],
              replyCurrentCardId: -1,
              replyActionsIdentity: 'pending-round',
              replyCardIndex: 1,
              replyCardCount: 3,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(const ValueKey('reply-card-gesture'))).height,
      0,
    );
    final messageBottom = tester
        .getRect(
          find.byKey(
            const ValueKey('chat-message-bubble-message-before-pending-card'),
          ),
        )
        .bottom;
    final paginationTop = tester
        .getRect(find.byKey(const ValueKey('location-chat-reply-pagination')))
        .top;
    expect(
      paginationTop - messageBottom,
      closeTo(LocationChatReplyActions.contentBottomGap, 1),
    );
  });

  for (final secondScroll in [false, true]) {
    for (final inspiration in [false, true]) {
      testWidgets(
        'variable height keeps the toolbar anchored through every frame (secondScroll=$secondScroll, inspiration=$inspiration)',
        (tester) async {
          final coordinator = LocationChatScrollCoordinator();
          addTearDown(coordinator.dispose);
          final history = List.generate(12, (i) => _message('history-$i', 3));
          final cards = [
            LocationChatReplyCard(id: 1, messages: [_message('short', 3)]),
            LocationChatReplyCard(
              id: 2,
              messages: [_message('long', 18), _message('second', 2)],
            ),
          ];
          var current = 1;
          var revision = 0;
          final commits = <int>[];
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 390,
                  height: 500,
                  child: StatefulBuilder(
                    builder: (context, update) {
                      final selected = cards.firstWhere(
                        (card) => card.id == current,
                      );
                      return NotificationListener<ScrollNotification>(
                        onNotification: coordinator.handleScrollNotification,
                        child: LocationChatAnchoredMessageList(
                          inspirationFeature: LocationChatInspirationFeature(
                            state: LocationChatReplyActionState.idle,
                            messages: inspiration
                                ? [List.filled(8, 'Suggestion line').join('\n')]
                                : const [],
                          ),
                          coordinator: coordinator,
                          topTitle: secondScroll ? 'History' : '',
                          oldestEdgeNoticeRequiresSecondScroll: secondScroll,
                          messages: [...history, ...selected.messages],
                          replyCards: cards,
                          replyCurrentCardId: current,
                          replyActionsIdentity: 'round',
                          replyPresentationRevision: revision,
                          replyCardCount: 2,
                          replyCardIndex: current - 1,
                          onReplyCardSelected: (id) {
                            commits.add(id);
                            update(() {
                              current = id;
                              revision++;
                            });
                            return true;
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final controls = find.byKey(const ValueKey('reply-actions-round'));
          for (final direction in ['next', 'previous']) {
            if (inspiration) {
              await tester.tap(find.bySemanticsLabel('Inspiration'));
              await tester.pumpAndSettle();
            }
            double controlAnchor() => inspiration
                ? tester.getBottomLeft(controls).dy
                : tester.getTopLeft(controls).dy;
            final y = controlAnchor();
            await tester.tap(
              find.byKey(ValueKey('location-chat-reply-$direction-card')),
            );
            await tester.pump();
            for (var frame = 0; frame < 36; frame++) {
              await tester.pump(const Duration(milliseconds: 16));
              expect(controlAnchor(), closeTo(y, 1), reason: 'frame $frame');
              expect(tester.takeException(), isNull);
            }
            await tester.pumpAndSettle();
          }
          expect(commits, [2, 1]);
          expect(find.byKey(const ValueKey('reply-card-page-2')), findsNothing);
        },
      );
    }
  }

  for (final secondScroll in [false, true]) {
    testWidgets(
      'post-regenerate card switching keeps the card bottom fixed while waiting space is retained (secondScroll=$secondScroll)',
      (tester) async {
        final coordinator = LocationChatScrollCoordinator();
        addTearDown(coordinator.dispose);
        final history = List.generate(12, (i) => _message('history-$i', 3));
        final cards = [
          LocationChatReplyCard(id: 1, messages: [_message('short', 3)]),
          LocationChatReplyCard(
            id: 2,
            messages: [_message('long', 18), _message('second', 2)],
          ),
        ];
        var current = 1;
        var revision = 0;
        var regenerating = true;
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 390,
                height: 500,
                child: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    final selected = cards.firstWhere(
                      (card) => card.id == current,
                    );
                    return NotificationListener<ScrollNotification>(
                      onNotification: coordinator.handleScrollNotification,
                      child: LocationChatAnchoredMessageList(
                        coordinator: coordinator,
                        topTitle: secondScroll ? 'History' : '',
                        oldestEdgeNoticeRequiresSecondScroll: secondScroll,
                        messages: [...history, ...selected.messages],
                        replyCards: cards,
                        replyCurrentCardId: current,
                        replyActionsIdentity: 'round',
                        replyPresentationRevision: revision,
                        replyCardCount: 2,
                        replyCardIndex: current - 1,
                        replyRegenerationInProgress: regenerating,
                        onReplyCardSelected: (id) {
                          update(() {
                            current = id;
                            revision++;
                          });
                          return true;
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        update(() => regenerating = false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final card = find.byKey(const ValueKey('reply-card-gesture'));
        final actions = find.byKey(const ValueKey('reply-actions-round'));
        expect(coordinator.isDetached, isTrue);

        for (final direction in ['next', 'previous']) {
          final cardBottom = tester.getBottomLeft(card).dy;
          final actionsTop = tester.getTopLeft(actions).dy;
          if (direction == 'previous') {
            final gesture = await tester.startGesture(
              Offset(195, cardBottom - 20),
            );
            await gesture.moveBy(const Offset(30, 0));
            await gesture.moveBy(const Offset(140, 0));
            await gesture.up();
          } else {
            await tester.tap(
              find.byKey(ValueKey('location-chat-reply-$direction-card')),
            );
          }
          await tester.pump();
          for (var frame = 0; frame < 36; frame++) {
            await tester.pump(const Duration(milliseconds: 16));
            expect(
              tester.getBottomLeft(card).dy,
              closeTo(cardBottom, 1),
              reason: '$direction card bottom at frame $frame',
            );
            expect(
              tester.getTopLeft(actions).dy,
              closeTo(actionsTop, 1),
              reason: '$direction actions boundary at frame $frame',
            );
          }
          await tester.pumpAndSettle();
        }
        expect(current, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

ChatMessageVm _message(String id, int lines) => ChatMessageVm(
  localId: id,
  senderId: 'role',
  senderName: 'Role',
  text: List.filled(lines, 'Reply line').join('\n'),
  isMe: false,
  status: 'sent',
);

Widget _host(
  GlobalKey<LocationChatReplyCardSwitcherState> key,
  List<int> commits,
  List<bool> busy, {
  bool enabled = true,
  String identity = 'round',
  bool reducedMotion = false,
}) => MaterialApp(
  home: Scaffold(
    body: MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 400,
          child: LocationChatReplyCardSwitcher(
            key: key,
            identity: identity,
            currentCardId: 1,
            enabled: enabled,
            cards: const [
              LocationChatReplyCard(id: 1, messages: []),
              LocationChatReplyCard(id: 2, messages: []),
            ],
            cardBuilder: (card) => SizedBox(
              key: ValueKey('body-${card.id}'),
              height: card.id == 1 ? 160 : 280,
              child: Text('card ${card.id}'),
            ),
            onCommit: (id) {
              commits.add(id);
              return true;
            },
            onBusyChanged: busy.add,
            onWillChangeLayout: () {},
          ),
        ),
      ),
    ),
  ),
);
