import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/features/location_chat_reply/edit/edit.dart';
import 'package:genesis_flutter_android/features/location_chat_reply/go_on/go_on.dart';
import 'package:genesis_flutter_android/features/location_chat_reply/inspiration/inspiration.dart';
import 'package:genesis_flutter_android/features/location_chat_reply/regenerate/regenerate.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_reply_actions.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_reply_card_switcher.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_scroll_coordinator.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';

void main() {
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
                  replyActionsAnchorIndex: selected.messages.length,
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
                    replyActionsAnchorIndex: selected.messages.length,
                    replyPresentationRevision: revision,
                    replyCardCount: 2,
                    replyCardIndex: current - 1,
                    regenerateFeature: LocationChatRegenerateFeature(
                      onInvoke: () => regenerateCalls++,
                      enabled: true,
                      busy: false,
                    ),
                    goOnFeature: const LocationChatGoOnFeature(
                      onInvoke: null,
                      enabled: true,
                      busy: false,
                    ),
                    editFeature: const LocationChatEditFeature(
                      onInvoke: null,
                      enabled: true,
                      busy: false,
                    ),
                    inspirationFeature: const LocationChatInspirationFeature(
                      messages: [],
                      loading: false,
                      enabled: true,
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
              replyActionsAnchorIndex: 1,
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
    testWidgets(
      'variable height keeps the toolbar anchored through every frame (secondScroll=$secondScroll)',
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
                        coordinator: coordinator,
                        topTitle: secondScroll ? 'History' : '',
                        oldestEdgeNoticeRequiresSecondScroll: secondScroll,
                        messages: [...history, ...selected.messages],
                        replyCards: cards,
                        replyCurrentCardId: current,
                        replyActionsIdentity: 'round',
                        replyActionsAnchorIndex:
                            history.length + selected.messages.length,
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
        final y = tester.getTopLeft(controls).dy;
        for (final direction in ['next', 'previous']) {
          await tester.tap(
            find.byKey(ValueKey('location-chat-reply-$direction-card')),
          );
          await tester.pump();
          for (var frame = 0; frame < 16; frame++) {
            await tester.pump(const Duration(milliseconds: 16));
            expect(
              tester.getTopLeft(controls).dy,
              closeTo(y, 1),
              reason: 'frame $frame',
            );
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
