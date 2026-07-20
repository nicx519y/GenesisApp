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
import 'package:posthog_flutter/posthog_flutter.dart';

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

class _FakePostHogClient implements PostHogTelemetryClient {
  final configs = <PostHogConfig>[];
  final captures = <_PostHogCapture>[];
  final identifies = <_PostHogIdentify>[];
  final exceptions = <_PostHogExceptionCapture>[];
  var resets = 0;

  @override
  Future<void> setup(PostHogConfig config) async {
    configs.add(config);
  }

  @override
  Future<void> capture({
    required String eventName,
    Map<String, Object>? properties,
  }) async {
    captures.add(_PostHogCapture(eventName, properties ?? const {}));
  }

  @override
  Future<void> identify({
    required String userId,
    Map<String, Object>? userProperties,
  }) async {
    identifies.add(_PostHogIdentify(userId, userProperties ?? const {}));
  }

  @override
  Future<void> reset() async {
    resets += 1;
  }

  @override
  Future<void> captureException({
    required Object error,
    StackTrace? stackTrace,
    Map<String, Object>? properties,
  }) async {
    exceptions.add(
      _PostHogExceptionCapture(
        error: error,
        stackTrace: stackTrace,
        properties: properties ?? const {},
      ),
    );
  }
}

class _FakeCollectClient implements CollectTelemetryClient {
  final payloads = <Map<String, Object>>[];
  final headers = <Map<String, String>>[];

  @override
  Future<void> collect(
    Map<String, Object> payload, {
    Map<String, String> headers = const <String, String>{},
  }) async {
    payloads.add(payload);
    this.headers.add(headers);
  }
}

class _PostHogCapture {
  const _PostHogCapture(this.eventName, this.properties);

  final String eventName;
  final Map<String, Object> properties;
}

class _PostHogIdentify {
  const _PostHogIdentify(this.userId, this.userProperties);

  final String userId;
  final Map<String, Object> userProperties;
}

class _PostHogExceptionCapture {
  const _PostHogExceptionCapture({
    required this.error,
    required this.stackTrace,
    required this.properties,
  });

  final Object error;
  final StackTrace? stackTrace;
  final Map<String, Object> properties;
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

  test(
    'default sink sends collectLog body only to collect without PostHog',
    () async {
      final postHog = _FakePostHogClient();
      final collect = _FakeCollectClient();
      final defaultSink = await GenesisTelemetry.buildDefaultSinkForTesting(
        config: const AppConfig(postHogProjectToken: ''),
        postHogClient: postHog,
        collectClient: collect,
      );
      await defaultSink.setContext(GenesisTelemetry.contextForTesting);
      await defaultSink.setUserId(' user-1 ');

      await defaultSink.record(
        GenesisTelemetryEvent(
          name: 'home-my worlds',
          category: 'collect.log',
          data: const {
            'action_type': 'pageview',
            'action': 'home-my worlds',
            'object1': '',
            'device_id': 'must-not-send',
            'uid': 'must-not-send',
            'app_version': 'must-not-send',
            'created_at': 'must-not-send',
          },
          context: GenesisTelemetry.contextForTesting,
        ),
      );

      expect(postHog.configs, isEmpty);
      expect(postHog.captures, isEmpty);
      expect(defaultSink, isA<CollectGenesisTelemetrySink>());
      expect(collect.payloads.single, {
        'action_type': 'pageview',
        'action': 'home-my worlds',
      });
      expect(collect.headers.single['X-Platform'], 'android');
      expect(collect.headers.single['X-Device-ID'], 'device-test-1');
      expect(collect.headers.single['X-App-Version'], '1.2.3');
      expect(collect.headers.single['X-UID'], 'user-1');
    },
  );

  test('PostHog default sink config disables duplicate autocapture', () async {
    final postHog = _FakePostHogClient();
    final defaultSink = await GenesisTelemetry.buildDefaultSinkForTesting(
      config: const AppConfig(
        postHogProjectToken: ' phc_test ',
        postHogHost: 'https://eu.i.posthog.com',
        postHogDebug: true,
        collectEnabled: false,
      ),
      postHogClient: postHog,
    );

    expect(defaultSink, isA<PostHogGenesisTelemetrySink>());
    final config = postHog.configs.single;
    expect(config.projectToken, 'phc_test');
    expect(config.host, 'https://eu.i.posthog.com');
    expect(config.debug, true);
    expect(config.captureApplicationLifecycleEvents, false);
    expect(config.sessionReplay, false);
    expect(config.surveys, false);
  });

