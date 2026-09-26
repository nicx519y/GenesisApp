import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/attribution/adjust_device_registration.dart';
import 'package:genesis_flutter_android/app/attribution/adjust_local_adid_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('saved ADID survives a new local-store instance', () async {
    const first = SharedPreferencesAdjustLocalAdidStore();
    await first.write('saved-adid');
    const second = SharedPreferencesAdjustLocalAdidStore();

    expect(await second.read(), 'saved-adid');
  });

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

  test('reports ADID failure only after the delayed startup check', () async {
    var readCount = 0;
    var requestCount = 0;
    final reports = <String>[];
    final registration = AdjustDeviceRegistration(
      platform: TargetPlatform.iOS,
      environmentProvider: () => 'sandbox',
      readAdid: (_) async {
        readCount++;
        return null;
      },
      reportAdidFailure: (source, platform) => reports.add(source),
      registerDevice:
          ({required adid, required environment, gpsAdid, idfa, idfv}) async {
            requestCount++;
          },
    );

    await registration.register();
    expect(reports, isEmpty);

    await registration.registerAfterSessionWithoutAdid();
    expect(reports, isEmpty);
    await registration.checkAdidAfterStartup();
    await registration.checkAdidAfterStartup();

    expect(readCount, 4);
    expect(requestCount, 0);
    expect(reports, ['startup_delayed_check']);
  });

  test('delayed check uses the saved ADID before calling Adjust', () async {
    final localStore = _MemoryAdjustLocalAdidStore(value: 'saved-adid');
    final requests = <String>[];
    final reports = <String>[];
    final registration = AdjustDeviceRegistration(
      platform: TargetPlatform.iOS,
      environmentProvider: () => 'sandbox',
      localAdidStore: localStore,
      readAdid: (_) async => throw StateError('Adjust must not be read'),
      readIdfa: () async => null,
      readIdfv: () async => null,
      reportAdidFailure: (source, platform) => reports.add(source),
      registerDevice:
          ({required adid, required environment, gpsAdid, idfa, idfv}) async {
            requests.add(adid);
          },
    );

    await registration.checkAdidAfterStartup();

    expect(localStore.readCount, 1);
    expect(requests, ['saved-adid']);
    expect(reports, isEmpty);
  });

  test('ADID returned by Adjust is saved for the next app run', () async {
    final localStore = _MemoryAdjustLocalAdidStore();
    final first = AdjustDeviceRegistration(
      platform: TargetPlatform.iOS,
      environmentProvider: () => 'sandbox',
      localAdidStore: localStore,
      readAdid: (_) async => 'sdk-adid',
      readIdfa: () async => null,
      readIdfv: () async => null,
      registerDevice:
          ({required adid, required environment, gpsAdid, idfa, idfv}) async {},
    );
    await first.register();

    final secondRequests = <String>[];
    final second = AdjustDeviceRegistration(
      platform: TargetPlatform.iOS,
      environmentProvider: () => 'sandbox',
      localAdidStore: localStore,
      readAdid: (_) async => throw StateError('Adjust must not be read'),
      readIdfa: () async => null,
      readIdfv: () async => null,
      registerDevice:
          ({required adid, required environment, gpsAdid, idfa, idfv}) async {
            secondRequests.add(adid);
          },
    );
    await second.checkAdidAfterStartup();

    expect(localStore.value, 'sdk-adid');
    expect(secondRequests, ['sdk-adid']);
  });

  test('unreadable local cache does not produce an ADID failure', () async {
    final reports = <String>[];
    final registration = AdjustDeviceRegistration(
      platform: TargetPlatform.iOS,
      environmentProvider: () => 'sandbox',
      localAdidStore: _MemoryAdjustLocalAdidStore(failRead: true),
      readAdid: (_) async => null,
      reportAdidFailure: (source, platform) => reports.add(source),
      registerDevice:
          ({required adid, required environment, gpsAdid, idfa, idfv}) async {},
    );

    await registration.checkAdidAfterStartup();

    expect(
      registration.lastResult,
      AdjustDeviceRegistrationResult.deferredNoAdid,
    );
    expect(reports, isEmpty);
  });

  test(
    'session failure fallback registers when the ADID becomes available',
    () async {
      final reports = <String>[];
      final requests = <String>[];
      final registration = AdjustDeviceRegistration(
        platform: TargetPlatform.iOS,
        environmentProvider: () => 'sandbox',
        readAdid: (_) async => 'adid-after-session-failure',
        readIdfa: () async => null,
        readIdfv: () async => null,
        reportAdidFailure: (source, platform) => reports.add(source),
        registerDevice:
            ({required adid, required environment, gpsAdid, idfa, idfv}) async {
              requests.add(adid);
            },
      );

      await registration.registerAfterSessionWithoutAdid();
      await registration.checkAdidAfterStartup();

      expect(requests, ['adid-after-session-failure']);
      expect(reports, isEmpty);
      expect(
        registration.lastResult,
        AdjustDeviceRegistrationResult.registered,
      );
    },
  );

  test(
    'delayed check registers a newly available ADID without failure',
    () async {
      var readCount = 0;
      final requests = <String>[];
      final reports = <String>[];
      final registration = AdjustDeviceRegistration(
        platform: TargetPlatform.iOS,
        environmentProvider: () => 'sandbox',
        readAdid: (_) async => ++readCount == 1 ? null : 'adid-later',
        readIdfa: () async => null,
        readIdfv: () async => null,
        reportAdidFailure: (source, platform) => reports.add(source),
        registerDevice:
            ({required adid, required environment, gpsAdid, idfa, idfv}) async {
              requests.add(adid);
            },
      );

      await registration.registerAfterSessionWithoutAdid();
      expect(reports, isEmpty);
      await registration.checkAdidAfterStartup();

      expect(readCount, 2);
      expect(requests, ['adid-later']);
      expect(reports, isEmpty);
    },
  );

  test(
    'session failure reads again after an earlier cached read finishes',
    () async {
      final firstRead = Completer<String?>();
      var readCount = 0;
      final requests = <String>[];
      final reports = <String>[];
      final registration = AdjustDeviceRegistration(
        platform: TargetPlatform.iOS,
        environmentProvider: () => 'sandbox',
        readAdid: (_) => ++readCount == 1
            ? firstRead.future
            : Future<String?>.value('adid-after-failure'),
        readIdfa: () async => null,
        readIdfv: () async => null,
        reportAdidFailure: (source, platform) => reports.add(source),
        registerDevice:
            ({required adid, required environment, gpsAdid, idfa, idfv}) async {
              requests.add(adid);
            },
      );

      final startupAttempt = registration.register();
      final failureAttempt = registration.registerAfterSessionWithoutAdid();
      firstRead.complete(null);
      await Future.wait([startupAttempt, failureAttempt]);

      expect(readCount, 2);
      expect(requests, ['adid-after-failure']);
      expect(reports, isEmpty);
    },
  );

  test(
    'missing ADID waits for a later explicit trigger without polling',
    () async {
      var readCount = 0;
      var requestCount = 0;
      final scheduledDelays = <Duration>[];
      final registration = AdjustDeviceRegistration(
        platform: TargetPlatform.iOS,
        environmentProvider: () => 'sandbox',
        readAdid: (_) async => ++readCount == 1 ? null : 'adid-ready',
        readIdfa: () async => null,
        readIdfv: () async => 'idfv',
        retryDelays: const [Duration(seconds: 1), Duration(seconds: 2)],
        retryScheduler: (delay, callback) {
          scheduledDelays.add(delay);
          return () {};
        },
        registerDevice:
            ({required adid, required environment, gpsAdid, idfa, idfv}) async {
              requestCount++;
            },
      );

      await registration.register();

      expect(requestCount, 0);
      expect(readCount, 1);
      expect(scheduledDelays, isEmpty);
      expect(
        registration.lastResult,
        AdjustDeviceRegistrationResult.deferredNoAdid,
      );

      await registration.register();

      expect(readCount, 2);
      expect(requestCount, 1);
      expect(scheduledDelays, isEmpty);
      expect(
        registration.lastResult,
        AdjustDeviceRegistrationResult.registered,
      );
    },
  );

  test('session callback ADID registers without another SDK read', () async {
    final requests = <String>[];
    final localStore = _MemoryAdjustLocalAdidStore();
    final registration = AdjustDeviceRegistration(
      platform: TargetPlatform.iOS,
      environmentProvider: () => 'production',
      localAdidStore: localStore,
      readAdid: (_) async => throw StateError('must not be read'),
      readIdfa: () async => null,
      readIdfv: () async => 'idfv',
      registerDevice:
          ({required adid, required environment, gpsAdid, idfa, idfv}) async {
            requests.add(adid);
          },
    );

    await registration.registerKnownAdid(' adid-from-session ');

    expect(requests, ['adid-from-session']);
    expect(localStore.value, 'adid-from-session');
    expect(registration.lastResult, AdjustDeviceRegistrationResult.registered);
  });

  test(
    'session callback during cached read does not repeat registration',
    () async {
      final cachedRead = Completer<String?>();
      var requestCount = 0;
      final registration = AdjustDeviceRegistration(
        platform: TargetPlatform.iOS,
        environmentProvider: () => 'production',
        readAdid: (_) => cachedRead.future,
        readIdfa: () async => null,
        readIdfv: () async => 'idfv',
        registerDevice:
            ({required adid, required environment, gpsAdid, idfa, idfv}) async {
              requestCount++;
            },
      );

      final startupAttempt = registration.register();
      final sessionAttempt = registration.registerKnownAdid('adid-ready');
      cachedRead.complete('adid-ready');
      await Future.wait([startupAttempt, sessionAttempt]);

      expect(requestCount, 1);
      expect(
        registration.lastResult,
        AdjustDeviceRegistrationResult.alreadyRegistered,
      );
    },
  );

  test('network failure uses bounded automatic retries', () async {
    var readCount = 0;
    var requestCount = 0;
    final scheduledCallbacks = <AdjustDeviceRegistrationRetryCallback>[];
    final registration = AdjustDeviceRegistration(
      platform: TargetPlatform.iOS,
      environmentProvider: () => 'sandbox',
      readAdid: (_) async {
        readCount++;
        return 'adid';
      },
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

    expect(readCount, 1);
    expect(requestCount, 2);
    expect(registration.lastResult, AdjustDeviceRegistrationResult.registered);
    expect(scheduledCallbacks, hasLength(1));
  });

  test('automatic retry stops after the configured budget', () async {
    var readCount = 0;
    var requestCount = 0;
    final scheduledCallbacks = <AdjustDeviceRegistrationRetryCallback>[];
    final registration = AdjustDeviceRegistration(
      platform: TargetPlatform.iOS,
      environmentProvider: () => 'sandbox',
      readAdid: (_) async {
        readCount++;
        return 'adid';
      },
      readIdfa: () async => null,
      readIdfv: () async => 'idfv',
      retryDelays: const [Duration(seconds: 1), Duration(seconds: 2)],
      retryScheduler: (_, callback) {
        scheduledCallbacks.add(callback);
        return () {};
      },
      registerDevice:
          ({required adid, required environment, gpsAdid, idfa, idfv}) async {
            requestCount++;
            throw StateError('offline');
          },
    );

    await registration.register();
    await scheduledCallbacks[0]();
    await scheduledCallbacks[1]();

    expect(readCount, 1);
    expect(requestCount, 3);
    expect(scheduledCallbacks, hasLength(2));
    expect(registration.lastResult, AdjustDeviceRegistrationResult.failed);
  });

  test('dispose cancels a pending automatic retry', () async {
    var readCount = 0;
    var requestCount = 0;
    var retryCancelled = false;
    late AdjustDeviceRegistrationRetryCallback scheduledCallback;
    final registration = AdjustDeviceRegistration(
      platform: TargetPlatform.iOS,
      environmentProvider: () => 'sandbox',
      readAdid: (_) async {
        readCount++;
        return 'adid';
      },
      readIdfa: () async => null,
      readIdfv: () async => 'idfv',
      retryDelays: const [Duration(seconds: 1)],
      retryScheduler: (_, callback) {
        scheduledCallback = callback;
        return () => retryCancelled = true;
      },
      registerDevice:
          ({required adid, required environment, gpsAdid, idfa, idfv}) async {
            requestCount++;
            throw StateError('offline');
          },
    );

    await registration.register();
    registration.dispose();
    await scheduledCallback();

    expect(retryCancelled, isTrue);
    expect(readCount, 1);
    expect(requestCount, 1);
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

class _MemoryAdjustLocalAdidStore implements AdjustLocalAdidStore {
  _MemoryAdjustLocalAdidStore({this.value, this.failRead = false});

  String? value;
  final bool failRead;
  int readCount = 0;

  @override
  Future<String?> read() async {
    readCount++;
    if (failRead) throw StateError('local storage unavailable');
    return value;
  }

  @override
  Future<void> write(String adid) async {
    value = adid;
  }
}
