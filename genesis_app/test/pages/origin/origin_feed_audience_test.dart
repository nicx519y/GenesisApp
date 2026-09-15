import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/onboarding/personalization_store.dart';
import 'package:genesis_flutter_android/network/models/personalization.dart';
import 'package:genesis_flutter_android/pages/origin/origin_feed_audience.dart';
import 'package:genesis_flutter_android/pages/origin/origin_feed_cache_store.dart';
import 'package:genesis_flutter_android/platform/session/memory_user_session_store.dart';
import 'package:genesis_flutter_android/platform/session/user_session_store.dart';

void main() {
  for (final entry in <String?, String?>{
    'Male': 'Female',
    'male': 'Female',
    ' Female ': 'Male',
    'female': 'Male',
    'Non_binary': null,
    'unknown': null,
    '': null,
    null: null,
  }.entries) {
    test('current gender ${entry.key} targets ${entry.value}', () async {
      final store = MemoryUserSessionStore();
      await store.saveUid('u_one');
      await store.saveUserInfo({'uid': 'u_one', 'gender': entry.key});

      expect(await loadOriginFeedAudience(store), (
        ownerUid: 'u_one',
        gender: entry.value,
      ));
    });
  }

  test('ignores a profile that belongs to the previous account', () async {
    final store = MemoryUserSessionStore();
    await store.saveUid('u_two');
    await store.saveUserInfo({'uid': 'u_one', 'gender': 'Male'});

    expect(await loadOriginFeedAudience(store), (
      ownerUid: 'u_two',
      gender: null,
    ));
  });

  test('missing guest profile leaves targeting unspecified', () async {
    expect(await loadOriginFeedAudience(MemoryUserSessionStore()), (
      ownerUid: OriginFeedCacheStore.anonymousOwnerUid,
      gender: null,
    ));
  });

  for (final entry in <String?, String?>{
    'Male': 'Female',
    'female': 'Male',
    'Non_binary': null,
    '': null,
    null: null,
  }.entries) {
    test(
      'guest uses personalization ${entry.key} instead of userInfo',
      () async {
        final store = _FailedUserInfoStore();
        final personalization = _personalizationStore(store, gender: entry.key);
        addTearDown(personalization.dispose);
        expect(
          await loadOriginFeedAudience(store, personalization: personalization),
          (
            ownerUid: OriginFeedCacheStore.anonymousOwnerUid,
            gender: entry.value,
          ),
        );
        expect(store.reads, 0);
      },
    );
  }

  test(
    'guest ignores personalization belonging to a signed-out account',
    () async {
      final store = MemoryUserSessionStore();
      final personalization = _personalizationStore(
        store,
        gender: 'Male',
        uid: 'u_old',
      );
      addTearDown(personalization.dispose);
      expect(
        await loadOriginFeedAudience(store, personalization: personalization),
        (ownerUid: OriginFeedCacheStore.anonymousOwnerUid, gender: null),
      );
    },
  );

  test('logged-in user never falls back to personalization', () async {
    final store = MemoryUserSessionStore();
    await store.saveUid('u_one');
    final personalization = _personalizationStore(store, gender: 'Male');
    addTearDown(personalization.dispose);
    for (final gender in ['Female', '', 'Non_binary']) {
      await store.saveUserInfo({'uid': 'u_one', 'gender': gender});
      expect(
        await loadOriginFeedAudience(store, personalization: personalization),
        (ownerUid: 'u_one', gender: gender == 'Female' ? 'Male' : null),
      );
    }
  });

  test(
    'failed user info read omits gender but preserves cache owner',
    () async {
      final store = _FailedUserInfoStore();
      await store.saveUid('u_one');
      expect(await loadOriginFeedAudience(store), (
        ownerUid: 'u_one',
        gender: null,
      ));
    },
  );

  test('unknown owner loads without targeting and disables cache', () async {
    expect(await loadOriginFeedAudience(_FailedUidStore()), (
      ownerUid: null,
      gender: null,
    ));
  });
}

class _FailedUserInfoStore extends MemoryUserSessionStore {
  int reads = 0;
  @override
  Future<Map<String, dynamic>?> readUserInfo() async {
    reads++;
    throw StateError('Read failed');
  }
}

class _FailedUidStore extends MemoryUserSessionStore {
  @override
  Future<String?> readUid() async => throw StateError('Read failed');
}

PersonalizationStore _personalizationStore(
  MemoryUserSessionStore session, {
  String? gender,
  String? uid,
}) {
  return PersonalizationStore(
      readLoginUid: session.readLoginUid,
      load: () async =>
          throw StateError('Audience must not request personalization'),
      save: (_) async => throw StateError('Unexpected save'),
    )
    ..state.value = PersonalizationState(
      uid: uid,
      data: PersonalizationData(
        profile: PersonalizationProfile(gender: gender),
        form: const [],
      ),
    );
}
