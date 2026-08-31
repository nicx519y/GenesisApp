import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/telemetry/genesis_telemetry.dart';
import 'package:genesis_flutter_android/network/api_client.dart';
import 'package:genesis_flutter_android/network/api_exception.dart';
import 'package:genesis_flutter_android/network/api_request_trace_sampling.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';

class _FakeTransport implements HttpTransport {
  _FakeTransport({required this.handler});

  final FutureOr<TransportResponse> Function(TransportRequest request) handler;

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    return handler(request);
  }
}

Map<String, Object?> _extData(CollectEvent event) {
  return Map<String, Object?>.from(jsonDecode(event.extData) as Map);
}

void main() {
  late MemoryCollectEventStore store;
  late CollectTelemetryUploader uploader;

  setUp(() {
    GenesisTelemetry.resetForTesting();
    ApiRequestTraceSampling.resetForTesting();
    ApiRequestTraceSampling.configureForLaunch(1, randomValue: 0);
    store = MemoryCollectEventStore();
    var nextEventId = 1;
    uploader = CollectTelemetryUploader(
      store: store,
      idGenerator: () => 'collect-event-${nextEventId++}',
    )..configure(enabled: true);
    GenesisTelemetry.setCollectUploaderForTesting(uploader);
  });

  tearDown(() async {
    await uploader.waitForPendingWrites();
    ApiRequestTraceSampling.resetForTesting();
    GenesisTelemetry.resetForTesting();
  });

  Future<List<CollectEvent>> events() async {
    await uploader.waitForPendingWrites();
    return store.eventsForTesting;
  }

  test('successful business request emits start and success', () async {
    final client = ApiClient(
      baseUrl: 'https://example.test/api/',
      transport: _FakeTransport(
        handler: (_) => const TransportResponse(
          statusCode: 200,
          headers: {'content-type': 'application/json'},
          body: '{"err_no":0,"data":{"ok":true}}',
        ),
      ),
    );

    await client.get<Object?>(
      'v1/world/list',
      query: const {'token': 'secret', 'page': 2},
    );

    final recorded = await events();
    expect(recorded.map((event) => event.action), <String>[
      'api_request_start',
      'api_request_success',
    ]);
    expect(recorded.map((event) => event.object1).toSet(), {
      '/api/v1/world/list',
    });
    expect(recorded.first.object2, isNotEmpty);
    expect(recorded.last.object2, recorded.first.object2);
    expect(recorded.first.object3, isEmpty);
    expect(recorded.first.object4, '0');
    expect(recorded.last.object3, isEmpty);
    expect(int.tryParse(recorded.last.object4), isNotNull);
  });

  test(
    'automatic retry followed by success emits one terminal event',
    () async {
      var attempts = 0;
      final client = ApiClient(
        baseUrl: 'https://example.test/api/',
        retryPolicy: ApiRetryPolicy.safe,
        transport: _FakeTransport(
          handler: (_) async {
            attempts += 1;
            if (attempts == 1) {
              await Future<void>.delayed(const Duration(milliseconds: 300));
              throw TimeoutException('slow');
            }
            await Future<void>.delayed(const Duration(milliseconds: 20));
            return const TransportResponse(
              statusCode: 200,
              headers: {'content-type': 'application/json'},
              body: '{"err_no":0,"data":{}}',
            );
          },
        ),
      );

      await client.get<Object?>('v1/profile');

      expect(attempts, 2);
      final recorded = await events();
      expect(recorded.map((event) => event.action), <String>[
        'api_request_start',
        'api_request_success',
      ]);
      expect(recorded.last.object2, recorded.first.object2);
      expect(int.parse(recorded.last.object4), lessThan(200));
    },
  );

  test(
    'a page-level retry records each logical request independently',
    () async {
      var shouldFail = true;
      final client = ApiClient(
        baseUrl: 'https://example.test/api/',
        transport: _FakeTransport(
          handler: (_) {
            if (shouldFail) throw Exception('connection reset');
            return const TransportResponse(
              statusCode: 200,
              headers: {'content-type': 'application/json'},
              body: '{"err_no":0,"data":{}}',
            );
          },
        ),
      );

      await expectLater(
        client.get<Object?>('v1/profile'),
        throwsA(isA<ApiException>()),
      );
      shouldFail = false;
      await client.get<Object?>('v1/profile');

      final recorded = await events();
      expect(recorded.map((event) => event.action), <String>[
        'api_request_start',
        'api_request_failed',
        'api_request_start',
        'api_request_success',
      ]);
      final failure = recorded[1];
      expect(failure.actionType, 'monitor');
      expect(failure.object2, recorded.first.object2);
      expect(failure.object3, isEmpty);
      expect(int.tryParse(failure.object4), isNotNull);
      expect(_extData(failure)['failure_reason'], 'connection');
    },
  );

  test('exhausted automatic retry reports one timeout failure', () async {
    var attempts = 0;
    final client = ApiClient(
      baseUrl: 'https://example.test/api/',
      retryPolicy: ApiRetryPolicy.safe,
      transport: _FakeTransport(
        handler: (_) {
          attempts += 1;
          throw TimeoutException('slow');
        },
      ),
    );

    await expectLater(
      client.get<Object?>('v1/profile'),
      throwsA(isA<ApiException>()),
    );

    final recorded = await events();
    expect(attempts, 2);
    expect(recorded.map((event) => event.action), <String>[
      'api_request_start',
      'api_request_failed',
    ]);
    expect(recorded.last.object2, recorded.first.object2);
    expect(recorded.last.object3, isEmpty);
    expect(int.tryParse(recorded.last.object4), isNotNull);
    expect(_extData(recorded.last)['failure_reason'], 'timeout');
  });

  test('HTTP and business failures use queryable scalar reasons', () async {
    var response = const TransportResponse(
      statusCode: 500,
      headers: {'content-type': 'application/json'},
      body: '{"message":"server error"}',
    );
    final client = ApiClient(
      baseUrl: 'https://example.test/api/',
      transport: _FakeTransport(handler: (_) => response),
    );

    await expectLater(
      client.get<Object?>('v1/world/detail'),
      throwsA(isA<ApiException>()),
    );
    response = const TransportResponse(
      statusCode: 200,
      headers: {'content-type': 'application/json'},
      body: '{"err_no":1001,"err_msg":"denied","data":{}}',
    );
    await client.get<Object?>('v1/world/detail');

    final recorded = await events();
    final failures = recorded
        .where((event) => event.action == 'api_request_failed')
        .toList();
    expect(failures.map((event) => event.object3), <String>['500', '200']);
    expect(failures.every((event) => event.object2.isNotEmpty), isTrue);
    expect(failures.map((event) => event.object2).toSet(), hasLength(2));
    expect(_extData(failures[0]), <String, Object?>{
      'error_type': 'http_status',
      'failure_reason': 'http_500',
      'method': 'GET',
      'attempt_count': 1,
      'status_code': 500,
      'error_message': 'server error',
    });
    expect(_extData(failures[1]), <String, Object?>{
      'error_type': 'business',
      'failure_reason': 'business_1001',
      'method': 'GET',
      'attempt_count': 1,
      'error_code': 1001,
      'status_code': 200,
      'error_message': 'denied',
    });
    expect(
      recorded.where((event) => event.action == 'api_request_success'),
      isEmpty,
    );
  });

  test(
    'malformed JSON and response processing failures stay distinct',
    () async {
      var response = const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{invalid',
      );
      final client = ApiClient(
        baseUrl: 'https://example.test/api/',
        transport: _FakeTransport(handler: (_) => response),
      );

      await client.get<Object?>('v1/world/list');
      response = const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"err_no":0,"data":{}}',
      );
      await expectLater(
        client.get<Object?>(
          'v1/world/list',
          responseProcessor: (_) => throw StateError('mapping failed'),
        ),
        throwsStateError,
      );

      final failures = (await events())
          .where((event) => event.action == 'api_request_failed')
          .toList();
      expect(failures.map((event) => _extData(event)['failure_reason']), [
        'decode',
        'response',
      ]);
      expect(failures.map((event) => event.object3), <String>['200', '200']);
      expect(_extData(failures[0])['error_type'], 'response_decode');
      expect(
        _extData(failures[0])['error_message'],
        'Response body is not valid JSON.',
      );
      expect(_extData(failures[1])['exception_type'], 'StateError');
      expect(
        _extData(failures[1])['error_message'],
        contains('mapping failed'),
      );
    },
  );

  test('gateway auth and cancellation use their dedicated reasons', () async {
    final authClient = ApiClient(
      baseUrl: 'https://example.test/api/',
      requestHeaderProvider: () async => throw ApiException(
        message: 'auth unavailable',
        kind: ApiExceptionKind.gatewayAuth,
      ),
      transport: _FakeTransport(
        handler: (_) => throw StateError('transport must not run'),
      ),
    );
    await expectLater(
      authClient.get<Object?>('v1/profile'),
      throwsA(isA<ApiException>()),
    );

    final token = NetworkCancellationToken()..cancel();
    final cancelledClient = ApiClient(
      baseUrl: 'https://example.test/api/',
      transport: _FakeTransport(
        handler: (request) {
          request.cancellationToken?.throwIfCancelled();
          throw StateError('unreachable');
        },
      ),
    );
    await expectLater(
      cancelledClient.get<Object?>('v1/profile', cancellationToken: token),
      throwsA(isA<NetworkRequestCancelledException>()),
    );

    final failures = (await events())
        .where((event) => event.action == 'api_request_failed')
        .toList();
    expect(failures.map((event) => _extData(event)['failure_reason']), [
      'gateway_auth',
      'cancelled',
    ]);
    expect(failures.every((event) => event.object3.isEmpty), isTrue);
  });

  test('request preparation failures report the failing stage', () async {
    final headersClient = ApiClient(
      baseUrl: 'https://example.test/api/',
      requestHeaderProvider: () async => throw StateError('headers failed'),
      transport: _FakeTransport(
        handler: (_) => throw StateError('transport must not run'),
      ),
    );
    await expectLater(
      headersClient.get<Object?>('v1/profile'),
      throwsStateError,
    );

    final bodyClient = ApiClient(
      baseUrl: 'https://example.test/api/',
      transport: _FakeTransport(
        handler: (_) => throw StateError('transport must not run'),
      ),
    );
    await expectLater(
      bodyClient.post<Object?>('v1/profile', body: _ThrowingBody()),
      throwsStateError,
    );

    final apiUnknownClient = ApiClient(
      baseUrl: 'https://example.test/api/',
      requestHeaderProvider: () async =>
          throw ApiException(message: 'unclassified API failure'),
      transport: _FakeTransport(
        handler: (_) => throw StateError('transport must not run'),
      ),
    );
    await expectLater(
      apiUnknownClient.get<Object?>('v1/profile'),
      throwsA(isA<ApiException>()),
    );

    final failures = (await events())
        .where((event) => event.action == 'api_request_failed')
        .toList();
    expect(failures.map((event) => _extData(event)['failure_reason']), [
      'request_headers',
      'request_body',
      'api_unknown',
    ]);
    expect(failures.every((event) => event.object3.isEmpty), isTrue);
    expect(_extData(failures[0])['exception_type'], 'StateError');
    expect(_extData(failures[0])['error_message'], contains('headers failed'));
    expect(_extData(failures[1])['error_message'], contains('body encoding'));
    expect(_extData(failures[2])['exception_kind'], 'unknown');
  });

  test(
    'formerly unknown transport failures use stable subcategories',
    () async {
      for (final testCase in <({Object error, String reason})>[
        (
          error: Exception('certificate handshake failed'),
          reason: 'bad_certificate',
        ),
        (
          error: Exception(
            'HTTPS requires HTTP/2 or HTTP/3, but negotiated HTTP/1.1; '
            'uri=https://example.test/api/v1/profile?token=secret',
          ),
          reason: 'http_protocol',
        ),
        (
          error: Exception(
            'QuicException: protocol error, quicDetailedErrorCode=42',
          ),
          reason: 'http3_quic_42',
        ),
        (
          error: Exception('NetworkClientException: errorCode=6'),
          reason: 'cronet_6',
        ),
        (
          error: Exception('NSErrorClientException: code=-1009'),
          reason: 'ios_network_-1009',
        ),
        (
          error: Exception('DioException [connection error]: failed'),
          reason: 'dio_connection',
        ),
        (
          error: Exception('ClientException: invalid response'),
          reason: 'http_client',
        ),
        (
          error: StateError('transport state failed'),
          reason: 'transport_internal',
        ),
        (
          error: Exception('unexpected transport failure'),
          reason: 'transport_unknown',
        ),
      ]) {
        final client = ApiClient(
          baseUrl: 'https://example.test/api/',
          transport: _FakeTransport(handler: (_) => throw testCase.error),
        );
        await expectLater(
          client.get<Object?>('v1/profile'),
          throwsA(isA<ApiException>()),
        );
      }

      final failures = (await events())
          .where((event) => event.action == 'api_request_failed')
          .toList();
      expect(failures.map((event) => _extData(event)['failure_reason']), [
        'bad_certificate',
        'http_protocol',
        'http3_quic_42',
        'cronet_6',
        'ios_network_-1009',
        'dio_connection',
        'http_client',
        'transport_internal',
        'transport_unknown',
      ]);
      expect(failures.every((event) => event.object3.isEmpty), isTrue);
      expect(_extData(failures[1])['native_error_message'], contains('<url>'));
      expect(_extData(failures[2])['native_error_code'], '42');
      expect(_extData(failures[3])['native_error_code'], '6');
      expect(_extData(failures[4])['native_error_code'], '-1009');
    },
  );

  test('gateway, chatroom, and other paths are excluded', () async {
    final transport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"err_no":0,"data":{}}',
      ),
    );

    await ApiClient(
      baseUrl: 'https://example.test/apix/',
      transport: transport,
    ).get<Object?>('v1/time');
    await ApiClient(
      baseUrl: 'https://example.test/',
      transport: transport,
    ).get<Object?>('/aitown-chat/v1/message/list');
    await ApiClient(
      baseUrl: 'https://example.test/',
      transport: transport,
    ).get<Object?>('/assets/config.json');

    expect(await events(), isEmpty);
  });

  test('continuous message polling paths are excluded', () async {
    final requests = <Uri>[];
    final client = ApiClient(
      baseUrl: 'https://example.test/api/',
      transport: _FakeTransport(
        handler: (request) {
          requests.add(request.uri);
          return const TransportResponse(
            statusCode: 200,
            headers: {'content-type': 'application/json'},
            body: '{"err_no":0,"data":{}}',
          );
        },
      ),
    );

    await client.get<Object?>(
      'v1/message/unread',
      tracePolicy: ApiRequestTracePolicy.excluded,
    );
    await client.get<Object?>(
      'v1/direct_message/conversations',
      tracePolicy: ApiRequestTracePolicy.excluded,
    );
    await client.get<Object?>(
      'v1/direct_message/list',
      tracePolicy: ApiRequestTracePolicy.excluded,
    );

    expect(requests.map((uri) => uri.path), <String>[
      '/api/v1/message/unread',
      '/api/v1/direct_message/conversations',
      '/api/v1/direct_message/list',
    ]);
    expect(await events(), isEmpty);
  });

  test('successful non-polling direct message action is tracked', () async {
    final client = ApiClient(
      baseUrl: 'https://example.test/api/',
      transport: _FakeTransport(
        handler: (_) => const TransportResponse(
          statusCode: 200,
          headers: {'content-type': 'application/json'},
          body: '{"err_no":0,"data":{}}',
        ),
      ),
    );

    await client.post<Object?>(
      'v1/direct_message/send',
      body: const {'peer_uid': 'user-1', 'content': 'hello'},
    );

    expect((await events()).map((event) => event.action), <String>[
      'api_request_start',
      'api_request_success',
    ]);
  });

  test(
    'ordinary requests are excluded when launch sampling is disabled',
    () async {
      ApiRequestTraceSampling.resetForTesting();
      final client = ApiClient(
        baseUrl: 'https://example.test/api/',
        transport: _FakeTransport(
          handler: (_) => const TransportResponse(
            statusCode: 200,
            headers: {'content-type': 'application/json'},
            body: '{"err_no":0,"data":{}}',
          ),
        ),
      );

      await client.get<Object?>('v1/world/list');

      expect(await events(), isEmpty);
    },
  );

  test(
    'global config is always tracked when launch sampling is disabled',
    () async {
      ApiRequestTraceSampling.resetForTesting();
      final client = ApiClient(
        baseUrl: 'https://example.test/api/',
        transport: _FakeTransport(
          handler: (_) => const TransportResponse(
            statusCode: 200,
            headers: {'content-type': 'application/json'},
            body: '{"err_no":0,"data":{"apiTraceSamplingRate":1}}',
          ),
        ),
      );

      await client.get<Object?>('v1/app/config');

      expect((await events()).map((event) => event.action), <String>[
        'api_request_start',
        'api_request_success',
      ]);
    },
  );

  test(
    'collect endpoint is always excluded from API request tracing',
    () async {
      final client = ApiClient(
        baseUrl: 'https://example.test/api/',
        transport: _FakeTransport(
          handler: (_) => const TransportResponse(
            statusCode: 200,
            headers: {'content-type': 'application/json'},
            body: '{"err_no":0,"data":{}}',
          ),
        ),
      );

      await client.post<Object?>('v1/collect', body: const {'events': []});

      expect(await events(), isEmpty);
    },
  );
}

class _ThrowingBody {
  @override
  String toString() => throw StateError('body encoding failed');
}
