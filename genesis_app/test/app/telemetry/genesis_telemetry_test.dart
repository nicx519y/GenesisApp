import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/config/app_config.dart';
import 'package:genesis_flutter_android/app/telemetry/genesis_telemetry.dart';
import 'package:genesis_flutter_android/network/api_client.dart';
import 'package:genesis_flutter_android/network/app_request_headers.dart';
import 'package:genesis_flutter_android/network/gateway_auth.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';
import 'package:genesis_flutter_android/platform/app/app_metadata_service.dart';
import 'package:genesis_flutter_android/platform/device/device_id_service.dart';

class _FakeTelemetrySink implements GenesisTelemetrySink {
  final events = <GenesisTelemetryEvent>[];
  final contexts = <GenesisTelemetryContext>[];
  final userIds = <String?>[];

  @override
  Future<void> captureException(Object error, StackTrace stackTrace) async {}

  @override
  Future<void> record(GenesisTelemetryEvent event) async {
    events.add(event);
  }

  @override
  Future<void> setContext(GenesisTelemetryContext context) async {
    contexts.add(context);
  }

  @override
  Future<void> setUserId(String? uid) async {
    userIds.add(uid);
  }
}

class _TestDeviceIdService implements DeviceIdService {
  const _TestDeviceIdService();

  @override
  Future<String> getDeviceId() async => 'device-test-1';
}

class _FakeTransport implements HttpTransport {
  _FakeTransport({required this.handler});

  final FutureOr<TransportResponse> Function(TransportRequest request) handler;
  final requests = <TransportRequest>[];

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    requests.add(request);
    return handler(request);
  }
}

class _FakeKeyStore implements GatewayDeviceKeyStore {
  @override
  Future<String> publicKeyBase64Url() async => 'AQID';

  @override
  Future<void> reset() async {}

  @override
  Future<String> signCanonical(String canonical) async => 'fake-signature';
}

class _MemoryGatewayRegistrationStore implements GatewayRegistrationStore {
  String? keyId;

  @override
  Future<void> clearKeyId() async {
    keyId = null;
  }

  @override
  Future<String?> readKeyId() async => keyId;

  @override
  Future<void> saveKeyId(String keyId) async {
    this.keyId = keyId;
  }
}

