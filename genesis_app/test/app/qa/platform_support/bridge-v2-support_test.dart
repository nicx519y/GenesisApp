import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/qa/qa_bridge.dart';
import 'package:genesis_flutter_android/platform/session/memory_user_session_store.dart';
import 'package:genesis_flutter_android/platform/session/user_session_store.dart';

void main() {
  test('contract phases retain authentication, mock preparation and Case isolation', () async {
    var calls = 0;
    Future<Object?> invoke(Map<String, dynamic> p, bool prepared, bool started) async { calls++; return prepared; }
    registerQaHook('contract.before_probe', invoke, 'before_start');
    registerQaHook('contract.after_probe', invoke);
    registerQaHook('contract.restore_probe', invoke, 'any');
    final store = MemoryUserSessionStore();
    final bridge = QaBridge(store, token: 'probe-secret', buildId: 'probe-build');
    await bridge.listen(port: 0);
    final client = HttpClient();
    Future<int> send(String operation, {String token = 'probe-secret', String build = 'probe-build', String? resource}) async {
      final request = await client.postUrl(Uri.parse('http://127.0.0.1:${bridge.port}/qa'));
      request.headers.set('authorization', 'Bearer $token');
      request.write(jsonEncode({'requestId': 'probe', 'buildId': build, 'interface': operation,
        'parameters': <String, dynamic>{}, if(resource != null) 'resource': resource}));
      final response = await request.close(); await response.drain<void>(); return response.statusCode;
    }
    try {
      expect(await send('contract.before_probe', token: 'wrong'), 403);
      expect(await send('contract.before_probe', build: 'stale'), 400);
      expect(await send('contract.before_probe', resource: 'foreign'), 400);
      expect(await send('contract.before_probe'), 400); expect(calls, 0);
      expect(await send('session.local.prepare'), 200);
      expect(await send('contract.before_probe'), 200);
      expect(await send('contract.after_probe'), 400);
      expect(await send('contract.restore_probe'), 200);
      bridge.started = true;
      expect(await send('contract.before_probe'), 400);
      expect(await send('contract.after_probe'), 200);
      expect(await send('app.startup.continue'), 400);
      expect(await send('session.local.cleanup'), 200);
      expect(await store.readLoginUid(), null);
    } finally {client.close(force: true); await bridge.close();}
  });
  test('real log observation forwards existing output and cannot be forged over HTTP', () async {
    String? observed;
    registerQaHook('log.platform_probe', (p, prepared, started) async {observed = p['message'] as String?; return null;}, 'any');
    registerQaHook('observe.platform_probe', (p, prepared, started) async => observed, 'any');
    final original = debugPrint;
    final bridge = QaBridge(MemoryUserSessionStore(), token: 'probe-secret', buildId: 'probe-build');
    QaBridge.current = bridge; installQaLogObservation(); await bridge.listen(port: 0);
    final client = HttpClient();
    Future<(int, Map<String, dynamic>)> send(String operation) async {
      final request = await client.postUrl(Uri.parse('http://127.0.0.1:${bridge.port}/qa'));
      request.headers.set('authorization', 'Bearer probe-secret');
      request.write(jsonEncode({'requestId': 'probe', 'buildId': 'probe-build', 'interface': operation, 'parameters': {'message':'forged'}}));
      final response=await request.close();return (response.statusCode,jsonDecode(await response.transform(utf8.decoder).join()) as Map<String,dynamic>);
    }
    try {
      expect((await send('log.platform_probe')).$1, 400);expect(observed, null);
      debugPrint('real observation'); await Future<void>.delayed(Duration.zero);
      expect((await send('observe.platform_probe')).$2['actual'], 'real observation');
    } finally {client.close(force: true);await bridge.close();}
    expect(debugPrint, same(original));
  });
  test('reserved interfaces, invalid phases and duplicates remain unavailable', () {
    Future<Object?> callback(Map<String,dynamic> p,bool a,bool b) async => true;
    expect(()=>registerQaHook('session.local.read',callback), throwsArgumentError);
    expect(()=>registerQaHook('contract.invalid_phase',callback,'invalid'), throwsArgumentError);
    registerQaHook('contract.unique_v2',callback);
    expect(()=>registerQaHook('contract.unique_v2',callback), throwsStateError);
  });
}
