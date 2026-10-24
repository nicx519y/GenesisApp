import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/qa/qa_bridge.dart';
import 'package:genesis_flutter_android/app/qa/fixtures/http/mock_response_overrides.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';
import 'package:genesis_flutter_android/platform/session/memory_user_session_store.dart';
import 'package:genesis_flutter_android/app/qa/hooks/android%253Amessages.private.empty_state%253Avisible/contract_fixture.dart';

void main() {
  test('contract gate rejects Case and started preparation', () async {
    await expectLater(prepareEmptyContract({}, false, false), throwsStateError);
    await expectLater(prepareEmptyContract({}, true, true), throwsStateError);
  });
  for (final priorToken in <String?>[null, 'qa_mock_previous']) {
    test('actual response lease and session restore: $priorToken', () async {
      final store = MemoryUserSessionStore();
      await store.saveUid('qa_test_empty');
      if (priorToken != null) await store.saveAuthToken(priorToken);
      await store.saveUserInfo({'uid': 'qa_test_empty', 'name': 'prior'});
      final bridge = QaBridge(store, token: 'token', buildId: 'build');
      QaBridge.current = bridge;
      final request = TransportRequest(
        method: 'GET',
        uri: Uri.parse('https://qa.invalid/api/v1/direct_message/conversations'),
        headers: const {},
        bodyBytes: null,
        timeoutMs: 1,
      );
      try {
        if (!QaMockResponseOverrides.enabled) {
          await expectLater(
            prepareEmptyContract({}, true, false),
            throwsStateError,
          );
          return;
        }
        expect(await prepareEmptyContract({}, true, false), {
          'owner': 'qa_test_empty',
          'resource': bridge.resource,
          'backendSessionReady': true,
        });
        expect((await store.readAuthToken())?.isNotEmpty, isTrue);
        final response = await QaMockResponseOverrides.respond(request);
        expect(jsonDecode(response!.body)['data']['list'], isEmpty);
        await expectLater(
          prepareEmptyContract({}, true, false),
          throwsStateError,
        );
        await store.saveUid('qa_test_other');
        await expectLater(
          QaMockResponseOverrides.respond(request),
          throwsStateError,
        );
        await store.saveUid('qa_test_empty');
      } finally {
        expect(await restoreEmptyContract({}, true, false), {'restored': true});
        expect(await QaMockResponseOverrides.respond(request), isNull);
        expect(await store.readAuthToken(), priorToken);
        expect(await store.readUserInfo(), {'uid': 'qa_test_empty', 'name': 'prior'});
        expect(await store.readUid(), 'qa_test_empty');
        await bridge.close();
        await store.clearUid();
      }
    });
  }
}