void main() {
  late _FakeTelemetrySink sink;

  setUp(() async {
    sink = _FakeTelemetrySink();
    GenesisTelemetry.setSinkForTesting(sink);
    await GenesisTelemetry.initialize(
      config: const AppConfig(apiEnvironment: 'test'),
      deviceIdService: const _TestDeviceIdService(),
      appVersion: const AppVersionInfo(
        versionName: '1.2.3',
        versionCode: '45',
        packageName: 'com.worldo.ai',
      ),
    );
  });

  tearDown(GenesisTelemetry.resetForTesting);

  test(
    'initialize disables event capture when tracking is not authorized',
    () async {
      await GenesisTelemetry.initialize(
        config: const AppConfig(apiEnvironment: 'test'),
        deviceIdService: const _TestDeviceIdService(),
        appVersion: const AppVersionInfo(
          versionName: '1.2.3',
          versionCode: '45',
          packageName: 'com.worldo.ai',
        ),
        trackingEnabled: false,
      );

      GenesisTelemetry.pageView(
        routeName: '/home',
        pageClassName: 'AppShellPage',
        navigationType: 'push',
      );
      await Future<void>.delayed(Duration.zero);

      expect(sink.events, isEmpty);
      expect(sink.contexts.last.deviceId, 'device-test-1');
    },
  );

  test('page and click telemetry carries app version and device id', () async {
    GenesisTelemetry.pageView(
      routeName: '/home',
      pageClassName: 'AppShellPage',
      navigationType: 'push',
    );
    GenesisTelemetry.click(
      actionId: 'button.primary.submit',
      component: 'GenesisPrimaryButton',
      enabled: true,
    );
    await Future<void>.delayed(Duration.zero);

    expect(sink.contexts.single.appVersion, '1.2.3');
    expect(sink.contexts.single.appBuild, '45');
    expect(sink.contexts.single.deviceId, 'device-test-1');
    expect(
      sink.events
          .where((event) => event.name == 'page_view')
          .single
          .fullData['app_version'],
      '1.2.3',
    );
    expect(
      sink.events
          .where((event) => event.name == 'ui_click')
          .single
          .fullData['device_id'],
      'device-test-1',
    );
  });

  test('http telemetry keeps path sanitized and omits query/body', () async {
    final client = ApiClient(
      baseUrl: 'https://example.test/api/',
      transport: _FakeTransport(
        handler: (_) => const TransportResponse(
          statusCode: 200,
          headers: {'content-type': 'application/json'},
          body: '{"ok":true}',
        ),
      ),
    );

    await client.get<Object?>(
      'v1/profile',
      query: const {'token': 'secret-token', 'uid': 'u_1'},
    );
    await Future<void>.delayed(Duration.zero);

    final event = sink.events
        .where((event) => event.name == 'http_request')
        .single;
    expect(event.fullData['path'], '/api/v1/profile');
    expect(event.fullData['host'], 'example.test');
    expect(event.fullData['status_code'], 200);
    expect(event.fullData['app_version'], '1.2.3');
    expect(event.fullData['device_id'], 'device-test-1');
    expect(event.fullData.values.join(' '), isNot(contains('secret-token')));
    expect(event.fullData.keys, isNot(contains('body')));
  });

  test('gateway retry telemetry records reason with app context', () async {
    final authTransport = _FakeTransport(handler: _gatewayAuthResponse);
    final coordinator = GatewayAuthCoordinator(
      gatewayBaseUrl: 'https://gateway.test/apix/',
      appHeaderProvider: () async => const <String, String>{},
      identityProvider: () async => const AppRequestIdentity(
        appId: 'app-hash',
        platform: 'android',
        appVersion: '1.2.3',
      ),
      deviceIdService: const _TestDeviceIdService(),
      keyStore: _FakeKeyStore(),
      registrationStore: _MemoryGatewayRegistrationStore(),
      transport: authTransport,
    );
    final interceptor = GatewayRequestInterceptor(coordinator: coordinator);
    var attempts = 0;

    await interceptor.call(
      TransportRequest(
        method: 'GET',
        uri: Uri.parse('https://gateway.test/api/v1/protected'),
        headers: const {},
        bodyBytes: null,
        timeoutMs: 15000,
      ),
      (_) async {
        attempts += 1;
        if (attempts == 1) {
          return _json({'err_no': 20502, 'err_msg': 'bad time', 'data': {}});
        }
        return _json({'err_no': 0, 'err_msg': 'succ', 'data': {}});
      },
    );
    await Future<void>.delayed(Duration.zero);

    final retry = sink.events
        .where((event) => event.name == 'gateway.request.retry')
        .single;
    expect(retry.fullData['reason'], 'time_20502');
    expect(retry.fullData['app_version'], '1.2.3');
    expect(retry.fullData['device_id'], 'device-test-1');
  });
}

TransportResponse _gatewayAuthResponse(TransportRequest request) {
  switch (request.uri.path) {
    case '/apix/v1/time':
      return _json({
        'err_no': 0,
        'err_msg': 'succ',
        'data': {'server_time_ms': DateTime.now().millisecondsSinceEpoch},
      });
    case '/apix/v1/app/device/challenge':
      return _json({
        'err_no': 0,
        'err_msg': 'succ',
        'data': {'register_id': 'reg-1'},
      });
    case '/apix/v1/app/device/register':
      return _json({
        'err_no': 0,
        'err_msg': 'succ',
        'data': {'key_id': 'key-registered'},
      });
  }
  return _json({'err_no': 404, 'err_msg': 'unexpected', 'data': {}});
}

TransportResponse _json(Map<String, Object?> body) {
  return TransportResponse(
    statusCode: 200,
    headers: const {'content-type': 'application/json'},
    body: jsonEncode(body),
  );
}
