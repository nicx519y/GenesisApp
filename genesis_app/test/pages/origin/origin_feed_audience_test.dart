import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/onboarding/personalization_store.dart';
import 'package:genesis_flutter_android/network/models/personalization.dart';
import 'package:genesis_flutter_android/pages/origin/origin_feed_audience.dart';
import 'package:genesis_flutter_android/pages/origin/origin_feed_cache_store.dart';
import 'package:genesis_flutter_android/platform/session/memory_user_session_store.dart';
import 'package:genesis_flutter_android/platform/session/user_session_store.dart';

void main() {
  for (final uid in <String?>[null, 'u_one']) {
    for (final gender in ['', 'Male', 'Female', 'Non_binary']) {
      test('cached $gender wins before personalization for $uid', () async {
        final session = _FailedUserInfoStore();
        if (uid != null) await session.saveUid(uid);
        final personalization = _store(session);
        addTearDown(personalization.dispose);
        final result = await loadOriginFeedAudienceState(
          session,
          personalization: personalization,
          waitForPersonalization: true,
          loadCachedGender: (owner) async {
            expect(owner, uid ?? OriginFeedCacheStore.anonymousOwnerUid);
            return gender;
          },
        );
        expect(result.isReady, isTrue);
        expect(result.audience.gender, gender);
        expect(personalization.isStarted, isFalse);
      });
    }
    for (final preference in <String?>[
      null,
      'All',
      'Male',
      'Female',
      'Non_binary',
    ]) {
      test('GET preference $preference is used directly for $uid', () async {
        final session = _FailedUserInfoStore();
        if (uid != null) await session.saveUid(uid);
        final personalization = _store(session)
          ..state.value = PersonalizationState(
            uid: uid,
            data: PersonalizationData(
              profile: PersonalizationProfile(
                gender: 'Male',
                originFeedGender: preference,
              ),
              form: const [],
            ),
          );
        addTearDown(personalization.dispose);
        final result = await loadOriginFeedAudienceState(
          session,
          personalization: personalization,
          waitForPersonalization: true,
        );
        expect(result.isReady, isTrue);
        expect(result.audience.gender, preference == 'All' ? '' : preference);
      });
    }
    test(
      'no cache waits for GET and failure falls back to All for $uid',
      () async {
        final session = _FailedUserInfoStore();
        if (uid != null) await session.saveUid(uid);
        final personalization = _store(session);
        addTearDown(personalization.dispose);
        for (final state in const [
          PersonalizationState(),
          PersonalizationState(loading: true),
        ]) {
          personalization.state.value = state;
          expect(
            (await loadOriginFeedAudienceState(
              session,
              personalization: personalization,
              waitForPersonalization: true,
            )).isReady,
            isFalse,
          );
        }
        personalization.state.value = PersonalizationState(
          uid: uid,
          error: StateError('offline'),
        );
        final failed = await loadOriginFeedAudienceState(
          session,
          personalization: personalization,
          waitForPersonalization: true,
        );
        expect(failed.isReady, isTrue);
        expect(failed.audience.gender, isNull);
      },
    );
    test('does not use another identity personalization for $uid', () async {
      final session = _FailedUserInfoStore();
      if (uid != null) await session.saveUid(uid);
      final personalization = _store(session)
        ..state.value = PersonalizationState(
          uid: uid == null ? 'u_old' : null,
          data: const PersonalizationData(
            profile: PersonalizationProfile(originFeedGender: 'Female'),
            form: [],
          ),
        );
      addTearDown(personalization.dispose);
      final result = await loadOriginFeedAudienceState(
        session,
        personalization: personalization,
        waitForPersonalization: true,
      );
      expect(result.isReady, isFalse);
      expect(result.audience.gender, isNull);
    });
  }
  test(
    'disabled form still loads preference once, sharing the in-flight GET',
    () async {
      final session = MemoryUserSessionStore();
      final response = Completer<PersonalizationData>();
      var calls = 0;
      final personalization = PersonalizationStore(
        readLoginUid: session.readLoginUid,
        load: () {
          calls++;
          return response.future;
        },
        save: (_) async => throw StateError('Unexpected save'),
      )..setEnabled(false);
      addTearDown(personalization.dispose);
      for (var i = 0; i < 3; i++) {
        expect(
          (await loadOriginFeedAudienceState(
            session,
            personalization: personalization,
          )).isReady,
          isFalse,
        );
      }
      expect(calls, 1);
      expect(personalization.blocksOtherPrompts.value, isFalse);
      response.complete(
        const PersonalizationData(
          profile: PersonalizationProfile(originFeedGender: 'Non_binary'),
          form: [],
        ),
      );
      await personalization.loadForOriginFeed();
      expect(
        (await loadOriginFeedAudienceState(
          session,
          personalization: personalization,
        )).audience.gender,
        'Non_binary',
      );
      expect(calls, 1);
    },
  );
  test('unknown owner disables targeting and cache', () async {
    expect(await loadOriginFeedAudience(_FailedUidStore()), (
      ownerUid: null,
      gender: null,
    ));
  });
}

PersonalizationStore _store(MemoryUserSessionStore session) =>
    PersonalizationStore(
      readLoginUid: session.readLoginUid,
      load: () async => throw StateError('Unexpected GET'),
      save: (_) async => throw StateError('Unexpected save'),
    );

class _FailedUserInfoStore extends MemoryUserSessionStore {
  @override
  Future<Map<String, dynamic>?> readUserInfo() async =>
      throw StateError('Must not read userInfo');
}

class _FailedUidStore extends MemoryUserSessionStore {
  @override
  Future<String?> readUid() async => throw StateError('Read failed');
}
