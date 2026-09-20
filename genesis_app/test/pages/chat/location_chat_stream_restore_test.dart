import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/debug/location_chat_bubble_layout_settings.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_scroll_coordinator.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_reply_card_switcher.dart';

ChatMessageVm _message(String text, {bool streaming = true}) => ChatMessageVm(
  localId: 'narrator',
  globalMessageId: 1,
  roundId: '1',
  senderId: 'narrator',
  senderName: '',
  senderType: 'narrator',
  text: text,
  isMe: false,
  status: streaming ? 'streaming' : 'sent',
);

Widget _tree(
  LocationChatScrollCoordinator coordinator,
  List<ChatMessageVm> messages, {
  bool ready = true,
  String? operation,
  bool card = false,
  bool active = true,
}) => MaterialApp(
  home: Scaffold(
    body: ChatStreamingEffects(
      settings: LocationChatBubbleLayoutSettings.defaults,
      presentationRevision: messages,
      child: TickerMode(
        enabled: active,
        child: LocationChatAnchoredMessageList(
          coordinator: coordinator,
          messages: messages,
          topTitle: '',
          showDateDividers: false,
          restoreInitialCompletedContent: true,
          active: active,
          initialContentReady: ready,
          waitingPositionIdentity: operation,
          replyCards: card
              ? [LocationChatReplyCard(id: 1, messages: messages)]
              : const [],
          replyCurrentCardId: card ? 1 : 0,
          replyCardBindingIdentity: card ? 'round-1' : null,
        ),
      ),
    ),
  ),
);

double _progress(WidgetTester tester) => ChatStreamingBody.revealedGraphemesOf(
  tester.element(find.byType(ChatStreamingBody).first),
);

bool _settled(WidgetTester tester) => ChatStreamingEffects.isSettledOf(
  tester.element(find.byType(LocationChatAnchoredMessageList)),
  listen: false,
);

void main() {
  for (final card in [false, true]) {
    for (final streaming in [true, false]) {
      testWidgets(
        'entry skips only completed message reveals (streaming=$streaming, card=$card)',
        (tester) async {
          var coordinator = LocationChatScrollCoordinator();
          await tester.pumpWidget(_tree(coordinator, [], card: card));
          final text = 'a' * 200;
          final messages = [_message(text, streaming: streaming)];
          await tester.pumpWidget(
            _tree(coordinator, messages, operation: 'send', card: card),
          );
          await tester.pump(const Duration(milliseconds: 60));
          expect(_progress(tester), greaterThan(0));
          expect(_progress(tester), lessThan(text.length));
          for (var entry = 0; entry < 3; entry++) {
            await tester.pumpWidget(const SizedBox.shrink());
            coordinator.dispose();
            coordinator = LocationChatScrollCoordinator();
            await tester.pumpWidget(_tree(coordinator, messages, card: card));
            if (streaming) {
              expect(_progress(tester), lessThan(text.length));
              final before = _progress(tester);
              await tester.pump(const Duration(milliseconds: 60));
              expect(_progress(tester), closeTo(before + 10, .01));
              expect(_settled(tester), isFalse);
            } else {
              expect(_progress(tester), text.length);
              await tester.pumpAndSettle();
              expect(_progress(tester), text.length);
              expect(_settled(tester), isTrue);
            }
          }
          await tester.pumpWidget(const SizedBox.shrink());
          coordinator.dispose();
        },
      );
    }
  }

  testWidgets(
    'async incomplete entry keeps revealing through subsequent chunks and end',
    (tester) async {
      final coordinator = LocationChatScrollCoordinator();
      addTearDown(coordinator.dispose);
      await tester.pumpWidget(_tree(coordinator, [], ready: false));
      final prefix = 'a' * 100;
      await tester.pumpWidget(_tree(coordinator, [_message(prefix)]));
      expect(_progress(tester), 0);
      await tester.pump(const Duration(milliseconds: 60));
      final before = _progress(tester);
      expect(before, closeTo(10, .01));
      expect(_settled(tester), isFalse);
      final full = prefix + 'b' * 100;
      await tester.pumpWidget(_tree(coordinator, [_message(full)]));
      expect(_progress(tester), before);
      await tester.pump(const Duration(milliseconds: 60));
      expect(_progress(tester), closeTo(before + 10, .01));
      expect(_settled(tester), isFalse);
      await tester.pumpWidget(
        _tree(coordinator, [_message(full, streaming: false)]),
      );
      expect(_progress(tester), lessThan(full.length));
      await tester.pumpAndSettle();
      expect(_progress(tester), full.length);
      expect(_settled(tester), isTrue);
    },
  );

  testWidgets('async completed entry is fully visible on its first layout', (
    tester,
  ) async {
    final coordinator = LocationChatScrollCoordinator();
    addTearDown(coordinator.dispose);
    await tester.pumpWidget(_tree(coordinator, [], ready: false));
    await tester.pumpWidget(
      _tree(coordinator, [_message('a' * 200, streaming: false)]),
    );
    expect(_progress(tester), 200);
    await tester.pumpAndSettle();
    expect(_settled(tester), isTrue);
  });

  for (final completedWhileAway in [false, true]) {
    testWidgets(
      'retained page checks receive state before resuming (completed=$completedWhileAway)',
      (tester) async {
        final coordinator = LocationChatScrollCoordinator();
        addTearDown(coordinator.dispose);
        await tester.pumpWidget(_tree(coordinator, []));
        final text = 'a' * 200;
        var messages = [_message(text)];
        await tester.pumpWidget(
          _tree(coordinator, messages, operation: 'send'),
        );
        await tester.pump(const Duration(milliseconds: 60));
        final before = _progress(tester);
        expect(before, greaterThan(0));
        expect(before, lessThan(text.length));
        await tester.pumpWidget(
          _tree(coordinator, messages, operation: 'send', active: false),
        );
        if (completedWhileAway) messages = [_message(text, streaming: false)];
        await tester.pumpWidget(
          _tree(coordinator, messages, operation: 'send', active: false),
        );
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpWidget(
          _tree(coordinator, messages, operation: 'send'),
        );
        if (completedWhileAway) {
          expect(_progress(tester), text.length);
          await tester.pumpAndSettle();
          expect(_settled(tester), isTrue);
        } else {
          expect(_progress(tester), closeTo(before, .01));
          await tester.pump(const Duration(milliseconds: 60));
          expect(_progress(tester), closeTo(before + 10, .01));
          expect(_settled(tester), isFalse);
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'first live stream in an already-ready empty room still reveals',
    (tester) async {
      final coordinator = LocationChatScrollCoordinator();
      addTearDown(coordinator.dispose);
      await tester.pumpWidget(_tree(coordinator, []));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_tree(coordinator, [_message('a' * 100)]));
      expect(_progress(tester), 0);
      await tester.pump(const Duration(milliseconds: 60));
      expect(_progress(tester), closeTo(10, .01));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
