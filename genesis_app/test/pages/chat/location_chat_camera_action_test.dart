import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/features/location_chat_reply/edit/edit.dart';
import 'package:genesis_flutter_android/features/location_chat_reply/go_on/go_on.dart';
import 'package:genesis_flutter_android/features/location_chat_reply/inspiration/inspiration.dart';
import 'package:genesis_flutter_android/features/location_chat_reply/regenerate/regenerate.dart';
import 'package:genesis_flutter_android/features/location_chat_reply/shared/reply_action_state.dart';
import 'package:genesis_flutter_android/features/location_chat_reply/shared/reply_feature_button.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_reply_actions.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_scroll_coordinator.dart';

void main() {
  for (final senderType in ['image', 'nar_pic']) {
    testWidgets(
      'image toolbar follows conversation capabilities: $senderType',
      (tester) async {
        final coordinator = LocationChatScrollCoordinator();
        addTearDown(coordinator.dispose);
        var submitting = false;
        var message = ChatMessageVm(
          localId: 'output',
          senderId: 'nar_pic',
          senderName: '',
          senderType: senderType,
          text: '',
          isMe: false,
          status: 'sent',
        );
        Widget tree() => MaterialApp(
          home: Scaffold(
            body: LocationChatAnchoredMessageList(
              coordinator: coordinator,
              topTitle: '',
              style: kLocationChatStyle,
              messages: [message],
              replyActionsIdentity: 'round',
              replyActionsMessageId: 'output',
              cameraState: submitting
                  ? LocationChatReplyActionState.busy
                  : LocationChatReplyActionState.idle,
              onTakePhoto: () {},
              regenerateFeature: LocationChatRegenerateFeature(
                state: LocationChatReplyActionState.idle,
                onInvoke: () {},
              ),
              editFeature: LocationChatEditFeature(
                state: LocationChatReplyActionState.idle,
                onInvoke: () {},
              ),
              goOnFeature: LocationChatGoOnFeature(
                state: LocationChatReplyActionState.idle,
                onInvoke: () {},
              ),
              inspirationFeature: const LocationChatInspirationFeature(
                state: LocationChatReplyActionState.idle,
                messages: [],
              ),
            ),
          ),
        );
        await tester.pumpWidget(tree());
        await tester.pumpAndSettle();
        final regenerate = find.bySemanticsLabel('Regenerate');
        final edit = find.bySemanticsLabel('Edit');
        final camera = find.byKey(const ValueKey('location-chat-take-photo'));
        expect(regenerate, findsOneWidget);
        expect(edit, findsOneWidget);
        expect(
          find.byKey(const ValueKey('location-chat-go-on')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('location-chat-inspiration')),
          findsOneWidget,
        );
        expect(
          tester.widget<LocationChatReplyFeatureButton>(camera).state,
          LocationChatReplyActionState.idle,
        );
        submitting = true;
        await tester.pumpWidget(tree());
        expect(
          tester.widget<LocationChatReplyFeatureButton>(camera).state,
          LocationChatReplyActionState.busy,
        );
        expect(regenerate, findsOneWidget);
        expect(edit, findsOneWidget);
        submitting = false;
        message = ChatMessageVm(
          localId: 'output',
          senderId: 'char',
          senderName: 'Character',
          senderType: 'char',
          text: 'A later text reply.',
          isMe: false,
          status: 'sent',
        );
        await tester.pumpWidget(tree());
        await tester.pumpAndSettle();
        expect(regenerate, findsOneWidget);
        expect(edit, findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('camera cannot open a toolbar without a server reply identity', (
    tester,
  ) async {
    final coordinator = LocationChatScrollCoordinator();
    addTearDown(coordinator.dispose);
    var captured = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 350,
            height: 420,
            child: LocationChatAnchoredMessageList(
              coordinator: coordinator,
              topTitle: '',
              style: kLocationChatStyle,
              replyActionsVisible: false,
              messages: [
                ChatMessageVm(
                  localId: 'restored-scene',
                  senderId: 'char-1',
                  senderName: 'Character',
                  text: 'A restored scene.',
                  isMe: false,
                  status: 'sent',
                  senderType: 'char',
                ),
              ],
              cameraState: LocationChatReplyActionState.idle,
              onTakePhoto: () => captured++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final action = find.byKey(const ValueKey('location-chat-take-photo'));
    expect(action, findsNothing);
    expect(captured, 0);
    expect(
      find.byKey(const ValueKey('location-chat-regenerate')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('camera uses the latest reply toolbar callback without sending', (
    tester,
  ) async {
    var opens = 0;
    var regenerations = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: LocationChatReplyActions(
              style: kLocationChatStyle,
              regenerateFeature: LocationChatRegenerateFeature(
                state: LocationChatReplyActionState.idle,
                onInvoke: () => regenerations++,
              ),
              goOnFeature: LocationChatGoOnFeature(
                state: LocationChatReplyActionState.idle,
                onInvoke: () {},
              ),
              editFeature: LocationChatEditFeature(
                state: LocationChatReplyActionState.idle,
                onInvoke: () {},
              ),
              inspirationFeature: const LocationChatInspirationFeature(
                state: LocationChatReplyActionState.idle,
                messages: [],
              ),
              cameraState: LocationChatReplyActionState.idle,
              onTakePhoto: () => opens++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final action = find.byKey(const ValueKey('location-chat-take-photo'));
    expect(action, findsOneWidget);
    final regenerate = find.byKey(const ValueKey('location-chat-regenerate'));
    expect(tester.getCenter(action).dy, tester.getCenter(regenerate).dy);
    expect(tester.getRect(action).right, 304);
    expect(tester.getSize(action), const Size(32, 32));
    await tester.tapAt(tester.getTopLeft(action) + const Offset(2, 2));
    expect(opens, 1);
    expect(regenerations, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LocationChatReplyActions(style: kLocationChatStyle),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Camera'), findsNothing);
  });

  testWidgets('camera create is busy and disables every other reply icon', (
    tester,
  ) async {
    Widget tree(bool submitting) => MaterialApp(
      home: Scaffold(
        body: LocationChatReplyActions(
          style: kLocationChatStyle,
          cameraState: submitting
              ? LocationChatReplyActionState.busy
              : LocationChatReplyActionState.idle,
          onTakePhoto: () {},
          regenerateFeature: LocationChatRegenerateFeature(
            state: LocationChatReplyActionState.idle,
            onInvoke: () {},
          ),
          goOnFeature: LocationChatGoOnFeature(
            state: LocationChatReplyActionState.idle,
            onInvoke: () {},
          ),
          editFeature: LocationChatEditFeature(
            state: LocationChatReplyActionState.idle,
            onInvoke: () {},
          ),
          inspirationFeature: const LocationChatInspirationFeature(
            state: LocationChatReplyActionState.idle,
            messages: [],
          ),
        ),
      ),
    );
    await tester.pumpWidget(tree(true));
    await tester.pump(const Duration(milliseconds: 300));
    final buttons = tester
        .widgetList<LocationChatReplyFeatureButton>(
          find.byType(LocationChatReplyFeatureButton),
        )
        .toList();
    expect(
      buttons.where((b) => b.state == LocationChatReplyActionState.busy),
      hasLength(1),
    );
    expect(
      buttons.where((b) => b.state == LocationChatReplyActionState.disabled),
      hasLength(4),
    );
    for (final button
        in find.byType(LocationChatReplyFeatureButton).evaluate()) {
      final gestures = find.descendant(
        of: find.byWidget(button.widget),
        matching: find.byType(GestureDetector),
      );
      expect(
        tester
            .widgetList<GestureDetector>(gestures)
            .every((g) => g.onTap == null),
        isTrue,
      );
    }
    await tester.pumpWidget(tree(false));
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<LocationChatReplyFeatureButton>(
            find.byType(LocationChatReplyFeatureButton),
          )
          .every((b) => b.state == LocationChatReplyActionState.idle),
      isTrue,
    );
  });

  for (final state in LocationChatReplyActionState.values) {
    testWidgets(
      'camera uses its public state without a Regenerate fallback: ${state.name}',
      (tester) async {
        var captured = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LocationChatReplyActions(
                style: kLocationChatStyle,
                cameraState: state,
                onTakePhoto: () => captured++,
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        final camera = find.byKey(const ValueKey('location-chat-take-photo'));
        if (state == LocationChatReplyActionState.none) {
          expect(find.bySemanticsLabel('Camera'), findsNothing);
        } else {
          final button = tester.widget<LocationChatReplyFeatureButton>(camera);
          expect(button.state, state);
          expect(
            find.descendant(
              of: camera,
              matching: find.byType(CircularProgressIndicator),
            ),
            state == LocationChatReplyActionState.busy
                ? findsOneWidget
                : findsNothing,
          );
          await tester.tap(camera);
          expect(captured, state == LocationChatReplyActionState.idle ? 1 : 0);
        }
      },
    );
  }

  for (final busyFeature in ['regenerate', 'goOn', 'edit', 'inspiration']) {
    testWidgets('camera is disabled while $busyFeature is busy and recovers', (
      tester,
    ) async {
      var captured = 0;
      Widget toolbar({required bool busy}) => MaterialApp(
        home: Scaffold(
          body: LocationChatReplyActions(
            style: kLocationChatStyle,
            regenerateFeature: LocationChatRegenerateFeature(
              state: busy && busyFeature == 'regenerate'
                  ? LocationChatReplyActionState.busy
                  : LocationChatReplyActionState.idle,
              onInvoke: () {},
            ),
            goOnFeature: LocationChatGoOnFeature(
              state: busy && busyFeature == 'goOn'
                  ? LocationChatReplyActionState.busy
                  : LocationChatReplyActionState.none,
              onInvoke: null,
            ),
            editFeature: LocationChatEditFeature(
              state: busy && busyFeature == 'edit'
                  ? LocationChatReplyActionState.busy
                  : LocationChatReplyActionState.none,
              onInvoke: null,
            ),
            inspirationFeature: LocationChatInspirationFeature(
              state: busy && busyFeature == 'inspiration'
                  ? LocationChatReplyActionState.busy
                  : LocationChatReplyActionState.none,
              messages: const [],
            ),
            cameraState: LocationChatReplyActionState.idle,
            onTakePhoto: () => captured++,
          ),
        ),
      );

      await tester.pumpWidget(toolbar(busy: true));
      await tester.pump(const Duration(milliseconds: 300));
      final camera = find.byKey(const ValueKey('location-chat-take-photo'));
      expect(
        tester.widget<LocationChatReplyFeatureButton>(camera).state,
        LocationChatReplyActionState.disabled,
      );
      expect(
        find.descendant(
          of: camera,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
      );
      await tester.tap(camera);
      expect(captured, 0);

      await tester.pumpWidget(toolbar(busy: false));
      await tester.pumpAndSettle();
      expect(
        tester.widget<LocationChatReplyFeatureButton>(camera).state,
        LocationChatReplyActionState.idle,
      );
      await tester.tap(camera);
      expect(captured, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
