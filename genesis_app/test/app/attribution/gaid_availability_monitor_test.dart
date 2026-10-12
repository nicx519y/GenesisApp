import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/attribution/adjust_device_registration.dart';
import 'package:genesis_flutter_android/app/attribution/gaid_availability_monitor.dart';
import 'package:genesis_flutter_android/app/telemetry/genesis_telemetry.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));
  tearDown(GenesisTelemetry.resetForTesting);

  test('default reporter queues the requested monitor payloads', () async {
    final events = MemoryCollectEventStore();
    GenesisTelemetry.setCollectUploaderForTesting(
      CollectTelemetryUploader(store: events)..configure(enabled: true),
    );
    final monitor = GaidAvailabilityMonitor();

    monitor.observe(environment: 'sandbox', source: null);
    monitor.observe(environment: 'sandbox', source: 'native');
    await monitor.whenIdle;

    expect(
      events.eventsForTesting.map(
        (event) =>
            (event.actionType, event.action, event.object1, event.object2),
      ),
      [
        (
          'monitor',
          'get_gaid_failed',
          'adjust_and_native_unavailable',
          'android',
        ),
        ('monitor', 'get_gaid_success', 'native', 'android'),
      ],
    );
  });

  test('a GAID available on the first read never reports success', () async {
    final events = <(String, String)>[];
    final monitor = GaidAvailabilityMonitor(
      report: (action, source) async {
        events.add((action, source));
        return true;
      },
    );
    final registration = _registration(
      monitor: monitor,
      adjustReader: () async => 'adjust-gaid',
      nativeReader: () async => throw StateError('native must not be read'),
    );

    await registration.register();
    await registration.register();
    await monitor.whenIdle;

    expect(events, isEmpty);
    registration.dispose();
  });

  test(
    'native fallback success does not report a failed Adjust read',
    () async {
      final events = <(String, String)>[];
      final monitor = GaidAvailabilityMonitor(
        report: (action, source) async {
          events.add((action, source));
          return true;
        },
      );
      final requests = <String?>[];
      final registration = _registration(
        monitor: monitor,
        adjustReader: () async => null,
        nativeReader: () async => 'native-gaid',
        requests: requests,
      );

      await registration.register();
      await monitor.whenIdle;

      expect(requests, ['native-gaid']);
      expect(events, isEmpty);
      registration.dispose();
    },
  );

  test('both readers failing report once, then Adjust recovery once', () async {
    final events = <(String, String)>[];
    final monitor = GaidAvailabilityMonitor(
      report: (action, source) async {
        events.add((action, source));
        return true;
      },
    );
    final requests = <String?>[];
    var reads = 0;
    final registration = _registration(
      monitor: monitor,
      adjustReader: () async => ++reads < 3 ? null : 'later-adjust-gaid',
      nativeReader: () async => null,
      requests: requests,
    );

    await registration.register();
    await registration.register();
    await registration.register();
    await registration.register();
    await monitor.whenIdle;

    expect(requests, ['', 'later-adjust-gaid']);
    expect(events, [
      ('get_gaid_failed', 'adjust_and_native_unavailable'),
      ('get_gaid_success', 'adjust'),
    ]);
    registration.dispose();
  });

  test('recovery can come from the native reader after a failure', () async {
    final events = <(String, String)>[];
    final monitor = GaidAvailabilityMonitor(
      report: (action, source) async {
        events.add((action, source));
        return true;
      },
    );
    var nativeReads = 0;
    final registration = _registration(
      monitor: monitor,
      adjustReader: () async => null,
      nativeReader: () async => ++nativeReads == 1 ? null : 'native-gaid',
    );

    await registration.register();
    await registration.register();
    await monitor.whenIdle;

    expect(events, [
      ('get_gaid_failed', 'adjust_and_native_unavailable'),
      ('get_gaid_success', 'native'),
    ]);
    registration.dispose();
  });

  test(
    'both readers timing out or throwing still register an empty GAID',
    () async {
      final events = <String>[];
      final requests = <String?>[];
      final monitor = GaidAvailabilityMonitor(
        report: (action, source) async {
          events.add(action);
          return true;
        },
      );
      final registration = _registration(
        monitor: monitor,
        adjustReader: () => Completer<String?>().future,
        nativeReader: () async => throw StateError('native unavailable'),
        optionalIdTimeout: const Duration(milliseconds: 10),
        requests: requests,
      );

      await registration.register();
      await monitor.whenIdle;

      expect(requests, ['']);
      expect(events, ['get_gaid_failed']);
      registration.dispose();
    },
  );

  test('a new failure after recovery starts a new monitoring period', () async {
    final events = <String>[];
    final monitor = GaidAvailabilityMonitor(
      report: (action, source) async {
        events.add(action);
        return true;
      },
    );
    var reads = 0;
    final registration = _registration(
      monitor: monitor,
      adjustReader: () async => (++reads).isEven ? 'gaid' : null,
      nativeReader: () async => null,
    );

    await registration.register();
    await registration.register();
    await registration.register();
    await registration.register();
    await monitor.whenIdle;

    expect(events, [
      'get_gaid_failed',
      'get_gaid_success',
      'get_gaid_failed',
      'get_gaid_success',
    ]);
    registration.dispose();
  });

  test('failed enqueue never arms a success event', () async {
    final events = <String>[];
    final monitor = GaidAvailabilityMonitor(
      report: (action, source) async {
        events.add(action);
        return false;
      },
    );
    var reads = 0;
    final registration = _registration(
      monitor: monitor,
      adjustReader: () async => ++reads == 1 ? null : 'later-gaid',
      nativeReader: () async => null,
    );

    await registration.register();
    await registration.register();
    await monitor.whenIdle;

    expect(events, ['get_gaid_failed']);
    expect(await monitor.store.hasPendingFailure('sandbox'), isFalse);
    registration.dispose();
  });

  test(
    'failed recovery enqueue leaves recovery pending for another read',
    () async {
      final events = <String>[];
      var successAttempts = 0;
      final monitor = GaidAvailabilityMonitor(
        report: (action, source) async {
          events.add(action);
          return action != 'get_gaid_success' || ++successAttempts > 1;
        },
      );
      var reads = 0;
      final registration = _registration(
        monitor: monitor,
        adjustReader: () async => ++reads == 1 ? null : 'later-gaid',
        nativeReader: () async => null,
      );

      await registration.register();
      await registration.register();
      await registration.register();
      await monitor.whenIdle;

      expect(events, [
        'get_gaid_failed',
        'get_gaid_success',
        'get_gaid_success',
      ]);
      expect(await monitor.store.hasPendingFailure('sandbox'), isFalse);
      registration.dispose();
    },
  );

  test('failure can be recovered after a new registration instance', () async {
    final events = <(String, String)>[];
    GaidAvailabilityMonitor monitor() => GaidAvailabilityMonitor(
      report: (action, source) async {
        events.add((action, source));
        return true;
      },
    );
    final firstMonitor = monitor();
    final first = _registration(
      monitor: firstMonitor,
      adjustReader: () async => null,
      nativeReader: () async => null,
    );
    await first.register();
    await firstMonitor.whenIdle;
    first.dispose();

    final secondMonitor = monitor();
    final second = _registration(
      monitor: secondMonitor,
      adjustReader: () async => 'later-gaid',
      nativeReader: () async => null,
    );
    await second.register();
    await secondMonitor.whenIdle;

    expect(events, [
      ('get_gaid_failed', 'adjust_and_native_unavailable'),
      ('get_gaid_success', 'adjust'),
    ]);
    expect(await secondMonitor.store.hasPendingFailure('sandbox'), isFalse);
    second.dispose();
  });

  test('a failure from another environment does not arm success', () async {
    final events = <(String, String)>[];
    final monitor = GaidAvailabilityMonitor(
      report: (action, source) async {
        events.add((action, source));
        return true;
      },
    );
    final sandbox = _registration(
      monitor: monitor,
      adjustReader: () async => null,
      nativeReader: () async => null,
    );
    final production = _registration(
      monitor: monitor,
      environment: 'production',
      adjustReader: () async => 'production-gaid',
      nativeReader: () async => null,
    );

    await sandbox.register();
    await production.register();
    await monitor.whenIdle;

    expect(events, [('get_gaid_failed', 'adjust_and_native_unavailable')]);
    expect(await monitor.store.hasPendingFailure('sandbox'), isTrue);
    expect(await monitor.store.hasPendingFailure('production'), isFalse);
    sandbox.dispose();
    production.dispose();
  });

  test('iOS does not report GAID availability', () async {
    final events = <String>[];
    final monitor = GaidAvailabilityMonitor(
      report: (action, source) async {
        events.add(action);
        return true;
      },
    );
    final registration = AdjustDeviceRegistration(
      platform: TargetPlatform.iOS,
      environmentProvider: () => 'sandbox',
      gaidAvailabilityMonitor: monitor,
      readAdid: (_) async => 'adid',
      readGoogleAdId: () async => throw StateError('must not be read'),
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
          }) async {},
    );

    await registration.register();
    await monitor.whenIdle;

    expect(events, isEmpty);
    registration.dispose();
  });
}

AdjustDeviceRegistration _registration({
  required GaidAvailabilityMonitor monitor,
  required Future<String?> Function() adjustReader,
  required Future<String?> Function() nativeReader,
  String environment = 'sandbox',
  Duration optionalIdTimeout = const Duration(seconds: 3),
  List<String?>? requests,
}) => AdjustDeviceRegistration(
  platform: TargetPlatform.android,
  environmentProvider: () => environment,
  gaidAvailabilityMonitor: monitor,
  readAdid: (_) async => 'adid',
  readGoogleAdId: adjustReader,
  readNativeGoogleAdId: nativeReader,
  optionalIdTimeout: optionalIdTimeout,
  registerDevice:
      ({
        required adid,
        required environment,
        gpsAdid,
        idfa,
        idfv,
        required appInstanceId,
      }) async {
        requests?.add(gpsAdid);
      },
);
