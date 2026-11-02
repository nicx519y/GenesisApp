import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/features/location_chat_reply/edit/edit.dart';
import 'package:genesis_flutter_android/features/location_chat_reply/go_on/go_on.dart';
import 'package:genesis_flutter_android/features/location_chat_reply/inspiration/inspiration.dart';
import 'package:genesis_flutter_android/features/location_chat_reply/regenerate/regenerate.dart';
import 'package:genesis_flutter_android/features/location_chat_reply/shared/reply_action_state.dart';
import 'package:genesis_flutter_android/features/location_chat_reply/shared/reply_touch_target.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_reply_actions.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_scroll_coordinator.dart';

void main() {
  Widget actions(
    List<String> calls, {
    bool enabled = true,
    bool expanded = true,
  }) => LocationChatReplyActions(
    style: kLocationChatStyle,
    actionsExpanded: expanded,
    regenerateFeature: LocationChatRegenerateFeature(
      state: enabled
          ? LocationChatReplyActionState.idle
          : LocationChatReplyActionState.disabled,
      onInvoke: () => calls.add('regenerate'),
    ),
    goOnFeature: LocationChatGoOnFeature(
      state: LocationChatReplyActionState.idle,
      onInvoke: () => calls.add('go-on'),
    ),
    editFeature: LocationChatEditFeature(
      state: LocationChatReplyActionState.idle,
      onInvoke: () => calls.add('edit'),
    ),
    inspirationFeature: LocationChatInspirationFeature(
      state: LocationChatReplyActionState.idle,
      messages: const [],
      onExpandedChanged: (_) => calls.add('inspiration'),
    ),
    onTakePhoto: () => calls.add('take-photo'),
  );

  Widget host(
    Widget child, {
    ScrollController? controller,
    VoidCallback? onHeaderTap,
  }) => MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 320,
          height: 500,
          child: LocationChatReplyTouchScope(
            child: SingleChildScrollView(
              controller: controller,
              child: Column(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onHeaderTap,
                    child: const SizedBox(height: 100, width: double.infinity),
                  ),
                  child,
                  const SizedBox(height: 1000),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('five 48-square touch targets keep the original 32-high layout', (
    tester,
  ) async {
    final calls = <String>[];
    await tester.pumpWidget(host(actions(calls)));
    final row = find.byKey(
      const ValueKey('location-chat-reply-actions-four-icons'),
    );
    expect(tester.getSize(row).height, 32);
    final ids = ['regenerate', 'go-on', 'edit', 'inspiration', 'take-photo'];
    for (var index = 0; index < ids.length; index++) {
      final id = ids[index];
      final button = find.byKey(ValueKey('location-chat-$id'));
      final rect = tester.getRect(button);
      final previousCalls = calls.where((call) => call == id).length;
      expect(rect.size, const Size(32, 32));
      expect(rect.center.dx, index < 4 ? 66.0 + 50 * index : 288.0);
      for (final offset in [
        const Offset(0, -23),
        const Offset(0, 23),
        const Offset(-23, 0),
        const Offset(23, 0),
        const Offset(-23, -23),
        const Offset(23, 23),
      ]) {
        await tester.tapAt(rect.center + offset);
        await tester.pumpAndSettle();
        expect(calls.last, id);
      }
      expect(calls.where((call) => call == id).length, previousCalls + 6);
      await tester.tapAt(rect.center + const Offset(0, 25));
      expect(calls.where((call) => call == id).length, previousCalls + 6);
    }
    expect(tester.getSize(row).height, 32);
    expect(tester.takeException(), isNull);
  });

  testWidgets('padding taps respect disabled, blocked and collapsed controls', (
    tester,
  ) async {
    final calls = <String>[];
    await tester.pumpWidget(host(actions(calls, enabled: false)));
    final button = find.byKey(const ValueKey('location-chat-regenerate'));
    final padding = tester.getCenter(button) + const Offset(0, 23);
    await tester.tapAt(padding);
    expect(calls, isEmpty);
    await tester.pumpWidget(host(IgnorePointer(child: actions(calls))));
    await tester.tapAt(padding);
    expect(calls, isEmpty);
    await tester.pumpWidget(host(actions(calls)));
    await tester.pumpAndSettle();
    await tester.pumpWidget(host(actions(calls, expanded: false)));
    await tester.tapAt(padding);
    await tester.pumpAndSettle();
    expect(calls, isEmpty);
  });

  testWidgets('a drag starting in expanded padding still scrolls the list', (
    tester,
  ) async {
    final calls = <String>[];
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(host(actions(calls), controller: controller));
    final button = find.byKey(const ValueKey('location-chat-regenerate'));
    await tester.dragFrom(
      tester.getCenter(button) + const Offset(0, 23),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(100));
    expect(calls, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('existing controls and modal barriers keep tap priority', (
    tester,
  ) async {
    final calls = <String>[];
    var headerTaps = 0;
    await tester.pumpWidget(
      host(actions(calls), onHeaderTap: () => headerTaps++),
    );
    final button = find.byKey(const ValueKey('location-chat-regenerate'));
    await tester.tapAt(tester.getCenter(button) + const Offset(0, -23));
    expect(headerTaps, 1);
    expect(calls, isEmpty);
    final padding = tester.getCenter(button) + const Offset(0, 23);
    final dialog = showDialog<void>(
      context: tester.element(button),
      builder: (_) => const AlertDialog(content: Text('Modal')),
    );
    await tester.pumpAndSettle();
    await tester.tapAt(padding);
    await tester.pumpAndSettle();
    await dialog;
    expect(calls, isEmpty);
    await tester.tapAt(padding);
    expect(calls.where((call) => call == 'regenerate'), ['regenerate']);
  });

  testWidgets(
    'real message viewport receives camera taps outside toolbar height',
    (tester) async {
      final coordinator = LocationChatScrollCoordinator();
      addTearDown(coordinator.dispose);
      var opens = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 500,
              child: LocationChatAnchoredMessageList(
                coordinator: coordinator,
                topTitle: '',
                style: kLocationChatStyle,
                replyActionsMessageId: 'reply',
                messages: [
                  ChatMessageVm(
                    localId: 'reply',
                    senderId: 'character',
                    senderName: 'Character',
                    text: 'A reply.',
                    isMe: false,
                    status: 'sent',
                    senderType: 'char',
                  ),
                ],
                regenerateFeature: LocationChatRegenerateFeature(
                  state: LocationChatReplyActionState.idle,
                  onInvoke: () {},
                ),
                onTakePhoto: () => opens++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final camera = find.byKey(const ValueKey('location-chat-take-photo'));
      expect(tester.getSize(camera), const Size(32, 32));
      await tester.tapAt(tester.getCenter(camera) + const Offset(0, -23));
      await tester.tapAt(tester.getCenter(camera) + const Offset(0, 23));
      expect(opens, 2);
      expect(tester.takeException(), isNull);
    },
  );
}
