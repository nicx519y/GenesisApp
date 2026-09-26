import 'dart:async';

import 'package:adjust_sdk/adjust_config.dart';
import 'package:adjust_sdk/adjust_session_failure.dart';
import 'package:adjust_sdk/adjust_session_success.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/attribution/adjust_attribution_runtime.dart';

void main() {
  tearDown(AdjustAttributionRuntime.resetForTesting);

  test('debug iOS config sends immediately without waiting for ATT', () {
    final config = AdjustAttributionRuntime.createConfig(
      releaseMode: false,
      platform: TargetPlatform.iOS,
    );

    expect(config.toMap['appToken'], AdjustAttributionRuntime.appToken);
    expect(config.toMap['environment'], 'sandbox');
    expect(config.toMap['logLevel'], 'verbose');
    expect(config.attConsentWaitingInterval, isNull);
    expect(config.attributionCallback, isNotNull);
    expect(config.sessionSuccessCallback, isNotNull);
    expect(config.sessionFailureCallback, isNotNull);
  });

  test('debug Android config does not set the iOS ATT wait', () {
    final config = AdjustAttributionRuntime.createConfig(
      releaseMode: false,
      platform: TargetPlatform.android,
    );

    expect(config.attConsentWaitingInterval, isNull);
    expect(config.toMap['fbAppId'], AdjustAttributionRuntime.metaAppId);
  });

  test('iOS config does not include the Android-only Meta app ID', () {
    final config = AdjustAttributionRuntime.createConfig(
      releaseMode: false,
      platform: TargetPlatform.iOS,
    );

    expect(config.toMap, isNot(contains('fbAppId')));
  });

  test('release config keeps session callbacks for device registration', () {
    final config = AdjustAttributionRuntime.createConfig(
      releaseMode: true,
      platform: TargetPlatform.iOS,
    );

    expect(config.toMap['environment'], 'production');
    expect(config.toMap['logLevel'], 'suppress');
    expect(config.attributionCallback, isNull);
    expect(config.sessionSuccessCallback, isNotNull);
    expect(config.sessionFailureCallback, isNotNull);
  });

  test('release session success publishes and replays the confirmed ADID', () {
    expect(AdjustAttributionRuntime.hasSuccessfulSession, isFalse);
    final config = AdjustAttributionRuntime.createConfig(
      releaseMode: true,
      platform: TargetPlatform.iOS,
    );
    final received = <String?>[];
    final removeFirst = AdjustAttributionRuntime.addSessionListener(
      received.add,
    );

    config.sessionSuccessCallback!(AdjustSessionSuccess(adid: ' adid-ready '));
    expect(AdjustAttributionRuntime.hasSuccessfulSession, isTrue);
    final removeSecond = AdjustAttributionRuntime.addSessionListener(
      received.add,
    );

    expect(received, ['adid-ready', 'adid-ready']);
    removeFirst();
    removeSecond();
  });

  test('session failure is published and replayed until a success', () {
    final config = AdjustAttributionRuntime.createConfig(
      releaseMode: true,
      platform: TargetPlatform.iOS,
    );
    final received = <AdjustSessionFailure>[];
    final removeFirst = AdjustAttributionRuntime.addSessionFailureListener(
      received.add,
    );
    final failure = AdjustSessionFailure(willRetry: true);

    config.sessionFailureCallback!(failure);
    final removeSecond = AdjustAttributionRuntime.addSessionFailureListener(
      received.add,
    );
    expect(received, [failure, failure]);

    config.sessionSuccessCallback!(AdjustSessionSuccess(adid: 'adid-ready'));
    final removeThird = AdjustAttributionRuntime.addSessionFailureListener(
      received.add,
    );
    expect(received, [failure, failure]);
    removeFirst();
    removeSecond();
    removeThird();
  });

  test(
    'successful session with no ADID publishes a one-time fallback signal',
    () {
      final config = AdjustAttributionRuntime.createConfig(
        releaseMode: true,
        platform: TargetPlatform.iOS,
      );
      final received = <String?>[];
      final removeFirst = AdjustAttributionRuntime.addSessionListener(
        received.add,
      );

      config.sessionSuccessCallback!(AdjustSessionSuccess());
      final removeSecond = AdjustAttributionRuntime.addSessionListener(
        received.add,
      );

      expect(received, [null, null]);
      removeFirst();
      removeSecond();
    },
  );

  test('initializes the Adjust SDK only once', () {
    final configs = <AdjustConfig>[];

    AdjustAttributionRuntime.initialize(
      releaseMode: false,
      platform: TargetPlatform.android,
      initializeSdk: configs.add,
    );
    AdjustAttributionRuntime.initialize(
      releaseMode: false,
      platform: TargetPlatform.android,
      initializeSdk: configs.add,
    );

    expect(configs, hasLength(1));
  });

  test('debug iOS reads the Worldo IDFV for diagnostics', () async {
    final idfvRequested = Completer<void>();

    AdjustAttributionRuntime.initialize(
      releaseMode: false,
      debugMode: true,
      platform: TargetPlatform.iOS,
      initializeSdk: (_) {},
      getIdfv: () async {
        idfvRequested.complete();
        return '11111111-2222-3333-4444-555555555555';
      },
    );

    await idfvRequested.future;
  });

  test('non-debug iOS does not read the Worldo IDFV', () {
    var idfvRequested = false;

    AdjustAttributionRuntime.initialize(
      releaseMode: true,
      debugMode: false,
      platform: TargetPlatform.iOS,
      initializeSdk: (_) {},
      getIdfv: () async {
        idfvRequested = true;
        return 'should-not-be-read';
      },
    );

    expect(idfvRequested, isFalse);
  });

  test('a synchronous SDK initialization failure is not retried', () {
    var attempts = 0;

    expect(AdjustAttributionRuntime.hasAttemptedInitialization, isFalse);

    expect(
      () => AdjustAttributionRuntime.initialize(
        releaseMode: false,
        platform: TargetPlatform.android,
        initializeSdk: (_) {
          attempts++;
          if (attempts == 1) throw StateError('test failure');
        },
      ),
      returnsNormally,
    );

    expect(AdjustAttributionRuntime.hasAttemptedInitialization, isTrue);
    expect(AdjustAttributionRuntime.isInitialized, isFalse);

    AdjustAttributionRuntime.initialize(
      releaseMode: false,
      platform: TargetPlatform.android,
      initializeSdk: (_) => attempts++,
    );
    AdjustAttributionRuntime.initialize(
      releaseMode: false,
      platform: TargetPlatform.android,
      initializeSdk: (_) => attempts++,
    );

    expect(attempts, 1);
  });
}
