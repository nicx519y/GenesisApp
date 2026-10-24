import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/qa/hooks/qa%253Aandroid%253Aa1d9337b98414f24b8b3/hook.dart' as hook;
import 'package:genesis_flutter_android/app/qa/hooks/qa%253Aandroid%253Aa1d9337b98414f24b8b3/contract_fixture.dart';

void main() {
  test('uses real inset values, including a keyboard without a world', () {
    expect(hook.keyboardObstructsWorld(worldPresent: true, bottomInset: 320), true);
    expect(hook.keyboardObstructsWorld(worldPresent: true, bottomInset: 0), false);
    expect(hook.keyboardObstructsWorld(worldPresent: false, bottomInset: 320), false);
    for (final value in [-1.0, double.nan, double.infinity]) {
      expect(() => hook.keyboardObstructsWorld(worldPresent: true, bottomInset: value), throwsStateError);
    }
  });
  test('rejects mutation, extra parameters and missing readiness', () async {
    await expectLater(hook.invoke({'operation':'prepare'}, false, true), throwsArgumentError);
    await expectLater(hook.invoke({'operation':'read','hide':true}, false, true), throwsArgumentError);
    await expectLater(hook.invoke({'operation':'read'}, false, false), throwsArgumentError);
  });
  test('contract fixture rejects Case sessions before acquiring resources', () async {
    await expectLater(fixture({'operation':'prepare'}, false, true), throwsStateError);
  });
  testWidgets('releases the actual overlay, input controller and focus resource', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(key:key))));
    final owned = KeyboardFixture(key.currentContext! as Element, null);
    try {
      final preparing = owned.prepare();
      await tester.pump();
      await preparing;
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);
      expect(owned.focus.hasFocus, true);
      final receipt = await owned.restore('contract-session');
      await tester.pump();
      expect(receipt, {'restored':true,'matchesSnapshot':true,'resource':'contract-session'});
      expect(find.byType(TextField), findsNothing);
      expect(owned.entry, isNull);
      expect(() => owned.controller.addListener(() {}), throwsFlutterError);
      expect(await owned.restore('contract-session'), receipt);
    } finally {
      if (!owned.released) await owned.restore('contract-session');
      await tester.pumpWidget(const SizedBox());
    }
  });
}