  test('collect client posts exact endpoint and accepts 204', () async {
    final transport = _FakeTransport(
      handler: (_) =>
          const TransportResponse(statusCode: 204, headers: {}, body: ''),
    );
    final client = SdkCollectTelemetryClient(
      endpoint: 'https://collect.worldo.ai/api/v1/collect',
      transport: transport,
      timeoutMs: 1234,
    );

    await client.collect(
      const {
        'action_type': 'event',
        'action': 'world_progress_submit_success',
        'object1': 'w_1',
        'object2': 12,
      },
      headers: const {
        'X-Platform': 'ios',
        'X-Device-ID': 'device-1',
        'X-App-Version': '1.2.3',
        'X-UID': 'u_1',
      },
    );

    final request = transport.requests.single;
    expect(request.method, 'POST');
    expect(request.uri.toString(), 'https://collect.worldo.ai/api/v1/collect');
    expect(request.timeoutMs, 1234);
    expect(request.headers['content-type'], 'application/json');
    expect(request.headers['accept'], 'application/json');
    expect(request.headers['X-Platform'], 'ios');
    expect(request.headers['X-Device-ID'], 'device-1');
    expect(request.headers['X-App-Version'], '1.2.3');
    expect(request.headers['X-UID'], 'u_1');
    expect(jsonDecode(utf8.decode(request.bodyBytes!)), {
      'action_type': 'event',
      'action': 'world_progress_submit_success',
      'object1': 'w_1',
      'object2': 12,
    });
  });

  test('collect sink ignores events without a collect payload', () async {
    final collect = _FakeCollectClient();
    final sink = CollectGenesisTelemetrySink(client: collect);

    await sink.record(
      GenesisTelemetryEvent(
        name: 'http_request',
        category: 'network.http',
        data: const {'path': '/api/v1/profile'},
        context: GenesisTelemetry.contextForTesting,
      ),
    );

    expect(collect.payloads, isEmpty);
  });

  test(
    'one billing event is sent to PostHog and identity-header Collect',
    () async {
      final postHog = _FakePostHogClient();
      final collect = _FakeCollectClient();
      final composite = CompositeGenesisTelemetrySink([
        PostHogGenesisTelemetrySink(client: postHog),
        CollectGenesisTelemetrySink(client: collect),
      ]);
      await composite.setContext(GenesisTelemetry.contextForTesting);
      await composite.setUserId('user-1');

      await composite.record(
        GenesisTelemetryEvent(
          name: 'pay_event',
          category: 'billing.purchase',
          data: const {
            'action': 'success',
            'attempt_id': 'attempt-1',
            'product_id': 'gem_pack_500',
            'result': 'completed',
          },
          context: GenesisTelemetry.contextForTesting,
          collectPayload: const {
            'action_type': 'pay_event',
            'action': 'success',
            'object1': 'gem_pack_500',
            'object2': 'attempt-1',
          },
        ),
      );

      expect(postHog.captures.single.eventName, 'pay_event');
      expect(postHog.captures.single.properties['action'], 'success');
      expect(postHog.captures.single.properties['attempt_id'], 'attempt-1');
      expect(collect.payloads.single, {
        'action_type': 'pay_event',
        'action': 'success',
        'object1': 'gem_pack_500',
        'object2': 'attempt-1',
      });
      expect(collect.headers.single['X-Platform'], 'android');
      expect(collect.headers.single['X-App-Version'], '1.2.3');
      expect(collect.headers.single['X-Device-ID'], 'device-test-1');
      expect(collect.headers.single['X-UID'], 'user-1');
    },
  );

