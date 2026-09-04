import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/startup/startup_dependency_guard.dart';

void main() {
  test('completes normally when the dependency becomes ready', () async {
    var timedOut = false;
    var failed = false;

    await waitForStartupDependency(
      Future<void>.value(),
      timeout: const Duration(milliseconds: 20),
      onTimeout: () => timedOut = true,
      onError: (_, _) => failed = true,
    );

    expect(timedOut, isFalse);
    expect(failed, isFalse);
  });

  test('releases startup when the dependency times out', () async {
    final dependency = Completer<void>();
    var timedOut = false;

    await waitForStartupDependency(
      dependency.future,
      timeout: const Duration(milliseconds: 5),
      onTimeout: () => timedOut = true,
    );

    expect(timedOut, isTrue);
  });

  test('releases startup when the dependency fails', () async {
    Object? capturedError;

    await waitForStartupDependency(
      Future<void>.error(StateError('failed')),
      timeout: const Duration(milliseconds: 20),
      onError: (error, _) => capturedError = error,
    );

    expect(capturedError, isA<StateError>());
  });
}
