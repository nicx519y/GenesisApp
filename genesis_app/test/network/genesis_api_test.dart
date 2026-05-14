import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/config/platform_config.dart';
import 'package:genesis_flutter_android/network/api_client.dart';
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

  test('default client uses configurable API base URL', () async {
    final apiTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"origins":[]}',
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
      'https://example.test/api/origins',
    );
  });

  test(
    'default client injects device user and authorization headers',
    () async {
      final apiTransport = _FakeTransport(
        handler: (_) => const TransportResponse(
          statusCode: 200,
          headers: {'content-type': 'application/json'},
          body: '{"origins":[]}',
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

      expect(
        apiTransport.lastRequest!.headers['x-device-id'],
        'test-device-id',
      );
      expect(apiTransport.lastRequest!.headers['x-user-id'], 'u_1');
      expect(
        apiTransport.lastRequest!.headers['authorization'],
        'Bearer backend-token',
      );
    },
  );

  test(
    'loginWithGoogle stores backend token for later default auth header',
    () async {
      late final MemoryUserSessionStore sessionStore;
      final apiTransport = _FakeTransport(
        handler: (request) {
          if (request.uri.path.endsWith('/auth/google')) {
            return const TransportResponse(
              statusCode: 200,
              headers: {'content-type': 'application/json'},
              body:
                  '{"token":"backend-token","user":{"id":"u_2","display_name":"Neo"}}',
            );
          }
          return const TransportResponse(
            statusCode: 200,
            headers: {'content-type': 'application/json'},
            body: '{"origins":[]}',
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

      await api.loginWithGoogle(idToken: 'google-token');
      expect(await sessionStore.readUid(), 'u_2');
      expect(await sessionStore.readAuthToken(), 'backend-token');

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
        if (request.uri.path.endsWith('/auth/apple')) {
          final body =
              jsonDecode(utf8.decode(request.bodyBytes ?? const [])) as Map;
          expect(body['id_token'], 'apple-token');
          expect(body['firebase_id_token'], 'firebase-token');
          return const TransportResponse(
            statusCode: 200,
            headers: {'content-type': 'application/json'},
            body:
                '{"token":"apple-backend-token","user":{"id":"apple_uid","display_name":"Ava"}}',
          );
        }
        return const TransportResponse(
          statusCode: 200,
          headers: {'content-type': 'application/json'},
          body: '{"origins":[]}',
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
  });

  test(
    'backend signOut posts logout then clears identity and local session',
    () async {
      final apiTransport = _FakeTransport(
        handler: (request) {
          if (request.uri.path.endsWith('/auth/logout')) {
            expect(request.method, 'POST');
            expect(request.headers['authorization'], 'Bearer backend-token');
            return const TransportResponse(
              statusCode: 200,
              headers: {'content-type': 'application/json'},
              body: '{"ok":true}',
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

      expect(apiTransport.requests.single.uri.path, '/api/auth/logout');
      expect(identityAuth.signOutCount, 1);
      expect(await sessionStore.readUid(), isNull);
      expect(await sessionStore.readAuthToken(), isNull);
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
    },
  );

  test('default client preserves configurable platform header', () async {
    final apiTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"origins":[]}',
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
