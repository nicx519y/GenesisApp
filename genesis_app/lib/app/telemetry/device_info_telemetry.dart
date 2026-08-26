import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../platform/app/app_metadata_service.dart';
import '../../platform/device/device_id_service.dart';
import 'genesis_telemetry.dart';

const int deviceInfoSchemaVersion = 1;

typedef DeviceInfoAppVersionReader = Future<AppVersionInfo> Function();
typedef DeviceInfoCollectLogger = Future<bool> Function(String object1);

class DeviceInfoTelemetryState {
  const DeviceInfoTelemetryState({
    required this.deviceId,
    required this.contextJson,
    required this.appVersion,
    required this.uid,
  });

  final String deviceId;
  final String contextJson;
  final String appVersion;
  final String uid;
}

abstract interface class DeviceInfoTelemetryStateStore {
  Future<DeviceInfoTelemetryState?> read();
  Future<void> write(DeviceInfoTelemetryState state);
}

class SharedPreferencesDeviceInfoTelemetryStateStore
    implements DeviceInfoTelemetryStateStore {
  const SharedPreferencesDeviceInfoTelemetryStateStore();

  static const _deviceIdKey = 'device_info_last_device_id_v1';
  static const _contextKey = 'device_info_last_context_v1';
  static const _appVersionKey = 'device_info_last_app_version_v1';
  static const _uidKey = 'device_info_last_uid_v1';

  @override
  Future<DeviceInfoTelemetryState?> read() async {
    final preferences = await SharedPreferences.getInstance();
    final contextJson = preferences.getString(_contextKey)?.trim() ?? '';
    if (contextJson.isEmpty) return null;
    return DeviceInfoTelemetryState(
      deviceId: preferences.getString(_deviceIdKey)?.trim() ?? '',
      contextJson: contextJson,
      appVersion: preferences.getString(_appVersionKey)?.trim() ?? '',
      uid: preferences.getString(_uidKey)?.trim() ?? '',
    );
  }

  @override
  Future<void> write(DeviceInfoTelemetryState state) async {
    final preferences = await SharedPreferences.getInstance();
    final results = await Future.wait<bool>(<Future<bool>>[
      preferences.setString(_deviceIdKey, state.deviceId),
      preferences.setString(_contextKey, state.contextJson),
      preferences.setString(_appVersionKey, state.appVersion),
      preferences.setString(_uidKey, state.uid),
    ]);
    if (results.any((saved) => !saved)) {
      throw StateError('Failed to persist device info telemetry state');
    }
  }
}

class DeviceInfoTelemetryReporter {
  DeviceInfoTelemetryReporter({
    required DeviceIdService deviceIdService,
    DeviceInfoTelemetryStateStore stateStore =
        const SharedPreferencesDeviceInfoTelemetryStateStore(),
    DeviceInfoAppVersionReader appVersionReader = AppMetadataService.appVersion,
    DeviceInfoCollectLogger? collectLogger,
  }) : _deviceIdService = deviceIdService,
       _stateStore = stateStore,
       _appVersionReader = appVersionReader,
       _collectLogger = collectLogger ?? _defaultCollectLogger;

  final DeviceIdService _deviceIdService;
  final DeviceInfoTelemetryStateStore _stateStore;
  final DeviceInfoAppVersionReader _appVersionReader;
  final DeviceInfoCollectLogger _collectLogger;
  Future<void> _pendingReports = Future<void>.value();

  Future<void> reportStartup({String? uid}) {
    return _serialize(() => _report(uid: uid));
  }

  Future<void> reportLoginSuccess(String uid) {
    return _serialize(() => _report(uid: uid, forcedTrigger: 'login_success'));
  }

  Future<void> _serialize(Future<void> Function() operation) {
    final next = _pendingReports.then((_) => operation());
    _pendingReports = next.catchError((Object error, StackTrace stackTrace) {
      debugPrint('[Telemetry][DeviceInfo] report failed: $error');
      debugPrint('[Telemetry][DeviceInfo] stacktrace:\n$stackTrace');
    });
    return next;
  }

