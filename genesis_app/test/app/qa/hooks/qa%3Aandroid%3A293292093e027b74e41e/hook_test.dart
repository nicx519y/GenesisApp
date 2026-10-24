import 'package:flutter/material.dart';
import 'package:genesis_flutter_android/pages/world/world_header.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/qa/hooks/qa%253Aandroid%253A293292093e027b74e41e/hook.dart'
    as hook;

void main() {
  test('contract evidence rejects Case sessions', () async {
    await expectLater(hook.contractEvidence({'operation': 'read'}, false, true), throwsStateError);
  });
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

  testWidgets('compares actual rendered header field with selected data', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorldMapTopBar(
            title: 'Actual name',
            timeText: 'Year 42',
            maxIdentityWidth: 240,
            onBackPressed: () {},
          ),
        ),
      ),
    );
    final root = tester.element(find.byType(Scaffold));
    expect(hook.observe(root, "Year 42"), isTrue);
    expect(hook.timeEvidence(root, '18:00'), {
      'selectedTime': '18:00',
      'headerTimes': ['Year 42'],
      'visibleTexts': ['Actual name', 'Year 42'],
      'matches': false,
    });
    expect(hook.timeEvidence(null, '18:00')['headerTimes'], isEmpty);
    expect(hook.timeEvidence(root, 'Year 42')['matches'], isTrue);
    expect(hook.observe(root, 'different'), isFalse);
    expect(hook.observe(root, ''), isFalse);
    expect(hook.observe(null, 'Actual name'), isFalse);
  });
}
