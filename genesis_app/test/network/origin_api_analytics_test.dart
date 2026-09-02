import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/telemetry/firebase_analytics_monitoring.dart';
import 'package:genesis_flutter_android/network/api_client.dart';
import 'package:genesis_flutter_android/network/api_exception.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';
import 'package:genesis_flutter_android/network/v1/origin_api.dart';

void main() {
  late _RecordingAnalyticsClient analytics;

  setUp(() {
    FirebaseAnalyticsMonitoring.resetForTesting();
    analytics = _RecordingAnalyticsClient();
    FirebaseAnalyticsMonitoring.setEnabledForTesting(true);
    FirebaseAnalyticsMonitoring.setReadinessForTesting(Future<void>.value());
    FirebaseAnalyticsMonitoring.setClientForTesting(analytics);
    FirebaseAnalyticsMonitoring.setOnceEventStoreForTesting(
      _MemoryOnceEventStore(),
    );
    FirebaseAnalyticsMonitoring.setDeviceIdReaderForTesting(
      () async => 'test-device-id',
    );
  });

  tearDown(FirebaseAnalyticsMonitoring.resetForTesting);

  test('preset launch records launch and explicit successful world', () async {
    final transport = _FakeTransport(
      (_) => _jsonResponse({
        'err_no': 0,
        'err_msg': 'succ',
        'data': {'world_id': '  world_1  '},
      }),
    );
    final api = _originApi(transport);

    final result = await api.launch(
      originId: '  origin_1  ',
      presetCharacterId: 'character_1',
    );
    await _flushAnalytics();

    expect(result['world_id'], '  world_1  ');
    expect(transport.requests, hasLength(1));
    expect(transport.requests.single.method, 'POST');
    expect(transport.requests.single.uri.path, '/api/v1/origin/launch');
    expect(_requestBody(transport.requests.single), {
      'origin_id': 'origin_1',
      'preset_character_id': 'character_1',
    });
    expect(analytics.events, [
      const _RecordedEvent('launch', {
        'origin_id': 'origin_1',
        'role_type': 'preset',
        'device_id': 'test-device-id',
      }),
      const _RecordedEvent('launch_first', {
        'origin_id': 'origin_1',
        'role_type': 'preset',
        'device_id': 'test-device-id',
      }),
      const _RecordedEvent('launch_success', {
        'origin_id': 'origin_1',
        'role_type': 'preset',
        'world_id': 'world_1',
        'device_id': 'test-device-id',
      }),
      const _RecordedEvent('launch_success_first', {
        'origin_id': 'origin_1',
        'role_type': 'preset',
        'world_id': 'world_1',
        'device_id': 'test-device-id',
      }),
    ]);
  });

  test('edited preset launch sends override without custom role', () async {
    final transport = _FakeTransport(
      (_) => _jsonResponse({
        'err_no': 0,
        'err_msg': 'succ',
        'data': {'world_id': 'world_edited_preset'},
      }),
    );
    final api = _originApi(transport);

    await api.launch(
      originId: 'origin_1',
      presetCharacterId: 'character_1',
      presetRoleOverride: {
        'avatar': 'avatar-edited',
        'name': 'Edited Hero',
        'identity': 'Edited Guide',
        'brief': 'Edited personality',
      },
    );
    await _flushAnalytics();

    final body = _requestBody(transport.requests.single);
    expect(body['preset_character_id'], 'character_1');
    expect(body.containsKey('custom_role'), isFalse);
    expect(body['preset_role_override'], {
      'avatar': 'avatar-edited',
      'name': 'Edited Hero',
      'identity': 'Edited Guide',
      'brief': 'Edited personality',
    });
  });

  test('custom launch accepts camel envelope and wid', () async {
    final transport = _FakeTransport(
      (_) => _jsonResponse({
        'errNo': '0',
        'errStr': 'success',
        'data': {'wid': 'world_custom'},
      }),
    );
    final api = _originApi(transport);

    await api.launch(
      originId: 'origin_custom',
      customRole: {'name': 'Traveler'},
    );
    await _flushAnalytics();

    expect(_requestBody(transport.requests.single), {
      'origin_id': 'origin_custom',
      'custom_role': {'name': 'Traveler'},
    });
    expect(analytics.events, [
      const _RecordedEvent('launch', {
        'origin_id': 'origin_custom',
        'role_type': 'custom',
        'device_id': 'test-device-id',
      }),
      const _RecordedEvent('launch_first', {
        'origin_id': 'origin_custom',
        'role_type': 'custom',
        'device_id': 'test-device-id',
      }),
      const _RecordedEvent('launch_success', {
        'origin_id': 'origin_custom',
        'role_type': 'custom',
        'world_id': 'world_custom',
        'device_id': 'test-device-id',
      }),
      const _RecordedEvent('launch_success_first', {
        'origin_id': 'origin_custom',
        'role_type': 'custom',
        'world_id': 'world_custom',
        'device_id': 'test-device-id',
      }),
    ]);
  });

  test('business error records the launch attempt only', () async {
    final transport = _FakeTransport(
      (_) => _jsonResponse({
        'err_no': 1001,
        'err_msg': 'launch failed',
        'data': <String, Object?>{},
      }),
    );
    final api = _originApi(transport);

    await expectLater(
      api.launch(originId: 'origin_1', presetCharacterId: 'character_1'),
      throwsA(
        isA<ApiException>()
            .having((error) => error.kind, 'kind', ApiExceptionKind.business)
            .having((error) => error.code, 'code', 1001),
      ),
    );
    await _flushAnalytics();

    expect(analytics.events, [
      const _RecordedEvent('launch', {
        'origin_id': 'origin_1',
        'role_type': 'preset',
        'device_id': 'test-device-id',
      }),
      const _RecordedEvent('launch_first', {
        'origin_id': 'origin_1',
        'role_type': 'preset',
        'device_id': 'test-device-id',
      }),
    ]);
  });

  test('empty world id does not record launch success', () async {
    final transport = _FakeTransport(
      (_) => _jsonResponse({
        'err_no': 0,
        'err_msg': 'succ',
        'data': {'world_id': '   '},
      }),
    );
    final api = _originApi(transport);

    await api.launch(originId: 'origin_1', presetCharacterId: 'character_1');
    await _flushAnalytics();

    expect(analytics.events, [
      const _RecordedEvent('launch', {
        'origin_id': 'origin_1',
        'role_type': 'preset',
        'device_id': 'test-device-id',
      }),
      const _RecordedEvent('launch_first', {
        'origin_id': 'origin_1',
        'role_type': 'preset',
        'device_id': 'test-device-id',
      }),
    ]);
  });

  test('missing err_no preserves response but is not launch success', () async {
    final transport = _FakeTransport(
      (_) => _jsonResponse({
        'data': {'world_id': 'world_legacy'},
      }),
    );
    final api = _originApi(transport);

    final result = await api.launch(
      originId: 'origin_1',
      presetCharacterId: 'character_1',
    );
    await _flushAnalytics();

    expect(result, {
      'data': {'world_id': 'world_legacy'},
    });
    expect(analytics.events, [
      const _RecordedEvent('launch', {
        'origin_id': 'origin_1',
        'role_type': 'preset',
        'device_id': 'test-device-id',
      }),
      const _RecordedEvent('launch_first', {
        'origin_id': 'origin_1',
        'role_type': 'preset',
        'device_id': 'test-device-id',
      }),
    ]);
  });

  test('invalid launch arguments send no request or analytics event', () async {
    final transport = _FakeTransport((_) => _jsonResponse(<String, Object?>{}));
    final api = _originApi(transport);

    expect(
      () => api.launch(originId: ' ', presetCharacterId: 'character_1'),
      throwsArgumentError,
    );
    expect(() => api.launch(originId: 'origin_1'), throwsArgumentError);
    expect(
      () => api.launch(
        originId: 'origin_1',
        presetCharacterId: 'character_1',
        customRole: {'name': 'Traveler'},
      ),
      throwsArgumentError,
    );
    expect(
      () => api.launch(
        originId: 'origin_1',
        customRole: {'name': 'Traveler'},
        presetRoleOverride: {'name': 'Hero', 'identity': 'Guide'},
      ),
      throwsArgumentError,
    );
    expect(
      () => api.launch(
        originId: 'origin_1',
        presetCharacterId: 'character_1',
        presetRoleOverride: {'name': 'Hero'},
      ),
      throwsArgumentError,
    );
    await _flushAnalytics();

    expect(transport.requests, isEmpty);
    expect(analytics.events, isEmpty);
  });

  test('gateway physical resend remains one logical launch event', () async {
    final transport = _FakeTransport(
      (_) => _jsonResponse({
        'err_no': 0,
        'data': {'world_id': 'world_1'},
      }),
    );
    final api = _originApi(
      transport,
      requestInterceptor: (request, send) async {
        await send(request);
        return send(request);
      },
    );

    await api.launch(originId: 'origin_1', presetCharacterId: 'character_1');
    await _flushAnalytics();

    expect(transport.requests, hasLength(2));
    expect(
      analytics.events.where((event) => event.name == 'launch'),
      hasLength(1),
    );
    expect(
      analytics.events.where((event) => event.name == 'launch_first'),
      hasLength(1),
    );
    expect(
      analytics.events.where((event) => event.name == 'launch_success'),
      hasLength(1),
    );
    expect(
      analytics.events.where((event) => event.name == 'launch_success_first'),
      hasLength(1),
    );
  });
}