  test('GenesisTelemetry.collectLog sends pageview payload', () async {
    final collect = _FakeCollectClient();
    GenesisTelemetry.setSinkForTesting(
      CollectGenesisTelemetrySink(client: collect),
    );
    await GenesisTelemetry.initialize(
      config: const AppConfig(apiEnvironment: 'test'),
      deviceIdService: const _TestDeviceIdService(),
      appVersion: const AppVersionInfo(
        versionName: '1.2.3',
        versionCode: '45',
        packageName: 'com.worldo.ai',
      ),
    );
    GenesisTelemetry.setUserId('u_1');
    await Future<void>.delayed(Duration.zero);

    GenesisTelemetry.collectLog(
      actionType: 'pageview',
      action: 'world_detail',
      object1: 'w_1',
    );
    await Future<void>.delayed(Duration.zero);

    expect(collect.payloads.single, {
      'action_type': 'pageview',
      'action': 'world_detail',
      'object1': 'w_1',
    });
    expect(collect.payloads.single.keys, isNot(contains('device_id')));
    expect(collect.payloads.single.keys, isNot(contains('uid')));
    expect(collect.payloads.single.keys, isNot(contains('app_version')));
    expect(collect.payloads.single.keys, isNot(contains('created_at')));
    expect(collect.headers.single['X-UID'], 'u_1');
  });

  test('PostHog sink captures events and maps user identity', () async {
    final postHog = _FakePostHogClient();
    final postHogSink = PostHogGenesisTelemetrySink(client: postHog);
    await postHogSink.setContext(GenesisTelemetry.contextForTesting);

    await postHogSink.record(
      GenesisTelemetryEvent(
        name: 'ui_click',
        category: 'ui.click',
        data: const {
          'action_id': 'button.primary.submit',
          'component': 'GenesisPrimaryButton',
          'enabled': true,
          'ignored_empty': '',
        },
        context: GenesisTelemetry.contextForTesting,
      ),
    );
    await postHogSink.setUserId(' user-1 ');
    await postHogSink.setUserId(null);

    final capture = postHog.captures.single;
    expect(capture.eventName, 'ui_click');
    expect(capture.properties['action_id'], 'button.primary.submit');
    expect(capture.properties['component'], 'GenesisPrimaryButton');
    expect(capture.properties['enabled'], true);
    expect(capture.properties['category'], 'ui.click');
    expect(capture.properties['level'], 'info');
    expect(capture.properties['ignored_empty'], isNull);
    expect(postHog.identifies.single.userId, 'user-1');
    expect(postHog.identifies.single.userProperties['app_version'], '1.2.3');
    expect(postHog.resets, 1);
  });

  test('PostHog http telemetry omits query, body, and token values', () async {
    final postHog = _FakePostHogClient();
    GenesisTelemetry.setSinkForTesting(
      PostHogGenesisTelemetrySink(client: postHog),
    );
    await GenesisTelemetry.initialize(
      config: const AppConfig(apiEnvironment: 'test'),
      deviceIdService: const _TestDeviceIdService(),
      appVersion: const AppVersionInfo(
        versionName: '1.2.3',
        versionCode: '45',
        packageName: 'com.worldo.ai',
      ),
    );
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

    final capture = postHog.captures
        .where((event) => event.eventName == 'http_request')
        .single;
    expect(capture.properties['path'], '/api/v1/profile');
    expect(capture.properties['host'], 'example.test');
    expect(capture.properties['status_code'], 200);
    expect(
      capture.properties.values.join(' '),
      isNot(contains('secret-token')),
    );
    expect(capture.properties.keys, isNot(contains('body')));
  });

  test('PostHog sink captures exceptions with app context', () async {
    final postHog = _FakePostHogClient();
    final postHogSink = PostHogGenesisTelemetrySink(client: postHog);
    await postHogSink.setContext(GenesisTelemetry.contextForTesting);
    final error = StateError('boom');
    final stackTrace = StackTrace.current;

    await postHogSink.captureException(error, stackTrace);

    final capture = postHog.exceptions.single;
    expect(capture.error, same(error));
    expect(capture.stackTrace, same(stackTrace));
    expect(capture.properties['error_type'], 'StateError');
    expect(capture.properties['handled'], true);
    expect(capture.properties['device_id'], 'device-test-1');
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
