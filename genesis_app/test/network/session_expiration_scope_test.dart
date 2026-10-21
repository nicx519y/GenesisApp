import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/api_exception.dart';
import 'package:genesis_flutter_android/network/genesis_api.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';
import 'package:genesis_flutter_android/platform/auth/backend_auth_coordinator.dart';
import 'package:genesis_flutter_android/platform/auth/identity_auth_service.dart';
import 'package:genesis_flutter_android/platform/auth/auth_session.dart';
import 'package:genesis_flutter_android/platform/session/memory_user_session_store.dart';

const _expired = TransportResponse(
  statusCode: 200,
  headers: {'content-type': 'application/json'},
  body: '{"err_no":10001,"err_msg":"ErrorUserNotLogin","data":{}}',
);

class _Transport implements HttpTransport {
  _Transport(this.respond);
  final FutureOr<TransportResponse> Function(TransportRequest) respond;

  @override
  Future<TransportResponse> send(TransportRequest request) async =>
      respond(request);
}

class _Identity implements IdentityAuthService {
  @override
  Future<AuthSession> signIn(IdentityProvider provider) async =>
      throw UnsupportedError('Sign-in is not used by these tests');

  @override
  Future<AuthSession?> refreshSilently() async => null;

  @override
  Future<void> signOutIdentity() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('session expiry scope', () {
    for (final uid in <String?>[null, 'guest_device']) {
      test('unauthenticated 10001 does not expire a session: $uid', () async {
        final store = MemoryUserSessionStore();
        if (uid != null) {
          await store.saveUid(uid);
          await store.saveAuthToken('guest-token');
        }
        var notifications = 0;
        final api = GenesisApi(
          transport: _Transport((_) => _expired),
          useMock: false,
          sessionStore: store,
          appHeaderProvider: () async => {},
          onSessionExpired: (_) async => notifications++,
        );

        await expectLater(
          api.v1.search.suggest(query: 'abc'),
          throwsA(isA<ApiException>().having((e) => e.code, 'code', 10001)),
        );
        await Future<void>.delayed(Duration.zero);
        expect(notifications, 0);
      });
    }

    test('current authenticated request still expires its session', () async {
      final store = MemoryUserSessionStore();
      await store.saveUid('user-a');
      await store.saveAuthToken('token-a');
      var notifications = 0;
      final api = GenesisApi(
        transport: _Transport((_) => _expired),
        useMock: false,
        sessionStore: store,
        appHeaderProvider: () async => {},
        onSessionExpired: (_) async => notifications++,
      );

      await expectLater(
        api.v1.search.suggest(query: 'abc'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 10001)),
      );
      await Future<void>.delayed(Duration.zero);
      expect(notifications, 1);
    });

    for (final nextSession in ['logged-out', 'new-login', 'refreshed-token']) {
      test('late 10001 is ignored after $nextSession', () async {
        final store = MemoryUserSessionStore();
        await store.saveUid('user-a');
        await store.saveAuthToken('token-a');
        final sent = Completer<void>();
        final response = Completer<TransportResponse>();
        var notifications = 0;
        final api = GenesisApi(
          transport: _Transport((request) {
            expect(request.headers['authorization'], 'Bearer token-a');
            sent.complete();
            return response.future;
          }),
          useMock: false,
          sessionStore: store,
          appHeaderProvider: () async => {},
          onSessionExpired: (_) async => notifications++,
        );
        final result = expectLater(
          api.v1.search.suggest(query: 'abc'),
          throwsA(isA<ApiException>().having((e) => e.code, 'code', 10001)),
        );
        await sent.future;
        if (nextSession != 'refreshed-token') await store.clearUid();
        if (nextSession == 'new-login') await store.saveUid('user-b');
        if (nextSession != 'logged-out') await store.saveAuthToken('token-b');
        response.complete(_expired);
        await result;
        await Future<void>.delayed(Duration.zero);

        expect(notifications, 0);
        expect(
          await store.readUid(),
          nextSession == 'logged-out'
              ? null
              : nextSession == 'new-login'
              ? 'user-b'
              : 'user-a',
        );
      });
    }

    test('unauthenticated request cannot expire a later login', () async {
      final store = MemoryUserSessionStore();
      final sent = Completer<void>();
      final response = Completer<TransportResponse>();
      var notifications = 0;
      final api = GenesisApi(
        transport: _Transport((request) {
          expect(request.headers['authorization'], isNull);
          sent.complete();
          return response.future;
        }),
        useMock: false,
        sessionStore: store,
        appHeaderProvider: () async => {},
        onSessionExpired: (_) async => notifications++,
      );
      final result = expectLater(
        api.v1.search.suggest(query: 'abc'),
        throwsA(isA<ApiException>()),
      );
      await sent.future;
      await store.saveUid('user-a');
      await store.saveAuthToken('token-a');
      response.complete(_expired);
      await result;
      await Future<void>.delayed(Duration.zero);
      expect(notifications, 0);
    });

    test('logout endpoint cannot trigger forced session expiry', () async {
      final store = MemoryUserSessionStore();
      await store.saveUid('user-a');
      await store.saveAuthToken('token-a');
      var notifications = 0;
      final api = GenesisApi(
        transport: _Transport((_) => _expired),
        useMock: false,
        sessionStore: store,
        appHeaderProvider: () async => {},
        onSessionExpired: (_) async => notifications++,
      );
      await expectLater(api.logout(), throwsA(isA<ApiException>()));
      await Future<void>.delayed(Duration.zero);
      expect(notifications, 0);
    });

    test('normal signOut ignores a delayed logout 10001', () async {
      final store = MemoryUserSessionStore();
      await store.saveUid('user-a');
      await store.saveAuthToken('token-a');
      final sent = Completer<void>();
      final response = Completer<TransportResponse>();
      var notifications = 0;
      final identity = _Identity();
      final api = GenesisApi(
        transport: _Transport((request) {
          expect(request.uri.path, '/api/v1/user/logout');
          expect(request.headers['authorization'], 'Bearer token-a');
          sent.complete();
          return response.future;
        }),
        useMock: false,
        sessionStore: store,
        appHeaderProvider: () async => {},
        onSessionExpired: (_) async => notifications++,
      );
      final coordinator = GenesisBackendAuthCoordinator(
        api: api,
        identityAuth: identity,
        sessionStore: store,
      );
      await coordinator.signOut();
      await sent.future;
      expect(await store.readUid(), isNull);
      response.complete(_expired);
      await Future<void>.delayed(Duration.zero);
      expect(notifications, 0);
    });
  });
}
