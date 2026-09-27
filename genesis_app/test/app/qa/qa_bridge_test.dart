import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/qa/qa_bridge.dart';
import 'package:genesis_flutter_android/platform/session/memory_user_session_store.dart';
import 'package:genesis_flutter_android/platform/session/user_session_store.dart';

void main() {
  test('production and release never expose the bridge', () {
    expect(
      qaBridgeAllowed(debug: false, flavor: 'internal', enabled: true),
      false,
    );
    expect(
      qaBridgeAllowed(debug: true, flavor: 'production', enabled: true),
      false,
    );
    expect(
      qaBridgeAllowed(debug: true, flavor: 'internal', enabled: false),
      false,
    );
    expect(
      qaBridgeAllowed(debug: true, flavor: 'internal', enabled: true),
      true,
    );
  });
  test('normal Case startup preserves existing identity and does not claim a frame', () async {
    final store = MemoryUserSessionStore();
    await store.saveUid('qa_test_existing');
    final bridge = QaBridge(store, token: 'test-secret', buildId: 'test-build');
    await bridge.waitForStartup(hold: false);
    expect(await store.readLoginUid(), 'qa_test_existing');
    expect(bridge.started, false);
  });
  test(
    'authenticated observations use the injected instance and reject stale builds',
    () async {
      final store = MemoryUserSessionStore();
      await store.saveUid('qa_test_user');
      final bridge = QaBridge(
        store,
        token: 'test-secret',
        buildId: 'test-build',
      );
      await bridge.listen(port: 0);
      final client = HttpClient();
      Future<(int, Map<String, dynamic>)> request(
        String interface, {
        String token = 'test-secret',
        String build = 'test-build',
        String? resource,
      }) async {
        final q = await client.postUrl(
          Uri.parse('http://127.0.0.1:${bridge.port}/qa'),
        );
        q.headers.set('authorization', 'Bearer $token');
        q.write(
          jsonEncode({
            'requestId': 'r',
            'buildId': build,
            'interface': interface,
            if (resource != null) 'resource': resource,
          }),
        );
        final r = await q.close();
        return (
          r.statusCode,
          jsonDecode(await utf8.decoder.bind(r).join()) as Map<String, dynamic>,
        );
      }

      try {
        expect(
          (await request('session.local.read')).$2['actual'],
          'qa_test_user',
        );
        await store.clearUid();
        expect((await request('session.local.read')).$2['actual'], null);
        expect((await request('session.local.read', token: 'wrong')).$1, 403);
        expect((await request('session.local.read', build: 'old')).$1, 400);
        expect(
          (await request('session.local.read', resource: 'other')).$1,
          400,
        );
        expect((await request('app.startup.resume')).$1, 400);
        expect((await request('arbitrary.code')).$1, 400);
      } finally {
        client.close(force: true);
        await bridge.close();
      }
    },
  );
}
