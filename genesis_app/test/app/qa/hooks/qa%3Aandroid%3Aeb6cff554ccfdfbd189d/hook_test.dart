import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/qa/hooks/qa%253Aandroid%253Aeb6cff554ccfdfbd189d/hook.dart';

void main() {
  testWidgets(
    'route discovery preserves the tree across cover, restore and removal',
    (tester) async {
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: key,
          home: const Scaffold(body: Text('original')),
        ),
      );
      final nav = key.currentState!;
      final original = currentRoutes(nav).single;
      for (var i = 0; i < 2; i++) {
        final cover = MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('cover')),
        );
        nav.push(cover);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(currentRoutes(nav), {cover});
        expect(original.isCurrent, false);
        nav.removeRoute(cover);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(currentRoutes(nav), {original});
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'map preparation cannot consume a contract session or start implicitly',
    () async {
      await expectLater(
        invoke({'operation': 'prepare'}, true, true),
        throwsStateError,
      );
      await expectLater(
        contract({'operation': 'prepare'}, false, true),
        throwsStateError,
      );
      await expectLater(
        invoke({'operation': 'prepare'}, false, false),
        throwsArgumentError,
      );
      await expectLater(
        invoke({'operation': 'read', 'navigate': true}, false, true),
        throwsArgumentError,
      );
    },
  );
}
