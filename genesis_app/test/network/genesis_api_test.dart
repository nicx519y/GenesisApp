import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/config/app_config.dart';
import 'package:genesis_flutter_android/app/config/platform_config.dart';
import 'package:genesis_flutter_android/network/api_client.dart';
import 'package:genesis_flutter_android/network/api_exception.dart';
import 'package:genesis_flutter_android/network/genesis_api.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';
import 'package:genesis_flutter_android/platform/auth/auth_session.dart';
import 'package:genesis_flutter_android/platform/auth/backend_auth_coordinator.dart';
import 'package:genesis_flutter_android/platform/auth/identity_auth_service.dart';
import 'package:genesis_flutter_android/platform/device/device_id_service.dart';
import 'package:genesis_flutter_android/platform/session/memory_user_session_store.dart';

class _FakeTransport implements HttpTransport {
  _FakeTransport({required this.handler});

  final TransportResponse Function(TransportRequest request) handler;
  TransportRequest? lastRequest;
  final List<TransportRequest> requests = <TransportRequest>[];

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    requests.add(request);
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

  final sessionStore = MemoryUserSessionStore();
  sessionStore.saveUid('u_1');
  return GenesisApi(
    apiClient: apiClient,
    healthClient: healthClient,
    deviceIdService: const _TestDeviceIdService(),
    sessionStore: sessionStore,
  );
}

