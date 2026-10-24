import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/qa/hooks/android%253Aworld.retry.preparation%253Avalue/lease.dart';
import 'package:genesis_flutter_android/app/qa/qa_bridge.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';
import 'package:genesis_flutter_android/platform/session/memory_user_session_store.dart';

// Inherit dart:io's real client factory without changing the surrounding
// Flutter HTTP override. This factory is only used by loopback fixture tests.
class _LoopbackHttpOverrides extends HttpOverrides {}

HttpClient _loopbackClient() => HttpOverrides.runWithHttpOverrides(
  () => HttpClient(),
  _LoopbackHttpOverrides(),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('loopback client preserves the surrounding HTTP isolation', () {
    final outer = HttpOverrides.current;
    HttpOverrides.runZoned(() {
      final guarded = HttpOverrides.current;
      expect(() => HttpClient(), throwsStateError);
      final client = _loopbackClient();
      try {
        expect(HttpOverrides.current, same(guarded));
        expect(() => HttpClient(), throwsStateError);
      } finally {
        client.close(force: true);
      }
    }, createHttpClient: (_) => throw StateError('HTTP isolation guard'));
    expect(HttpOverrides.current, same(outer));
  });
  test('no snapshot means no restoration receipt', () async {
    final bridge = QaBridge(
      MemoryUserSessionStore(),
      token: 'test',
      buildId: 'test',
    );
    await expectLater(WorldRetryLease(bridge).restore(), throwsStateError);
  });
  testWidgets(
    'actual identity snapshot, one failed response, same-world retry and real cleanup',
    (tester) async {
      final store = MemoryUserSessionStore();
      await store.saveUid('guest_before');
      await store.saveAuthToken('before-token');
      await store.saveUserInfo({'name': 'Before'});
      final bridge = QaBridge(store, token: 'test', buildId: 'test');
      QaBridge.current = bridge;
      final lease = WorldRetryLease(bridge);
      await tester.runAsync(() async {
        try {
          final receipt = await lease.prepare();
          expect(receipt['loggedIn'], true);
          expect(receipt['restorationRegistered'], true);
          expect(await store.readUid(), lease.uid);
          await expectLater(lease.prepare(), throwsStateError);
          // runAsync removes the fake clock, but not Flutter's HTTP override.
          // Only this loopback client uses real sockets; the test-wide guard stays.
          final client = _loopbackClient();
          try {
            final response = await (await client.getUrl(
              Uri.parse(lease.mapUrl),
            )).close();
            expect(response.statusCode, 200);
            expect(
              await response.fold<int>(0, (n, b) => n + b.length),
              greaterThan(0),
            );
          } finally {
            client.close(force: true);
          }
          // Exercise the same response method registered in the mock transport.
          final request = TransportRequest(
            method: 'GET',
            uri: Uri.parse(
              'http://mock/api/v1/world/detail?world_id=${lease.worldId}',
            ),
            headers: {},
            bodyBytes: null,
            timeoutMs: 1000,
          );
          final first = await lease.response(request);
          final second = await lease.response(request);
          expect(jsonDecode(first!.body)['err_no'], 503);
          expect(
            jsonDecode(second!.body)['data']['info']['world_id'],
            lease.worldId,
          );
          expect(jsonDecode(second.body)['data']['relation_status'], 'joined');
          expect(lease.detailRequests, 2);
          expect(lease.successfulResponses, 1);
          final other = TransportRequest(
            method: 'GET',
            uri: Uri.parse('http://mock/api/v1/world/detail?world_id=other'),
            headers: {},
            bodyBytes: null,
            timeoutMs: 1000,
          );
          expect(await lease.response(other), null);
          expect(lease.detailRequests, 2);
          await store.saveUid('foreign');
          await expectLater(lease.restore(), throwsStateError);
          expect(await store.readUid(), 'foreign');
          await store.saveUid(lease.uid);
        } finally {
          final restored = await lease.restore();
          for (final key in [
            'identityRestored',
            'worldDataRestored',
            'requestResponseStateRestored',
          ])
            expect(restored[key], true);
          expect(WorldRetryLease.active, null);
          expect(lease.server, null);
          expect(await store.readUid(), 'guest_before');
          expect(await store.readAuthToken(), 'before-token');
          expect(await store.readUserInfo(), {'name': 'Before'});
          QaBridge.current = null;
        }
      });
    },
  );
  testWidgets('map server serves real PNG, rejects unknown paths and closes',
      (tester) async {
    final previousBridge = QaBridge.current;
    final bridge = QaBridge(MemoryUserSessionStore(), token: 'test', buildId: 'test');
    QaBridge.current = bridge;
    final lease = WorldRetryLease(bridge);
    await tester.runAsync(() async {
      final override = HttpOverrides.current;
      final client = _loopbackClient();
      client.connectionTimeout = const Duration(seconds: 2);
      try {
        expect(HttpOverrides.current, same(override));
        await lease.prepare();
        final uri = Uri.parse(lease.mapUrl);
        final response = await (await client.getUrl(uri)).close();
        expect(response.statusCode, 200);
        expect(response.headers.contentType?.mimeType, 'image/png');
        final bytes = await response.fold<List<int>>([], (all, part) => all..addAll(part));
        expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
        final missing = await (await client.getUrl(uri.replace(path: '/missing.png'))).close();
        expect(missing.statusCode, 404);
        await missing.drain<void>();
        final restored = await lease.restore();
        expect(restored['identityRestored'], true);
        expect(restored['worldDataRestored'], true);
        expect(restored['requestResponseStateRestored'], true);
        // A fresh connection must fail after the actual listening socket closes.
        await expectLater(() async {
          final probe = _loopbackClient();
          probe.connectionTimeout = const Duration(seconds: 2);
          try {
            final request = await probe.getUrl(uri);
            await request.close();
          } finally {
            probe.close(force: true);
          }
        }, throwsA(isA<SocketException>()));
      } finally {
        client.close(force: true);
        try {
          if (lease.acquired) await lease.restore();
        } finally {
          QaBridge.current = previousBridge;
        }
      }
    });
  });

}
