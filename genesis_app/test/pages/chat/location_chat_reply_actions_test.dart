import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/features/location_chat_reply/edit/edit.dart';
import 'package:genesis_flutter_android/features/location_chat_reply/go_on/go_on.dart';
import 'package:genesis_flutter_android/features/location_chat_reply/inspiration/inspiration.dart';
import 'package:genesis_flutter_android/features/location_chat_reply/regenerate/regenerate.dart';
import 'package:genesis_flutter_android/features/location_chat_reply/shared/reply_action_state.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_reply_actions.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_scroll_coordinator.dart';
import 'package:genesis_flutter_android/components/gems/purchase_options_sheet.dart';
import 'package:genesis_flutter_android/components/common/genesis_bottom_sheet_panel.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_theme.dart';
import 'package:genesis_flutter_android/ui/tokens/genesis_colors.dart';

const _inspirationReplies = [
  'Good job!',
  "You're right to ask for a plan. Give me a little time to listen, and I'll come back with something we can actually build together.",
  "I don't have every answer yet, but I came back for a reason. Let's talk to the people who still believe in this town, hear what they need, and give them a reason to walk through these doors again.",
];

Widget _replyActions({
  required ChatUiStyleConfig style,
  LocationChatInspirationFeature? inspirationFeature,
  List<String> inspirationMessages = const [],
  ValueChanged<String>? onInspirationSend,
  ValueChanged<String>? onInspirationEdit,
  VoidCallback? onRegenerate,
  VoidCallback? onGoOn,
  VoidCallback? onEditReply,
  bool regenerateEnabled = true,
  bool goOnEnabled = true,
  bool editEnabled = true,
  bool regenerateBusy = false,
  bool goOnBusy = false,
  bool editBusy = false,
  LocationChatReplyActionState? regenerateState,
  LocationChatReplyActionState? goOnState,
  LocationChatReplyActionState? editState,
  int? editFreeUsesRemaining,
  int? inspirationFreeUsesRemaining,
  int cardIndex = 0,
  int cardCount = 0,
  bool cardsConfirmed = false,
  bool cardSwitchEnabled = true,
  VoidCallback? onPreviousCard,
  VoidCallback? onNextCard,
  double? selfMessageBubbleMaxWidthCap,
}) => LocationChatReplyActions(
  style: style,
  regenerateFeature: LocationChatRegenerateFeature(
    onInvoke: onRegenerate,
    state:
        regenerateState ??
        (regenerateBusy
            ? LocationChatReplyActionState.busy
            : regenerateEnabled && onRegenerate != null
            ? LocationChatReplyActionState.idle
            : LocationChatReplyActionState.none),
  ),
  goOnFeature: LocationChatGoOnFeature(
    onInvoke: onGoOn,
    state:
        goOnState ??
        (goOnBusy
            ? LocationChatReplyActionState.busy
            : goOnEnabled && onGoOn != null
            ? LocationChatReplyActionState.idle
            : LocationChatReplyActionState.none),
  ),
  editFeature: LocationChatEditFeature(
    onInvoke: onEditReply,
    state:
        editState ??
        (editBusy
            ? LocationChatReplyActionState.busy
            : editEnabled && onEditReply != null
            ? LocationChatReplyActionState.idle
            : LocationChatReplyActionState.none),
    freeUsesRemaining: editFreeUsesRemaining,
  ),
  inspirationFeature: LocationChatInspirationFeature(
    messages: inspirationFeature?.messages ?? inspirationMessages,
    state: inspirationFeature?.state ?? LocationChatReplyActionState.idle,
    freeUsesRemaining: inspirationFreeUsesRemaining,
    onSend: onInspirationSend ?? inspirationFeature?.onSend,
    onEdit: onInspirationEdit ?? inspirationFeature?.onEdit,
  ),
  cardIndex: cardIndex,
  cardCount: cardCount,
  cardsConfirmed: cardsConfirmed,
  cardSwitchEnabled: cardSwitchEnabled,
  onPreviousCard: onPreviousCard,
  onNextCard: onNextCard,
  selfMessageBubbleMaxWidthCap: selfMessageBubbleMaxWidthCap,
);

