import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/qa/hooks/android%253Aworld.detail.retry%253Avisible/hook.dart';

void main() {
  test('rejects undeclared operation before accessing App state', () async {
    await expectLater(
      invoke({'operation': 'unknown'}, false, true),
      throwsArgumentError,
    );
  });
  test(
    'rejects missing preparation instead of manufacturing an observation',
    () async {
      await expectLater(
        invoke({'operation': 'read'}, false, true),
        throwsStateError,
      );
    },
  );
}
