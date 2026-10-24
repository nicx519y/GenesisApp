import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/qa/hooks/qa%253Aandroid%253Afa6d6e9732df53bf7030/list_transition.dart';

void main() {
  const trigger = ValueKey('locations-trigger');
  const content = ValueKey('locations-list');

  Future<void> mount(
    WidgetTester tester,
    VoidCallback onTouch, {
    bool blocked = false,
    bool opens = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => AbsorbPointer(
              absorbing: blocked,
              child: GestureDetector(
                key: trigger,
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  onTouch();
                  if (opens) {
                    showModalBottomSheet<void>(
                      context: context,
                      builder: (_) => const SizedBox(
                        key: content,
                        height: 300,
                        child: Text('Parent'),
                      ),
                    );
                  }
                },
                child: const SizedBox(
                  width: 100,
                  height: 50,
                  child: Text('Locations'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Element? list(WidgetTester tester) {
    final found = find.byKey(content).evaluate();
    if (found.isEmpty) return null;
    final e = found.single;
    final box = e.findRenderObject() as RenderBox;
    final view = View.of(e);
    return (Offset.zero & (view.physicalSize / view.devicePixelRatio)).overlaps(
          box.localToGlobal(Offset.zero) & box.size,
        )
        ? e
        : null;
  }

  testWidgets('waits beyond the first modal frame after exactly one touch', (
    tester,
  ) async {
    var touches = 0;
    try {
      await mount(tester, () => touches++);
      var completed = false;
      final opening =
          openContractLocations(
            tester.element(find.byKey(trigger)),
            () => list(tester),
          ).then((value) {
            completed = true;
            return value;
          });
      await tester.pump();
      expect(completed, isFalse);
      for (var frame = 0; frame < 40 && !completed; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(completed, isTrue);
      final actual = await opening;
      expect(actual.widget.key, content);
      expect(
        ModalRoute.of(actual)!.animation!.status,
        AnimationStatus.completed,
      );
      expect(touches, 1);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(find.byKey(content), findsNothing);
    }
  });

  testWidgets('visible but intercepted target cannot open the list', (
    tester,
  ) async {
    var touches = 0;
    try {
      await mount(tester, () => touches++, blocked: true);
      expect(find.text('Locations'), findsOneWidget);
      await expectLater(
        openContractLocations(
          tester.element(find.byKey(trigger)),
          () => list(tester),
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'cause',
            contains('touch intercepted'),
          ),
        ),
      );
      expect(touches, 0);
      expect(find.byKey(content), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });

  testWidgets('no response fails without retrying the touch', (tester) async {
    var touches = 0;
    try {
      await mount(tester, () => touches++, opens: false);
      await expectLater(
        openContractLocations(
          tester.element(find.byKey(trigger)),
          () => list(tester),
          timeout: Duration.zero,
        ),
        throwsStateError,
      );
      expect(touches, 1);
      expect(find.byKey(content), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });
}
