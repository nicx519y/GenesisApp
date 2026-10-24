import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/qa/hooks/qa%253Aandroid%253A049d4a0c0bcd1b89f6c0/hook.dart';

void main() {
  for (final blocked in [false, true]) {
    testWidgets(
      'single pointer dispatch respects visible touch obstruction: $blocked',
      (tester) async {
        var requests = 0;
        const key = ValueKey('single-tick');
        try {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Center(
                  child: AbsorbPointer(
                    absorbing: blocked,
                    child: SizedBox(
                      key: key,
                      width: 140,
                      height: 48,
                      child: FilledButton(
                        onPressed: () {
                          requests++;
                        },
                        child: const Text('Tick now'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          expect(find.text('Tick now'), findsOneWidget);
          final target = tester.element(find.byKey(key));
          if (blocked) {
            expect(() => dispatchSingleTap(target), throwsStateError);
            expect(requests, 0);
          } else {
            dispatchSingleTap(target);
            expect(requests, 1);
            dispatchSingleTap(target);
            expect(requests, 2);
          }
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        }
        expect(find.byKey(key), findsNothing);
      },
    );
  }
}
