import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/qa/hooks/qa%253Aandroid%253Aa1fdcca31368e5998aff/hook.dart'
    as hook;

void main() {
  test('rejects undeclared input before resource access', () async {
    await expectLater(
      hook.invoke({'operation': 'prepare'}, false, true),
      throwsArgumentError,
    );
    await expectLater(
      hook.invoke({'operation': 'read', 'foreign': true}, false, true),
      throwsArgumentError,
    );
    await expectLater(
      hook.invoke({'operation': 'read'}, false, false),
      throwsArgumentError,
    );
  });
  test(
    'missing selection cannot manufacture a successful observation',
    () async {
      await expectLater(
        hook.invoke({'operation': 'read'}, false, true),
        throwsStateError,
      );
    },
  );

  testWidgets(
    'reads rendered Detail, excludes absent, offstage and disabled state',
    (tester) async {
      Future<void> mount(Widget child) =>
          tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
      await mount(TextButton(onPressed: () {}, child: const Text('Detail')));
      expect(hook.observe(tester.element(find.byType(Scaffold))), isTrue);
      await mount(const Text('unrelated'));
      expect(hook.observe(tester.element(find.byType(Scaffold))), isFalse);
      await mount(
        Offstage(
          offstage: true,
          child: TextButton(onPressed: () {}, child: const Text('Detail')),
        ),
      );
      expect(hook.observe(tester.element(find.byType(Scaffold))), isFalse);
      expect(hook.observe(null), isFalse);
      await mount(const TextButton(onPressed: null, child: Text('Detail')));
      expect(hook.observe(tester.element(find.byType(Scaffold))), isTrue);
    },
  );
}
