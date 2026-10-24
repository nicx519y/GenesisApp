import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/qa/hooks/qa%253Aandroid%253Ad43c9deee50740096afb/browse_gesture.dart';

void main() {
  for (final blocked in [false, true]) {
    testWidgets('waits for driven event pager; blocked=$blocked', (tester) async {
      final pager = PageController();
      const contentKey = ValueKey('current-event-content');
      try {
        await tester.pumpWidget(MaterialApp(
          home: PageView(
            controller: pager,
            scrollDirection: Axis.vertical,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              const SizedBox.expand(),
              AbsorbPointer(
                absorbing: blocked,
                child: ListView(
                  key: contentKey,
                  children: const [SizedBox(height: 80, child: Text('Event'))],
                ),
              ),
            ],
          ),
        ));
        final motion = pager.animateToPage(1,
            duration: const Duration(milliseconds: 400), curve: Curves.linear);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        final target = tester.state<ScrollableState>(find.descendant(
          of: find.byKey(contentKey), matching: find.byType(Scrollable)));
        expect(pager.position.isScrollingNotifier.value, isTrue);
        BrowseGestureResult? result;
        final operation = browseByTouch(target).then((value) => result = value);
        await tester.pump(const Duration(milliseconds: 30));
        expect(result, isNull, reason: 'Do not test reachability mid-animation');
        for (var i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 30));
        }
        await motion;
        await operation;
        expect(result!.scrollRequired, isFalse);
        expect(result!.succeeded, !blocked);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        pager.dispose();
      }
    });
  }

  Future<BrowseGestureResult> browse(
    WidgetTester tester, {
    bool blocked = false,
    bool disabled = false,
    int count = 40,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AbsorbPointer(
          absorbing: blocked,
          child: ListView(
            physics: disabled ? const NeverScrollableScrollPhysics() : null,
            children: List.generate(
              count,
              (i) => SizedBox(height: 80, child: Text('Event $i')),
            ),
          ),
        ),
      ),
    );
    final state = tester.state<ScrollableState>(find.byType(Scrollable));
    BrowseGestureResult? result;
    final operation = browseByTouch(state).then((value) => result = value);
    await tester.pump();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
    await operation;
    await tester.pumpAndSettle();
    return result!;
  }

  testWidgets('real gesture moves event contents', (tester) async {
    final result = await browse(tester);
    expect(result.scrollRequired, isTrue);
    expect(result.succeeded, isTrue);
    expect(result.to, greaterThan(result.from));
  });
  testWidgets('touch blocker cannot produce browsing success', (tester) async {
    final result = await browse(tester, blocked: true);
    expect(result.succeeded, isFalse);
    expect(result.to, result.from);
  });
  testWidgets('disabled scrolling cannot produce browsing success', (
    tester,
  ) async {
    final result = await browse(tester, disabled: true);
    expect(result.scrollRequired, isTrue);
    expect(result.succeeded, isFalse);
  });
  testWidgets('fully visible short event content remains browsable', (
    tester,
  ) async {
    final result = await browse(tester, count: 1);
    expect(result.scrollRequired, isFalse);
    expect(result.succeeded, isTrue);
  });
}
