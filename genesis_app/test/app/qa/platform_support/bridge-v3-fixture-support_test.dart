import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/qa/qa_bridge.dart';
import 'package:genesis_flutter_android/platform/session/memory_user_session_store.dart';
import 'package:genesis_flutter_android/platform/session/user_session_store.dart';

void main() {
  test('Case fixtures require mock, matching identity, phase and a fresh Case session', () async {
    const mock = String.fromEnvironment('GENESIS_API_ENV') == 'mock';
    final store = MemoryUserSessionStore();
    await store.saveUid('original-identity');
    String? previous;
    var prepared = false;
    var calls = 0;
    registerQaHook('fixture.platform_v3.prepare', (p, contract, started) async {
      calls++;
      if (!prepared) previous = await store.readLoginUid();
      prepared = true;
      await store.saveUid('qa_test_isolated');
      return store.readLoginUid();
    });
    registerQaHook('fixture.platform_v3.read', (p, contract, started) async {
      calls++; return store.readLoginUid();
    });
    registerQaHook('fixture.platform_v3.cleanup', (p, contract, started) async {
      calls++;
      if (prepared) {
        await store.clearUid();
        if (previous != null) await store.saveUid(previous!);
        prepared = false;
      }
      return store.readLoginUid();
    }, 'any');
    final bridge = QaBridge(store, token: 'fixture-secret', buildId: 'fixture-build');
    await bridge.listen(port: 0);
    final client = HttpClient();
    Future<(int, Map<String,dynamic>)> send(String operation, {
      String token = 'fixture-secret', String build = 'fixture-build',
      String? resource, bool omitResource = false,
    }) async {
      final request = await client.postUrl(Uri.parse('http://127.0.0.1:${bridge.port}/qa'));
      request.headers.set('authorization', 'Bearer $token');
      request.write(jsonEncode({'requestId':'fixture-request','buildId':build,
        'interface':operation,'parameters':<String,dynamic>{},
        if (!omitResource) 'resource':resource ?? bridge.resource}));
      final response = await request.close();
      return (response.statusCode, jsonDecode(await response.transform(utf8.decoder).join()) as Map<String,dynamic>);
    }
    try {
      expect((await send('fixture.platform_v3.prepare')).$1,400); // not started
      bridge.started = true;
      expect((await send('fixture.platform_v3.prepare',token:'foreign')).$1,403);
      expect((await send('fixture.platform_v3.prepare',build:'foreign')).$1,400);
      expect((await send('fixture.platform_v3.prepare',resource:'foreign')).$1,400);
      expect((await send('fixture.platform_v3.prepare',omitResource:true)).$1,400);
      expect(calls,0);
      expect(await store.readLoginUid(),'original-identity');
      if (!mock) {
        for (final op in ['prepare','read','cleanup']) {
          expect((await send('fixture.platform_v3.$op')).$1,400);
        }
        expect(calls,0); expect(await store.readLoginUid(),'original-identity');
        return;
      }
      expect((await send('fixture.platform_v3.prepare')).$2['actual'],'qa_test_isolated');
      expect((await send('fixture.platform_v3.read')).$2['actual'],'qa_test_isolated');
      expect((await send('fixture.platform_v3.cleanup')).$2['actual'],'original-identity');
      expect((await send('fixture.platform_v3.cleanup')).$2['actual'],'original-identity');
      bridge.started = false;
      expect((await send('session.local.prepare')).$1,200);
      bridge.started = true;
      final before = calls;
      for (final op in ['prepare','read','cleanup']) {
        expect((await send('fixture.platform_v3.$op')).$1,400);
      }
      expect(calls,before); // contract state must never leak into a Case
      expect((await send('session.local.cleanup')).$1,200);
    } finally { client.close(force:true); await bridge.close(); }
  });
}
