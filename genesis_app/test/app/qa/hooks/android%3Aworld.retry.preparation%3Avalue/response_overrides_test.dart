import 'dart:convert';
import 'package:genesis_flutter_android/app/qa/hooks/android%253Aworld.retry.preparation%253Avalue/lease.dart';
import 'package:genesis_flutter_android/app/qa/qa_bridge.dart';
import 'package:genesis_flutter_android/platform/session/memory_user_session_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/qa/fixtures/http/mock_response_overrides.dart' as entry;
import 'package:genesis_flutter_android/app/qa/hooks/android%253Aworld.retry.preparation%253Avalue/response_overrides.dart' as owned;
import 'package:genesis_flutter_android/network/http_transport.dart';

TransportRequest request(String path) => TransportRequest(
  method: 'GET', uri: Uri.parse('http://mock$path'), headers: {},
  bodyBytes: null, timeoutMs: 1000,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('HTTP entry dispatches only the owned world and stops after cleanup', (tester) async {
    final store = MemoryUserSessionStore();
    await store.saveUid('guest_before_dispatch');
    final bridge = QaBridge(store, token: 'test', buildId: 'test');
    final previousBridge = QaBridge.current;
    QaBridge.current = bridge;
    final lease = WorldRetryLease(bridge);
    await tester.runAsync(() async {
      try {
        await lease.prepare();
        final target = request('/api/v1/world/detail?world_id=${lease.worldId}');
        if (!entry.QaMockResponseOverrides.enabled) {
          expect(await entry.QaMockResponseOverrides.respond(target), null);
          expect(lease.detailRequests, 0);
        } else {
          expect(await entry.QaMockResponseOverrides.respond(
            request('/api/v1/world/detail?world_id=foreign')), null);
          expect(lease.detailRequests, 0);
          final first = await entry.QaMockResponseOverrides.respond(target);
          expect(jsonDecode(first!.body)['err_no'], 503);
          final retry = await entry.QaMockResponseOverrides.respond(target);
          expect(jsonDecode(retry!.body)['err_no'], 0);
          expect(jsonDecode(retry.body)['data']['info']['world_id'], lease.worldId);
          expect(lease.detailRequests, 2);
          expect(lease.successfulResponses, 1);
          await store.saveUid('foreign');
          await expectLater(entry.QaMockResponseOverrides.respond(target), throwsStateError);
          expect(lease.detailRequests, 2);
          await store.saveUid(lease.uid);
        }
      } finally {
        try {
          final receipt = await lease.restore();
          expect(receipt['identityRestored'], true);
          expect(receipt['worldDataRestored'], true);
          expect(receipt['requestResponseStateRestored'], true);
          expect(lease.server, null);
          expect(WorldRetryLease.active, null);
          expect(await entry.QaMockResponseOverrides.respond(
            request('/api/v1/world/detail?world_id=${lease.worldId}')), null);
          expect(await store.readUid(), 'guest_before_dispatch');
        } finally {
          QaBridge.current = previousBridge;
        }
      }
    });
  });
  test('compatibility export retains the same guarded lease and cleanup', () async {
    expect(entry.QaMockResponseOverrides.enabled, owned.QaMockResponseOverrides.enabled);
    String owner = 'qa_test_response_owner';
    bool resourceCurrent = true;
    entry.QaMockResponseLease install() => entry.QaMockResponseOverrides.install(
      resource: 'response-resource', ownerUid: 'qa_test_response_owner',
      currentOwner: () async => owner, currentResource: () => resourceCurrent,
      responses: {'GET /qa/response': {'observed': 7}},
    );
    if (!entry.QaMockResponseOverrides.enabled) {
      expect(install, throwsStateError);
      expect(await entry.QaMockResponseOverrides.respond(request('/qa/response')), null);
      return;
    }
    final lease = install();
    try {
      expect(lease, isA<owned.QaMockResponseLease>());
      expect(install, throwsStateError);
      final actual = await owned.QaMockResponseOverrides.respond(request('/qa/response'));
      expect(jsonDecode(actual!.body), {'observed': 7});
      expect(await entry.QaMockResponseOverrides.respond(request('/qa/unmatched')), null);
      owner = 'foreign';
      await expectLater(entry.QaMockResponseOverrides.respond(request('/qa/response')), throwsStateError);
      owner = 'qa_test_response_owner';
      resourceCurrent = false;
      await expectLater(entry.QaMockResponseOverrides.respond(request('/qa/response')), throwsStateError);
      resourceCurrent = true;
      final cancellation = NetworkCancellationToken()..cancel();
      await expectLater(entry.QaMockResponseOverrides.respond(
        request('/qa/response').withCancellationToken(cancellation)),
        throwsA(isA<NetworkRequestCancelledException>()));
    } finally {
      lease.restore();
    }
    expect(await owned.QaMockResponseOverrides.respond(request('/qa/response')), null);
    lease.restore();
    final next = install();
    next.restore();
    expect(await entry.QaMockResponseOverrides.respond(request('/qa/response')), null);
  });
}
