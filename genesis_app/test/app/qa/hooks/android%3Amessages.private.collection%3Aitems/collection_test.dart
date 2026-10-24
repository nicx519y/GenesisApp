import 'dart:convert';
import 'package:genesis_flutter_android/network/http_transport.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/qa/hooks/android%253Amessages.private.collection%253Aitems/collection.dart';
import 'package:genesis_flutter_android/app/qa/fixtures/http/mock_response_overrides.dart';
import 'package:genesis_flutter_android/network/direct_message_conversation_store.dart';
import 'package:genesis_flutter_android/network/genesis_api.dart';
import 'package:genesis_flutter_android/network/local_mock_genesis_transport.dart';
import 'package:genesis_flutter_android/platform/device/device_id_service.dart';
import 'package:genesis_flutter_android/platform/session/memory_user_session_store.dart';

class Device implements DeviceIdService {
  @override
  Future<String> getDeviceId() async => 'qa-collection-device';
}

class FailingTransport implements HttpTransport {
  bool fail = false;
  @override
  Future<TransportResponse> send(TransportRequest request) async {
    if (fail) {
      fail = false;
      throw StateError('request failed during cleanup');
    }
    return LocalMockGenesisTransport.instance.send(request);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'failed cleanup request still releases response override and restores cache',
    () async {
      expect(QaMockResponseOverrides.enabled, isTrue);
      final session = MemoryUserSessionStore();
      await session.saveUid('qa_test_cleanup');
      final transport = FailingTransport();
      final api = GenesisApi(
        transport: transport,
        sessionStore: session,
        deviceIdService: Device(),
      );
      final storage = MemoryDirectMessageConversationStorage();
      final store = DirectMessageConversationStore(
        api: api,
        sessionStore: session,
        storage: storage,
      );
      await store.syncConversations();
      final before = (await storage.loadConversations(
        'qa_test_cleanup',
      )).map((r) => jsonDecode(r.rawJson)).toList();
      final hook = PrivateCollection(
        session: session,
        store: store,
        storage: storage,
        resource: 'cleanup',
        currentResource: () => true,
      );
      try {
        await hook.prepare();
        transport.fail = true;
        await expectLater(
          hook.cleanup(),
          throwsA(isA<PrivateCollectionCleanupFailure>()),
        );
        expect(await hook.read(), before);
        expect((await api.v1.dm.conversations())['list'], isNotEmpty);
      } finally {
        transport.fail = false;
        expect(await hook.cleanup(), 'restored');
      }
    },
  );
  test(
    'actual mock source, store, cursor, ownership and cleanup are repeatable',
    () async {
      expect(
        QaMockResponseOverrides.enabled,
        isTrue,
        reason:
            'Run with FLUTTER_APP_FLAVOR=internal GENESIS_QA_BRIDGE=true GENESIS_API_ENV=mock',
      );
      final session = MemoryUserSessionStore();
      await session.saveUid('qa_test_collection');
      final storage = MemoryDirectMessageConversationStorage();
      final api = GenesisApi(
        useMock: true,
        transport: LocalMockGenesisTransport.instance,
        deviceIdService: Device(),
        sessionStore: session,
      );
      final store = DirectMessageConversationStore(
        api: api,
        sessionStore: session,
        storage: storage,
      );
      await store.syncConversations();
      final before = (await storage.loadConversations(
        'qa_test_collection',
      )).map((r) => jsonDecode(r.rawJson)).toList();
      final cursor = await storage.readCursor('qa_test_collection');
      final source = await api.v1.dm.conversations(pn: 1, rn: 100);
      expect(before, isNotEmpty);
      bool current = true;
      final collection = PrivateCollection(
        session: session,
        store: store,
        storage: storage,
        resource: 'resource-a',
        currentResource: () => current,
      );
      try {
        expect(await collection.prepare(), isEmpty);
        expect(await collection.read(), isEmpty);
        // A later business refresh must still consume the empty source.
        await store.syncConversations();
        expect(store.orderedConversationIds.value, isEmpty);
        expect((await api.v1.dm.conversations())['list'], isEmpty);
        await session.saveUid('qa_test_other');
        await expectLater(collection.read(), throwsStateError);
        await expectLater(collection.cleanup(), throwsStateError);
        await session.saveUid('qa_test_collection');
        current = false;
        await expectLater(collection.prepare(), throwsStateError);
        current = true;
      } finally {
        await session.saveUid('qa_test_collection');
        current = true;
        expect(await collection.cleanup(), 'restored');
      }
      expect(await collection.read(), before);
      expect(await storage.readCursor('qa_test_collection'), cursor);
      expect(await api.v1.dm.conversations(pn: 1, rn: 100), source);
      expect(await collection.cleanup(), 'restored');
      await expectLater(collection.prepare(), throwsStateError);
      expect(await session.readUid(), 'qa_test_collection');
      await session.saveUid('real-owner');
      final foreign = PrivateCollection(
        session: session,
        store: store,
        storage: storage,
        resource: 'resource-b',
        currentResource: () => true,
      );
      await expectLater(foreign.prepare(), throwsStateError);
    },
  );
}
