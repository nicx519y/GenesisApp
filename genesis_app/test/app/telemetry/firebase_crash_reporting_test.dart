import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:genesis_flutter_android/app/telemetry/firebase_crash_reporting.dart';
import 'package:genesis_flutter_android/components/origin/origin_item_cover_throttled_image_provider.dart';

void main() {
  test('image transport failure is non-fatal only in image loading', () {
    final error = http.ClientException('The network connection was lost');
    expect(
      isFirebaseFlutterErrorFatal(
        FlutterErrorDetails(
          exception: error,
          library: 'image resource service',
        ),
      ),
      isFalse,
    );
    expect(
      isFirebaseFlutterErrorFatal(FlutterErrorDetails(exception: error)),
      isTrue,
    );
    expect(
      isFirebaseFlutterErrorFatal(
        FlutterErrorDetails(
          exception: StateError('image decoder bug'),
          library: 'image resource service',
        ),
      ),
      isTrue,
    );
  });

  test('only inactive stream cancellation is non-fatal', () {
    final context = ErrorDescription(
      'while de-activating platform stream on channel test/channel',
    );
    expect(
      isFirebaseFlutterErrorFatal(
        FlutterErrorDetails(
          exception: PlatformException(
            code: 'error',
            message: 'No active stream to cancel',
          ),
          library: 'services library',
          context: context,
        ),
      ),
      isFalse,
    );
    expect(
      isFirebaseFlutterErrorFatal(
        FlutterErrorDetails(
          exception: PlatformException(
            code: 'error',
            message: 'Other native failure',
          ),
          library: 'services library',
          context: context,
        ),
      ),
      isTrue,
    );
  });

  test('same platform message outside stream cancellation stays fatal', () {
    for (final context in <DiagnosticsNode?>[
      null,
      ErrorDescription(
        'while activating platform stream on channel test/channel',
      ),
    ]) {
      expect(
        isFirebaseFlutterErrorFatal(
          FlutterErrorDetails(
            exception: PlatformException(
              code: 'error',
              message: 'No active stream to cancel',
            ),
            library: 'services library',
            context: context,
          ),
        ),
        isTrue,
      );
    }
  });

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
