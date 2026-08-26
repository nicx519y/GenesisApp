import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/telemetry/device_info_telemetry.dart';
import 'package:genesis_flutter_android/platform/app/app_metadata_service.dart';
import 'package:genesis_flutter_android/platform/device/device_id_service.dart';

class _MemoryStateStore implements DeviceInfoTelemetryStateStore {
  DeviceInfoTelemetryState? state;

  @override
  Future<DeviceInfoTelemetryState?> read() async => state;

  @override
  Future<void> write(DeviceInfoTelemetryState state) async {
    this.state = state;
  }
}

class _SnapshotDeviceIdService
    implements DeviceIdService, DeviceIdentitySnapshotService {
  _SnapshotDeviceIdService(this.snapshot);

  DeviceIdentitySnapshot snapshot;

  @override
  Future<String> getDeviceId() async => snapshot.deviceId;

  @override
  Future<DeviceIdentitySnapshot> getDeviceIdentitySnapshot() async => snapshot;
}

void main() {
  late _MemoryStateStore store;
  late _SnapshotDeviceIdService deviceId;
  late List<Map<String, Object?>> payloads;
  var version = '1.0.0';
  var versionCode = '1';

  DeviceInfoTelemetryReporter buildReporter({bool enqueueSucceeds = true}) {
    return DeviceInfoTelemetryReporter(
      deviceIdService: deviceId,
      stateStore: store,
      appVersionReader: () async =>
          AppVersionInfo(versionName: version, versionCode: versionCode),
      collectLogger: (object1) async {
        payloads.add(jsonDecode(object1) as Map<String, Object?>);
        return enqueueSucceeds;
      },
    );
  }

  setUp(() {
    store = _MemoryStateStore();
    payloads = <Map<String, Object?>>[];
    version = '1.0.0';
    versionCode = '1';
    deviceId = _SnapshotDeviceIdService(
      const DeviceIdentitySnapshot(
        platform: 'android',
        deviceId: 'android-id-1',
        fields: <String, Object?>{
          'device_id_source': 'android_id',
          'signing_cert_sha256': 'cert-hash',
          'android_user_serial': 0,
          'android_user_type': 'system',
          'gateway_public_key_hash': 'gateway-hash',
          'manufacturer': 'vivo',
          'model': 'V2241A',
          'device': 'V2241A',
          'os_build_fingerprint_hash': 'build-hash',
          'unexpected_field': 'must-not-upload',
        },
      ),
    );
  });

  test('first snapshot uses first_install and excludes device id', () async {
    final reporter = buildReporter();

    await reporter.reportStartup(uid: 'u_1');

    expect(payloads, hasLength(1));
    expect(payloads.single['schema_version'], deviceInfoSchemaVersion);
    expect(payloads.single['trigger'], 'first_install');
    expect(payloads.single['device_id_source'], 'android_id');
    expect(payloads.single['android_user_serial'], 0);
    expect(payloads.single, isNot(contains('device_id')));
    expect(payloads.single, isNot(contains('unexpected_field')));
    expect(store.state?.deviceId, 'android-id-1');
    expect(store.state?.uid, 'u_1');
  });

  test(
    'unchanged snapshot is deduplicated and app update is reported',
    () async {
      final reporter = buildReporter();

      await reporter.reportStartup();
      await reporter.reportStartup();
      version = '1.1.0';
      await reporter.reportStartup();

      expect(payloads.map((payload) => payload['trigger']), <Object?>[
        'first_install',
        'app_updated',
      ]);
    },
  );

  test('build number change is reported as app update', () async {
    final reporter = buildReporter();

    await reporter.reportStartup();
    versionCode = '2';
    await reporter.reportStartup();

    expect(payloads.last['trigger'], 'app_updated');
  });

  test(
    'device id and identity context changes have distinct triggers',
    () async {
      final reporter = buildReporter();
      await reporter.reportStartup();

      deviceId.snapshot = DeviceIdentitySnapshot(
        platform: 'android',
        deviceId: 'android-id-2',
        fields: deviceId.snapshot.fields,
      );
      await reporter.reportStartup();
      deviceId.snapshot = DeviceIdentitySnapshot(
        platform: 'android',
        deviceId: 'android-id-2',
        fields: <String, Object?>{
          ...deviceId.snapshot.fields,
          'android_user_serial': 10,
        },
      );
      await reporter.reportStartup();

      expect(payloads.map((payload) => payload['trigger']), <Object?>[
        'first_install',
        'device_id_changed',
        'device_context_changed',
      ]);
    },
  );

  test('login success is emitted even when snapshot is unchanged', () async {
    final reporter = buildReporter();
    await reporter.reportStartup();

    await reporter.reportLoginSuccess('u_2');

    expect(payloads.last['trigger'], 'login_success');
    expect(store.state?.uid, 'u_2');
  });

  test('iOS keychain errors are emitted on every startup', () async {
    deviceId.snapshot = const DeviceIdentitySnapshot(
      platform: 'ios',
      deviceId: 'ios-id-1',
      fields: <String, Object?>{
        'device_id_source': 'keychain_error',
        'keychain_read_status': -34018,
        'keychain_write_status': -34018,
        'bundle_id': 'com.worldo.ai',
      },
    );
    final reporter = buildReporter();

    await reporter.reportStartup();
    await reporter.reportStartup();

    expect(payloads.map((payload) => payload['trigger']), <Object?>[
      'first_install',
      'identity_error',
    ]);
    expect(payloads.last['keychain_read_status'], -34018);
  });

  test('iOS no-write snapshot keeps null keychain write status', () async {
    deviceId.snapshot = const DeviceIdentitySnapshot(
      platform: 'ios',
      deviceId: 'ios-id-1',
      fields: <String, Object?>{
        'device_id_source': 'keychain_existing',
        'keychain_read_status': 0,
        'keychain_write_status': null,
        'bundle_id': 'com.worldo.ai',
      },
    );
    final reporter = buildReporter();

    await reporter.reportStartup();

    expect(payloads.single, contains('keychain_write_status'));
    expect(payloads.single['keychain_write_status'], isNull);
  });

  test(
    'state is not persisted when Collect did not enqueue the event',
    () async {
      final reporter = buildReporter(enqueueSucceeds: false);

      await reporter.reportStartup();

      expect(payloads, hasLength(1));
      expect(store.state, isNull);
    },
  );
}
