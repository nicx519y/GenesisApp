import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/telemetry/genesis_telemetry.dart';
import 'package:genesis_flutter_android/network/api_client.dart';
import 'package:genesis_flutter_android/network/api_exception.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';

class _FakeTransport implements HttpTransport {
  _FakeTransport({required this.handler});

  final FutureOr<TransportResponse> Function(TransportRequest request) handler;

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    return handler(request);
  }
}

void main() {
  late MemoryCollectEventStore store;
  late CollectTelemetryUploader uploader;

  setUp(() {
    GenesisTelemetry.resetForTesting();
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
    GenesisTelemetry.resetForTesting();
  });

  Future<List<CollectEvent>> events() async {
    await uploader.waitForPendingWrites();
    return store.eventsForTesting;
  }

  test(
    'business request reports path-only start and first-attempt success',
    () async {
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
      expect(recorded.map((event) => event.actionType).toSet(), {'event'});
      expect(recorded.map((event) => event.object1).toSet(), {
        '/api/v1/world/list',
      });
      expect(recorded.first.object2, isNotEmpty);
      expect(recorded.last.object2, recorded.first.object2);
      expect(recorded.first.object3, '');
      expect(recorded.last.object3, 'attempt_1');
      expect(
        recorded
            .expand(
              (event) => <String>[event.object1, event.object2, event.object3],
            )
            .join(' '),
        isNot(contains('secret')),
      );
    },
  );

  test('automatic retry reports one start and one attempt_2 success', () async {
    var attempts = 0;
    final client = ApiClient(
      baseUrl: 'https://example.test/api/',
      retryPolicy: ApiRetryPolicy.safe,
      transport: _FakeTransport(
        handler: (_) {
          attempts += 1;
          if (attempts == 1) throw TimeoutException('slow');
          return const TransportResponse(
            statusCode: 200,
            headers: {'content-type': 'application/json'},
            body: '{"err_no":0,"data":{}}',
          );
        },
      ),
    );

    await client.get<Object?>('v1/profile');

    final recorded = await events();
    expect(attempts, 2);
    expect(recorded.map((event) => event.action), <String>[
      'api_request_start',
      'api_request_success',
    ]);
    expect(recorded.last.object3, 'attempt_2');
    expect(recorded.last.object2, recorded.first.object2);
  });

  test('a page-level retry starts a new request id at attempt_1', () async {
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
    expect(recorded[1].object3, 'connection');
    expect(recorded[3].object3, 'attempt_1');
    expect(recorded[0].object2, recorded[1].object2);
    expect(recorded[2].object2, recorded[3].object2);
    expect(recorded[2].object2, isNot(recorded[0].object2));
  });

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
    expect(recorded.last.object3, 'timeout');
    expect(recorded.last.object2, recorded.first.object2);
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
    expect(failures.map((event) => event.object3), <String>[
      'http_500',
      'business_1001',
    ]);
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
      expect(failures.map((event) => event.object3), <String>[
        'decode',
        'response',
      ]);
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
    expect(failures.map((event) => event.object3), <String>[
      'gateway_auth',
      'cancelled',
    ]);
  });

  test(
    'certificate and unknown transport failures stay distinguishable',
    () async {
      for (final testCase in <({String message, String reason})>[
        (message: 'certificate handshake failed', reason: 'bad_certificate'),
        (message: 'unexpected transport failure', reason: 'unknown'),
      ]) {
        final client = ApiClient(
          baseUrl: 'https://example.test/api/',
          transport: _FakeTransport(
            handler: (_) => throw Exception(testCase.message),
          ),
        );
        await expectLater(
          client.get<Object?>('v1/profile'),
          throwsA(isA<ApiException>()),
        );
      }

      final failures = (await events())
          .where((event) => event.action == 'api_request_failed')
          .toList();
      expect(failures.map((event) => event.object3), <String>[
        'bad_certificate',
        'unknown',
      ]);
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
}
