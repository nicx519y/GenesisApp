import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/telemetry/firebase_crash_reporting.dart';
import 'package:genesis_flutter_android/components/origin/origin_item_cover_throttled_image_provider.dart';

void main() {
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
