import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/api_client.dart';
import 'package:genesis_flutter_android/network/genesis_api.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';

class _FakeTransport implements HttpTransport {
  _FakeTransport({required this.handler});

  final TransportResponse Function(TransportRequest request) handler;
  TransportRequest? lastRequest;

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    lastRequest = request;
    return handler(request);
  }
}

GenesisApi _apiWith(_FakeTransport apiTransport, _FakeTransport healthTransport) {
  final apiClient = ApiClient(
    baseUrl: 'http://localhost:8080/api/v1/',
    defaultHeaders: const {
      'content-type': 'application/json',
      'accept': 'application/json',
    },
    transport: apiTransport,
    responseProcessor: (r) => ApiClient.defaultResponseProcessor(r),
  );

  final healthClient = ApiClient(
    baseUrl: 'http://localhost:8080/',
    defaultHeaders: const {'accept': 'application/json'},
    transport: healthTransport,
    responseProcessor: (r) => ApiClient.defaultResponseProcessor(r),
  );

  return GenesisApi(apiClient: apiClient, healthClient: healthClient);
}

void main() {
  test('bindDevice uses POST /users/bind with did', () async {
    final apiTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body:
            '{"data":{"id":1,"uid":"U0001","did":"d1","nickname":"n","avatar":"a","created_at":"2024-03-09T10:00:00Z"}}',
      ),
    );
    final healthTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"status":"ok"}',
      ),
    );

    final api = _apiWith(apiTransport, healthTransport);
    await api.bindDevice(did: 'd1');

    expect(apiTransport.lastRequest!.method, 'POST');
    expect(
      apiTransport.lastRequest!.uri.toString(),
      'http://localhost:8080/api/v1/users/bind',
    );

    final body =
        utf8.decode(apiTransport.lastRequest!.bodyBytes ?? const <int>[]);
    expect(jsonDecode(body), {'did': 'd1'});
  });

  test('getOrigins uses GET /origins with query params', () async {
    final apiTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"data":[],"total":0,"limit":20,"offset":0}',
      ),
    );
    final healthTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"status":"ok"}',
      ),
    );

    final api = _apiWith(apiTransport, healthTransport);
    await api.getOrigins(category: 'For you', limit: 20, offset: 0);

    expect(apiTransport.lastRequest!.method, 'GET');
    expect(apiTransport.lastRequest!.uri.path, '/api/v1/origins');
    expect(apiTransport.lastRequest!.uri.queryParameters['category'], 'For you');
    expect(apiTransport.lastRequest!.uri.queryParameters['limit'], '20');
    expect(apiTransport.lastRequest!.uri.queryParameters['offset'], '0');
  });

  test('sendMessage uses POST /worlds/:wid/messages', () async {
    final apiTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body:
            '{"data":{"id":1,"world_id":1,"location_id":1,"uid":"U0001","content":"Hello","message_type":"user","created_at":"2024-03-09T10:00:00Z"}}',
      ),
    );
    final healthTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"status":"ok"}',
      ),
    );

    final api = _apiWith(apiTransport, healthTransport);
    await api.sendMessage(
      wid: 'Wabc',
      uid: 'U0001',
      locationId: 1,
      content: 'Hello',
    );

    expect(apiTransport.lastRequest!.method, 'POST');
    expect(
      apiTransport.lastRequest!.uri.toString(),
      'http://localhost:8080/api/v1/worlds/Wabc/messages',
    );
  });

  test('health uses GET /health', () async {
    final apiTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"data":{}}',
      ),
    );
    final healthTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"status":"ok"}',
      ),
    );

    final api = _apiWith(apiTransport, healthTransport);
    final ok = await api.health();
    expect(ok, true);
    expect(healthTransport.lastRequest!.uri.toString(), 'http://localhost:8080/health');
  });
}

