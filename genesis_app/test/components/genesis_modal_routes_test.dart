import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/common/genesis_modal_routes.dart';

void main() {
  testWidgets(
    'dragging scrollable content down at its top dismisses the sheet',
    (tester) async {
      var dismissCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 300,
              child: GenesisBottomSheetDragDismissArea(
                onDismiss: () => dismissCount += 1,
                child: ListView.builder(
                  key: const ValueKey<String>('dismissible-list'),
                  physics: const ClampingScrollPhysics(),
                  itemExtent: 40,
                  itemCount: 30,
                  itemBuilder: (_, index) => Text('Item $index'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.drag(
        find.byKey(const ValueKey<String>('dismissible-list')),
        const Offset(0, 80),
      );

      expect(dismissCount, 1);
    },
  );

  testWidgets('dragging content before it reaches the top does not dismiss', (
    tester,
  ) async {
    var dismissCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 300,
            child: GenesisBottomSheetDragDismissArea(
              onDismiss: () => dismissCount += 1,
              child: ListView.builder(
                key: const ValueKey<String>('dismissible-list'),
                physics: const ClampingScrollPhysics(),
                itemExtent: 40,
                itemCount: 30,
                itemBuilder: (_, index) => Text('Item $index'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.drag(
      find.byKey(const ValueKey<String>('dismissible-list')),
      const Offset(0, -240),
    );
    await tester.pump();
    await tester.drag(
      find.byKey(const ValueKey<String>('dismissible-list')),
      const Offset(0, 80),
    );

    expect(dismissCount, 0);
  });
}
