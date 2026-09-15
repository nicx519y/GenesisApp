import '../../app/onboarding/personalization_store.dart';
import '../../platform/session/user_session_store.dart';
import 'origin_feed_cache_store.dart';

/// A fixed audience for one paginated list and its first-page cache.
typedef OriginFeedAudience = ({String? ownerUid, String? gender});

/// An empty gender is All only after the profile source has settled.
typedef OriginFeedAudienceState = ({OriginFeedAudience audience, bool isReady});

Future<OriginFeedAudience> loadOriginFeedAudience(
  UserSessionStore store, {
  PersonalizationStore? personalization,
}) async {
  return (await loadOriginFeedAudienceState(
    store,
    personalization: personalization,
  )).audience;
}

Future<OriginFeedAudienceState> loadOriginFeedAudienceState(
  UserSessionStore store, {
  PersonalizationStore? personalization,
  bool waitForGuestProfile = false,
  Future<String?> Function(String ownerUid)? loadManualGender,
}) async {
  try {
    return await _readOriginFeedAudience(
      store,
      personalization,
      waitForGuestProfile,
      loadManualGender,
    ).timeout(const Duration(seconds: 2));
  } catch (_) {
    // An unresolved owner must not read/write another account's first-page cache.
    // Optional targeting must not prevent the feed from loading.
    return (audience: (ownerUid: null, gender: null), isReady: true);
  }
}

Future<OriginFeedAudienceState> _readOriginFeedAudience(
  UserSessionStore store,
  PersonalizationStore? personalization,
  bool waitForGuestProfile,
  Future<String?> Function(String ownerUid)? loadManualGender,
) async {
  final uid = await store.readLoginUid();
  final ownerUid = uid ?? OriginFeedCacheStore.anonymousOwnerUid;
  final manualGender = await loadManualGender?.call(ownerUid);
  if (manualGender != null) {
    return (
      audience: (ownerUid: ownerUid, gender: manualGender),
      isReady: true,
    );
  }
  Object? gender;
  var isReady = true;
  if (uid == null) {
    // Reuse the guest device profile loaded by onboarding. Do not start another
    // request or use a logged-in user's personalization after signing out.
    final profile = personalization?.state.value;
    if (profile?.uid == null) gender = profile?.data?.profile.gender;
    isReady =
        !waitForGuestProfile ||
        (profile?.uid == null &&
            (profile?.data != null || profile?.error != null));
  } else {
    final user = await store.readUserInfo().catchError((Object _) => null);
    final cachedUid = user?['uid'];
    // Do not apply another account's profile during a session transition.
    if (cachedUid is! String || cachedUid.trim() == uid) {
      gender = user?['gender'];
    }
  }
  return (
    audience: (
      ownerUid: ownerUid,
      gender: switch (gender is String ? gender.trim().toLowerCase() : '') {
        'male' => 'Female',
        'female' => 'Male',
        _ => null,
      },
    ),
    isReady: isReady,
  );
}
