import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/platform/session/memory_user_session_store.dart';
import 'package:genesis_flutter_android/platform/session/user_language_cache.dart';

void main() {
  test('updates account language without replacing profile fields', () async {
    final store = MemoryUserSessionStore();
    await store.saveUid('a');
    await store.saveAuthToken('token');
    await store.saveUserInfo({'uid': 'a', 'language': 'en', 'name': 'Name'});
    await cacheUserLanguage(
      store: store,
      session: (uid: 'a', authToken: 'token'),
      language: 'fr',
      canSave: () => true,
    );
    expect(await store.readUserInfo(), {
      'uid': 'a',
      'language': 'fr',
      'name': 'Name',
    });
    final revision = store.userInfoRevision.value;
    await cacheUserLanguage(
      store: store,
      session: (uid: 'a', authToken: 'token'),
      language: 'fr',
      canSave: () => true,
    );
    expect(store.userInfoRevision.value, revision);
  });

  test('ignores stale session and invalidated language response', () async {
    final store = MemoryUserSessionStore();
    await store.saveUid('b');
    await store.saveAuthToken('token');
    await store.saveUserInfo({'uid': 'b', 'language': 'en'});
    for (final session in [
      (uid: 'a', authToken: 'token'),
      (uid: 'b', authToken: 'old-token'),
      (uid: 'b', authToken: 'token'),
    ]) {
      await cacheUserLanguage(
        store: store,
        session: session,
        language: 'fr',
        canSave: () => session.uid != 'b' || session.authToken != 'token',
      );
    }
    expect((await store.readUserInfo())?['language'], 'en');
  });
}
