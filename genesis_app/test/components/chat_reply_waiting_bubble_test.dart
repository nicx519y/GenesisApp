import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';

void main() {
  testWidgets('waiting bubble follows shared style and keeps its left edge', (
    tester,
  ) async {
    final style = kLocationChatStyle.copyWith(
      otherBubbleColor: Colors.blue,
      bubbleTextStyle: const TextStyle(color: Colors.yellow),
      bubbleBorderRadius: 18,
      bubblePadding: const EdgeInsets.all(9),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: ChatReplyWaitingBubble(style: style),
          ),
        ),
      ),
    );
    final surfaceFinder = find.byType(ChatBubbleSurface);
    final surface = tester.widget<ChatBubbleSurface>(surfaceFinder);
    expect(surface.color, Colors.blue);
    expect(surface.borderRadius, BorderRadius.circular(18));
    expect(surface.padding, const EdgeInsets.all(9));
    expect(tester.getTopLeft(surfaceFinder).dx, 60);
    expect(surface.blurSigma, 0);
    final dots = find.descendant(
      of: find.byKey(const ValueKey('location-chat-ack-loading-dots')),
      matching: find.byType(DecoratedBox),
    );
    expect(dots, findsNWidgets(3));
    for (final dot in tester.widgetList<DecoratedBox>(dots)) {
      expect((dot.decoration as BoxDecoration).color, Colors.yellow);
    }
    await tester.pump(const Duration(milliseconds: 350));
    expect(tester.getTopLeft(surfaceFinder).dx, 60);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
