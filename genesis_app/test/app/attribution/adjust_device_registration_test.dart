import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/attribution/adjust_device_registration.dart';

void main() {
  test('iOS registration sends ADID, IDFA, and IDFV', () async {
    final requests = <Map<String, String?>>[];
    final registration = AdjustDeviceRegistration(
      platform: TargetPlatform.iOS,
      environmentProvider: () => 'sandbox',
      readAdid: (_) async => ' adid-ios ',
      readIdfa: () async => ' idfa-ios ',
      readIdfv: () async => ' idfv-ios ',
      readGoogleAdId: () async => throw StateError('must not be read'),
      registerDevice:
          ({required adid, required environment, gpsAdid, idfa, idfv}) async {
            requests.add({
              'adid': adid,
              'environment': environment,
              'gps_adid': gpsAdid,
              'idfa': idfa,
              'idfv': idfv,
            });
          },
    );

    await registration.register();

    expect(requests, [
      {
        'adid': 'adid-ios',
        'environment': 'sandbox',
        'gps_adid': null,
        'idfa': 'idfa-ios',
        'idfv': 'idfv-ios',
      },
    ]);
  });

  test('Android registration sends ADID and Google advertising ID', () async {
    final requests = <Map<String, String?>>[];
    final registration = AdjustDeviceRegistration(
      platform: TargetPlatform.android,
      environmentProvider: () => 'production',
      readAdid: (_) async => 'adid-android',
      readGoogleAdId: () async => 'gps-adid',
      readIdfa: () async => throw StateError('must not be read'),
      readIdfv: () async => throw StateError('must not be read'),
      registerDevice:
          ({required adid, required environment, gpsAdid, idfa, idfv}) async {
            requests.add({
              'adid': adid,
              'environment': environment,
              'gps_adid': gpsAdid,
              'idfa': idfa,
              'idfv': idfv,
            });
          },
    );

    await registration.register();

    expect(requests, [
      {
        'adid': 'adid-android',
        'environment': 'production',
        'gps_adid': 'gps-adid',
        'idfa': null,
        'idfv': null,
      },
    ]);
  });

  test('missing ADID defers the request until a later trigger', () async {
    var readCount = 0;
    var requestCount = 0;
    final registration = AdjustDeviceRegistration(
      platform: TargetPlatform.iOS,
      environmentProvider: () => 'sandbox',
      readAdid: (_) async => ++readCount == 1 ? null : 'adid-ready',
      readIdfa: () async => null,
      readIdfv: () async => 'idfv',
      retryDelays: const [],
      registerDevice:
          ({required adid, required environment, gpsAdid, idfa, idfv}) async {
            requestCount++;
          },
    );

    await registration.register();
    expect(
      registration.lastResult,
      AdjustDeviceRegistrationResult.deferredNoAdid,
    );
    await registration.register();

    expect(readCount, 2);
    expect(requestCount, 1);
    expect(registration.lastResult, AdjustDeviceRegistrationResult.registered);
  });

  test('missing ADID retries automatically and stops after success', () async {
    var readCount = 0;
    var requestCount = 0;
    final scheduledDelays = <Duration>[];
    final scheduledCallbacks = <AdjustDeviceRegistrationRetryCallback>[];
    final registration = AdjustDeviceRegistration(
      platform: TargetPlatform.iOS,
      environmentProvider: () => 'sandbox',
      readAdid: (_) async => ++readCount == 1 ? null : 'adid-ready',
      readIdfa: () async => null,
      readIdfv: () async => 'idfv',
      retryDelays: const [Duration(seconds: 1), Duration(seconds: 2)],
      retryScheduler: (delay, callback) {
        scheduledDelays.add(delay);
        scheduledCallbacks.add(callback);
        return () {};
      },
      registerDevice:
          ({required adid, required environment, gpsAdid, idfa, idfv}) async {
            requestCount++;
          },
    );

    await registration.register();

    expect(requestCount, 0);
    expect(scheduledDelays, const [Duration(seconds: 1)]);
    expect(
      registration.lastResult,
      AdjustDeviceRegistrationResult.deferredNoAdid,
    );

    await scheduledCallbacks.single();

    expect(readCount, 2);
    expect(requestCount, 1);
    expect(scheduledDelays, const [Duration(seconds: 1)]);
    expect(registration.lastResult, AdjustDeviceRegistrationResult.registered);
  });

  test('network failure uses bounded automatic retries', () async {
    var requestCount = 0;
    final scheduledCallbacks = <AdjustDeviceRegistrationRetryCallback>[];
    final registration = AdjustDeviceRegistration(
      platform: TargetPlatform.iOS,
      environmentProvider: () => 'sandbox',
      readAdid: (_) async => 'adid',
      readIdfa: () async => null,
      readIdfv: () async => 'idfv',
      retryDelays: const [Duration(seconds: 1)],
      retryScheduler: (_, callback) {
        scheduledCallbacks.add(callback);
        return () {};
      },
      registerDevice:
          ({required adid, required environment, gpsAdid, idfa, idfv}) async {
            requestCount++;
            if (requestCount == 1) throw StateError('offline');
          },
    );

    await registration.register();

    expect(requestCount, 1);
    expect(registration.lastResult, AdjustDeviceRegistrationResult.failed);
    expect(scheduledCallbacks, hasLength(1));

    await scheduledCallbacks.single();

    expect(requestCount, 2);
    expect(registration.lastResult, AdjustDeviceRegistrationResult.registered);
    expect(scheduledCallbacks, hasLength(1));
  });

  test('automatic retry stops after the configured budget', () async {
    var readCount = 0;
    final scheduledCallbacks = <AdjustDeviceRegistrationRetryCallback>[];
    final registration = AdjustDeviceRegistration(
      platform: TargetPlatform.iOS,
      environmentProvider: () => 'sandbox',
      readAdid: (_) async {
        readCount++;
        return null;
      },
      retryDelays: const [Duration(seconds: 1), Duration(seconds: 2)],
      retryScheduler: (_, callback) {
        scheduledCallbacks.add(callback);
        return () {};
      },
      registerDevice:
          ({required adid, required environment, gpsAdid, idfa, idfv}) async {
            fail('request must not be sent without an ADID');
          },
    );

    await registration.register();
    await scheduledCallbacks[0]();
    await scheduledCallbacks[1]();

    expect(readCount, 3);
    expect(scheduledCallbacks, hasLength(2));
    expect(
      registration.lastResult,
      AdjustDeviceRegistrationResult.deferredNoAdid,
    );
  });

  test('dispose cancels a pending automatic retry', () async {
    var readCount = 0;
    var retryCancelled = false;
    late AdjustDeviceRegistrationRetryCallback scheduledCallback;
    final registration = AdjustDeviceRegistration(
      platform: TargetPlatform.iOS,
      environmentProvider: () => 'sandbox',
      readAdid: (_) async {
        readCount++;
        return null;
      },
      retryDelays: const [Duration(seconds: 1)],
      retryScheduler: (_, callback) {
        scheduledCallback = callback;
        return () => retryCancelled = true;
      },
      registerDevice:
          ({required adid, required environment, gpsAdid, idfa, idfv}) async {
            fail('request must not be sent without an ADID');
          },
    );

    await registration.register();
    registration.dispose();
    await scheduledCallback();

    expect(retryCancelled, isTrue);
    expect(readCount, 1);
  });

  test(
    'unchanged identifiers are deduplicated unless login forces sync',
    () async {
      var requestCount = 0;
      final registration = AdjustDeviceRegistration(
        platform: TargetPlatform.android,
        environmentProvider: () => 'sandbox',
        readAdid: (_) async => 'adid',
        readGoogleAdId: () async => 'gps-adid',
        registerDevice:
            ({required adid, required environment, gpsAdid, idfa, idfv}) async {
              requestCount++;
            },
      );

      await registration.register();
      await registration.register();
      await registration.register(force: true);

      expect(requestCount, 2);
    },
  );

  test(
    'a forced concurrent trigger is drained after the active request',
    () async {
      final firstRequest = Completer<void>();
      var requestCount = 0;
      final registration = AdjustDeviceRegistration(
        platform: TargetPlatform.android,
        environmentProvider: () => 'sandbox',
        readAdid: (_) async => 'adid',
        readGoogleAdId: () async => 'gps-adid',
        registerDevice:
            ({required adid, required environment, gpsAdid, idfa, idfv}) async {
              requestCount++;
              if (requestCount == 1) await firstRequest.future;
            },
      );

      final initial = registration.register();
      final loginSync = registration.register(force: true);
      firstRequest.complete();
      await Future.wait([initial, loginSync]);

      expect(requestCount, 2);
    },
  );

  test('an environment change triggers a new registration', () async {
    var environment = 'sandbox';
    final requests = <String>[];
    final registration = AdjustDeviceRegistration(
      platform: TargetPlatform.android,
      environmentProvider: () => environment,
      readAdid: (_) async => 'adid',
      readGoogleAdId: () async => 'gps-adid',
      registerDevice:
          ({required adid, required environment, gpsAdid, idfa, idfv}) async {
            requests.add(environment);
          },
    );

    await registration.register();
    await registration.register();
    environment = 'production';
    await registration.register();

    expect(requests, ['sandbox', 'production']);
  });
}
