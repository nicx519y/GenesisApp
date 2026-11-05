import 'package:flutter/material.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_reply_actions.dart';
import 'package:genesis_flutter_android/features/location_chat_reply/regenerate/regenerate.dart';
import 'package:genesis_flutter_android/features/location_chat_reply/shared/reply_action_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/network/chatroom/chat_photo.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_scroll_coordinator.dart';

void main() {
  testWidgets(
    'photo toolbar remains visible during small drags after expansion',
    (tester) async {
      final coordinator = LocationChatScrollCoordinator();
      addTearDown(coordinator.dispose);
      var rows = [for (var i = 0; i < 20; i++) _text('before-$i')];
      Widget tree() => MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            height: 600,
            child: AnimatedBuilder(
              animation: coordinator,
              builder: (_, _) => NotificationListener<ScrollNotification>(
                onNotification: coordinator.handleScrollNotification,
                child: LocationChatAnchoredMessageList(
                  coordinator: coordinator,
                  messages: rows,
                  photoArrivalRequestIds: const {'request'},
                  topTitle: '',
                  style: kLocationChatStyle,
                  replyActionsMessageId: rows.last.localId,
                  replyActionsIdentity: 'round',
                  onTakePhoto: () {},
                  regenerateFeature: LocationChatRegenerateFeature(
                    state: LocationChatReplyActionState.idle,
                    onInvoke: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(tree());
      await tester.pumpAndSettle();
      rows = [...rows, _photo()];
      await tester.pumpWidget(tree());
      await tester.pumpAndSettle();
      coordinator.controller.jumpTo(
        coordinator.controller.position.maxScrollExtent,
      );
      await tester.pumpAndSettle();
      final action = find.byKey(const ValueKey('location-chat-take-photo'));
      expect(action.hitTestable(), findsOneWidget);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(CustomScrollView)),
      );
      for (final dy in [2.0, -2.0, 5.0, -5.0, 1.0, -1.0]) {
        await gesture.moveBy(Offset(0, dy));
        await tester.pump(const Duration(milliseconds: 16));
        expect(
          tester
              .widget<LocationChatReplyActions>(
                find.byType(LocationChatReplyActions),
              )
              .actionsHidden,
          isFalse,
        );
        expect(action, findsOneWidget);
        expect(
          tester
              .getRect(action)
              .overlaps(tester.getRect(find.byType(CustomScrollView))),
          isTrue,
        );
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(action.hitTestable(), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'photo expands if its request registration follows the first message frame',
    (tester) async {
      final coordinator = LocationChatScrollCoordinator();
      addTearDown(coordinator.dispose);
      var rows = [_text('before')];
      var requests = <String>{};
      Widget tree() => MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            height: 600,
            child: LocationChatAnchoredMessageList(
              coordinator: coordinator,
              messages: rows,
              photoArrivalRequestIds: requests,
              topTitle: '',
              style: kLocationChatStyle,
              onTakePhoto: () {},
              replyActionsMessageId: rows.last.localId,
              replyActionsIdentity: 'round',
            ),
          ),
        ),
      );
      await tester.pumpWidget(tree());
      await tester.pumpAndSettle();
      rows = [...rows, _photo()];
      await tester.pumpWidget(tree());
      requests = {'request'};
      await tester.pumpWidget(tree());
      await tester.pump();
      expect(find.byKey(const ValueKey('photo-arrival-photo')), findsOneWidget);
      await tester.pumpAndSettle();
      expect(
        tester
            .getSize(find.byKey(const ValueKey('photo-arrival-photo')))
            .height,
        greaterThan(100),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'offscreen photo stays mounted for expansion then does not replay on scrolling back',
    (tester) async {
      final coordinator = LocationChatScrollCoordinator();
      addTearDown(coordinator.dispose);
      var rows = [for (var i = 0; i < 25; i++) _text('before-$i')];
      Widget tree() => MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            height: 600,
            child: LocationChatAnchoredMessageList(
              coordinator: coordinator,
              messages: rows,
              photoArrivalRequestIds: const {'request'},
              topTitle: '',
              style: kLocationChatStyle,
              replyWaitingPositioningEnabled: false,
            ),
          ),
        ),
      );
      await tester.pumpWidget(tree());
      await tester.pumpAndSettle();
      coordinator.beginHistoryNavigation();
      coordinator.controller.jumpTo(0);
      await tester.pumpAndSettle();
      rows = [...rows, _photo()];
      await tester.pumpWidget(tree());
      final arrival = find.byKey(const ValueKey('photo-arrival-photo'));
      expect(arrival, findsOneWidget);
      expect(tester.widget<SizeTransition>(arrival).sizeFactor.value, 0);
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester.widget<SizeTransition>(arrival).sizeFactor.value,
        inExclusiveRange(0, 1),
      );
      await tester.pumpAndSettle();
      coordinator.controller.jumpTo(
        coordinator.controller.position.maxScrollExtent,
      );
      await tester.pumpAndSettle();
      expect(tester.widget<SizeTransition>(arrival).sizeFactor.value, 1);
      expect(tester.getSize(arrival).height, greaterThan(100));
      await tester.pumpWidget(tree());
      expect(tester.widget<SizeTransition>(arrival).sizeFactor.value, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final interruption in ['leave', 'remove', 'cover']) {
    testWidgets('photo toolbar recovers after interruption: $interruption', (
      tester,
    ) async {
      final coordinator = LocationChatScrollCoordinator();
      addTearDown(coordinator.dispose);
      var active = true;
      var tickers = true;
      var rows = [_text('before')];
      Widget tree() => MaterialApp(
        home: Scaffold(
          body: TickerMode(
            enabled: tickers,
            child: SizedBox(
              width: 390,
              height: 600,
              child: LocationChatAnchoredMessageList(
                coordinator: coordinator,
                active: active,
                messages: rows,
                photoArrivalRequestIds: const {'request'},
                topTitle: '',
                style: kLocationChatStyle,
                replyActionsMessageId: 'before',
                replyActionsIdentity: 'round',
                onTakePhoto: () {},
                regenerateFeature: LocationChatRegenerateFeature(
                  state: LocationChatReplyActionState.idle,
                  onInvoke: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(tree());
      await tester.pumpAndSettle();
      rows = [
        ...rows,
        ChatMessageVm(
          localId: 'photo',
          senderId: '',
          senderName: '',
          text: '',
          senderType: 'image',
          isMe: false,
          status: 'sent',
          photo: const ChatPhoto(
            taskId: 'task',
            requestId: 'request',
            status: ChatPhotoStatus.generating,
          ),
        ),
      ];
      await tester.pumpWidget(tree());
      await tester.pump();
      expect(
        tester
            .widget<LocationChatReplyActions>(
              find.byType(LocationChatReplyActions),
            )
            .actionsHidden,
        isTrue,
      );
      if (interruption == 'remove') {
        rows = [rows.first];
      } else if (interruption == 'cover') {
        tickers = false;
      } else {
        active = false;
      }
      await tester.pumpWidget(tree());
      active = true;
      tickers = true;
      await tester.pumpWidget(tree());
      expect(
        tester
            .widget<LocationChatReplyActions>(
              find.byType(LocationChatReplyActions),
            )
            .actionsHidden,
        isFalse,
      );
      if (interruption != 'remove') {
        expect(
          tester
              .widget<SizeTransition>(
                find.byKey(const ValueKey('photo-arrival-photo')),
              )
              .sizeFactor
              .value,
          1,
        );
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final slowResponse in [false, true]) {
    testWidgets(
      'photo scroll starts at dispatch; toolbar waits for expansion: $slowResponse',
      (tester) async {
        final coordinator = LocationChatScrollCoordinator();
        addTearDown(coordinator.dispose);
        var rows = [for (var i = 0; i < 20; i++) _text('before-$i')];
        var requests = <String>{};
        var submitting = false;
        Widget tree() => MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 390,
              height: 600,
              child: AnimatedBuilder(
                animation: coordinator,
                builder: (_, _) => NotificationListener<ScrollNotification>(
                  onNotification: coordinator.handleScrollNotification,
                  child: LocationChatAnchoredMessageList(
                    coordinator: coordinator,
                    messages: rows,
                    photoArrivalRequestIds: requests,
                    topTitle: '',
                    style: kLocationChatStyle,
                    takingPhoto: submitting,
                    onTakePhoto: () {},
                    replyActionsMessageId: 'before-19',
                    replyActionsIdentity: 'round',
                    regenerateFeature: LocationChatRegenerateFeature(
                      state: LocationChatReplyActionState.idle,
                      onInvoke: () {},
                    ),
                    replyViewportReserveFraction: .6,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpWidget(tree());
        await tester.pumpAndSettle();
        final before = coordinator.controller.offset;
        requests = {'request'};
        submitting = true;
        await tester.pumpWidget(tree());
        await tester.pump();
        if (slowResponse) {
          for (var i = 0; i < 40; i++) {
            await tester.pump(const Duration(milliseconds: 16));
          }
          expect(coordinator.controller.offset, greaterThan(before));
          expect(
            find.byKey(const ValueKey('photo-arrival-photo')),
            findsNothing,
          );
          expect(
            tester
                .widget<LocationChatReplyActions>(
                  find.byType(LocationChatReplyActions),
                )
                .actionsHidden,
            isFalse,
          );
          // An uncertain HTTP result can be manually retried with the same ID.
          submitting = false;
          await tester.pumpWidget(tree());
          await tester.pumpAndSettle();
          await tester.drag(
            find.byType(CustomScrollView),
            const Offset(0, 160),
          );
          await tester.pumpAndSettle();
          final retryOffset = coordinator.controller.offset;
          submitting = true;
          await tester.pumpWidget(tree());
          for (var i = 0; i < 40; i++) {
            await tester.pump(const Duration(milliseconds: 16));
          }
          expect(coordinator.controller.offset, greaterThan(retryOffset));
        }
        submitting = false;
        rows = [
          ...rows,
          ChatMessageVm(
            localId: 'photo',
            senderId: '',
            senderName: '',
            senderType: 'image',
            text: '',
            isMe: false,
            status: 'sent',
            photo: const ChatPhoto(
              taskId: 'task',
              requestId: 'request',
              status: ChatPhotoStatus.generating,
            ),
          ),
        ];
        await tester.pumpWidget(tree());
        expect(
          tester
              .widget<LocationChatReplyActions>(
                find.byType(LocationChatReplyActions),
              )
              .actionsHidden,
          isTrue,
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          tester
              .widget<LocationChatReplyActions>(
                find.byType(LocationChatReplyActions),
              )
              .actionsHidden,
          isTrue,
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<LocationChatReplyActions>(
                find.byType(LocationChatReplyActions),
              )
              .actionsHidden,
          isFalse,
        );
        expect(
          tester
              .getSize(find.byKey(const ValueKey('photo-arrival-photo')))
              .height,
          greaterThan(100),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  for (final scenario in [
    (count: 0, interrupt: false),
    (count: 2, interrupt: false),
    (count: 20, interrupt: false),
    (count: 20, interrupt: true),
  ]) {
    final count = scenario.count;
    testWidgets('accepted photo scrolls before expanding once: $scenario', (
      tester,
    ) async {
      final coordinator = LocationChatScrollCoordinator();
      addTearDown(coordinator.dispose);
      var rows = [for (var i = 0; i < count; i++) _text('before-$i')];
      Widget tree() => MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            height: 600,
            child: AnimatedBuilder(
              animation: coordinator,
              builder: (_, _) => NotificationListener<ScrollNotification>(
                onNotification: coordinator.handleScrollNotification,
                child: LocationChatAnchoredMessageList(
                  coordinator: coordinator,
                  messages: rows,
                  photoArrivalRequestIds: const {'request'},
                  topTitle: '',
                  style: kLocationChatStyle,
                  replyViewportReserveFraction: .6,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(tree());
      await tester.pumpAndSettle();
      final before = coordinator.controller.offset;
      rows = [
        ...rows,
        ChatMessageVm(
          localId: 'photo',
          senderId: '',
          senderName: '',
          senderType: 'image',
          text: '',
          isMe: false,
          status: 'sent',
          photo: const ChatPhoto(
            taskId: 'task',
            requestId: 'request',
            status: ChatPhotoStatus.generating,
          ),
        ),
      ];
      await tester.pumpWidget(tree());
      await tester.pump();
      final arrival = find.byKey(const ValueKey('photo-arrival-photo'));
      expect(arrival, findsOneWidget);
      expect(tester.getSize(arrival).height, 0);
      await tester.pump(const Duration(milliseconds: 120));
      if (count > 0) expect(tester.getSize(arrival).height, 0);
      if (scenario.interrupt) {
        await tester.drag(find.byType(CustomScrollView), const Offset(0, 160));
      } else if (count > 0) {
        var factor = tester.widget<SizeTransition>(arrival).sizeFactor.value;
        for (var frame = 0; factor == 0 && frame < 90; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          factor = tester.widget<SizeTransition>(arrival).sizeFactor.value;
        }
        expect(factor, greaterThan(0));
        expect(factor, lessThan(1));
      }
      await tester.pumpAndSettle();
      if (scenario.interrupt) expect(coordinator.isReadingHistory, isTrue);
      if (count == 20 && !scenario.interrupt) {
        expect(coordinator.controller.offset, greaterThan(before));
      }
      expect(tester.getSize(arrival).height, greaterThan(100));
      final complete = tester.getSize(arrival).height;
      await tester.pumpWidget(tree());
      expect(tester.getSize(arrival).height, complete);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final scenario in [
    (before: 50, after: 20),
    (before: 50, after: 0),
    (before: 0, after: 0),
  ]) {
    testWidgets('photo reveal top/bottom clamp $scenario and user takeover', (
      tester,
    ) async {
      final coordinator = LocationChatScrollCoordinator();
      addTearDown(coordinator.dispose);
      final rows = <ChatMessageVm>[
        for (var i = 0; i < scenario.before; i++) _text('before-$i'),
        ChatMessageVm(
          localId: 'photo',
          senderId: '',
          senderName: '',
          senderType: 'image',
          text: '',
          isMe: false,
          status: 'sent',
          photo: const ChatPhoto(
            taskId: 't',
            requestId: '',
            status: ChatPhotoStatus.generating,
          ),
        ),
        for (var i = 0; i < scenario.after; i++) _text('after-$i'),
      ];
      ({int generation, String localId})? reveal;
      var settled = 0;
      Widget tree() => MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 390,
              height: 600,
              child: AnimatedBuilder(
                animation: coordinator,
                builder: (_, _) => NotificationListener<ScrollNotification>(
                  onNotification: coordinator.handleScrollNotification,
                  child: LocationChatAnchoredMessageList(
                    coordinator: coordinator,
                    messages: rows,
                    historyReveal: reveal,
                    historyRevealAlignTop: true,
                    onHistoryRevealSettled: () => settled++,
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
      await tester.pumpWidget(tree());
      await tester.pumpAndSettle();
      reveal = (
        generation: coordinator.beginHistoryNavigation(),
        localId: 'photo',
      );
      await tester.pumpWidget(tree());
      await tester.pumpAndSettle();
      final image = find.byType(AspectRatio);
      expect(image, findsOneWidget);
      expect(tester.getSize(image).aspectRatio, closeTo(2 / 3, .001));
      if (scenario.after > 0) {
        expect(
          tester.getTopLeft(image).dy,
          closeTo(tester.getTopLeft(find.byType(CustomScrollView)).dy, 1),
        );
      } else {
        expect(
          coordinator.controller.position.pixels,
          closeTo(coordinator.controller.position.maxScrollExtent, 1),
        );
      }
      expect(settled, 1);
      rows.add(_text('new-live-message'));
      await tester.pumpWidget(tree());
      await tester.pumpAndSettle();
      expect(settled, 1);
      if (scenario.before > 0) {
        await tester.drag(find.byType(CustomScrollView), const Offset(0, 160));
        await tester.pumpAndSettle();
        expect(coordinator.commandGeneration, isNot(reveal.generation));
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

ChatMessageVm _text(String id) => ChatMessageVm(
  localId: id,
  senderId: 'narrator',
  senderName: '',
  senderType: 'narrator',
  text: '$id: ${'A varying paragraph. ' * (1 + id.length % 4)}',
  isMe: false,
  status: 'sent',
);

ChatMessageVm _photo() => ChatMessageVm(
  localId: 'photo',
  senderId: '',
  senderName: '',
  senderType: 'image',
  text: '',
  isMe: false,
  status: 'sent',
  photo: const ChatPhoto(
    taskId: 'task',
    requestId: 'request',
    status: ChatPhotoStatus.generating,
  ),
);
