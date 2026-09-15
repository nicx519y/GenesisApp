import '../../app/onboarding/personalization_store.dart';
import '../../platform/session/user_session_store.dart';
import 'origin_feed_cache_store.dart';

/// A fixed audience for one paginated list and its first-page cache.
typedef OriginFeedAudience = ({String? ownerUid, String? gender});

Future<OriginFeedAudience> loadOriginFeedAudience(
  UserSessionStore store, {
  PersonalizationStore? personalization,
}) async {
  try {
    return await _readOriginFeedAudience(
      store,
      personalization,
    ).timeout(const Duration(seconds: 2));
  } catch (_) {
    // An unresolved owner must not read/write another account's first-page cache.
    // Optional targeting must not prevent the feed from loading.
    return (ownerUid: null, gender: null);
  }
}

Future<OriginFeedAudience> _readOriginFeedAudience(
  UserSessionStore store,
  PersonalizationStore? personalization,
) async {
  final uid = await store.readLoginUid();
  Object? gender;
  if (uid == null) {
    // Reuse the guest device profile loaded by onboarding. Do not start another
    // request or use a logged-in user's personalization after signing out.
    final profile = personalization?.state.value;
    if (profile?.uid == null) gender = profile?.data?.profile.gender;
  } else {
    final user = await store.readUserInfo().catchError((Object _) => null);
    final cachedUid = user?['uid'];
    // Do not apply another account's profile during a session transition.
    if (cachedUid is! String || cachedUid.trim() == uid) {
      gender = user?['gender'];
    }
  }
  return (
    ownerUid: uid ?? OriginFeedCacheStore.anonymousOwnerUid,
    gender: switch (gender is String ? gender.trim().toLowerCase() : '') {
      'male' => 'Female',
      'female' => 'Male',
      _ => null,
    },
  );
}