void main() {
  for (final remaining in [0, 1, 2, 3]) {
    testWidgets(
      'free quota prompts stay visible with $remaining uses and use secondary red',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: _replyActions(
                style: kLocationChatStyle,
                onEditReply: () {},
                editFreeUsesRemaining: 1,
                inspirationFreeUsesRemaining: remaining,
              ),
            ),
          ),
        );
        expect(find.byType(LocationChatSubscriptionPrompt), findsNothing);
        await tester.tap(find.bySemanticsLabel('Edit'));
        await tester.pumpAndSettle();
        final prompt = find.byKey(const ValueKey('edit-subscription-prompt'));
        expect(prompt, findsOneWidget);
        final richText = tester.widget<Text>(
          find.descendant(of: prompt, matching: find.byType(Text)),
        );
        expect(richText.style?.fontSize, 13);
        final root = richText.textSpan! as TextSpan;
        final message = root.children!.first as TextSpan;
        expect((message.children!.last as TextSpan).text, '"1"');
        expect(
          (message.children!.last as TextSpan).style?.color,
          GenesisColors.redSecondary,
        );
        expect(
          (root.children!.last as TextSpan).style?.color,
          GenesisColors.redSecondary,
        );
        expect((root.children!.last as TextSpan).text, '\nGet more >');
        expect(
          tester.getTopLeft(prompt).dy -
              tester
                  .getBottomLeft(
                    find.byKey(
                      const ValueKey('location-chat-reply-actions-four-icons'),
                    ),
                  )
                  .dy,
          4.5,
        );
        await tester.tap(find.bySemanticsLabel('Inspiration'));
        await tester.pumpAndSettle();
        expect(prompt, findsNothing);
        expect(
          find.text('Free inspiration uses left: "$remaining"\nGet more >'),
          findsOneWidget,
        );
        final inspirationPrompt = find.byKey(
          const ValueKey('inspiration-subscription-prompt'),
        );
        expect(
          tester.getTopLeft(inspirationPrompt).dy -
              tester
                  .getBottomLeft(
                    find.byKey(
                      const ValueKey('location-chat-reply-actions-four-icons'),
                    ),
                  )
                  .dy,
          4.5,
        );
        expect(
          find.byKey(const ValueKey('inspiration-replies-carousel')),
          findsNothing,
        );
        await tester.tap(find.bySemanticsLabel('Inspiration'));
        await tester.pumpAndSettle();
        expect(
          find.text('Free inspiration uses left: "$remaining"\nGet more >'),
          findsOneWidget,
        );
      },
    );
  }

  for (final remaining in [0, 2]) {
    testWidgets(
      'inspiration list animates both ways while retaining its $remaining-use prompt',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: _replyActions(
                style: kLocationChatStyle,
                inspirationMessages: _inspirationReplies,
                inspirationFreeUsesRemaining: remaining,
              ),
            ),
          ),
        );
        final button = find.bySemanticsLabel('Inspiration');
        final carousel = find.byKey(
          const ValueKey('inspiration-replies-carousel'),
        );
        final transition = find.byKey(
          const ValueKey('inspiration-replies-transition'),
        );
        final prompt = find.byKey(
          const ValueKey('inspiration-subscription-prompt'),
        );
        await tester.tap(button);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 110));
        final expandingHeight = tester.getSize(transition).height;
        final promptElement = tester.element(prompt);
        await tester.pumpAndSettle();
        final fullHeight = tester.getSize(transition).height;
        expect(expandingHeight, greaterThan(0));
        expect(expandingHeight, lessThan(fullHeight));
        await tester.tap(button);
        await tester.pump();
        expect(
          carousel,
          findsOneWidget,
          reason: 'Keep the content until the closing animation finishes.',
        );
        await tester.pump(const Duration(milliseconds: 110));
        expect(tester.getSize(transition).height, greaterThan(0));
        expect(tester.getSize(transition).height, lessThan(fullHeight));
        expect(tester.element(prompt), same(promptElement));
        await tester.pumpAndSettle();
        expect(carousel, findsNothing);
        expect(tester.element(prompt), same(promptElement));
        await tester.tap(button);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 110));
        expect(
          tester.getSize(transition).height,
          closeTo(expandingHeight, 0.1),
        );
        await tester.pumpAndSettle();
        expect(carousel, findsOneWidget);
        expect(tester.element(prompt), same(promptElement));
      },
    );
  }

  for (final reason in [
    'source reset',
    'new round',
    'ACK loading',
    'hidden controls',
    'unavailable action',
    'inactive page',
  ]) {
    testWidgets('inspiration uses the same closing animation after $reason', (
      tester,
    ) async {
      final coordinator = LocationChatScrollCoordinator();
      addTearDown(coordinator.dispose);
      final sent = <String>[];
      final message = ChatMessageVm(
        localId: 'reply',
        senderId: 'role',
        senderName: 'Role',
        text: 'Reply content',
        isMe: false,
        status: 'sent',
      );
      Widget host({bool invalidated = false}) => MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            height: 600,
            child: LocationChatAnchoredMessageList(
              coordinator: coordinator,
              messages: [message],
              topTitle: '',
              replyActionsIdentity: invalidated && reason == 'new round'
                  ? 'round-b'
                  : 'round-a',
              replyActionsMessageId: 'reply',
              replyActionsVisible:
                  !(invalidated && reason == 'hidden controls'),
              goOnAwaitingContentIdentity:
                  invalidated && reason == 'ACK loading'
                  ? 'go-on:301:401'
                  : null,
              active: !(invalidated && reason == 'inactive page'),
              inspirationIdentity: invalidated && reason == 'new round'
                  ? 'source-b'
                  : 'source-a',
              inspirationFeature: LocationChatInspirationFeature(
                state: invalidated && reason == 'unavailable action'
                    ? LocationChatReplyActionState.none
                    : LocationChatReplyActionState.idle,
                messages: invalidated && reason == 'source reset'
                    ? const []
                    : _inspirationReplies,
                onSend: sent.add,
              ),
              style: kLocationChatStyle,
            ),
          ),
        ),
      );
      final carousel = find.byKey(
        const ValueKey('inspiration-replies-carousel'),
      );
      final transition = find.byKey(
        const ValueKey('inspiration-replies-transition'),
      );
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Inspiration'));
      await tester.pumpAndSettle();
      final state = tester.state(find.byType(LocationChatInspirationReplies));
      final fullHeight = tester.getSize(transition).height;
      await tester.pumpWidget(host(invalidated: true));
      expect(
        tester.state(find.byType(LocationChatInspirationReplies)),
        same(state),
      );
      expect(carousel, findsOneWidget);
      final bubble = tester.widget<ChatMessageBubble>(
        find.descendant(
          of: find.byKey(const ValueKey('inspiration-reply-card-0')),
          matching: find.byType(ChatMessageBubble),
        ),
      );
      bubble.onTap!();
      expect(
        sent,
        isEmpty,
        reason: 'A retained closing snapshot is no longer actionable.',
      );
      await tester.pump(const Duration(milliseconds: 110));
      expect(tester.getSize(transition).height, greaterThan(0));
      expect(tester.getSize(transition).height, lessThan(fullHeight));
      await tester.pump(const Duration(milliseconds: 220));
      expect(carousel, findsNothing);
      if (reason == 'unavailable action') {
        await tester.pumpWidget(host());
        await tester.pumpAndSettle();
        expect(
          carousel,
          findsNothing,
          reason: 'Restoring eligibility must wait for another user click.',
        );
      }
    });
  }

  for (final action in ['Regenerate', 'Go on', 'Edit']) {
    testWidgets('$action closes inspiration through the shared animation', (
      tester,
    ) async {
      var invocations = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _replyActions(
              style: kLocationChatStyle,
              inspirationMessages: _inspirationReplies,
              onRegenerate: () => invocations++,
              onGoOn: () => invocations++,
              onEditReply: () => invocations++,
            ),
          ),
        ),
      );
      await tester.tap(find.bySemanticsLabel('Inspiration'));
      await tester.pumpAndSettle();
      final transition = find.byKey(
        const ValueKey('inspiration-replies-transition'),
      );
      final height = tester.getSize(transition).height;
      await tester.tap(find.bySemanticsLabel(action));
      await tester.pump();
      expect(invocations, 1);
      await tester.pump(const Duration(milliseconds: 110));
      expect(tester.getSize(transition).height, inExclusiveRange(0, height));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('inspiration-replies-carousel')),
        findsNothing,
      );
    });
  }

  testWidgets('a new inspiration source waits for the old snapshot to close', (
    tester,
  ) async {
    Widget host(String identity, List<String> messages) => MaterialApp(
      home: Scaffold(
        body: LocationChatReplyActions(
          style: kLocationChatStyle,
          inspirationExpanded: true,
          inspirationIdentity: identity,
          inspirationFeature: LocationChatInspirationFeature(
            state: LocationChatReplyActionState.idle,
            messages: messages,
          ),
        ),
      ),
    );
    await tester.pumpWidget(host('a', const ['Old inspiration']));
    await tester.pumpAndSettle();
    await tester.pumpWidget(host('b', const ['New inspiration']));
    await tester.pump(const Duration(milliseconds: 110));
    expect(find.text('Old inspiration'), findsOneWidget);
    expect(find.text('New inspiration'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('Old inspiration'), findsNothing);
    expect(find.text('New inspiration'), findsOneWidget);
  });

  testWidgets(
    'free inspiration prompt wraps within its card width with scaled text',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(280, 800),
              textScaler: TextScaler.linear(1.8),
            ),
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 280,
                  child: _replyActions(
                    style: kLocationChatStyle,
                    selfMessageBubbleMaxWidthCap: 200,
                    inspirationFreeUsesRemaining: 2,
                    inspirationMessages: const ['A saved suggestion.'],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.bySemanticsLabel('Inspiration'));
      await tester.pumpAndSettle();
      final prompt = find.byKey(
        const ValueKey('inspiration-subscription-prompt'),
      );
      expect(tester.getSize(prompt).width, lessThanOrEqualTo(200));
      expect(tester.getCenter(prompt).dx, 400);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('all four actions invoke their enabled features', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _replyActions(
            style: kLocationChatStyle,
            inspirationFeature: const LocationChatInspirationFeature(
              messages: _inspirationReplies,
              state: LocationChatReplyActionState.idle,
            ),
            onRegenerate: () => calls++,
            onGoOn: () => calls++,
            onEditReply: () => calls++,
          ),
        ),
      ),
    );
    for (final action in ['Regenerate', 'Go on', 'Edit', 'Inspiration']) {
      await tester.tap(find.bySemanticsLabel(action));
      await tester.pumpAndSettle();
    }
    expect(calls, 3);
    expect(
      find.byKey(const ValueKey('edit-subscription-prompt')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('inspiration-replies-carousel')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('inspiration-get-more')), findsNothing);
  });

  testWidgets('default members invoke actions with independent availability', (
    tester,
  ) async {
    final calls = <String>[];
    Widget host({bool busy = false}) => MaterialApp(
      home: Scaffold(
        body: _replyActions(
          inspirationFeature: const LocationChatInspirationFeature(
            messages: _inspirationReplies,
            state: LocationChatReplyActionState.idle,
          ),
          style: kLocationChatStyle,
          onRegenerate: () => calls.add('regenerate'),
          onGoOn: () => calls.add('goOn'),
          onEditReply: () => calls.add('edit'),
          regenerateBusy: busy,
          goOnEnabled: !busy,
        ),
      ),
    );
    await tester.pumpWidget(host());
    for (final action in ['Regenerate', 'Go on', 'Edit', 'Inspiration']) {
      expect(find.byTooltip(action), findsOneWidget);
      expect(tester.getSize(find.bySemanticsLabel(action)), const Size(32, 32));
    }
    for (final action in ['Regenerate', 'Go on', 'Edit']) {
      await tester.tap(find.bySemanticsLabel(action));
      await tester.pump();
    }
    expect(calls, ['regenerate', 'goOn', 'edit']);
    expect(
      find.byKey(const ValueKey('edit-subscription-prompt')),
      findsNothing,
    );
    await tester.pumpWidget(host(busy: true));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.bySemanticsLabel('Go on'), findsNothing);
    expect(
      tester
          .widget<Semantics>(find.bySemanticsLabel('Regenerate'))
          .properties
          .value,
      'Loading',
    );
    for (final action in ['Regenerate', 'Edit']) {
      await tester.tap(find.bySemanticsLabel(action));
      await tester.pump();
    }
    expect(calls, ['regenerate', 'goOn', 'edit', 'edit']);
    await tester.pumpWidget(host());
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(find.bySemanticsLabel('Regenerate'));
    await tester.pump();
    expect(calls.last, 'regenerate');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('none actions collapse while an empty toolbar keeps height', (
    tester,
  ) async {
    Widget host({
      bool regenerateEnabled = false,
      bool goOnEnabled = false,
      bool editEnabled = false,
      bool inspirationEnabled = false,
      bool regenerateBusy = false,
    }) => MaterialApp(
      home: Scaffold(
        body: _replyActions(
          style: kLocationChatStyle,
          onRegenerate: () {},
          onGoOn: () {},
          onEditReply: () {},
          regenerateEnabled: regenerateEnabled,
          goOnEnabled: goOnEnabled,
          editEnabled: editEnabled,
          regenerateBusy: regenerateBusy,
          inspirationFeature: inspirationEnabled
              ? const LocationChatInspirationFeature(
                  messages: _inspirationReplies,
                  state: LocationChatReplyActionState.idle,
                )
              : const LocationChatInspirationFeature.disabled(),
        ),
      ),
    );

    const toolbarKey = ValueKey('location-chat-reply-actions-four-icons');
    await tester.pumpWidget(host());
    expect(find.byKey(toolbarKey), findsOneWidget);
    expect(tester.getSize(find.byKey(toolbarKey)).height, 32);
    for (final action in ['Regenerate', 'Go on', 'Edit', 'Inspiration']) {
      expect(find.bySemanticsLabel(action), findsNothing);
    }
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.pumpWidget(
      host(regenerateBusy: true, editEnabled: true, inspirationEnabled: true),
    );
    expect(find.bySemanticsLabel('Regenerate'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.bySemanticsLabel('Go on'), findsNothing);
    expect(find.byKey(const ValueKey('location-chat-go-on')), findsNothing);
    expect(find.bySemanticsLabel('Edit'), findsOneWidget);
    expect(find.bySemanticsLabel('Inspiration'), findsOneWidget);

    final regenerateLeft = tester.getTopLeft(
      find.byKey(const ValueKey('location-chat-regenerate')),
    );
    final editLeft = tester.getTopLeft(find.bySemanticsLabel('Edit'));
    final inspirationLeft = tester.getTopLeft(
      find.bySemanticsLabel('Inspiration'),
    );
    expect(
      editLeft.dx - regenerateLeft.dx,
      LocationChatReplyActions.centerSpacing,
    );
    expect(
      inspirationLeft.dx - editLeft.dx,
      LocationChatReplyActions.centerSpacing,
    );
  });

  testWidgets('disabled stays gray and slotful; busy spins; idle can invoke', (
    tester,
  ) async {
    var calls = 0;
    Widget host(LocationChatReplyActionState regenerateState) => MaterialApp(
      home: Scaffold(
        body: _replyActions(
          style: kLocationChatStyle,
          onRegenerate: () => calls++,
          regenerateState: regenerateState,
          goOnState: LocationChatReplyActionState.none,
          editState: LocationChatReplyActionState.busy,
          inspirationFeature: const LocationChatInspirationFeature(
            messages: [],
            state: LocationChatReplyActionState.idle,
          ),
        ),
      ),
    );
    await tester.pumpWidget(host(LocationChatReplyActionState.disabled));
    final regenerate = find.bySemanticsLabel('Regenerate');
    expect(regenerate, findsOneWidget);
    expect(tester.widget<Semantics>(regenerate).properties.enabled, isFalse);
    expect(
      tester
          .widget<SvgPicture>(
            find.descendant(of: regenerate, matching: find.byType(SvgPicture)),
          )
          .colorFilter,
      const ColorFilter.mode(GenesisColors.darkTextTertiary, BlendMode.srcIn),
    );
    expect(find.bySemanticsLabel('Go on'), findsNothing);
    expect(find.bySemanticsLabel('Edit'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<Semantics>(find.bySemanticsLabel('Edit')).properties.value,
      'Loading',
    );
    expect(
      tester.getTopLeft(find.bySemanticsLabel('Edit')).dx -
          tester.getTopLeft(regenerate).dx,
      LocationChatReplyActions.centerSpacing,
    );
    expect(
      tester.getTopLeft(find.bySemanticsLabel('Inspiration')).dx -
          tester.getTopLeft(find.bySemanticsLabel('Edit')).dx,
      LocationChatReplyActions.centerSpacing,
    );
    await tester.tap(regenerate);
    await tester.pump();
    expect(calls, 0);

    await tester.pumpWidget(host(LocationChatReplyActionState.idle));
    expect(tester.widget<Semantics>(regenerate).properties.enabled, isTrue);
    expect(
      tester
          .widget<SvgPicture>(
            find.descendant(of: regenerate, matching: find.byType(SvgPicture)),
          )
          .colorFilter,
      const ColorFilter.mode(GenesisColors.darkTextPrimary, BlendMode.srcIn),
    );
    await tester.tap(regenerate);
    expect(calls, 1);
  });

  testWidgets('opening capability renders Go on, Edit, and Inspiration only', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _replyActions(
            style: kLocationChatStyle,
            regenerateEnabled: false,
            goOnEnabled: true,
            editEnabled: true,
            inspirationFeature: const LocationChatInspirationFeature(
              messages: _inspirationReplies,
              state: LocationChatReplyActionState.idle,
            ),
            onGoOn: () {},
            onEditReply: () {},
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Regenerate'), findsNothing);
    expect(find.bySemanticsLabel('Go on'), findsOneWidget);
    expect(find.bySemanticsLabel('Edit'), findsOneWidget);
    expect(find.bySemanticsLabel('Inspiration'), findsOneWidget);
  });

  testWidgets(
    'reply pagination exposes actual positions and boundary actions',
    (tester) async {
      var page = 0;
      late StateSetter setHostState;
      var confirmed = false;
      var count = 3;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                setHostState = setState;
                return _replyActions(
                  inspirationFeature: const LocationChatInspirationFeature(
                    messages: _inspirationReplies,
                    state: LocationChatReplyActionState.idle,
                  ),
                  style: kLocationChatStyle,
                  cardIndex: page,
                  cardCount: count,
                  cardsConfirmed: confirmed,
                  onPreviousCard: () => setState(() => page--),
                  onNextCard: () => setState(() => page++),
                );
              },
            ),
          ),
        ),
      );
      final previous = find.byKey(
        const ValueKey('location-chat-reply-previous-card'),
      );
      final next = find.byKey(const ValueKey('location-chat-reply-next-card'));
      expect(find.text('1 / 3'), findsOneWidget);
      final pagination = find.byKey(
        const ValueKey('location-chat-reply-pagination'),
      );
      final actionRow = find.byKey(
        const ValueKey('location-chat-reply-actions-four-icons'),
      );
      expect(
        LocationChatReplyActions.contentBottomGap +
            tester.getTopLeft(find.text('1 / 3')).dy -
            tester.getTopLeft(pagination).dy,
        closeTo(12, 0.01),
      );
      expect(
        tester.getTopLeft(actionRow).dy +
            7.5 -
            tester.getBottomLeft(find.text('1 / 3')).dy,
        closeTo(12, 0.01),
      );
      expect(find.bySemanticsLabel('Reply 1 of 3'), findsOneWidget);
      expect(tester.widget<IconButton>(previous).onPressed, isNull);
      await tester.tap(next);
      await tester.pump();
      expect(find.text('2 / 3'), findsOneWidget);
      await tester.tap(next);
      await tester.pump();
      expect(find.text('3 / 3'), findsOneWidget);
      expect(tester.widget<IconButton>(next).onPressed, isNull);
      await tester.tap(previous);
      await tester.pump();
      expect(find.text('2 / 3'), findsOneWidget);
      setHostState(() => confirmed = true);
      await tester.pump();
      expect(previous, findsNothing);
      setHostState(() {
        confirmed = false;
        count = 1;
        page = 0;
      });
      await tester.pump();
      expect(previous, findsNothing);
      setHostState(() => count = 0);
      await tester.pump();
      expect(
        find.byKey(const ValueKey('location-chat-reply-page-indicator')),
        findsNothing,
      );
    },
  );

  testWidgets('locked pagination keeps both arrows visible and disabled', (
    tester,
  ) async {
    var previousCalls = 0;
    var nextCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _replyActions(
            style: kLocationChatStyle,
            cardIndex: 1,
            cardCount: 3,
            cardSwitchEnabled: false,
            onPreviousCard: () => previousCalls++,
            onNextCard: () => nextCalls++,
          ),
        ),
      ),
    );
    final previous = find.byKey(
      const ValueKey('location-chat-reply-previous-card'),
    );
    final next = find.byKey(const ValueKey('location-chat-reply-next-card'));
    expect(previous, findsOneWidget);
    expect(next, findsOneWidget);
    expect(tester.widget<IconButton>(previous).onPressed, isNull);
    expect(tester.widget<IconButton>(next).onPressed, isNull);
    await tester.tap(previous);
    await tester.tap(next);
    expect(previousCalls, 0);
    expect(nextCalls, 0);
  });

  testWidgets(
    'inspiration swipes through three previews matching the user bubble',
    (tester) async {
      final style = kLocationChatStyle;
      await tester.pumpWidget(
        MaterialApp(
          scrollBehavior: const GenesisScrollBehavior(),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 390,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: style.messageListPadding,
                    child: Column(
                      children: [
                        ChatSelfMessageBubble(
                          message: ChatMessageVm(
                            localId: 'reference-user',
                            senderId: 'user',
                            senderName: 'User',
                            text:
                                'A long reference reply that fills the maximum '
                                'available width of the user message bubble.',
                            isMe: true,
                            status: 'sent',
                          ),
                          style: style,
                          maxWidthCap: 230,
                        ),
                        _replyActions(
                          inspirationFeature:
                              const LocationChatInspirationFeature(
                                messages: _inspirationReplies,
                                state: LocationChatReplyActionState.idle,
                              ),
                          style: style,
                          selfMessageBubbleMaxWidthCap: 230,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final inspiration = find.bySemanticsLabel('Inspiration');
      final first = find.byKey(const ValueKey('inspiration-reply-card-0'));
      expect(first, findsNothing);
      await tester.tap(inspiration);
      await tester.pumpAndSettle();

      final reference = tester.getRect(
        find.byKey(const ValueKey('chat-message-bubble-reference-user')),
      );
      final carousel = find.byKey(
        const ValueKey('inspiration-replies-carousel'),
      );
      expect(find.byKey(const ValueKey('inspiration-get-more')), findsNothing);
      for (var index = 0; index < 3; index++) {
        if (index > 0) {
          await tester.drag(carousel, const Offset(-230, 0));
          await tester.pumpAndSettle();
        }
        final card = find.byKey(ValueKey('inspiration-reply-card-$index'));
        expect(card, findsOneWidget);
        final bounds = tester.getRect(card);
        expect(bounds.width, closeTo(reference.width, 0.01));
        final viewport = tester.getRect(carousel);
        expect(bounds.right, closeTo(reference.right, 0.01));
        final neighborIndex = index < 2 ? index + 1 : index - 1;
        final neighbor = tester.getRect(
          find.byKey(ValueKey('inspiration-reply-card-$neighborIndex')),
        );
        expect(
          neighbor.overlaps(viewport),
          isTrue,
          reason: 'The adjacent card must peek into the viewport.',
        );
        expect(viewport.contains(neighbor.center), isFalse);
        expect(bounds.top, closeTo(tester.getTopLeft(carousel).dy, 0.01));
        final bubble = tester.widget<ChatMessageBubble>(
          find.descendant(of: card, matching: find.byType(ChatMessageBubble)),
        );
        expect(
          bubble.style!.selfBubbleColor,
          chatNarratorMessageBackgroundColor(
            style,
          ).withValues(alpha: style.selfBubbleColor.a),
        );
        expect(bubble.onTap, isNotNull);
        final surface = tester.widget<ChatStableBackdropSurface>(
          find.descendant(
            of: card,
            matching: find.byType(ChatStableBackdropSurface),
          ),
        );
        expect(surface.sigma, style.bubbleBackdropBlurSigma);
      }
      await tester.tap(inspiration);
      await tester.pumpAndSettle();
      expect(first, findsNothing);
      await tester.tap(inspiration);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('inspiration-reply-card-2')),
        findsOneWidget,
      );
      await tester.drag(carousel, const Offset(230, 0));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('inspiration-reply-card-1')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('inspiration sends the card or edits from the full right strip', (
    tester,
  ) async {
    final sent = <String>[];
    final edited = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        scrollBehavior: const GenesisScrollBehavior(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 390,
              child: _replyActions(
                inspirationFeature: const LocationChatInspirationFeature(
                  messages: _inspirationReplies,
                  state: LocationChatReplyActionState.idle,
                ),
                style: kLocationChatStyle,
                onInspirationSend: sent.add,
                onInspirationEdit: edited.add,
              ),
            ),
          ),
        ),
      ),
    );
    final toggle = find.bySemanticsLabel('Inspiration');
    final carousel = find.byKey(const ValueKey('inspiration-replies-carousel'));
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    final activeRight = tester
        .getRect(find.byKey(const ValueKey('inspiration-reply-card-0')))
        .right;
    var current = 0;
    for (final target in [1, 0, 1, 2, 1, 0]) {
      // The left preview exposes its edit strip; that must only select it.
      final tapTarget = find.byKey(
        ValueKey(
          target < current
              ? 'inspiration-edit-$target'
              : 'inspiration-reply-card-$target',
        ),
      );
      final visible = tester
          .getRect(tapTarget)
          .intersect(tester.getRect(carousel));
      expect(visible.isEmpty, isFalse);
      await tester.tapAt(visible.center);
      await tester.pumpAndSettle();
      expect(sent, isEmpty);
      expect(edited, isEmpty);
      expect(carousel, findsOneWidget);
      expect(
        tester
            .getRect(find.byKey(ValueKey('inspiration-reply-card-$target')))
            .right,
        closeTo(activeRight, 0.01),
      );
      current = target;
    }
    await tester.tap(find.byKey(const ValueKey('inspiration-reply-card-0')));
    await tester.pumpAndSettle();
    expect(sent, ['Good job!']);
    expect(edited, isEmpty);
    expect(carousel, findsNothing);

    // Both ends of the strip respond, even far away from the centered icon.
    for (final nearTop in [true, false]) {
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      final strip = tester.getRect(
        find.byKey(const ValueKey('inspiration-edit-0')),
      );
      await tester.tapAt(
        Offset(strip.center.dx, nearTop ? strip.top + 4 : strip.bottom - 4),
      );
      await tester.pumpAndSettle();
      expect(carousel, findsNothing);
    }
    expect(edited, ['Good job!', 'Good job!']);
    expect(sent, ['Good job!']);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    await tester.drag(carousel, const Offset(-230, 0));
    await tester.pumpAndSettle();
    expect(sent, ['Good job!'], reason: 'Swiping must not send.');
    await tester.tap(find.byKey(const ValueKey('inspiration-reply-card-1')));
    await tester.pumpAndSettle();
    expect(sent.last, startsWith("You're right to ask for a plan."));
    expect(carousel, findsNothing);
  });
  testWidgets('inspiration collapses when a retained chat page is reentered', (
    tester,
  ) async {
    final coordinator = LocationChatScrollCoordinator();
    addTearDown(coordinator.dispose);
    final messages = [
      ChatMessageVm(
        localId: 'reply',
        senderId: 'character',
        senderName: 'Character',
        text: 'A completed reply.',
        isMe: false,
        status: 'sent',
        senderType: 'character',
      ),
    ];
    Widget host(bool active) => MaterialApp(
      scrollBehavior: const GenesisScrollBehavior(),
      home: Scaffold(
        body: SizedBox(
          width: 390,
          height: 600,
          child: LocationChatAnchoredMessageList(
            inspirationFeature: const LocationChatInspirationFeature(
              messages: _inspirationReplies,
              state: LocationChatReplyActionState.idle,
            ),
            coordinator: coordinator,
            active: active,
            messages: messages,
            topTitle: '',
            replyActionsMessageId: 'reply',
            style: kLocationChatStyle,
          ),
        ),
      ),
    );
    final carousel = find.byKey(const ValueKey('inspiration-replies-carousel'));
    await tester.pumpWidget(host(true));
    await tester.pumpAndSettle();
    final retainedState = tester.state(
      find.byType(LocationChatAnchoredMessageList),
    );
    for (var visit = 0; visit < 2; visit++) {
      expect(carousel, findsNothing);
      await tester.tap(find.bySemanticsLabel('Inspiration'));
      await tester.pumpAndSettle();
      expect(carousel, findsOneWidget);
      await tester.pumpWidget(host(true));
      await tester.pumpAndSettle();
      expect(
        carousel,
        findsOneWidget,
        reason: 'An ordinary rebuild must keep it expanded.',
      );
      await tester.pumpWidget(host(false));
      await tester.pumpAndSettle();
      expect(carousel, findsNothing);
      await tester.pumpWidget(host(true));
      await tester.pumpAndSettle();
      expect(
        tester.state(find.byType(LocationChatAnchoredMessageList)),
        same(retainedState),
      );
      expect(carousel, findsNothing);
    }
    expect(tester.takeException(), isNull);
  });
  testWidgets('inspiration survives recycling its message row', (tester) async {
    final coordinator = LocationChatScrollCoordinator();
    addTearDown(coordinator.dispose);
    final messages = List.generate(
      45,
      (index) => ChatMessageVm(
        localId: 'reply-$index',
        senderId: 'character',
        senderName: 'Character',
        text:
            'This is a long reply with enough content to fill several lines in the chat history. '
            'Scrolling away should not discard the inspiration selection.',
        isMe: false,
        status: 'sent',
        senderType: 'character',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        scrollBehavior: const GenesisScrollBehavior(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 390,
              height: 600,
              child: LocationChatAnchoredMessageList(
                inspirationFeature: const LocationChatInspirationFeature(
                  messages: _inspirationReplies,
                  state: LocationChatReplyActionState.idle,
                ),
                coordinator: coordinator,
                messages: messages,
                topTitle: '',
                replyActionsMessageId: 'reply-44',
                style: kLocationChatStyle,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Inspiration'));
    await tester.pumpAndSettle();
    final carousel = find.byKey(const ValueKey('inspiration-replies-carousel'));
    await tester.ensureVisible(carousel);
    await tester.drag(carousel, const Offset(-300, 0));
    await tester.pumpAndSettle();
    coordinator.controller.jumpTo(0);
    await tester.pumpAndSettle();
    expect(find.byType(LocationChatReplyActions), findsNothing);
    coordinator.controller.jumpTo(
      coordinator.controller.position.maxScrollExtent,
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('inspiration-reply-card-1')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'guest subscription prompt opens only Subscription and cannot swipe to Gems',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          scrollBehavior: const GenesisScrollBehavior(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: LocationChatSubscriptionPrompt(
                style: kLocationChatStyle,
                promptKey: const ValueKey('guest-subscription-prompt'),
                semanticsLabel: 'Get more',
                message: const TextSpan(text: 'Subscription'),
                actionLabel: 'Get more >',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final getMore = find.byKey(const ValueKey('guest-subscription-prompt'));
      await tester.ensureVisible(getMore);
      await tester.tap(getMore);
      await tester.pumpAndSettle();
      expect(find.text('Subscription'), findsOneWidget);
      expect(find.text('Buy Gems'), findsNothing);
      expect(find.byKey(const ValueKey('pro-tier-title')), findsOneWidget);
      await tester.drag(
        find.byKey(const ValueKey('purchase-sheet-pages')),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('pro-tier-title')), findsOneWidget);
      expect(find.text('Buy Gems'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('gem-purchase-sheet-close')));
      await tester.pumpAndSettle();
      expect(find.byType(PurchaseOptionsSheet), findsNothing);
    },
  );
  testWidgets('purchase tabs share the dark action sheet header geometry', (
    tester,
  ) async {
    Widget host(Widget child) => MaterialApp(
      theme: ThemeData.dark(),
      scrollBehavior: const GenesisScrollBehavior(),
      home: Scaffold(body: SizedBox(width: 390, height: 500, child: child)),
    );
    const contentKey = ValueKey('purchase-content-position');
    const closeKey = ValueKey('gem-purchase-sheet-close');
    await tester.pumpWidget(
      host(
        GenesisBottomSheetPanel(
          title: 'Low Gems',
          height: 500,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          trailing: GenesisBottomSheetCloseButton(
            buttonKey: closeKey,
            onPressed: () {},
          ),
          child: const SizedBox.expand(key: contentKey),
        ),
      ),
    );
    final closeRect = tester.getRect(find.byKey(closeKey));
    final contentTop = tester.getTopLeft(find.byKey(contentKey)).dy;
    await tester.pumpWidget(
      host(
        PurchaseOptionsSheet(
          gemsBuilder: (_) => const SizedBox.expand(key: contentKey),
        ),
      ),
    );
    expect(tester.getRect(find.byKey(closeKey)), closeRect);
    expect(tester.getTopLeft(find.byKey(contentKey)).dy, contentTop);
  });
  testWidgets('collapsing inspiration keeps the bottom after horizontal swipes', (
    tester,
  ) async {
    final coordinator = LocationChatScrollCoordinator();
    addTearDown(coordinator.dispose);
    final messages = List.generate(
      25,
      (index) => ChatMessageVm(
        localId: 'cycle-$index',
        senderId: 'character',
        senderName: 'Character',
        text:
            'A reply long enough to fill several lines, keeping the conversation scrollable while testing inspiration expansion.',
        isMe: false,
        status: 'sent',
        senderType: 'character',
      ),
    );
    const viewportKey = ValueKey('cycle-viewport');
    await tester.pumpWidget(
      MaterialApp(
        scrollBehavior: const GenesisScrollBehavior(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              key: viewportKey,
              width: 390,
              height: 650,
              child: NotificationListener<ScrollNotification>(
                onNotification: coordinator.handleScrollNotification,
                child: LocationChatAnchoredMessageList(
                  inspirationFeature: const LocationChatInspirationFeature(
                    messages: _inspirationReplies,
                    state: LocationChatReplyActionState.idle,
                  ),
                  coordinator: coordinator,
                  messages: messages,
                  topTitle: '',
                  replyActionsMessageId: 'cycle-24',
                  style: kLocationChatStyle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (var cycle = 0; cycle < 3; cycle++) {
      await tester.tap(find.bySemanticsLabel('Inspiration'));
      await tester.pumpAndSettle();
      expect(coordinator.isAtBottom, isTrue);
      final viewport = tester.getRect(find.byKey(viewportKey));
      final footer = tester.getRect(
        find.byKey(const ValueKey('inspiration-replies-carousel')),
      );
      expect(footer.bottom, lessThanOrEqualTo(viewport.bottom));
      await tester.drag(
        find.byKey(const ValueKey('inspiration-replies-carousel')),
        Offset(cycle.isEven ? -230 : 230, 0),
      );
      await tester.pumpAndSettle();
      expect(
        coordinator.mode,
        LocationChatViewportMode.followingLatest,
        reason:
            'Horizontal card swipes must not detach the vertical conversation.',
      );
      await tester.tap(find.bySemanticsLabel('Inspiration'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('inspiration-get-more')), findsNothing);
      expect(
        find.byKey(const ValueKey('inspiration-replies-carousel')),
        findsNothing,
      );
      expect(coordinator.isAtBottom, isTrue);
    }
  });
  testWidgets(
    'round controls exist without candidate messages and retain state',
    (tester) async {
      final coordinator = LocationChatScrollCoordinator();
      addTearDown(coordinator.dispose);
      final user = ChatMessageVm(
        localId: 'user',
        senderId: 'user',
        senderName: 'User',
        text: 'Hello',
        isMe: true,
        status: 'sent',
      );
      Widget host(
        List<ChatMessageVm> messages, {
        String status = 'Generating…',
      }) => MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            height: 600,
            child: LocationChatAnchoredMessageList(
              inspirationFeature: const LocationChatInspirationFeature(
                messages: _inspirationReplies,
                state: LocationChatReplyActionState.idle,
              ),
              coordinator: coordinator,
              messages: messages,
              topTitle: '',
              replyActionsIdentity: 'world/location/round',
              replyStatus: Text(status),
              replyCardIndex: 1,
              replyCardCount: 2,
              regenerateFeature: const LocationChatRegenerateFeature.disabled(),
              goOnFeature: const LocationChatGoOnFeature.disabled(),
              editFeature: const LocationChatEditFeature.disabled(),
            ),
          ),
        ),
      );
      await tester.pumpWidget(host([user]));
      await tester.pumpAndSettle();
      final controls = find.byKey(
        const ValueKey('reply-actions-world/location/round'),
      );
      expect(controls, findsOneWidget);
      expect(find.text('Generating…'), findsOneWidget);
      final state = tester.state(controls);
      final candidate = ChatMessageVm(
        localId: 'candidate-100',
        senderId: 'role',
        senderName: 'Role',
        text: 'A candidate reply',
        isMe: false,
        status: 'streaming',
      );
      await tester.pumpWidget(host([user, candidate]));
      await tester.pumpAndSettle();
      expect(tester.state(controls), same(state));
      await tester.pumpWidget(host([user], status: 'Generation failed'));
      await tester.pumpAndSettle();
      expect(tester.state(controls), same(state));
      expect(find.text('Generation failed'), findsOneWidget);
      final list = tester.widget<LocationChatAnchoredMessageList>(
        find.byType(LocationChatAnchoredMessageList),
      );
      expect(list.messages, [user]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reply action slot stays at the tail across send and new reply', (
    tester,
  ) async {
    final coordinator = LocationChatScrollCoordinator();
    addTearDown(coordinator.dispose);
    final oldReply = ChatMessageVm(
      localId: 'old-reply',
      senderId: 'role',
      senderName: 'Role',
      text: 'Old reply',
      isMe: false,
      status: 'sent',
    );
    final userMessage = ChatMessageVm(
      localId: 'new-user',
      senderId: 'user',
      senderName: 'User',
      text: 'New user message',
      isMe: true,
      status: 'sending',
    );
    final newReply = ChatMessageVm(
      localId: 'new-reply',
      senderId: 'role',
      senderName: 'Role',
      text: 'New reply',
      isMe: false,
      status: 'sent',
    );
    Widget host(
      List<ChatMessageVm> messages, {
      required String round,
      required bool actionsVisible,
    }) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 390,
          height: 600,
          child: LocationChatAnchoredMessageList(
            coordinator: coordinator,
            messages: messages,
            topTitle: '',
            replyActionsIdentity: round,
            replyActionsVisible: actionsVisible,
          ),
        ),
      ),
    );

    const slotKey = ValueKey('location-chat-reply-action-slot');
    await tester.pumpWidget(
      host([oldReply], round: 'round-1', actionsVisible: true),
    );
    final slot = find.byKey(slotKey);
    final slotElement = slot.evaluate().single;
    final slotHeight = tester.getSize(slot).height;
    expect(
      find.byKey(const ValueKey('location-chat-reply-control:round-1')),
      findsOneWidget,
    );

    await tester.pumpWidget(
      host([oldReply, userMessage], round: 'round-1', actionsVisible: false),
    );
    expect(slot.evaluate().single, same(slotElement));
    expect(tester.getSize(slot).height, slotHeight);
    expect(
      find.byKey(const ValueKey('location-chat-reply-control:round-1')),
      findsNothing,
    );
    expect(
      tester.getTopLeft(slot).dy,
      greaterThan(tester.getBottomLeft(find.text('New user message')).dy),
    );

    await tester.pumpWidget(
      host(
        [oldReply, userMessage, newReply],
        round: 'round-2',
        actionsVisible: true,
      ),
    );
    expect(slot.evaluate().single, same(slotElement));
    expect(tester.getSize(slot).height, slotHeight);
    expect(
      find.byKey(const ValueKey('location-chat-reply-control:round-2')),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(slot).dy,
      greaterThan(tester.getBottomLeft(find.text('New reply')).dy),
    );
  });

  testWidgets(
    'explicit card switches keep the round controls in the viewport',
    (tester) async {
      final coordinator = LocationChatScrollCoordinator();
      addTearDown(coordinator.dispose);
      final messages = List.generate(
        15,
        (index) => ChatMessageVm(
          localId: 'history-$index',
          senderId: 'role',
          senderName: 'Role',
          text: 'Previous history. ' * 10,
          isMe: false,
          status: 'sent',
        ),
      );
      Widget host(int revision, int lines, {bool loading = false}) =>
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 390,
                height: 500,
                child: NotificationListener<ScrollNotification>(
                  onNotification: coordinator.handleScrollNotification,
                  child: LocationChatAnchoredMessageList(
                    inspirationFeature: const LocationChatInspirationFeature(
                      messages: _inspirationReplies,
                      state: LocationChatReplyActionState.idle,
                    ),
                    coordinator: coordinator,
                    topTitle: '',
                    oldestEdgeLoading: loading,
                    messages: [
                      ...messages,
                      ChatMessageVm(
                        localId: 'candidate-$revision',
                        senderId: 'role',
                        senderName: 'Role',
                        text: List.filled(
                          lines,
                          'Candidate reply line',
                        ).join('\n'),
                        isMe: false,
                        status: 'sent',
                      ),
                    ],
                    replyActionsIdentity: 'world/location/round',
                    replyPresentationRevision: revision,
                    replyCardIndex: revision,
                    replyCardCount: 3,
                  ),
                ),
              ),
            ),
          );
      final controls = find.byKey(
        const ValueKey('reply-actions-world/location/round'),
      );
      await tester.pumpWidget(host(0, 5));
      await tester.pumpAndSettle();
      final top = tester.getTopLeft(controls).dy;
      await tester.pumpWidget(host(1, 20));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(controls).dy, closeTo(top, 1));
      expect(coordinator.shouldFollowLatest, isTrue);
      // A concurrent history request must not hold a user-selected candidate.
      await tester.pumpWidget(host(1, 20, loading: true));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpWidget(host(2, 3, loading: true));
      await tester.pump();
      expect(find.text('3 / 3'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('chat-message-bubble-candidate-2')),
        findsOneWidget,
      );
      await tester.pumpWidget(host(2, 3));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'candidate chunks follow only while the reader is at the bottom',
    (tester) async {
      final coordinator = LocationChatScrollCoordinator();
      addTearDown(coordinator.dispose);
      final history = List.generate(
        20,
        (index) => ChatMessageVm(
          localId: 'past-$index',
          senderId: 'role',
          senderName: 'Role',
          text: 'Earlier messages in this conversation. ' * 5,
          isMe: false,
          status: 'sent',
        ),
      );
      Widget host(int lines, {bool loading = false}) => MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            height: 500,
            child: NotificationListener<ScrollNotification>(
              onNotification: coordinator.handleScrollNotification,
              child: LocationChatAnchoredMessageList(
                inspirationFeature: const LocationChatInspirationFeature(
                  messages: _inspirationReplies,
                  state: LocationChatReplyActionState.idle,
                ),
                coordinator: coordinator,
                topTitle: '',
                oldestEdgeLoading: loading,
                messages: [
                  ...history,
                  ChatMessageVm(
                    localId: 'live-candidate',
                    senderId: 'role',
                    senderName: 'Role',
                    text: List.filled(lines, 'Streaming line').join('\n'),
                    isMe: false,
                    status: 'streaming',
                  ),
                ],
                replyActionsIdentity: 'world/location/round',
                replyPresentationRevision: 1,
                replyCardIndex: 1,
                replyCardCount: 2,
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(host(2));
      await tester.pumpAndSettle();
      final previousOffset = coordinator.controller.offset;
      await tester.pumpWidget(host(8));
      await tester.pumpAndSettle();
      expect(coordinator.controller.offset, greaterThan(previousOffset));
      expect(coordinator.isAtBottom, isTrue);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 200));
      await tester.pumpAndSettle();
      expect(coordinator.isDetached, isTrue);
      final detachedOffset = coordinator.controller.offset;
      await tester.pumpWidget(host(18));
      await tester.pumpAndSettle();
      expect(coordinator.controller.offset, closeTo(detachedOffset, 0.1));
      // A history loader does not buffer new candidate text.
      await tester.pumpWidget(host(18, loading: true));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpWidget(host(20, loading: true));
      await tester.pump();
      final candidateRow = tester.widget<ChatMessageRow>(
        find.byKey(const ValueKey('live-candidate')),
      );
      expect(candidateRow.message.text.split('\n'), hasLength(20));
      await tester.pumpWidget(host(20));
      await tester.pumpAndSettle();
      expect(coordinator.isDetached, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
