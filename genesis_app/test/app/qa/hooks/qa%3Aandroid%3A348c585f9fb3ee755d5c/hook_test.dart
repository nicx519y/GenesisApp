import 'package:flutter/material.dart';
import 'package:genesis_flutter_android/pages/world/world_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/qa/hooks/qa%253Aandroid%253A348c585f9fb3ee755d5c/hook.dart'
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

  test('matches only the actual selected world widget', () {
    expect(hook.matchesWorld(const WorldPage(wid: 'actual'), 'actual'), isTrue);
    expect(hook.matchesWorld(const WorldPage(wid: 'other'), 'actual'), isFalse);
    expect(hook.matchesWorld(const SizedBox(), 'actual'), isFalse);
    expect(hook.matchesWorld(const WorldPage(wid: ''), ''), isFalse);
  });
}
