import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/qa/hooks/qa%253Aandroid%253Ac839964e03663ecef892/hook.dart'
    as hook;

void main() {
  test('rejects undeclared input before resource access', () async {
    await expectLater(
      hook.invoke({'operation': 'prepare'}, false, true),
      throwsArgumentError,
    );
    await expectLater(
      hook.invoke({'operation': 'interact', 'foreign': true}, false, true),
      throwsArgumentError,
    );
    await expectLater(
      hook.invoke({'operation': 'interact'}, false, false),
      throwsArgumentError,
    );
  });
  test(
    'missing selection cannot manufacture a successful observation',
    () async {
      await expectLater(
        hook.invoke({'operation': 'interact'}, false, true),
        throwsStateError,
      );
    },
  );
}
