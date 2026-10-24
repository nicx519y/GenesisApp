import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/qa/hooks/android%253Aapp.navigation%253Apage/contract_identity.dart';
import 'package:genesis_flutter_android/platform/session/memory_user_session_store.dart';
import 'package:genesis_flutter_android/platform/session/user_session_store.dart';

void main() {
  test(
    'restores the actual guest snapshot, including token and user data',
    () async {
      final store = MemoryUserSessionStore();
      await store.saveUid('guest_original');
      await store.saveAuthToken('original-token');
      await store.saveUserInfo({'name': 'Guest'});
      final fixture = NavigationContractIdentity(store);
      try {
        expect(await fixture.call('prepare', 'run'), {
          'runId': 'run',
          'identity': NavigationContractIdentity.testUid,
        });
        expect(await store.readLoginUid(), NavigationContractIdentity.testUid);
        await expectLater(fixture.call('prepare', 'other'), throwsStateError);
        await expectLater(fixture.call('restore', 'other'), throwsStateError);
      } finally {
        expect(await fixture.call('restore', 'run'), {
          'runId': 'run',
          'restored': true,
          'identity': null,
        });
      }
      expect(await store.readUid(), 'guest_original');
      expect(await store.readAuthToken(), 'original-token');
      expect(await store.readUserInfo(), {'name': 'Guest'});
      await expectLater(fixture.call('restore', 'run'), throwsStateError);
    },
  );
  test('restores a null snapshot and rejects foreign identity', () async {
    final store = MemoryUserSessionStore();
    final fixture = NavigationContractIdentity(store);
    await fixture.call('prepare', 'run');
    try {
      await store.saveUid('foreign');
      await expectLater(fixture.call('restore', 'run'), throwsStateError);
      expect(await store.readUid(), 'foreign');
    } finally {
      await store.saveUid(NavigationContractIdentity.testUid);
      await fixture.call('restore', 'run');
    }
    expect(await store.readUid(), null);
    expect(await store.readAuthToken(), null);
    expect(await store.readUserInfo(), null);
  });
  test(
    'does not replace an existing login or enter an unprepared session',
    () async {
      final store = MemoryUserSessionStore();
      await store.saveUid('existing');
      await expectLater(
        NavigationContractIdentity(store).call('prepare', 'run'),
        throwsStateError,
      );
      expect(await store.readUid(), 'existing');
      await expectLater(
        navigationContractIdentity(
          {'operation': 'prepare', 'runId': 'run'},
          false,
          true,
        ),
        throwsStateError,
      );
      await expectLater(
        navigationContractIdentity(
          {'operation': 'prepare', 'runId': 'run'},
          true,
          false,
        ),
        throwsStateError,
      );
    },
  );
}
