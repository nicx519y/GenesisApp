import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../../../lib/app/qa/hooks/android%253Amessages.private.empty_state%253Atext/observer.dart';

Widget subject([String text = 'Actual new copy']) => Center(
  key: const ValueKey('direct-messages-empty-state'),
  child: Text(text),
);
void main() {
  testWidgets(
    'reads current keyed content and excludes missing, hidden, background tabs',
    (tester) async {
      try {
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: subject())));
        expect(await readEmptyText({}, false, true), 'Actual new copy');
        expect(await readEmptyText({}, false, false), '');
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: Offstage(offstage: true, child: subject())),
          ),
        );
        expect(await readEmptyText({}, false, true), '');
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: IndexedStack(
                index: 0,
                children: [const Text('Home'), subject()],
              ),
            ),
          ),
        );
        expect(await readEmptyText({}, false, true), '');
        await tester.pumpWidget(
          const MaterialApp(home: Text('Actual new copy')),
        );
        expect(await readEmptyText({}, false, true), '');
        await expectLater(
          readEmptyText({'unexpected': true}, false, true),
          throwsArgumentError,
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
      expect(await readEmptyText({}, false, true), '');
    },
  );
  testWidgets('rejects duplicate visible subjects', (tester) async {
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              Expanded(child: subject()),
              Expanded(child: subject()),
            ],
          ),
        ),
      );
      await expectLater(readEmptyText({}, false, true), throwsStateError);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });
}
