import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/attribution/adjust_device_registration.dart';

void main() {
  test('iOS registration sends ADID, IDFA, and IDFV', () async {
    final requests = <Map<String, String?>>[];
    final registration = AdjustDeviceRegistration(
      platform: TargetPlatform.iOS,
      readAdid: (_) async => ' adid-ios ',
      readIdfa: () async => ' idfa-ios ',
      readIdfv: () async => ' idfv-ios ',
      readGoogleAdId: () async => throw StateError('must not be read'),
      registerDevice: ({required adid, gpsAdid, idfa, idfv}) async {
        requests.add({
          'adid': adid,
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
      readAdid: (_) async => 'adid-android',
      readGoogleAdId: () async => 'gps-adid',
      readIdfa: () async => throw StateError('must not be read'),
      readIdfv: () async => throw StateError('must not be read'),
      registerDevice: ({required adid, gpsAdid, idfa, idfv}) async {
        requests.add({
          'adid': adid,
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
      readAdid: (_) async => ++readCount == 1 ? null : 'adid-ready',
      readIdfa: () async => null,
      readIdfv: () async => 'idfv',
      registerDevice: ({required adid, gpsAdid, idfa, idfv}) async {
        requestCount++;
      },
    );

    await registration.register();
    await registration.register();

    expect(readCount, 2);
    expect(requestCount, 1);
  });

  test(
    'unchanged identifiers are deduplicated unless login forces sync',
    () async {
      var requestCount = 0;
      final registration = AdjustDeviceRegistration(
        platform: TargetPlatform.android,
        readAdid: (_) async => 'adid',
        readGoogleAdId: () async => 'gps-adid',
        registerDevice: ({required adid, gpsAdid, idfa, idfv}) async {
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
        readAdid: (_) async => 'adid',
        readGoogleAdId: () async => 'gps-adid',
        registerDevice: ({required adid, gpsAdid, idfa, idfv}) async {
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
}
