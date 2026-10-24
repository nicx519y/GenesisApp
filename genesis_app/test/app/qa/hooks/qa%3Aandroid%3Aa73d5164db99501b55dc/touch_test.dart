import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/qa/hooks/qa%253Aandroid%253Aa73d5164db99501b55dc/touch.dart';

void main() {
  const key = ValueKey('tick-target');
  for (final blocked in [false, true]) {
    testWidgets('rapid taps respect touch interception: $blocked', (tester) async {
      var callbacks = 0;
      var submissions = 0;
      var inFlight = false;
      try {
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(
          child: AbsorbPointer(absorbing: blocked, child: SizedBox(
            key: key, width: 140, height: 48,
            child: FilledButton(onPressed: () {
              callbacks++;
              if (inFlight) return;
              inFlight = true;
              submissions++;
            }, child: const Text('Tick now')),
          )),
        ))));
        final target = tester.element(find.byKey(key));
        if (blocked) {
          expect(() => dispatchRapidTaps(target), throwsStateError);
          expect(callbacks, 0);
          expect(submissions, 0);
        } else {
          expect(dispatchRapidTaps(target), 2);
          expect(callbacks, 2);
          expect(submissions, 1);
        }
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    });
  }
}