  Future<void> _report({String? uid, String? forcedTrigger}) async {
    final service = _deviceIdService;
    if (service is! DeviceIdentitySnapshotService) return;

    final snapshot = await (service as DeviceIdentitySnapshotService)
        .getDeviceIdentitySnapshot();
    if (snapshot.platform != 'android' && snapshot.platform != 'ios') return;
    final appVersion = await _appVersionReader();
    final version = appVersion.displayVersion;
    final normalizedUid = uid?.trim() ?? '';
    final context = _normalizedContext(snapshot);
    final contextJson = jsonEncode(SplayTreeMap<String, Object?>.of(context));
    final previous = await _stateStore.read();
    final trigger =
        forcedTrigger ??
        _startupTrigger(
          previous: previous,
          snapshot: snapshot,
          contextJson: contextJson,
          appVersion: version,
        );
    if (trigger == null) return;

    final payload = SplayTreeMap<String, Object?>.of(<String, Object?>{
      'schema_version': deviceInfoSchemaVersion,
      'trigger': trigger,
      ...context,
    });
    final object1 = jsonEncode(payload);
    if (utf8.encode(object1).length > 2048) {
      throw StateError('device_info object1 exceeds Collect 2048-byte limit');
    }
    final enqueued = await _collectLogger(object1);
    if (!enqueued) return;
    await _stateStore.write(
      DeviceInfoTelemetryState(
        deviceId: snapshot.deviceId.trim(),
        contextJson: contextJson,
        appVersion: version,
        uid: normalizedUid,
      ),
    );
  }

  String? _startupTrigger({
    required DeviceInfoTelemetryState? previous,
    required DeviceIdentitySnapshot snapshot,
    required String contextJson,
    required String appVersion,
  }) {
    if (previous == null) return 'first_install';
    if (previous.deviceId != snapshot.deviceId.trim()) {
      return 'device_id_changed';
    }
    if (previous.appVersion != appVersion) return 'app_updated';
    if (_hasIdentityError(snapshot.fields)) return 'identity_error';
    if (previous.contextJson != contextJson) return 'device_context_changed';
    return null;
  }

  Map<String, Object?> _normalizedContext(DeviceIdentitySnapshot snapshot) {
    final allowedFields = snapshot.platform == 'android'
        ? _androidFields
        : _iosFields;
    return <String, Object?>{
      for (final key in allowedFields)
        if (_isTelemetryValue(snapshot.fields[key]) ||
            (snapshot.platform == 'ios' &&
                key == 'keychain_write_status' &&
                snapshot.fields.containsKey(key)))
          key: snapshot.fields[key],
    };
  }

  bool _hasIdentityError(Map<String, Object?> fields) {
    if (fields['device_id_source'] == 'keychain_error') return true;
    final readStatus = fields['keychain_read_status'];
    if (readStatus is num && readStatus != 0 && readStatus != -25300) {
      return true;
    }
    final writeStatus = fields['keychain_write_status'];
    return writeStatus is num && writeStatus != 0;
  }

  bool _isTelemetryValue(Object? value) {
    if (value == null) return false;
    if (value is String) return value.trim().isNotEmpty;
    return value is num || value is bool;
  }

  static Future<bool> _defaultCollectLogger(String object1) {
    return GenesisTelemetry.collectLogAndWait(
      actionType: 'event',
      action: 'device_info',
      object1: object1,
    );
  }

  static const _androidFields = <String>[
    'device_id_source',
    'signing_cert_sha256',
    'android_user_serial',
    'android_user_type',
    'gateway_public_key_hash',
    'manufacturer',
    'model',
    'device',
    'os_build_fingerprint_hash',
  ];

  static const _iosFields = <String>[
    'device_id_source',
    'keychain_read_status',
    'keychain_write_status',
    'bundle_id',
    'app_id_prefix',
    'keychain_access_group_hash',
    'gateway_public_key_hash',
    'idfv_hash',
    'device_model',
    'os_build',
  ];
}
