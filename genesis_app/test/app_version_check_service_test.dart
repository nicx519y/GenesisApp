import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/config/app_config.dart';
import 'package:genesis_flutter_android/app/version/app_version_check_service.dart';
import 'package:genesis_flutter_android/network/genesis_api.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';
import 'package:genesis_flutter_android/platform/app/app_metadata_service.dart';
import 'package:genesis_flutter_android/platform/device/device_id_service.dart';
import 'package:genesis_flutter_android/platform/session/memory_user_session_store.dart';

void main() {
  test('builds documented version check request context', () async {
    final transport = _RecordingTransport(
      responseBody:
          '{"err_no":0,"err_msg":"succ","data":{"need_upgrade":true,"force_upgrade":true,"latest_version_name":"1.1.0","latest_version_code":10100,"min_version_code":10000,"upgrade_type":2,"title":"发现新版本","content":"请升级","download_url":"https://example.com/app.apk","store_url":"","package_size":0,"package_md5":"","can_ignore":false}}',
    );
    final sessionStore = MemoryUserSessionStore();
    await sessionStore.saveUid('u_4LA63V');
    final service = GenesisAppVersionCheckService(
      config: const AppConfig(appId: 'aitown', appChannel: 'appstore'),
      api: GenesisApi(
        transport: transport,
        useMock: false,
        deviceIdService: const _DeviceIdService('device_xxx'),
        sessionStore: sessionStore,
        appHeaderProvider: () async => const <String, String>{},
      ),
      deviceIdService: const _DeviceIdService('device_xxx'),
      sessionStore: sessionStore,
      appVersionLoader: () async => const AppVersionInfo(
        versionName: '1.0.0',
        versionCode: '10000',
        packageName: 'com.worldo.ai',
      ),
      platformResolver: () => 'ios',
    );

    final result = await service.check();

    expect(result.isForceUpgrade, true);
    expect(transport.requests.single.uri.path, '/api/v1/app/version/check');
    expect(jsonDecode(utf8.decode(transport.requests.single.bodyBytes!)), {
      'app_id': 'aitown',
      'platform': 'ios',
      'channel': 'appstore',
      'version_name': '1.0.0',
      'version_code': 10000,
      'device_id': 'device_xxx',
      'uid': 'u_4LA63V',
    });
  });

  test('skips check when version code is unavailable', () async {
    final transport = _RecordingTransport();
    final sessionStore = MemoryUserSessionStore();
    final service = GenesisAppVersionCheckService(
      config: const AppConfig(),
      api: GenesisApi(
        transport: transport,
        useMock: false,
        deviceIdService: const _DeviceIdService('device_xxx'),
        sessionStore: sessionStore,
        appHeaderProvider: () async => const <String, String>{},
      ),
      deviceIdService: const _DeviceIdService('device_xxx'),
      sessionStore: sessionStore,
      appVersionLoader: () async => const AppVersionInfo(versionName: '1.0.0'),
      platformResolver: () => 'android',
    );

    final result = await service.check();

    expect(result.skipped, true);
    expect(result.isForceUpgrade, false);
    expect(transport.requests, isEmpty);
  });

  test('returns failed non-force result when API fails', () async {
    final transport = _RecordingTransport(error: StateError('offline'));
    final sessionStore = MemoryUserSessionStore();
    final service = GenesisAppVersionCheckService(
      config: const AppConfig(),
      api: GenesisApi(
        transport: transport,
        useMock: false,
        deviceIdService: const _DeviceIdService('device_xxx'),
        sessionStore: sessionStore,
        appHeaderProvider: () async => const <String, String>{},
      ),
      deviceIdService: const _DeviceIdService('device_xxx'),
      sessionStore: sessionStore,
      appVersionLoader: () async =>
          const AppVersionInfo(versionName: '1.0.0', versionCode: '10000'),
      platformResolver: () => 'android',
    );

    final result = await service.check();

    expect(result.failed, true);
    expect(result.isForceUpgrade, false);
  });
}

class _RecordingTransport implements HttpTransport {
  _RecordingTransport({
    this.responseBody =
        '{"err_no":0,"err_msg":"succ","data":{"need_upgrade":false,"force_upgrade":false,"latest_version_name":"","latest_version_code":0,"min_version_code":0,"upgrade_type":0,"title":"","content":"","download_url":"","store_url":"","package_size":0,"package_md5":"","can_ignore":true}}',
    this.error,
  });

  final String responseBody;
  final Object? error;
  final requests = <TransportRequest>[];

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    requests.add(request);
    final error = this.error;
    if (error != null) throw error;
    return TransportResponse(
      statusCode: 200,
      headers: const {'content-type': 'application/json'},
      body: responseBody,
    );
  }
}

class _DeviceIdService implements DeviceIdService {
  const _DeviceIdService(this.deviceId);

  final String deviceId;

  @override
  Future<String> getDeviceId() async => deviceId;
}