void main() {
  test('AppConfig switches production and mock network environments', () {
    expect(const AppConfig().useMock, false);
    expect(const AppConfig(apiEnvironment: 'mock').useMock, true);
    expect(const AppConfig(apiEnvironment: 'production').useMock, false);
    expect(
      const AppConfig(apiEnvironment: 'production', useMock: true).useMock,
      true,
    );
  });

  test('bindDevice uses GET /v1/user/info', () async {
    final apiTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body:
            '{"err_no":0,"err_msg":"succ","data":{"user":{"uid":"u_1","name":"n","avatar":"a"}}}',
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
      'http://localhost:8080/api/v1/user/info',
    );
    expect(user.uid, 'u_1');
  });

  test('getOrigins uses GET /v1/origin/list for default category', () async {
    final apiTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"err_no":0,"err_msg":"succ","data":{"list":[],"total":0}}',
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
    expect(apiTransport.lastRequest!.uri.path, '/api/v1/origin/list');
    expect(apiTransport.lastRequest!.uri.queryParameters['pn'], '1');
    expect(apiTransport.lastRequest!.uri.queryParameters['rn'], '20');
    expect(apiTransport.lastRequest!.uri.queryParameters['tag_name'], isNull);
  });

  test('getOrigins maps non-default category to Apifox tag_name', () async {
    final apiTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"err_no":0,"err_msg":"succ","data":{"list":[],"total":0}}',
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
    expect(apiTransport.lastRequest!.uri.path, '/api/v1/origin/list');
    expect(
      apiTransport.lastRequest!.uri.queryParameters['tag_name'],
      'Billionare',
    );
    expect(apiTransport.lastRequest!.uri.queryParameters['rn'], '20');
  });

  test('profile list facades use Apifox origin and world list endpoints', () async {
    final apiTransport = _FakeTransport(
      handler: (request) {
        if (request.uri.path.endsWith('/v1/origin/list')) {
          return const TransportResponse(
            statusCode: 200,
            headers: {'content-type': 'application/json'},
            body:
                '{"err_no":0,"err_msg":"succ","data":{"list":[{"info":{"origin_id":"o_1","origin_name":"Origin One","brief":"origin brief","cover":"","tags":["tag"],"created_at":1716000000},"stats":{"copy_cnt":2,"connect_cnt":3}}],"total":1}}',
          );
        }
        if (request.uri.path.endsWith('/v1/world/list')) {
          return const TransportResponse(
            statusCode: 200,
            headers: {'content-type': 'application/json'},
            body:
                '{"err_no":0,"err_msg":"succ","data":{"list":[{"info":{"world_id":"w_1","world_name":"World One","cover":"","created_at":1716000000},"stats":{"tick_cnt":4,"player_cnt":5}}],"total":1}}',
          );
        }
        return const TransportResponse(
          statusCode: 404,
          headers: {'content-type': 'application/json'},
          body: '{"error":"unexpected path"}',
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
    final origins = await api.getMyLaunchedOrigins(
      uid: 'u_2',
      limit: 10,
      offset: 10,
    );
    final worlds = await api.getMyWorlds(uid: 'u_2', limit: 10, offset: 10);

    expect(origins.data.single.oid, 'o_1');
    expect(worlds.single.wid, 'w_1');
    expect(apiTransport.requests[0].uri.path, '/api/v1/origin/list');
    expect(apiTransport.requests[0].uri.queryParameters['uid'], 'u_2');
    expect(apiTransport.requests[0].uri.queryParameters['pn'], '2');
    expect(apiTransport.requests[0].uri.queryParameters['rn'], '10');
    expect(apiTransport.requests[1].uri.path, '/api/v1/world/list');
    expect(apiTransport.requests[1].uri.queryParameters['owner_uid'], 'u_2');
    expect(
      apiTransport.requests[1].uri.queryParameters.containsKey('uid'),
      false,
    );
    expect(apiTransport.requests[1].uri.queryParameters['pn'], '2');
    expect(apiTransport.requests[1].uri.queryParameters['rn'], '10');
  });

  test('getWorld maps tick_result narrator paragraphs from detail', () async {
    final apiTransport = _FakeTransport(
      handler: (request) => TransportResponse(
        statusCode: 200,
        headers: const {'content-type': 'application/json'},
        body: jsonEncode({
          'err_no': 0,
          'err_msg': 'succ',
          'data': {
            'info': {
              'world_id': 'w_1',
              'world_name': 'World One',
              'origin_id': 'o_1',
              'owner_uid': 'u_1',
              'owner_name': 'Tester',
              'created_at': '2026-05-01T00:00:00Z',
              'updated_at': '2026-05-02T00:00:00Z',
              'status': 1,
            },
            'stats': {
              'tick_cnt': 1,
              'connect_cnt': 0,
              'character_cnt': 0,
              'player_cnt': 0,
            },
            'characters': const <Object?>[],
            'locations': [
              {
                'location_id': 'loc_1',
                'location_name': 'Gate',
                'location_summary': '',
                'location_description': 'Gate fallback description.',
              },
            ],
            'ticks': [
              {
                'tick_index': 1,
                'created_at': '2026-05-02T00:00:00Z',
                'tick_result': {
                  'narrator': 'Narrator from tick result.',
                  'paragraphs': [
                    {
                      'location_id': 'loc_1',
                      'text': 'Location paragraph text.',
                      'character_details': [
                        {'name': 'Iris Vale', 'delta': '+3 focus'},
                      ],
                    },
                  ],
                },
              },
            ],
          },
        }),
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
    final world = await api.getWorld('w_1');
    final location = world.worldLocations.single;
    final tickResult = world.ticks.single['tick_result'] as Map;
    final paragraph = (tickResult['paragraphs'] as List).single as Map;

    expect(apiTransport.lastRequest!.uri.path, '/api/v1/world/detail');
    expect(apiTransport.lastRequest!.uri.queryParameters['world_id'], 'w_1');
    expect(location['location_summary'], '');
    expect(location['location_description'], 'Gate fallback description.');
    expect(location['description'], '');
    expect(world.lastProgressUpdate, 'Narrator from tick result.');
    expect(tickResult['narrator'], 'Narrator from tick result.');
    expect(paragraph['location_id'], 'loc_1');
    expect(paragraph['text'], 'Location paragraph text.');
    expect((paragraph['character_details'] as List).single, {
      'name': 'Iris Vale',
      'delta': '+3 focus',
    });
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
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"origins":[],"worlds":[],"users":[]}',
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
    await api.search(query: 'ori', limit: 10);

    expect(apiTransport.lastRequest!.method, 'GET');
    expect(apiTransport.lastRequest!.uri.path, '/api/search');
    expect(apiTransport.lastRequest!.uri.queryParameters['q'], 'ori');
    expect(apiTransport.lastRequest!.uri.queryParameters['limit'], '10');
  });

  test('default client uses configurable API base URL', () async {
    final apiTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"err_no":0,"err_msg":"succ","data":{"list":[],"total":0}}',
      ),
    );

    final api = GenesisApi(
      transport: apiTransport,
      useMock: false,
      platformConfig: const _TestPlatformConfig(
        'android',
        apiBaseUrl: 'https://example.test/api/',
      ),
    );
    await api.getOrigins();

    expect(
      apiTransport.lastRequest!.uri.toString(),
      'https://example.test/api/v1/origin/list?pn=1&rn=20',
    );
  });

  test('default client targets dev API base URL', () async {
    final apiTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"err_no":0,"err_msg":"succ","data":{"list":[],"total":0}}',
      ),
    );

    final api = GenesisApi(transport: apiTransport, useMock: false);
    await api.getOrigins();

    expect(
      apiTransport.lastRequest!.uri.toString(),
      'https://dev.hushie.ai/api/v1/origin/list?pn=1&rn=20',
    );
  });

  test('default client injects device and authorization headers', () async {
    final apiTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"err_no":0,"err_msg":"succ","data":{"list":[],"total":0}}',
      ),
    );
    final sessionStore = MemoryUserSessionStore();
    await sessionStore.saveUid('u_1');
    await sessionStore.saveAuthToken('backend-token');

    final api = GenesisApi(
      transport: apiTransport,
      useMock: false,
      deviceIdService: const _TestDeviceIdService(),
      sessionStore: sessionStore,
    );
    await api.getOrigins();

    expect(apiTransport.lastRequest!.headers['device-id'], 'test-device-id');
    expect(
      apiTransport.lastRequest!.headers.containsKey('x-device-id'),
      isFalse,
    );
    expect(apiTransport.lastRequest!.headers.containsKey('x-user-id'), isFalse);
    expect(
      apiTransport.lastRequest!.headers['authorization'],
      'Bearer backend-token',
    );
  });

  test(
    'loginWithGoogle stores backend token for later default auth header',
    () async {
      late final MemoryUserSessionStore sessionStore;
      final apiTransport = _FakeTransport(
        handler: (request) {
          if (request.uri.path.endsWith('/v1/user/oauth/google')) {
            final body =
                jsonDecode(utf8.decode(request.bodyBytes ?? const [])) as Map;
            expect(body['id_token'], 'google-token');
            expect(body['name'], 'Neo');
            expect(body['avatar'], 'https://cdn/neo.png');
            return const TransportResponse(
              statusCode: 200,
              headers: {'content-type': 'application/json'},
              body:
                  '{"err_no":0,"err_msg":"succ","data":{"token":"backend-token","user":{"uid":"u_2","name":"Neo"}}}',
            );
          }
          return const TransportResponse(
            statusCode: 200,
            headers: {'content-type': 'application/json'},
            body: '{"err_no":0,"err_msg":"succ","data":{"list":[],"total":0}}',
          );
        },
      );
      sessionStore = MemoryUserSessionStore();
      final api = GenesisApi(
        transport: apiTransport,
        useMock: false,
        deviceIdService: const _TestDeviceIdService(),
        sessionStore: sessionStore,
      );

      await api.loginWithGoogle(
        idToken: 'google-token',
        name: 'Neo',
        avatar: 'https://cdn/neo.png',
      );
      expect(await sessionStore.readUid(), 'u_2');
      expect(await sessionStore.readAuthToken(), 'backend-token');
      expect(await sessionStore.readUserInfo(), containsPair('uid', 'u_2'));
      expect(await sessionStore.readUserInfo(), containsPair('name', 'Neo'));

      await api.getOrigins();
      expect(
        apiTransport.lastRequest!.headers['authorization'],
        'Bearer backend-token',
      );
    },
  );

  test('loginWithIdentity posts Apple tokens and stores backend token', () async {
    final apiTransport = _FakeTransport(
      handler: (request) {
        if (request.uri.path.endsWith('/v1/user/oauth/apple')) {
          final body =
              jsonDecode(utf8.decode(request.bodyBytes ?? const [])) as Map;
          expect(body['id_token'], 'apple-token');
          expect(body.containsKey('firebase_id_token'), isFalse);
          expect(body['name'], 'Ava');
          return const TransportResponse(
            statusCode: 200,
            headers: {'content-type': 'application/json'},
            body:
                '{"err_no":0,"err_msg":"succ","data":{"token":"apple-backend-token","user":{"uid":"apple_uid","name":"Ava"}}}',
          );
        }
        return const TransportResponse(
          statusCode: 200,
          headers: {'content-type': 'application/json'},
          body: '{"err_no":0,"err_msg":"succ","data":{"list":[],"total":0}}',
        );
      },
    );
    final sessionStore = MemoryUserSessionStore();
    final api = GenesisApi(
      transport: apiTransport,
      useMock: false,
      deviceIdService: const _TestDeviceIdService(),
      sessionStore: sessionStore,
    );

    await api.loginWithIdentity(
      const AuthSession(
        provider: IdentityProvider.apple,
        providerIdToken: 'apple-token',
        firebaseIdToken: 'firebase-token',
        identityUid: 'firebase-uid',
        email: 'ava@example.com',
        displayName: 'Ava',
        photoUrl: '',
      ),
    );

    expect(await sessionStore.readUid(), 'apple_uid');
    expect(await sessionStore.readAuthToken(), 'apple-backend-token');
    expect(await sessionStore.readUserInfo(), containsPair('uid', 'apple_uid'));
  });

  test(
    'loginWithIdentity falls back to identity uid when backend omits user id',
    () async {
      final apiTransport = _FakeTransport(
        handler: (request) {
          if (request.uri.path.endsWith('/v1/user/oauth/apple')) {
            return const TransportResponse(
              statusCode: 200,
              headers: {'content-type': 'application/json'},
              body:
                  '{"err_no":0,"err_msg":"succ","data":{"token":"apple-backend-token","user":{}}}',
            );
          }
          return const TransportResponse(
            statusCode: 200,
            headers: {'content-type': 'application/json'},
            body: '{"err_no":0,"err_msg":"succ","data":{"list":[],"total":0}}',
          );
        },
      );
      final sessionStore = MemoryUserSessionStore();
      final api = GenesisApi(
        transport: apiTransport,
        useMock: false,
        deviceIdService: const _TestDeviceIdService(),
        sessionStore: sessionStore,
      );

      final user = await api.loginWithIdentity(
        const AuthSession(
          provider: IdentityProvider.apple,
          providerIdToken: 'apple-token',
          firebaseIdToken: 'firebase-token',
          identityUid: 'firebase-uid',
          email: 'ava@example.com',
          displayName: 'Ava',
          photoUrl: '',
        ),
      );

      expect(user.uid, 'firebase-uid');
      expect(await sessionStore.readUid(), 'firebase-uid');
      expect(await sessionStore.readAuthToken(), 'apple-backend-token');
      expect(
        await sessionStore.readUserInfo(),
        containsPair('uid', 'firebase-uid'),
      );
    },
  );

  test(
    'backend signOut posts logout then clears identity and local session',
    () async {
      final apiTransport = _FakeTransport(
        handler: (request) {
          if (request.uri.path.endsWith('/v1/user/logout')) {
            expect(request.method, 'POST');
            expect(request.headers['authorization'], 'Bearer backend-token');
            return const TransportResponse(
              statusCode: 200,
              headers: {'content-type': 'application/json'},
              body: '{"err_no":0,"err_msg":"succ","data":{}}',
            );
          }
          return const TransportResponse(
            statusCode: 404,
            headers: {'content-type': 'application/json'},
            body: '{"error":"not_found"}',
          );
        },
      );
      final sessionStore = MemoryUserSessionStore();
      await sessionStore.saveUid('u_2');
      await sessionStore.saveAuthToken('backend-token');
      final identityAuth = _FakeIdentityAuthService();
      final api = GenesisApi(
        transport: apiTransport,
        useMock: false,
        deviceIdService: const _TestDeviceIdService(),
        sessionStore: sessionStore,
        identityAuthService: identityAuth,
      );
      final coordinator = GenesisBackendAuthCoordinator(
        api: api,
        identityAuth: identityAuth,
        sessionStore: sessionStore,
      );

      await coordinator.signOut();

      expect(apiTransport.requests.single.uri.path, '/api/v1/user/logout');
      expect(identityAuth.signOutCount, 1);
      expect(await sessionStore.readUid(), isNull);
      expect(await sessionStore.readAuthToken(), isNull);
      expect(await sessionStore.readUserInfo(), isNull);
    },
  );

  test(
    'backend signOut still clears local session when logout endpoint fails',
    () async {
      final apiTransport = _FakeTransport(
        handler: (_) => const TransportResponse(
          statusCode: 500,
          headers: {'content-type': 'application/json'},
          body: '{"error":"server_error"}',
        ),
      );
      final sessionStore = MemoryUserSessionStore();
      await sessionStore.saveUid('u_2');
      await sessionStore.saveAuthToken('backend-token');
      final identityAuth = _FakeIdentityAuthService();
      final api = GenesisApi(
        transport: apiTransport,
        useMock: false,
        deviceIdService: const _TestDeviceIdService(),
        sessionStore: sessionStore,
        identityAuthService: identityAuth,
      );
      final coordinator = GenesisBackendAuthCoordinator(
        api: api,
        identityAuth: identityAuth,
        sessionStore: sessionStore,
      );

      await coordinator.signOut();

      expect(identityAuth.signOutCount, 1);
      expect(await sessionStore.readUid(), isNull);
      expect(await sessionStore.readAuthToken(), isNull);
      expect(await sessionStore.readUserInfo(), isNull);
    },
  );

  test('default client preserves configurable platform header', () async {
    final apiTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"err_no":0,"err_msg":"succ","data":{"list":[],"total":0}}',
      ),
    );

    final api = GenesisApi(
      transport: apiTransport,
      useMock: false,
      platformConfig: const _TestPlatformConfig('ios'),
    );
    await api.getOrigins();

    expect(apiTransport.lastRequest!.headers['x-platform'], 'ios');
  });

  test('v1 origin list uses Apifox query format', () async {
    final apiTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"err_no":0,"err_msg":"succ","data":{"list":[],"total":0}}',
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
    final result = await api.v1.origin.list(
      scene: 'mine',
      keyword: 'steam',
      tagName: 'politics',
      pn: 2,
      rn: 10,
    );

    expect(result['total'], 0);
    expect(apiTransport.lastRequest!.method, 'GET');
    expect(apiTransport.lastRequest!.uri.path, '/api/v1/origin/list');
    expect(apiTransport.lastRequest!.uri.queryParameters['scene'], isNull);
    expect(apiTransport.lastRequest!.uri.queryParameters['keyword'], 'steam');
    expect(
      apiTransport.lastRequest!.uri.queryParameters['tag_name'],
      'politics',
    );
    expect(apiTransport.lastRequest!.uri.queryParameters['pn'], '2');
    expect(apiTransport.lastRequest!.uri.queryParameters['rn'], '10');
  });

  test('v1 direct message send posts Apifox JSON body', () async {
    final apiTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body:
            '{"err_no":0,"err_msg":"succ","data":{"message":{"msg_id":"m1"}}}',
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
    await api.v1.dm.send(peerUid: 'U_2', content: 'hello');

    expect(apiTransport.lastRequest!.method, 'POST');
    expect(apiTransport.lastRequest!.uri.path, '/api/v1/direct_message/send');
    final body = jsonDecode(utf8.decode(apiTransport.lastRequest!.bodyBytes!));
    expect(body['peer_uid'], 'U_2');
    expect(body['content'], 'hello');
    expect(body.containsKey('targetUid'), isFalse);
    expect(body.containsKey('peerUid'), isFalse);
    expect(body.containsKey('target_uid'), isFalse);
    expect(body.containsKey('client_msg_id'), isFalse);
  });

  test('v1 message notifications uses Apifox block query', () async {
    final apiTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body:
            '{"err_no":0,"err_msg":"succ","data":{"list":[],"total":0,"pn":1,"rn":20}}',
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
    await api.v1.messages.notifications(block: 'interaction', pn: 1, rn: 20);

    expect(apiTransport.lastRequest!.method, 'GET');
    expect(apiTransport.lastRequest!.uri.path, '/api/v1/message/notifications');
    expect(
      apiTransport.lastRequest!.uri.queryParameters['block'],
      'interaction',
    );
    expect(apiTransport.lastRequest!.uri.queryParameters['pn'], '1');
    expect(apiTransport.lastRequest!.uri.queryParameters['rn'], '20');
    expect(
      apiTransport.lastRequest!.uri.queryParameters.containsKey('category'),
      isFalse,
    );
  });

  test('v1 mark notifications read posts Apifox block body', () async {
    final apiTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"err_no":0,"err_msg":"succ","data":{}}',
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
    await api.v1.messages.markNotificationsRead(block: 'world_apply');

    expect(apiTransport.lastRequest!.method, 'POST');
    expect(apiTransport.lastRequest!.uri.path, '/api/v1/message/read');
    final body = jsonDecode(utf8.decode(apiTransport.lastRequest!.bodyBytes!));
    expect(body['block'], 'world_apply');
    expect(body.containsKey('category'), isFalse);
    expect(body.containsKey('notification_ids'), isFalse);
  });

  test(
    'v1 direct message conversations supports after_message_id cursor',
    () async {
      final apiTransport = _FakeTransport(
        handler: (_) => const TransportResponse(
          statusCode: 200,
          headers: {'content-type': 'application/json'},
          body: '{"err_no":0,"err_msg":"succ","data":{"list":[]}}',
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
      await api.v1.dm.conversations(
        pn: 2,
        rn: 20,
        afterMessageId: 'DM_CURSOR_001',
      );

      expect(apiTransport.lastRequest!.method, 'GET');
      expect(
        apiTransport.lastRequest!.uri.path,
        '/api/v1/direct_message/conversations',
      );
      expect(
        apiTransport.lastRequest!.uri.queryParameters.containsKey('pn'),
        isFalse,
      );
      expect(
        apiTransport.lastRequest!.uri.queryParameters.containsKey('rn'),
        isFalse,
      );
      expect(
        apiTransport.lastRequest!.uri.queryParameters['after_message_id'],
        'DM_CURSOR_001',
      );
    },
  );

  test('v1 API throws ApiException when err_no is non-zero', () async {
    final apiTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"err_no":1001,"err_msg":"bad request","data":{}}',
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

    expect(
      () => api.v1.user.info(),
      throwsA(
        isA<ApiException>().having((e) => e.message, 'message', 'bad request'),
      ),
    );
  });

  test(
    'v1 discuss list uses Apifox query and normalizes response keys',
    () async {
      final apiTransport = _FakeTransport(
        handler: (_) => const TransportResponse(
          statusCode: 200,
          headers: {'content-type': 'application/json'},
          body:
              '{"errNo":0,"errStr":"success","data":{"list":[{"comment":{"discussId":"dis_001","isLiked":true,"likeCnt":11},"latestReplies":[{"discussId":"dis_002","rootDiscussId":"dis_001"}]}],"topTotal":1,"totalAll":2,"pn":1,"rn":20}}',
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
      final result = await api.v1.discuss.list(bizId: 'ori_001', pn: 1, rn: 20);

      expect(apiTransport.lastRequest!.method, 'GET');
      expect(apiTransport.lastRequest!.uri.path, '/api/v1/discuss/list');
      expect(apiTransport.lastRequest!.uri.queryParameters['biz_type'], '1');
      expect(
        apiTransport.lastRequest!.uri.queryParameters['biz_id'],
        'ori_001',
      );
      expect(
        apiTransport.lastRequest!.uri.queryParameters.containsKey('bizType'),
        isFalse,
      );
      final item = (result['list'] as List).first as Map<String, dynamic>;
      final comment = item['comment'] as Map<String, dynamic>;
      expect(comment['discuss_id'], 'dis_001');
      expect(comment['is_liked'], isTrue);
      expect(comment['like_cnt'], 11);
      expect(comment.containsKey('discussId'), isFalse);
      final replies = item['latest_replies'] as List;
      expect((replies.first as Map)['discuss_id'], 'dis_002');
      expect(result['top_total'], 1);
      expect(result['total_all'], 2);
    },
  );

  test('v1 discuss write APIs use Apifox paths and body fields', () async {
    final apiTransport = _FakeTransport(
      handler: (request) {
        if (request.uri.path.endsWith('/discuss/post')) {
          return const TransportResponse(
            statusCode: 200,
            headers: {'content-type': 'application/json'},
            body:
                '{"err_no":0,"err_msg":"succ","data":{"discuss_id":"dis_new","root_discuss_id":"dis_root","level":2}}',
          );
        }
        return const TransportResponse(
          statusCode: 200,
          headers: {'content-type': 'application/json'},
          body: '{"err_no":0,"err_msg":"succ","data":{}}',
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
    final created = await api.v1.discuss.post(
      bizId: 'ori_001',
      content: 'reply',
      images: const ['https://cdn.example.com/discuss/a.jpg'],
      rootDiscussId: 'dis_root',
      parentDiscussId: 'dis_parent',
    );

    expect(created['discuss_id'], 'dis_new');
    expect(apiTransport.lastRequest!.uri.path, '/api/v1/discuss/post');
    final postBody = jsonDecode(
      utf8.decode(apiTransport.lastRequest!.bodyBytes!),
    );
    expect(postBody['biz_type'], 1);
    expect(postBody['biz_id'], 'ori_001');
    expect(postBody['root_discuss_id'], 'dis_root');
    expect(postBody['parent_discuss_id'], 'dis_parent');
    expect(postBody.containsKey('rootDiscussId'), isFalse);

    await api.v1.discuss.like(discussId: 'dis_new');
    expect(apiTransport.lastRequest!.uri.path, '/api/v1/discuss/like');
    final likeBody = jsonDecode(
      utf8.decode(apiTransport.lastRequest!.bodyBytes!),
    );
    expect(likeBody, {'discuss_id': 'dis_new'});

    await api.v1.discuss.unlike(discussId: 'dis_new');
    expect(apiTransport.lastRequest!.uri.path, '/api/v1/discuss/unlike');

    await api.v1.discuss.delete(discussId: 'dis_new');
    expect(apiTransport.lastRequest!.uri.path, '/api/v1/discuss/delete');
    final deleteBody = jsonDecode(
      utf8.decode(apiTransport.lastRequest!.bodyBytes!),
    );
    expect(deleteBody, {'discuss_id': 'dis_new'});
  });

  test('v1 upload uses multipart body through ApiClient transport', () async {
    final apiTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body:
            '{"err_no":0,"err_str":"success","data":{"file_url":"https://cdn/x.png"}}',
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
    final result = await api.v1.common.uploadFile(
      bytes: utf8.encode('abc'),
      bizType: 'avatar',
      filename: 'a.txt',
      contentType: 'text/plain',
    );

    expect(result['file_url'], 'https://cdn/x.png');
    expect(apiTransport.lastRequest!.uri.path, '/api/v1/common/upload');
    expect(
      apiTransport.lastRequest!.headers['content-type'],
      startsWith('multipart/form-data; boundary='),
    );
    final body = utf8.decode(apiTransport.lastRequest!.bodyBytes!);
    expect(body, contains('name="biz_type"'));
    expect(body, contains('avatar'));
    expect(body, contains('filename="a.txt"'));
    expect(body, contains('abc'));
  });

  test('v1 upload image uses Apifox multipart contract', () async {
    final apiTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body:
            '{"err_no":0,"err_msg":"succ","data":{"url":"https://cdn.example.com/uploads/20260526/123.jpg","object_key":"uploads/20260526/123.jpg"}}',
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
    final result = await api.v1.upload.image(
      bytes: utf8.encode('image-bytes'),
      filename: 'avatar.png',
      contentType: 'image/png',
    );

    expect(result['url'], 'https://cdn.example.com/uploads/20260526/123.jpg');
    expect(result['object_key'], 'uploads/20260526/123.jpg');
    expect(apiTransport.lastRequest!.method, 'POST');
    expect(apiTransport.lastRequest!.uri.path, '/api/v1/upload/image');
    expect(
      apiTransport.lastRequest!.headers['content-type'],
      startsWith('multipart/form-data; boundary='),
    );
    final body = utf8.decode(apiTransport.lastRequest!.bodyBytes!);
    expect(body, contains('name="file"; filename="avatar.png"'));
    expect(body, contains('Content-Type: image/png'));
    expect(body, isNot(contains('name="biz_type"')));
  });
}

class _TestPlatformConfig implements PlatformConfig {
  const _TestPlatformConfig(
    this.platformHeader, {
    this.apiBaseUrl = GenesisApi.defaultApiBaseUrl,
  });

  @override
  final String platformHeader;

  @override
  final String apiBaseUrl;

  @override
  String get assetBaseUrl => GenesisApi.defaultAssetBaseUrl;
}

class _TestDeviceIdService implements DeviceIdService {
  const _TestDeviceIdService();

  @override
  Future<String> getDeviceId() async => 'test-device-id';
}

class _FakeIdentityAuthService implements IdentityAuthService {
  int signOutCount = 0;

  @override
  IdentityProfile? currentProfile() => null;

  @override
  bool hasLocalIdentitySession() => false;

  @override
  Future<AuthSession?> refreshSilently() async => null;

  @override
  Future<AuthSession> signIn() {
    throw UnimplementedError();
  }

  @override
  Future<void> signOutIdentity() async {
    signOutCount += 1;
  }
}
