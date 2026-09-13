import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/features/location_chat_reply/inspiration/inspiration.dart';
import 'package:genesis_flutter_android/features/location_chat_reply/shared/reply_action_state.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_reply_actions.dart';

const _replies = [
  'One reply.',
  'A second, longer reply that wraps to another line.',
];

Widget _host({
  List<String> replies = _replies,
  double width = 360,
  double scale = 1,
  TextDirection direction = TextDirection.ltr,
  ChatUiStyleConfig? style,
  bool busy = false,
  int quota = 2,
  int page = 0,
  bool expanded = true,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(
      size: Size(800, 600),
      textScaler: TextScaler.linear(scale),
    ),
    child: Directionality(
      textDirection: direction,
      child: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: LocationChatReplyActions(
              style: style ?? kLocationChatStyle,
              inspirationExpanded: expanded,
              inspirationPage: page,
              inspirationFeature: LocationChatInspirationFeature(
                messages: replies,
                state: busy
                    ? LocationChatReplyActionState.busy
                    : LocationChatReplyActionState.idle,
                freeUsesRemaining: quota,
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  setUp(() => debugLocationChatInspirationTextLayoutCount = 0);
  tearDown(() => debugLocationChatInspirationTextLayoutCount = 0);

  testWidgets(
    'page, busy, quota and equivalent content reuse one height result',
    (tester) async {
      await tester.pumpWidget(_host());
      expect(debugLocationChatInspirationTextLayoutCount, _replies.length);
      final initialHeight = tester
          .getSize(find.byKey(const ValueKey('inspiration-replies-carousel')))
          .height;
      await tester.drag(find.byType(PageView), const Offset(-260, 0));
      await tester.pumpAndSettle();
      expect(debugLocationChatInspirationTextLayoutCount, _replies.length);
      await tester.pumpWidget(_host(busy: true, quota: 1, page: 1));
      await tester.pump(const Duration(milliseconds: 120));
      expect(debugLocationChatInspirationTextLayoutCount, _replies.length);
      await tester.pumpWidget(
        _host(replies: List<String>.of(_replies), page: 1),
      );
      await tester.pumpAndSettle();
      expect(debugLocationChatInspirationTextLayoutCount, _replies.length);
      expect(
        tester
            .getSize(find.byKey(const ValueKey('inspiration-replies-carousel')))
            .height,
        initialHeight,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'changed content and layout inputs each invalidate the latest result',
    (tester) async {
      final replies = List<String>.of(_replies);
      var expectedLayouts = 0;
      Future<void> measure(Widget widget) async {
        await tester.pumpWidget(widget);
        expectedLayouts += replies.length;
        expect(debugLocationChatInspirationTextLayoutCount, expectedLayouts);
        expect(tester.takeException(), isNull);
      }

      await measure(_host(replies: replies));
      replies[0] = 'The same source list now holds different content.';
      await measure(_host(replies: replies));
      await measure(_host(replies: replies, width: 280));
      await measure(_host(replies: replies, width: 280, scale: 1.4));
      await measure(
        _host(
          replies: replies,
          width: 280,
          scale: 1.4,
          direction: TextDirection.rtl,
        ),
      );
      final style = kLocationChatStyle.copyWith(
        bubbleTextStyle: kLocationChatStyle.bubbleTextStyle.copyWith(
          fontSize: 18,
        ),
      );
      await measure(
        _host(
          replies: replies,
          width: 280,
          scale: 1.4,
          direction: TextDirection.rtl,
          style: style,
        ),
      );
      await measure(
        _host(
          replies: replies,
          width: 280,
          scale: 1.4,
          direction: TextDirection.rtl,
          style: style.copyWith(
            bubblePadding: style.bubblePadding.copyWith(top: 16),
          ),
        ),
      );
      await measure(_host(replies: replies));
    },
  );

  testWidgets('collapsing releases the cache with the carousel', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    expect(debugLocationChatInspirationTextLayoutCount, _replies.length);
    await tester.pumpWidget(_host(expanded: false));
    expect(find.byType(PageView), findsNothing);
    await tester.pumpWidget(_host());
    expect(debugLocationChatInspirationTextLayoutCount, _replies.length * 2);
    expect(tester.takeException(), isNull);
  });
}
