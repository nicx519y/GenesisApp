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

GenesisApi _apiWith(
  _FakeTransport apiTransport,
  _FakeTransport healthTransport,
) {
  final apiClient = ApiClient(
    baseUrl: 'http://localhost:8080/api/',
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
  test('bindDevice uses GET /auth/me/public-profile', () async {
    final apiTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"id":"u_1","display_name":"n","avatar_url":"a"}',
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
    final user = await api.bindDevice(did: 'd1');

    expect(apiTransport.lastRequest!.method, 'GET');
    expect(
      apiTransport.lastRequest!.uri.toString(),
      'http://localhost:8080/api/auth/me/public-profile',
    );
    expect(user.uid, 'u_1');
  });

  test('getOrigins uses GET /origins for default category', () async {
    final apiTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"origins":[]}',
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
    expect(apiTransport.lastRequest!.uri.path, '/api/origins');
  });

  test('getOrigins uses GET /origins/popular for other categories', () async {
    final apiTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"origins":[]}',
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
    await api.getOrigins(category: 'Billionare', limit: 20, offset: 0);

    expect(apiTransport.lastRequest!.method, 'GET');
    expect(apiTransport.lastRequest!.uri.path, '/api/origins/popular');
    expect(apiTransport.lastRequest!.uri.queryParameters['limit'], '20');
  });

  test('launchWorld uses POST /worlds/launch with new body', () async {
    final apiTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"ok":true,"wid":"wid_1","wid_str":"W_1"}',
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
    await api.launchWorld(
      originId: 123,
      ownerUid: 'u_1',
      worldviewId: 'wv_1',
      worldName: 'World 1',
    );

    expect(apiTransport.lastRequest!.method, 'POST');
    expect(
      apiTransport.lastRequest!.uri.toString(),
      'http://localhost:8080/api/worlds/launch',
    );

    final body = utf8.decode(
      apiTransport.lastRequest!.bodyBytes ?? const <int>[],
    );
    expect(jsonDecode(body), {
      'user_id': 'u_1',
      'worldview_id': 'wv_1',
      'world_name': 'World 1',
    });
  });

  test('sendMessage uses POST /points/:point_id/messages/enqueue', () async {
    final apiTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"ok":true,"user_message":{"id":"m_1"}}',
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
      wid: 'wid_1',
      uid: 'u_1',
      pointId: 'pt_9',
      locationId: 'loc_3',
      content: 'Hello',
    );

    expect(apiTransport.lastRequest!.method, 'POST');
    expect(
      apiTransport.lastRequest!.uri.toString(),
      'http://localhost:8080/api/points/pt_9/messages/enqueue',
    );

    final body = utf8.decode(
      apiTransport.lastRequest!.bodyBytes ?? const <int>[],
    );
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    expect(decoded['user_id'], 'u_1');
    expect(decoded['wid'], 'wid_1');
    expect(decoded['location_id'], 'loc_3');
    expect(decoded['text'], 'Hello');
    expect(decoded['player_id'], 'player1');
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
    expect(
      healthTransport.lastRequest!.uri.toString(),
      'http://localhost:8080/health',
    );
  });

  test('search uses GET /search with query', () async {
    final apiTransport = _FakeTransport(
      handler: (request) {
        if (request.uri.path.endsWith('/auth/me/public-profile')) {
          return const TransportResponse(
            statusCode: 200,
            headers: {'content-type': 'application/json'},
            body: '{"id":"u_1","display_name":"n","avatar_url":"a"}',
          );
        }
        return const TransportResponse(
          statusCode: 200,
          headers: {'content-type': 'application/json'},
          body: '{"origins":[],"worlds":[],"users":[]}',
        );
      },
    );
    final healthTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"status":"ok"}',
      ),
    );

    final api = _apiWith(apiTransport, healthTransport);
    await api.search(query: 'ori', limit: 10);

    expect(apiTransport.lastRequest!.method, 'GET');
    expect(apiTransport.lastRequest!.uri.path, '/api/search');
    expect(apiTransport.lastRequest!.uri.queryParameters['q'], 'ori');
    expect(apiTransport.lastRequest!.uri.queryParameters['limit'], '10');
  });
}
