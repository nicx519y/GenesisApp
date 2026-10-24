import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/qa/hooks/android%253Aworld.test_identity%253Avalue/identity.dart';
import 'package:genesis_flutter_android/app/qa/hooks/qa%253Aandroid%253Afa6d6e9732df53bf7030/chat_identity.dart';
import 'package:genesis_flutter_android/app/qa/hooks/qa%253Aandroid%253Afa6d6e9732df53bf7030/peer.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_client.dart';
import 'package:genesis_flutter_android/platform/session/memory_user_session_store.dart';
import 'package:genesis_flutter_android/platform/session/user_session_store.dart';

class DroppedTokenStore extends MemoryUserSessionStore {
  @override
  Future<void> saveAuthToken(String token) async {}
}

void main() {
  test('local login alone cannot connect; owned mock credentials connect and restore', () async {
    final store = MemoryUserSessionStore();
    await store.saveUid('original');
    await store.saveAuthToken('original-token');
    await store.saveUserInfo({'name': 'original'});
    final identity = WorldTestIdentity(store, 'parent-connection');
    final peer = ParentPeer('world', identity.uid, () async {
      expect((await identity.read())['isolated'], true);
    });
    ChatroomSession? session;
    try {
      await identity.prepare();
      expect(await store.readLoginUid(), identity.uid);
      expect(await store.readCompleteSession(), isNull);
      await peer.open();
      final client = ChatroomClient(wsBaseUrl: peer.url, sessionStore: store, autoHeartbeat: false);
      await expectLater(client.connect(worldId: 'world'), throwsA(predicate((e) => e.toString().contains('authToken is required'))));
      expect(peer.connected, false);
      await prepareParentChatIdentity(identity);
      expect((await store.readCompleteSession())?.uid, identity.uid);
      session = await client.connect(worldId: 'world');
      expect(peer.connected, true);
      expect(peer.errors, isEmpty);
    } finally {
      try {
        await session?.close();
      } finally {
        try {
          if (peer.acquired) await peer.close();
        } finally {
          expect((await identity.restore())['matchesSnapshot'], true);
        }
      }
    }
    expect(peer.closed, true);
    expect(peer.connected, false);
    expect(await store.readUid(), 'original');
    expect(await store.readAuthToken(), 'original-token');
    expect(await store.readUserInfo(), {'name': 'original'});
  });

  test('unowned or changed identities cannot receive mock credentials', () async {
    final store = MemoryUserSessionStore();
    final identity = WorldTestIdentity(store, 'ownership');
    await expectLater(prepareParentChatIdentity(identity), throwsStateError);
    expect(await store.readAuthToken(), isNull);
    await identity.prepare();
    try {
      await store.saveUid('foreign');
      await expectLater(prepareParentChatIdentity(identity), throwsStateError);
      expect(await store.readUid(), 'foreign');
      expect(await store.readAuthToken(), isNull);
    } finally {
      await store.saveUid(identity.uid);
      await identity.restore();
    }
  });

  test('failed token persistence is detected and original snapshot remains restorable', () async {
    final store = DroppedTokenStore();
    final identity = WorldTestIdentity(store, 'write-failure');
    await identity.prepare();
    try {
      await expectLater(prepareParentChatIdentity(identity), throwsStateError);
    } finally {
      expect((await identity.restore())['matchesSnapshot'], true);
    }
    expect(await store.readCompleteSession(), isNull);
  });
}
