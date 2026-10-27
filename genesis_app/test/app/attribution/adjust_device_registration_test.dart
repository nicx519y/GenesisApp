import 'dart:async';

import 'package:adjust_sdk/adjust_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/attribution/adjust_attribution_runtime.dart';
import 'package:genesis_flutter_android/app/attribution/adjust_device_registration.dart';
import 'package:genesis_flutter_android/app/attribution/adjust_local_adid_store.dart';
import 'package:genesis_flutter_android/app/config/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/app/telemetry/genesis_telemetry.dart';
import 'package:genesis_flutter_android/app/attribution/adid_availability_monitor.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test(
      'ADID failure reports register identifiers before HTTP completes on ${platform.name}',
      () async {
        final reports = <Map<String, Object?>>[];
        final request = Completer<void>();
        Map<String, Object?>? registered;
        final registration = AdjustDeviceRegistration(
          platform: platform,
          environmentProvider: () => 'sandbox',
          readAdid: (_) async => null,
          readGoogleAdId: () async => 'gaid-test',
          readNativeGoogleAdId: () async => 'native-gaid-test',
          readIdfa: () async => '00000000-0000-0000-0000-000000000000',
          readIdfv: () async => 'idfv-test',
          readAppInstanceId: () async => 'instance-test',
          reportAdidFailure: (source, platform, ids) => reports.add(ids),
          registerDevice:
              ({
                required adid,
                required environment,
                gpsAdid,
                idfa,
                idfv,
                required appInstanceId,
                privacyConsent,
              }) async {
                registered = {
                  'adid': adid,
                  'app_instance_id': appInstanceId,
                  if (platform == TargetPlatform.android) 'gps_adid': gpsAdid,
                  if (platform == TargetPlatform.iOS) 'idfa': idfa,
                  if (platform == TargetPlatform.iOS) 'idfv': idfv,
                };
                await request.future;
              },
        );
        final check = registration.checkAdidAfterStartup();
        for (var i = 0; registered == null && i < 100; i++) {
          await Future<void>.delayed(Duration.zero);
        }
        expect(registered, isNotNull);
        expect(reports, hasLength(1));
        expect(registered?['adid'], '');
        expect(reports.single['app_instance_id'], 'instance-test');
        expect(
          reports.single[platform == TargetPlatform.android
              ? 'native_gps_adid'
              : 'idfv'],
          platform == TargetPlatform.android ? 'native-gaid-test' : 'idfv-test',
        );
        request.complete();
        await check;
        await registration.checkAdidAfterStartup();
        expect(reports, hasLength(1));
        registration.dispose();
      },
    );
  }

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test(
      'default ADID monitor exposes raw identifiers on ${platform.name}',
      () async {
        final events = MemoryCollectEventStore();
        GenesisTelemetry.setCollectUploaderForTesting(
          CollectTelemetryUploader(store: events)..configure(enabled: true),
        );
        addTearDown(GenesisTelemetry.resetForTesting);
        var nativeReads = 0;
        final registration = AdjustDeviceRegistration(
          platform: platform,
          environmentProvider: () => 'sandbox',
          readAdid: (_) async => '',
          readGoogleAdId: () async => 'adjust-gaid',
          readNativeGoogleAdId: () async {
            nativeReads++;
            return 'native-gaid';
          },
          readIdfa: () async => 'idfa',
          readIdfv: () async => 'idfv',
          readAppInstanceId: () async => 'instance',
          registerDevice:
              ({
                required adid,
                required environment,
                gpsAdid,
                idfa,
                idfv,
                required appInstanceId,
                privacyConsent,
              }) async {},
        );
        await registration.register();
        expect(nativeReads, 0);
        await registration.checkAdidAfterStartup();
        await launchAdidAvailabilityMonitor.whenIdle;
        await GenesisTelemetry.waitForCollectWritesForTesting();
        final event = events.eventsForTesting.singleWhere(
          (event) => event.action == 'get_adid_failed',
        );
        expect(
          (event.actionType, event.object1, event.object2, event.object3),
          (
            'monitor',
            platform == TargetPlatform.android ? 'adjust-gaid' : 'idfa',
            platform == TargetPlatform.android ? 'native-gaid' : 'idfv',
            'instance',
          ),
        );
        expect(
          events.eventsForTesting.where(
            (event) =>
                event.action == 'get_gaid_failed' ||
                event.action == 'get_gaid_success',
          ),
          isEmpty,
        );
        expect(nativeReads, platform == TargetPlatform.android ? 1 : 0);
        await registration.registerKnownAdid('recovered-adid');
        await registration.registerKnownAdid('recovered-adid');
        await launchAdidAvailabilityMonitor.whenIdle;
        final paired = events.eventsForTesting
            .where((event) => event.action.startsWith('get_adid_'))
            .toList();
        expect(paired.map((event) => event.action), [
          'get_adid_failed',
          'get_adid_success',
        ]);
        expect(
          (paired.last.object1, paired.last.object2, paired.last.object3),
          ('recovered-adid', '', 'instance'),
        );
        registration.dispose();
      },
    );
  }

  test(
    'ADID pairing shares the launch state and telemetry enqueue does not block registration',
    () async {
      final failureQueued = Completer<bool>();
      final events = <List<String>>[];
      var valid = false;
      var nativeReads = 0;
      var requests = 0;
      final monitor = AdidAvailabilityMonitor(
        report: (action, a, n, f) async {
          events.add([action, a, n, f]);
          return action == 'get_adid_failed' ? failureQueued.future : true;
        },
      );
      AdjustDeviceRegistration create() => AdjustDeviceRegistration(
        platform: TargetPlatform.android,
        environmentProvider: () => 'sandbox',
        readAdid: (_) async => valid ? 'adid' : '',
        readGoogleAdId: () async => valid ? 'adjust-gaid' : '',
        readNativeGoogleAdId: () async {
          nativeReads++;
          return valid ? 'native-gaid' : '';
        },
        readAppInstanceId: () async => 'instance',
        adidAvailabilityMonitor: monitor,
        registerDevice:
            ({
              required adid,
              required environment,
              gpsAdid,
              idfa,
              idfv,
              required appInstanceId,
              privacyConsent,
            }) async {
              requests++;
            },
      );
      final first = create();
      await first.checkAdidAfterStartup();
      expect(requests, 1);
      valid = true;
      final second = create();
      await second.register();
      expect(requests, 2);
      expect(nativeReads, 2);
      failureQueued.complete(true);
      await monitor.whenIdle;
      expect(events, [
        ['get_adid_failed', '', '', 'instance'],
        ['get_adid_success', 'adid', '', 'instance'],
      ]);
      await second.register();
      await monitor.whenIdle;
      expect(events, hasLength(2));
      expect(nativeReads, 2);
      first.dispose();
      second.dispose();
    },
  );

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    launchAdidAvailabilityMonitor.resetForTesting();
  });
  tearDown(AdjustAttributionRuntime.resetForTesting);

  test('saved ADID survives a new local-store instance', () async {
    const first = SharedPreferencesAdjustLocalAdidStore();
    await first.write('saved-adid');
    const second = SharedPreferencesAdjustLocalAdidStore();

    expect(await second.read(), 'saved-adid');
  });

  test(
    'cached ADIDs are separated by the selected Adjust environment',
    () async {
      const production = SharedPreferencesAdjustLocalAdidStore(
        environment: AdjustEnvironment.production,
      );
      const sandbox = SharedPreferencesAdjustLocalAdidStore(
        environment: AdjustEnvironment.sandbox,
      );

      await production.write('production-adid');
      expect(await sandbox.read(), isNull);
      await sandbox.write('sandbox-adid');
      expect(await production.read(), 'production-adid');
      expect(await sandbox.read(), 'sandbox-adid');
    },
  );

  test('first registration uses the selected Adjust SDK environment', () async {
    AdjustAttributionRuntime.configureEnvironment(
      const AppConfig(apiBaseUrl: 'https://dev.hushie.ai/api/'),
      releaseMode: true,
    );
    final environments = <String>[];
    final registration = AdjustDeviceRegistration(
      platform: TargetPlatform.android,
      environmentProvider: () => AdjustAttributionRuntime.environment.name,
      localAdidStore: SharedPreferencesAdjustLocalAdidStore(
        environment: AdjustAttributionRuntime.environment,
      ),
      readGoogleAdId: () async => null,
      registerDevice:
          ({
            required adid,
            required environment,
            gpsAdid,
            idfa,
            idfv,
            required appInstanceId,
            privacyConsent,
          }) async {
            environments.add(environment);
          },
    );

    await registration.registerKnownAdid('sandbox-adid');

    expect(environments, ['sandbox']);
    registration.dispose();
  });

  test('iOS registration sends ADID, IDFA, IDFV, and Firebase ID', () async {
    final requests = <Map<String, String?>>[];
    final registration = AdjustDeviceRegistration(
      platform: TargetPlatform.iOS,
      environmentProvider: () => 'sandbox',
      readAdid: (_) async => ' adid-ios ',
      readIdfa: () async => ' idfa-ios ',
      readIdfv: () async => ' idfv-ios ',
      readAppInstanceId: () async => ' firebase-ios ',
      readGoogleAdId: () async => throw StateError('must not be read'),
      registerDevice:
          ({
            required adid,
            required environment,
            gpsAdid,
            idfa,
            idfv,
            required appInstanceId,
            privacyConsent,
          }) async {
            requests.add({
              'adid': adid,
              'environment': environment,
              'gps_adid': gpsAdid,
              'idfa': idfa,
              'idfv': idfv,
              'app_instance_id': appInstanceId,
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
        'app_instance_id': 'firebase-ios',
      },
    ]);
  });

  test('iOS sends empty IDFA until a nonzero value is available', () async {
    var idfa = '00000000-0000-0000-0000-000000000000';
    final requests = <String?>[];
    final registration = AdjustDeviceRegistration(
      platform: TargetPlatform.iOS,
      environmentProvider: () => 'sandbox',
      readAdid: (_) async => 'adid-ios',
      readIdfa: () async => idfa,
      readIdfv: () async => 'idfv-ios',
      registerDevice:
          ({
            required adid,
            required environment,
            gpsAdid,
            idfa,
            idfv,
            required appInstanceId,
            privacyConsent,
          }) async {
            requests.add(idfa);
          },
    );

    await registration.register();
    idfa = '12345678-1234-1234-1234-123456789abc';
    await registration.register();

    expect(requests, ['', '12345678-1234-1234-1234-123456789abc']);
    registration.dispose();
  });

  test('Android registration sends ADID, GAID, and Firebase ID', () async {
    final requests = <Map<String, String?>>[];
    final registration = AdjustDeviceRegistration(
      platform: TargetPlatform.android,
      environmentProvider: () => 'production',
      readAdid: (_) async => 'adid-android',
      readGoogleAdId: () async => 'gps-adid',
      readAppInstanceId: () async => ' firebase-android ',
      readIdfa: () async => throw StateError('must not be read'),
      readIdfv: () async => throw StateError('must not be read'),
      registerDevice:
          ({
            required adid,
            required environment,
            gpsAdid,
            idfa,
            idfv,
            required appInstanceId,
            privacyConsent,
          }) async {
            requests.add({
              'adid': adid,
              'environment': environment,
              'gps_adid': gpsAdid,
              'idfa': idfa,
              'idfv': idfv,
              'app_instance_id': appInstanceId,
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
        'app_instance_id': 'firebase-android',
      },
    ]);
  });

  for (final (reason, reader) in <(String, AdjustOptionalIdReader)>[
    ('null', () async => null),
    ('blank', () async => '  '),
    ('error', () async => throw StateError('Firebase unavailable')),
    ('timeout', () => Completer<String?>().future),
  ]) {
    test('unavailable Firebase ID is sent as empty after $reason', () async {
      final requests = <String>[];
      final registration = AdjustDeviceRegistration(
        platform: TargetPlatform.android,
        environmentProvider: () => 'sandbox',
        readAdid: (_) async => 'adid',
        readGoogleAdId: () async => 'gaid',
        readAppInstanceId: reader,
        optionalIdTimeout: const Duration(milliseconds: 10),
        registerDevice:
            ({
              required adid,
              required environment,
              gpsAdid,
              idfa,
              idfv,
              required appInstanceId,
              privacyConsent,
            }) async {
              requests.add(appInstanceId);
            },
      );

      await registration.register();

      expect(requests, ['']);
      registration.dispose();
    });
  }

  test(
    'Firebase ID arriving during registration is sent in a follow-up',
    () async {
      final firstReadStarted = Completer<void>();
      final firstRead = Completer<String?>();
      final requests = <String>[];
      var reads = 0;
      final registration = AdjustDeviceRegistration(
        platform: TargetPlatform.iOS,
        environmentProvider: () => 'sandbox',
        readAdid: (_) async => 'adid',
        readIdfa: () async => '',
        readIdfv: () async => '',
        readAppInstanceId: () {
          reads++;
          if (reads == 1) {
            firstReadStarted.complete();
            return firstRead.future;
          }
          return Future<String?>.value('firebase-ready');
        },
        registerDevice:
            ({
              required adid,
              required environment,
              gpsAdid,
              idfa,
              idfv,
              required appInstanceId,
              privacyConsent,
            }) async {
              requests.add(appInstanceId);
            },
      );

      final initial = registration.register();
      await firstReadStarted.future;
      final followUp = registration.registerAfterFirebaseReady();
      firstRead.complete(null);
      await Future.wait(<Future<void>>[initial, followUp]);
      await registration.register();

      expect(requests, ['', 'firebase-ready']);
      registration.dispose();
    },
  );

  test('Android prefers a valid Adjust GAID without calling native', () async {
    var nativeReads = 0;
    final requests = <String?>[];
    final registration = AdjustDeviceRegistration(
      platform: TargetPlatform.android,
      environmentProvider: () => 'sandbox',
      readAdid: (_) async => 'adid',
      readGoogleAdId: () async => ' adjust-gaid ',
      readNativeGoogleAdId: () async {
        nativeReads++;
        return 'native-gaid';
      },
      registerDevice:
          ({
            required adid,
            required environment,
            gpsAdid,
            idfa,
            idfv,
            required appInstanceId,
            privacyConsent,
          }) async {
            requests.add(gpsAdid);
          },
    );

    await registration.register();

    expect(requests, ['adjust-gaid']);
    expect(nativeReads, 0);
    registration.dispose();
  });

  for (final (description, adjustReader) in <(String, AdjustOptionalIdReader)>[
    ('empty', () async => '  '),
    ('null', () async => null),
    ('all-zero', () async => '00000000-0000-0000-0000-000000000000'),
    ('error', () async => throw StateError('Adjust unavailable')),
    ('timeout', () => Completer<String?>().future),
  ]) {
    test(
      'Android falls back to live native GAID after Adjust $description',
      () async {
        final requests = <String?>[];
        var nativeReads = 0;
        final registration = AdjustDeviceRegistration(
          platform: TargetPlatform.android,
          environmentProvider: () => 'sandbox',
          optionalIdTimeout: const Duration(milliseconds: 10),
          readAdid: (_) async => 'adid',
          readGoogleAdId: adjustReader,
          readNativeGoogleAdId: () async {
            nativeReads++;
            return ' native-gaid ';
          },
          registerDevice:
              ({
                required adid,
                required environment,
                gpsAdid,
                idfa,
                idfv,
                required appInstanceId,
                privacyConsent,
              }) async {
                requests.add(gpsAdid);
              },
        );

        await registration.register();

        expect(requests, ['native-gaid']);
        expect(nativeReads, 1);
        registration.dispose();
      },
    );
  }

  test('Android sends empty GAID when both readers return all zeros', () async {
    final requests = <String?>[];
    final registration = AdjustDeviceRegistration(
      platform: TargetPlatform.android,
      environmentProvider: () => 'sandbox',
      readAdid: (_) async => 'adid',
      readGoogleAdId: () async => '00000000-0000-0000-0000-000000000000',
      readNativeGoogleAdId: () async => '00000000-0000-0000-0000-000000000000',
      registerDevice:
          ({
            required adid,
            required environment,
            gpsAdid,
            idfa,
            idfv,
            required appInstanceId,
            privacyConsent,
          }) async {
            requests.add(gpsAdid);
          },
    );

    await registration.register();

    expect(requests, ['']);
    registration.dispose();
  });

  test('Android keeps empty GAID when native fallback fails', () async {
    final requests = <String?>[];
    final registration = AdjustDeviceRegistration(
      platform: TargetPlatform.android,
      environmentProvider: () => 'sandbox',
      readAdid: (_) async => 'adid',
      readGoogleAdId: () async => null,
      readNativeGoogleAdId: () async =>
          throw StateError('Play services unavailable'),
      registerDevice:
          ({
            required adid,
            required environment,
            gpsAdid,
            idfa,
            idfv,
            required appInstanceId,
            privacyConsent,
          }) async {
            requests.add(gpsAdid);
          },
    );

    await registration.register();

    expect(requests, ['']);
    registration.dispose();
  });

  test(
    'Android resends registration when Adjust later supplies a new GAID',
    () async {
      var adjustReads = 0;
      var nativeReads = 0;
      final requests = <String?>[];
      final registration = AdjustDeviceRegistration(
        platform: TargetPlatform.android,
        environmentProvider: () => 'sandbox',
        readAdid: (_) async => 'adid',
        readGoogleAdId: () async => ++adjustReads == 1 ? null : 'adjust-gaid',
        readNativeGoogleAdId: () async {
          nativeReads++;
          return 'native-gaid';
        },
        registerDevice:
            ({
              required adid,
              required environment,
              gpsAdid,
              idfa,
              idfv,
              required appInstanceId,
              privacyConsent,
            }) async {
              requests.add(gpsAdid);
            },
      );

      await registration.register();
      await registration.register();
      await registration.register();

      expect(requests, ['native-gaid', 'adjust-gaid']);
      expect(nativeReads, 1);
      registration.dispose();
    },
  );

  test('iOS never reads the Android native GAID', () async {
    var nativeReads = 0;
    final registration = AdjustDeviceRegistration(
      platform: TargetPlatform.iOS,
      environmentProvider: () => 'sandbox',
      readAdid: (_) async => 'adid',
      readIdfa: () async => '',
      readIdfv: () async => 'idfv',
      readNativeGoogleAdId: () async {
        nativeReads++;
        return 'native-gaid';
      },
      registerDevice:
          ({
            required adid,
            required environment,
            gpsAdid,
            idfa,
            idfv,
            required appInstanceId,
            privacyConsent,
          }) async {},
    );

    await registration.register();

    expect(nativeReads, 0);
    registration.dispose();
  });

  test('Android registers GAID while ADID is unavailable', () async {
    final requests = <Map<String, String?>>[];
    var adidReads = 0;
    final registration = AdjustDeviceRegistration(
      platform: TargetPlatform.android,
      environmentProvider: () => 'sandbox',
      readAdid: (_) async => ++adidReads == 1 ? null : 'later-adid',
      readGoogleAdId: () async => ' gaid-available ',
      registerDevice:
          ({
            required adid,
            required environment,
            gpsAdid,
            idfa,
            idfv,
            required appInstanceId,
            privacyConsent,
          }) async {
            requests.add({'adid': adid, 'gps_adid': gpsAdid});
          },
    );

    await registration.register();
    expect(requests, [
      {'adid': '', 'gps_adid': 'gaid-available'},
    ]);
    expect(
      registration.lastResult,
      AdjustDeviceRegistrationResult.registeredWithoutAdid,
    );

    await registration.register();
    expect(requests, [
      {'adid': '', 'gps_adid': 'gaid-available'},
      {'adid': 'later-adid', 'gps_adid': 'gaid-available'},
    ]);
    registration.dispose();
  });

  test('iOS registers IDFA and IDFV while ADID is unavailable', () async {
    final requests = <Map<String, String?>>[];
    final registration = AdjustDeviceRegistration(
      platform: TargetPlatform.iOS,
      environmentProvider: () => 'sandbox',
      readAdid: (_) async => null,
      readIdfa: () async => ' idfa-available ',
      readIdfv: () async => ' idfv-available ',
      registerDevice:
          ({
            required adid,
            required environment,
            gpsAdid,
            idfa,
            idfv,
            required appInstanceId,
            privacyConsent,
          }) async {
            requests.add({'adid': adid, 'idfa': idfa, 'idfv': idfv});
          },
    );

    await registration.register();
    expect(requests, [
      {'adid': '', 'idfa': 'idfa-available', 'idfv': 'idfv-available'},
    ]);
    registration.dispose();
  });

  test('unavailable optional IDs are sent as empty strings', () async {
    final requests = <Map<String, String?>>[];
    final androidRegistration = AdjustDeviceRegistration(
      platform: TargetPlatform.android,
      environmentProvider: () => 'sandbox',
      readAdid: (_) async => null,
      readGoogleAdId: () async => '  ',
      registerDevice:
          ({
            required adid,
            required environment,
            gpsAdid,
            idfa,
            idfv,
            required appInstanceId,
            privacyConsent,
          }) async {
            requests.add({'adid': adid, 'gps_adid': gpsAdid});
          },
    );
    final iosRegistration = AdjustDeviceRegistration(
      platform: TargetPlatform.iOS,
      environmentProvider: () => 'sandbox',
      readAdid: (_) async => null,
      readIdfa: () async => '',
      readIdfv: () async => ' ',
      registerDevice:
          ({
            required adid,
            required environment,
            gpsAdid,
            idfa,
            idfv,
            required appInstanceId,
            privacyConsent,
          }) async {
            requests.add({'adid': adid, 'idfa': idfa, 'idfv': idfv});
          },
    );

    await androidRegistration.register();
    await iosRegistration.register();
    expect(requests, [
      {'adid': '', 'gps_adid': ''},
      {'adid': '', 'idfa': '', 'idfv': ''},
    ]);
    androidRegistration.dispose();
    iosRegistration.dispose();
  });

  test('a newly available GAID is sent even when ADID stays missing', () async {
    final requests = <Map<String, String?>>[];
    var gaidReads = 0;
    final registration = AdjustDeviceRegistration(
      platform: TargetPlatform.android,
      environmentProvider: () => 'sandbox',
      readAdid: (_) async => null,
      readGoogleAdId: () async => ++gaidReads == 1 ? null : 'later-gaid',
      registerDevice:
          ({
            required adid,
            required environment,
            gpsAdid,
            idfa,
            idfv,
            required appInstanceId,
            privacyConsent,
          }) async {
            requests.add({'adid': adid, 'gps_adid': gpsAdid});
          },
    );

    await registration.register();
    await registration.register();
    await registration.register();

    expect(gaidReads, 3);
    expect(requests, [
      {'adid': '', 'gps_adid': ''},
      {'adid': '', 'gps_adid': 'later-gaid'},
    ]);
    registration.dispose();
  });

  test('missing ADID registers available IDs and updates later', () async {
    var readCount = 0;
    final requests = <String>[];
    final registration = AdjustDeviceRegistration(
      platform: TargetPlatform.iOS,
      environmentProvider: () => 'sandbox',
      readAdid: (_) async => ++readCount == 1 ? null : 'adid-ready',
      readIdfa: () async => null,
      readIdfv: () async => 'idfv',
      retryDelays: const [],
      registerDevice:
          ({
            required adid,
            required environment,
            gpsAdid,
            idfa,
            idfv,
            required appInstanceId,
            privacyConsent,
          }) async {
            requests.add(adid);
          },
    );

    await registration.register();
    expect(
      registration.lastResult,
      AdjustDeviceRegistrationResult.registeredWithoutAdid,
    );
    await registration.register();

    expect(readCount, 2);
    expect(requests, ['', 'adid-ready']);
    expect(registration.lastResult, AdjustDeviceRegistrationResult.registered);
  });

  test(
    'unanswered ADID read releases registration for a later retry',
    () async {
      final unansweredRead = Completer<String?>();
      final reports = <String>[];
      final requests = <String>[];
      var readCount = 0;
      final registration = AdjustDeviceRegistration(
        platform: TargetPlatform.android,
        environmentProvider: () => 'sandbox',
        adidTimeout: const Duration(milliseconds: 10),
        readAdid: (_) => ++readCount == 1
            ? unansweredRead.future
            : Future<String?>.value('later-adid'),
        readGoogleAdId: () async => null,
        reportAdidFailure: (source, platform, identifiers) =>
            reports.add(source),
        registerDevice:
            ({
              required adid,
              required environment,
              gpsAdid,
              idfa,
              idfv,
              required appInstanceId,
              privacyConsent,
            }) async {
              requests.add(adid);
            },
      );

      await registration.checkAdidAfterStartup();
      expect(
        registration.lastResult,
        AdjustDeviceRegistrationResult.registeredWithoutAdidReadError,
      );
      expect(reports, isEmpty);

      await registration.register();
      expect(requests, ['', 'later-adid']);
      expect(
        registration.lastResult,
        AdjustDeviceRegistrationResult.registered,
      );
      registration.dispose();
    },
  );

  test('unanswered optional ID does not block ADID registration', () async {
    final unansweredRead = Completer<String?>();
    final requests = <String?>[];
    final registration = AdjustDeviceRegistration(
      platform: TargetPlatform.android,
      environmentProvider: () => 'sandbox',
      optionalIdTimeout: const Duration(milliseconds: 10),
      readGoogleAdId: () => unansweredRead.future,
      registerDevice:
          ({
            required adid,
            required environment,
            gpsAdid,
            idfa,
            idfv,
            required appInstanceId,
            privacyConsent,
          }) async {
            requests.add(gpsAdid);
          },
    );

    await registration.registerKnownAdid('ready-adid');
    await registration.register(force: true);

    expect(requests, ['', '']);
    expect(registration.lastResult, AdjustDeviceRegistrationResult.registered);
    registration.dispose();
  });

  test('unanswered iOS identifiers are sent as empty strings', () async {
    final unansweredRead = Completer<String?>();
    final requests = <Map<String, String?>>[];
    final registration = AdjustDeviceRegistration(
      platform: TargetPlatform.iOS,
      environmentProvider: () => 'sandbox',
      optionalIdTimeout: const Duration(milliseconds: 10),
      readIdfa: () => unansweredRead.future,
      readIdfv: () => unansweredRead.future,
      registerDevice:
          ({
            required adid,
            required environment,
            gpsAdid,
            idfa,
            idfv,
            required appInstanceId,
            privacyConsent,
          }) async {
            requests.add({'adid': adid, 'idfa': idfa, 'idfv': idfv});
          },
    );

    await registration.registerKnownAdid('ready-adid');

    expect(requests, [
      {'adid': 'ready-adid', 'idfa': '', 'idfv': ''},
    ]);
    registration.dispose();
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
      reportAdidFailure: (source, platform, identifiers) => reports.add(source),
      registerDevice:
          ({
            required adid,
            required environment,
            gpsAdid,
            idfa,
            idfv,
            required appInstanceId,
            privacyConsent,
          }) async {
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
    expect(requestCount, 1);
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
      reportAdidFailure: (source, platform, identifiers) => reports.add(source),
      registerDevice:
          ({
            required adid,
            required environment,
            gpsAdid,
            idfa,
            idfv,
            required appInstanceId,
            privacyConsent,
          }) async {
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
          ({
            required adid,
            required environment,
            gpsAdid,
            idfa,
            idfv,
            required appInstanceId,
            privacyConsent,
          }) async {},
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
          ({
            required adid,
            required environment,
            gpsAdid,
            idfa,
            idfv,
            required appInstanceId,
            privacyConsent,
          }) async {
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
      reportAdidFailure: (source, platform, identifiers) => reports.add(source),
      registerDevice:
          ({
            required adid,
            required environment,
            gpsAdid,
            idfa,
            idfv,
            required appInstanceId,
            privacyConsent,
          }) async {},
    );

    await registration.checkAdidAfterStartup();

    expect(
      registration.lastResult,
      AdjustDeviceRegistrationResult.registeredWithoutAdid,
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
        reportAdidFailure: (source, platform, identifiers) =>
            reports.add(source),
        registerDevice:
            ({
              required adid,
              required environment,
              gpsAdid,
              idfa,
              idfv,
              required appInstanceId,
              privacyConsent,
            }) async {
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
        reportAdidFailure: (source, platform, identifiers) =>
            reports.add(source),
        registerDevice:
            ({
              required adid,
              required environment,
              gpsAdid,
              idfa,
              idfv,
              required appInstanceId,
              privacyConsent,
            }) async {
              requests.add(adid);
            },
      );

      await registration.registerAfterSessionWithoutAdid();
      expect(reports, isEmpty);
      await registration.checkAdidAfterStartup();

      expect(readCount, 2);
      expect(requests, ['', 'adid-later']);
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
        reportAdidFailure: (source, platform, identifiers) =>
            reports.add(source),
        registerDevice:
            ({
              required adid,
              required environment,
              gpsAdid,
              idfa,
              idfv,
              required appInstanceId,
              privacyConsent,
            }) async {
              requests.add(adid);
            },
      );

      final startupAttempt = registration.register();
      final failureAttempt = registration.registerAfterSessionWithoutAdid();
      firstRead.complete(null);
      await Future.wait([startupAttempt, failureAttempt]);

      expect(readCount, 2);
      expect(requests, ['', 'adid-after-failure']);
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
            ({
              required adid,
              required environment,
              gpsAdid,
              idfa,
              idfv,
              required appInstanceId,
              privacyConsent,
            }) async {
              requestCount++;
            },
      );

      await registration.register();

      expect(requestCount, 1);
      expect(readCount, 1);
      expect(scheduledDelays, isEmpty);
      expect(
        registration.lastResult,
        AdjustDeviceRegistrationResult.registeredWithoutAdid,
      );

      await registration.register();

      expect(readCount, 2);
      expect(requestCount, 2);
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
          ({
            required adid,
            required environment,
            gpsAdid,
            idfa,
            idfv,
            required appInstanceId,
            privacyConsent,
          }) async {
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
            ({
              required adid,
              required environment,
              gpsAdid,
              idfa,
              idfv,
              required appInstanceId,
              privacyConsent,
            }) async {
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
          ({
            required adid,
            required environment,
            gpsAdid,
            idfa,
            idfv,
            required appInstanceId,
            privacyConsent,
          }) async {
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
          ({
            required adid,
            required environment,
            gpsAdid,
            idfa,
            idfv,
            required appInstanceId,
            privacyConsent,
          }) async {
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
          ({
            required adid,
            required environment,
            gpsAdid,
            idfa,
            idfv,
            required appInstanceId,
            privacyConsent,
          }) async {
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
            ({
              required adid,
              required environment,
              gpsAdid,
              idfa,
              idfv,
              required appInstanceId,
              privacyConsent,
            }) async {
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
            ({
              required adid,
              required environment,
              gpsAdid,
              idfa,
              idfv,
              required appInstanceId,
              privacyConsent,
            }) async {
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
          ({
            required adid,
            required environment,
            gpsAdid,
            idfa,
            idfv,
            required appInstanceId,
            privacyConsent,
          }) async {
            requests.add(environment);
          },
    );

    await registration.register();
    await registration.register();
    environment = 'production';
    await registration.register();

    expect(requests, ['sandbox', 'production']);
  });

  test(
    'network recovery uses saved ADID after an unavailable SDK read',
    () async {
      final localStore = _MemoryAdjustLocalAdidStore(value: 'saved-adid');
      final requests = <String>[];
      final registration = AdjustDeviceRegistration(
        platform: TargetPlatform.iOS,
        environmentProvider: () => 'production',
        localAdidStore: localStore,
        readAdid: (_) async => null,
        readIdfa: () async => null,
        readIdfv: () async => null,
        registerDevice:
            ({
              required adid,
              required environment,
              gpsAdid,
              idfa,
              idfv,
              required appInstanceId,
              privacyConsent,
            }) async {
              requests.add('$environment:$adid');
            },
      );

      await registration.retryAfterNetworkRestored();
      await registration.retryAfterNetworkRestored();

      expect(requests, ['production:', 'production:saved-adid']);
      expect(
        registration.lastResult,
        AdjustDeviceRegistrationResult.registered,
      );
      registration.dispose();
    },
  );

  test(
    'network recovery retries a failed report and skips after success',
    () async {
      var requestCount = 0;
      var canceledRetries = 0;
      final registration = AdjustDeviceRegistration(
        platform: TargetPlatform.android,
        environmentProvider: () => 'production',
        readGoogleAdId: () async => null,
        retryScheduler: (delay, callback) =>
            () => canceledRetries++,
        registerDevice:
            ({
              required adid,
              required environment,
              gpsAdid,
              idfa,
              idfv,
              required appInstanceId,
              privacyConsent,
            }) async {
              requestCount++;
              if (requestCount == 1) throw StateError('offline');
            },
      );

      await registration.registerKnownAdid('adid');
      expect(registration.lastResult, AdjustDeviceRegistrationResult.failed);

      await registration.retryAfterNetworkRestored();
      await registration.retryAfterNetworkRestored();

      expect(requestCount, 2);
      expect(canceledRetries, 1);
      expect(
        registration.lastResult,
        AdjustDeviceRegistrationResult.registered,
      );
      registration.dispose();
    },
  );
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
