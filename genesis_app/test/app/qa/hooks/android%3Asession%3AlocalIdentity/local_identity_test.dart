import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/qa/hooks/android%253Asession%253AlocalIdentity/local_identity.dart';
import 'package:genesis_flutter_android/platform/session/memory_user_session_store.dart';

void main() {
  test(
    'default prepare is signed in and restores full original source',
    () async {
      final store = MemoryUserSessionStore();
      await store.saveUid('original');
      await store.saveAuthToken('token');
      await store.saveUserInfo({
        'nested': {'name': 'original'},
      });
      final hook = LocalIdentityHook(store, resource: 'instance');
      try {
        expect(await hook.prepare({}), 'qa_test_instance');
        expect(await hook.read({}), 'qa_test_instance');
        expect(await store.readAuthToken(), null);
        expect(await hook.prepare({'uid': null}), null);
        expect(await hook.read({}), null);
        expect(await hook.prepare({'uid': 'qa_test_second'}), 'qa_test_second');
      } finally {
        expect(await hook.cleanup({}), 'restored');
      }
      expect(await store.readUid(), 'original');
      expect(await store.readAuthToken(), 'token');
      expect(await store.readUserInfo(), {
        'nested': {'name': 'original'},
      });
      expect(await hook.cleanup({}), 'restored');
      expect(await store.readUid(), 'original');
    },
  );
  test('reads and rejects invalid calls without modifying identity', () async {
    final store = MemoryUserSessionStore();
    await store.saveUid('guest_original');
    final hook = LocalIdentityHook(store, resource: 'instance');
    expect(await hook.read({}), null);
    for (final p in <Map<String, dynamic>>[
      {'uid': 'real'},
      {'uid': 'qa_test_'},
      {'uid': 'qa_test_user '},
      {'uid': 42},
      {'extra': true},
    ]) {
      await expectLater(hook.prepare(p), throwsArgumentError);
    }
    expect(await store.readUid(), 'guest_original');
    expect(await hook.cleanup({}), 'restored');
    expect(await store.readUid(), 'guest_original');
  });
  test(
    'contract and Case dispatch remain isolated before and after start',
    () async {
      final store = MemoryUserSessionStore();
      final hook = LocalIdentityHook(store, resource: 'instance');
      for (final started in [false, true]) {
        expect(
          () => hook.handlers['fixture.localIdentity.prepare']!(
            {},
            true,
            started,
          ),
          throwsStateError,
        );
        expect(
          () => hook.handlers['contract.localIdentity.prepare']!(
            {},
            false,
            started,
          ),
          throwsStateError,
        );
        try {
          expect(
            await hook.handlers['contract.localIdentity.prepare']!(
              {},
              true,
              started,
            ),
            'qa_test_instance',
          );
        } finally {
          expect(
            await hook.handlers['contract.localIdentity.cleanup']!(
              {},
              true,
              started,
            ),
            'restored',
          );
        }
        expect(await store.readUid(), null);
      }
    },
  );
  test('partial write failure still owns restoration', () async {
    final store = FailingStore();
    await store.saveUid('original');
    final hook = LocalIdentityHook(store, resource: 'instance');
    store.fail = true;
    try {
      await expectLater(hook.prepare({}), throwsStateError);
    } finally {
      store.fail = false;
      expect(await hook.cleanup({}), 'restored');
    }
    expect(await store.readUid(), 'original');
  });
}

class FailingStore extends MemoryUserSessionStore {
  bool fail = false;
  @override
  Future<void> saveUid(String uid) async {
    if (fail) throw StateError('write failed');
    await super.saveUid(uid);
  }
}
