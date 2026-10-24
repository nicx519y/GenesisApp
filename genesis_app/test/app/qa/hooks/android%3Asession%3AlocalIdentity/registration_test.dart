import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/qa/qa_bridge.dart';
import 'package:genesis_flutter_android/app/qa/hooks/android%253Asession%253AlocalIdentity/registration.dart';
import 'package:genesis_flutter_android/platform/session/memory_user_session_store.dart';

void main() {
  test('registered package URI segments resolve to physical hook files', () {
    // Compiling this test also imports the production bridge and handler above.
    // Check decoded URI segments, not the raw string as a filesystem path.
    final bridgeSource = File('lib/app/qa/qa_bridge.dart').readAsStringSync();
    final imports = RegExp("import '([^']*hooks/[^']+)';")
        .allMatches(bridgeSource)
        .map((match) => Uri.parse(match.group(1)!))
        .toList();
    expect(imports, isNotEmpty);
    for (final uri in imports) {
      expect(uri.scheme, 'package');
      expect(uri.pathSegments.first, 'genesis_flutter_android');
      final path = uri.pathSegments.skip(1).join('/');
      expect(path, contains('%3A'));
      expect(File('lib/$path').existsSync(), isTrue, reason: '$uri');
      expect(File('lib/${Uri.decodeComponent(path)}').existsSync(), isFalse);
    }
  });

  test('identity registration preserves source and rejects foreign sessions', () async {
    const mock = String.fromEnvironment('GENESIS_API_ENV') == 'mock';
    registerQaHook('fixture.localIdentity.prepare', prepareIdentityCase);
    registerQaHook('fixture.localIdentity.cleanup', cleanupIdentityCase, 'any');
    registerQaHook('observe.localIdentity.read', readLocalIdentity, 'any');
    registerQaHook('contract.localIdentity.prepare', prepareIdentityContract, 'any');
    registerQaHook('contract.localIdentity.read', readIdentityContract, 'any');
    registerQaHook('contract.localIdentity.cleanup', cleanupIdentityContract, 'any');
    final store = MemoryUserSessionStore();
    await store.saveUid('original');
    await store.saveAuthToken('original-token');
    await store.saveUserInfo({'name': 'original'});
    final bridge = QaBridge(store, token: 'identity-test', buildId: 'identity-build');
    QaBridge.current = bridge;
    await bridge.listen(port: 0);
    final client = HttpClient();
    Future<(int, Map<String, dynamic>)> send(String id, {
      Map<String, dynamic> parameters = const {},
      String? resource,
      String token = 'identity-test',
    }) async {
      final request = await client.postUrl(Uri.parse('http://127.0.0.1:${bridge.port}/qa'));
      request.headers.set('authorization', 'Bearer $token');
      request.write(jsonEncode({
        'interface': id, 'parameters': parameters, 'requestId': 'identity-test',
        'buildId': 'identity-build', 'resource': resource ?? bridge.resource,
      }));
      final response = await request.close();
      return (response.statusCode,
        jsonDecode(await response.transform(utf8.decoder).join()) as Map<String, dynamic>);
    }
    try {
      expect((await send('observe.localIdentity.read')).$2['actual'], 'original');
      expect((await send('fixture.localIdentity.prepare')).$1, 400);
      bridge.started = true;
      expect((await send('fixture.localIdentity.prepare', token: 'foreign')).$1, 403);
      expect((await send('fixture.localIdentity.prepare', resource: 'foreign')).$1, 400);
      expect((await send('contract.localIdentity.prepare')).$1, 400);
      expect(await store.readUid(), 'original');
      if (!mock) {
        expect((await send('fixture.localIdentity.prepare')).$1, 400);
        expect((await send('fixture.localIdentity.cleanup')).$1, 400);
        expect(await store.readAuthToken(), 'original-token');
        return;
      }
      final prepared = await send('fixture.localIdentity.prepare');
      expect(prepared.$1, 200);
      expect(prepared.$2['actual'], 'qa_test_${bridge.resource}');
      for (var i = 0; i < 2; i++) {
        expect((await send('observe.localIdentity.read')).$2['actual'], prepared.$2['actual']);
      }
      expect((await send('fixture.localIdentity.prepare', parameters: {'uid': null})).$2['actual'], null);
      expect((await send('observe.localIdentity.read')).$2['actual'], null);
      expect((await send('fixture.localIdentity.cleanup')).$2['actual'], 'restored');
      expect(await store.readUid(), 'original');
      expect(await store.readAuthToken(), 'original-token');
      expect(await store.readUserInfo(), {'name': 'original'});
      expect((await send('fixture.localIdentity.cleanup')).$2['actual'], 'restored');
      bridge.started = false;
      expect((await send('session.local.prepare')).$1, 200);
      bridge.started = true;
      expect((await send('fixture.localIdentity.prepare')).$1, 400);
      expect((await send('fixture.localIdentity.cleanup')).$1, 400);
      expect((await send('contract.localIdentity.prepare')).$1, 200);
      expect((await send('contract.localIdentity.read')).$2['actual'], 'qa_test_${bridge.resource}');
      expect((await send('contract.localIdentity.cleanup')).$2['actual'], 'restored');
      expect(await store.readUid(), null);
    } finally {
      // Restore any partial override before releasing the bridge and HTTP client.
      try {
        if (mock) await cleanupIdentityCase({}, false, bridge.started);
      } finally {
        client.close(force: true);
        await bridge.close();
      }
    }
  });
}
