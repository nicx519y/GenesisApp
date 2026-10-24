import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/telemetry/firebase_crash_reporting.dart';
import 'package:genesis_flutter_android/components/origin/origin_item_cover_throttled_image_provider.dart';

void main() {
  for (final enabled in [true, false]) {
    test(
      'configuration ($enabled) contains absent Firebase initialization',
      () async {
        expect(Firebase.apps, isEmpty);
        final previous = FlutterError.onError;
        await expectLater(FirebaseCrashReporting.configure(enabled), completes);
        expect(
          FlutterError.onError,
          same(previous),
          reason: 'Failed initialization must not install error handlers.',
        );
      },
    );
  }

  test('expected cover cancellation is not recorded as a fatal error', () {
    expect(
      shouldRecordFirebaseFlutterError(
        const FlutterErrorDetails(
          exception: OriginItemCoverLoadCancelledException(),
        ),
      ),
      isFalse,
    );
    expect(
      shouldRecordFirebaseFlutterError(
        FlutterErrorDetails(exception: StateError('unexpected image failure')),
      ),
      isTrue,
    );
  });

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