OriginV1Api _originApi(
  HttpTransport transport, {
  ApiRequestInterceptor? requestInterceptor,
}) {
  return OriginV1Api(
    ApiClient(
      baseUrl: 'https://example.com/api/',
      defaultHeaders: const <String, String>{
        'accept': 'application/json',
        'content-type': 'application/json',
      },
      transport: transport,
      requestInterceptor: requestInterceptor,
    ),
  );
}

Map<String, Object?> _requestBody(TransportRequest request) {
  return (jsonDecode(utf8.decode(request.bodyBytes!)) as Map).map(
    (key, value) => MapEntry(key.toString(), value),
  );
}

TransportResponse _jsonResponse(Map<String, Object?> body) {
  return TransportResponse(
    statusCode: 200,
    headers: const {'content-type': 'application/json'},
    body: jsonEncode(body),
  );
}

Future<void> _flushAnalytics() => Future<void>.delayed(Duration.zero);

class _FakeTransport implements HttpTransport {
  _FakeTransport(this.handler);

  final FutureOr<TransportResponse> Function(TransportRequest request) handler;
  final List<TransportRequest> requests = <TransportRequest>[];

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    requests.add(request);
    return handler(request);
  }
}

class _RecordingAnalyticsClient implements AppAnalyticsClient {
  final List<_RecordedEvent> events = <_RecordedEvent>[];

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    events.add(_RecordedEvent(name, Map<String, Object>.of(parameters ?? {})));
  }
}

class _MemoryOnceEventStore implements FirebaseAnalyticsOnceEventStore {
  final Set<String> sentEvents = <String>{};

  @override
  Future<void> markSent(String eventName) async {
    sentEvents.add(eventName);
  }

  @override
  Future<bool> wasSent(String eventName) async {
    return sentEvents.contains(eventName);
  }
}

class _RecordedEvent {
  const _RecordedEvent(this.name, this.parameters);

  final String name;
  final Map<String, Object> parameters;

  @override
  bool operator ==(Object other) {
    return other is _RecordedEvent &&
        other.name == name &&
        _mapsEqual(other.parameters, parameters);
  }

  @override
  int get hashCode =>
      Object.hash(name, Object.hashAllUnordered(parameters.entries));

  @override
  String toString() => '_RecordedEvent($name, $parameters)';
}

bool _mapsEqual(Map<String, Object> left, Map<String, Object> right) {
  if (left.length != right.length) return false;
  for (final entry in left.entries) {
    if (right[entry.key] != entry.value) return false;
  }
  return true;
}
