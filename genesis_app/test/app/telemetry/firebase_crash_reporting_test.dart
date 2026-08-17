import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/telemetry/firebase_crash_reporting.dart';

void main() {
  test('best-effort crash recording contains asynchronous failures', () async {
    await expectLater(
      recordFirebaseCrashlyticsBestEffort(
        () => Future<void>.error(StateError('async recording failed')),
        operation: 'test async recording',
      ),
      completes,
    );
  });

  test('best-effort crash recording contains synchronous failures', () async {
    await expectLater(
      recordFirebaseCrashlyticsBestEffort(
        () => throw StateError('sync recording failed'),
        operation: 'test sync recording',
      ),
      completes,
    );
  });
}
