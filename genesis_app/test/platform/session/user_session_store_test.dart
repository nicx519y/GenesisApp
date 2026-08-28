import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/platform/session/memory_user_session_store.dart';
import 'package:genesis_flutter_android/platform/session/user_session_store.dart';

void main() {
  test('readCompleteSession returns normalized uid and auth token', () async {
    final store = MemoryUserSessionStore();
    await store.saveUid('  u_123  ');
    await store.saveAuthToken('  token-123  ');

    final session = await store.readCompleteSession();

    expect(session, isNotNull);
    expect(session!.uid, 'u_123');
    expect(session.authToken, 'token-123');
  });

  test(
    'readCompleteSession clears a successfully read partial session',
    () async {
      final store = MemoryUserSessionStore();
      await store.saveUid('u_123');
      await store.saveUserInfo({'uid': 'u_123'});

      expect(await store.readCompleteSession(), isNull);
      expect(await store.readUid(), isNull);
      expect(await store.readAuthToken(), isNull);
      expect(await store.readUserInfo(), isNull);
    },
  );

  test('readCompleteSession rejects and clears a guest session', () async {
    final store = MemoryUserSessionStore();
    await store.saveUid('guest_123');
    await store.saveAuthToken('token-123');

    expect(await store.readCompleteSession(), isNull);
    expect(await store.readUid(), isNull);
    expect(await store.readAuthToken(), isNull);
  });

  test(
    'readCompleteSession does not clear an already signed-out store',
    () async {
      final store = _TrackingSessionStore();

      expect(await store.readCompleteSession(), isNull);
      expect(store.clearCount, 0);
    },
  );

  test(
    'readCompleteSession does not clear when storage reading fails',
    () async {
      final store = _ThrowingUidSessionStore();
      await store.saveAuthToken('token-123');

      await expectLater(store.readCompleteSession(), throwsStateError);
      expect(store.clearCount, 0);
      expect(await store.readAuthToken(), 'token-123');
    },
  );
}

class _TrackingSessionStore extends MemoryUserSessionStore {
  var clearCount = 0;

  @override
  Future<void> clearUid() async {
    clearCount += 1;
    await super.clearUid();
  }
}

class _ThrowingUidSessionStore extends MemoryUserSessionStore {
  var clearCount = 0;

  @override
  Future<String?> readUid() async {
    throw StateError('uid storage unavailable');
  }

  @override
  Future<void> clearUid() async {
    clearCount += 1;
    await super.clearUid();
  }
}
