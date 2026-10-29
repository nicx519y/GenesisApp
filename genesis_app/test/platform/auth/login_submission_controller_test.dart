import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/platform/auth/auth_session.dart';
import 'package:genesis_flutter_android/platform/auth/login_submission_controller.dart';

void main() {
  test(
    'success is shared until a session change and cannot be replayed',
    () async {
      final controller = LoginSubmissionController();
      addTearDown(controller.dispose);
      var calls = 0;
      await controller.submit(IdentityProvider.google, () async {
        calls++;
        controller.markSucceeded();
      });
      expect(controller.succeeded, isTrue);
      expect(controller.value, isNull);
      await controller.submit(IdentityProvider.apple, () async => calls++);
      expect(calls, 1);
      controller.resetSessionResult();
      expect(controller.succeeded, isFalse);
      await controller.submit(IdentityProvider.apple, () async => calls++);
      expect(calls, 2);
    },
  );

  test('retired submissions cannot publish success or start work', () async {
    final controller = LoginSubmissionController();
    addTearDown(controller.dispose);
    final pending = Completer<void>();
    final attempt = controller.submit(IdentityProvider.google, () async {
      await pending.future;
      controller.markSucceeded();
    });
    controller.invalidate();
    pending.complete();
    await attempt;
    expect(controller.succeeded, isFalse);
    var calls = 0;
    await controller.submit(IdentityProvider.apple, () async => calls++);
    expect(calls, 0);
  });

  for (final fails in [false, true]) {
    test(
      'login blocks other providers and restores state fails=$fails',
      () async {
        final controller = LoginSubmissionController();
        addTearDown(controller.dispose);
        final pending = Completer<void>();
        final changes = <IdentityProvider?>[];
        controller.addListener(() => changes.add(controller.value));
        final attempt = controller.submit(
          IdentityProvider.google,
          () => pending.future,
        );
        expect(controller.value, IdentityProvider.google);
        var duplicateCalls = 0;
        await controller.submit(IdentityProvider.apple, () async {
          duplicateCalls++;
        });
        expect(duplicateCalls, 0);
        if (fails) {
          final expectation = expectLater(attempt, throwsStateError);
          pending.completeError(StateError('login failed'));
          await expectation;
        } else {
          pending.complete();
          await attempt;
        }
        expect(controller.value, isNull);
        expect(changes, [IdentityProvider.google, null]);
        await controller.submit(IdentityProvider.apple, () async {
          duplicateCalls++;
        });
        expect(duplicateCalls, 1);
      },
    );
  }

  test('late completion after app services disposal is safe', () async {
    final controller = LoginSubmissionController();
    final pending = Completer<void>();
    final attempt = controller.submit(
      IdentityProvider.google,
      () => pending.future,
    );
    controller.dispose();
    pending.complete();
    await attempt;
  });
}
