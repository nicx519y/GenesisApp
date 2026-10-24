import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/qa/hooks/android%253Aworld.test_identity%253Avalue/identity.dart';
import 'package:genesis_flutter_android/platform/session/memory_user_session_store.dart';
import 'package:genesis_flutter_android/platform/session/user_session_store.dart';

class FailingStore extends MemoryUserSessionStore {
  bool fail = true;
  @override
  Future<void> saveUid(String uid) async {
    if (fail && uid.startsWith('qa_test_world_'))
      throw StateError('write failed');
    await super.saveUid(uid);
  }
}

class FailingRestoreStore extends MemoryUserSessionStore {
  bool failRestore = false;
  @override
  Future<void> saveAuthToken(String token) async {
    if (failRestore) {
      failRestore = false;
      throw StateError('restore write failed');
    }
    await super.saveAuthToken(token);
  }
}

void main() {
  test('a partial restore keeps the snapshot and can finish safely', () async {
    final store = FailingRestoreStore();
    await store.saveUid('original');
    await store.saveAuthToken('original-token');
    final lease = WorldTestIdentity(store, 'restore-retry');
    await lease.prepare();
    store.failRestore = true;
    await expectLater(lease.restore(), throwsStateError);
    expect(await store.readUid(), 'original');
    expect((await lease.restore())['matchesSnapshot'], true);
    expect(await store.readAuthToken(), 'original-token');
  });
  for (final original in [null, 'guest_original', 'existing_login']) {
    test(
      'real store snapshot restores $original including nested user data',
      () async {
        final store = MemoryUserSessionStore();
        if (original != null) await store.saveUid(original);
        await store.saveAuthToken('original-token');
        await store.saveUserInfo({
          'nested': {'name': 'original'},
        });
        final lease = WorldTestIdentity(store, 'instance-a');
        expect((await lease.read())['isolated'], false);
        await expectLater(lease.restore(), throwsStateError);
        try {
          final actual = await lease.prepare();
          expect(actual['loggedIn'], true);
          expect(actual['isolated'], true);
          expect(await store.readLoginUid(), lease.uid);
          expect(await store.readAuthToken(), null);
          expect(await store.readUserInfo(), null);
          expect(await lease.prepare(), actual);
          await store.saveUserInfo({
            'nested': {'name': 'changed'},
          });
        } finally {
          expect(await lease.restore(), {
            'restored': true,
            'matchesSnapshot': true,
            'resource': 'instance-a',
          });
        }
        expect(await store.readUid(), original);
        expect(await store.readAuthToken(), 'original-token');
        expect(await store.readUserInfo(), {
          'nested': {'name': 'original'},
        });
        expect((await lease.restore())['matchesSnapshot'], true);
        await expectLater(lease.prepare(), throwsStateError);
      },
    );
  }
  for (final foreign in [null, 'different_user']) {
    test('does not overwrite changed identity $foreign', () async {
      final store = MemoryUserSessionStore();
      final lease = WorldTestIdentity(store, 'instance-b');
      await lease.prepare();
      try {
        await store.clearUid();
        if (foreign != null) await store.saveUid(foreign);
        await expectLater(lease.restore(), throwsStateError);
        await expectLater(lease.prepare(), throwsStateError);
        expect(await store.readUid(), foreign);
      } finally {
        await store.saveUid(lease.uid);
        await lease.restore();
      }
    });
  }
  test(
    'partial failed prepare retains original snapshot for real cleanup',
    () async {
      final store = FailingStore();
      await store.saveUid('guest_before');
      await store.saveAuthToken('before-token');
      final lease = WorldTestIdentity(store, 'instance-c');
      await expectLater(lease.prepare(), throwsStateError);
      expect(await store.readUid(), null);
      expect((await lease.restore())['matchesSnapshot'], true);
      expect(await store.readUid(), 'guest_before');
      expect(await store.readAuthToken(), 'before-token');
    },
  );
  test('runtime and contract protocols cannot be interchanged', () async {
    await expectLater(prepareWorldIdentity({}, true, true), throwsStateError);
    await expectLater(restoreWorldIdentity({}, true, true), throwsStateError);
    await expectLater(
      contractWorldIdentity({'operation': 'prepare'}, false, true),
      throwsStateError,
    );
    await expectLater(prepareWorldIdentity({}, false, false), throwsStateError);
  });
}
