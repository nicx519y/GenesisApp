import 'package:genesis_flutter_android/app/qa/hooks/android%253Aqa.login.sheet%253Avisible/contract_fixture.dart';
import 'package:genesis_flutter_android/platform/session/user_session_store.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/qa/qa_bridge.dart';
import 'package:genesis_flutter_android/app/qa/fixtures/personalization/fixture.dart';
import 'package:genesis_flutter_android/platform/session/memory_user_session_store.dart';

void main() {
  test(
    'contract profile preparation restores snapshot and cannot enter Case dispatch',
    () async {
      final store = MemoryUserSessionStore();
      Map<String, Object?>? profile;
      final fixture = PersonalizationFixture(
        identity: store.readLoginUid,
        owner: () async => 'guest',
        snapshot: (_) => profile,
        write: (_, value) => profile = value,
        observed: () => {'loaded': true, ...?profile},
      );
      final bridge = QaBridge(
        store,
        token: 'secret',
        buildId: 'build',
        operations: {
          for (final op in ['prepare', 'read', 'restore'])
            'fixture.personalization.$op': (p, started) =>
                fixture.call(op, p, started),
        },
      );
      registerQaHook('contract.loginSheet.personalization.prepare', prepareLoginSheetContract, 'before_start');
      registerQaHook('contract.loginSheet.personalization.read', readLoginSheetContract);
      registerQaHook('contract.loginSheet.personalization.restore', restoreLoginSheetContract, 'any');
      QaBridge.current = bridge;
      await bridge.listen(port: 0);
      final client = HttpClient();
      Future<(int, Map<String, dynamic>)> call(
        String name, {
        Map<String, Object?> parameters = const {},
        String token = 'secret',
        String build = 'build',
        String? resource,
      }) async {
        final request = await client.postUrl(
          Uri.parse('http://127.0.0.1:${bridge.port}/qa'),
        );
        request.headers.set('authorization', 'Bearer $token');
        request.write(
          jsonEncode({
            'requestId': 'r',
            'buildId': build,
            'interface': name,
            'parameters': parameters,
            if (resource != null) 'resource': resource,
          }),
        );
        final response = await request.close();
        return (
          response.statusCode,
          jsonDecode(await utf8.decoder.bind(response).join())
              as Map<String, dynamic>,
        );
      }

      const prepare = 'contract.loginSheet.personalization.prepare';
      const parameters = {
        'runId': 'run',
        'version': 1,
        'mode': 'completed',
        'gender': 'Male',
        'age': '18-24',
      };
      try {
        expect((await call(prepare, parameters: parameters)).$1, 400);
        expect((await call('session.local.prepare')).$1, 200);
        expect(
          (await call(prepare, parameters: parameters, token: 'wrong')).$1,
          403,
        );
        expect(
          (await call(prepare, parameters: parameters, build: 'stale')).$1,
          400,
        );
        expect(
          (await call(prepare, parameters: parameters, resource: 'foreign')).$1,
          400,
        );
        expect(profile, null);
        expect(
          (await call(
            'fixture.personalization.prepare',
            parameters: parameters,
          )).$1,
          400,
        );
        final result = await call(prepare, parameters: parameters);
        expect(result.$1, 200);
        expect(result.$2['actual']['identityUnchanged'], true);
        expect(profile?['completed'], true);
        expect((await call('app.startup.continue')).$1, 400);
        expect((await call('app.startup.resume')).$1, 200);
        bridge.started = true;
        final read = await call(
          'contract.loginSheet.personalization.read',
          parameters: {'runId': 'run'},
        );
        expect(read.$2['actual']['observed']['completed'], true);
        expect(
          (await call(
            'contract.loginSheet.personalization.restore',
            parameters: {'runId': 'other'},
          )).$1,
          400,
        );
        final restored = await call(
          'contract.loginSheet.personalization.restore',
          parameters: {'runId': 'run'},
        );
        expect(restored.$2['actual']['restored'], true);
        expect(profile, null);
        expect(await store.readLoginUid(), null);
        expect(
          (await call(
            prepare,
            parameters: {...parameters, 'runId': 'late'},
          )).$1,
          400,
        );
      } finally {
        client.close(force: true);
        await bridge.close();
      }
    },
  );
}
