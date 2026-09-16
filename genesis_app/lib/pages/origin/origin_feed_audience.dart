import 'dart:async';

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
  bool waitForPersonalization = false,
  Future<String?> Function(String ownerUid)? loadCachedGender,
}) async {
  try {
    return await _readOriginFeedAudience(
      store,
      personalization,
      waitForPersonalization,
      loadCachedGender,
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
  bool waitForPersonalization,
  Future<String?> Function(String ownerUid)? loadCachedGender,
) async {
  final uid = await store.readLoginUid();
  final ownerUid = uid ?? OriginFeedCacheStore.anonymousOwnerUid;
  final cachedGender = await loadCachedGender?.call(ownerUid);
  if (cachedGender != null) {
    return (
      audience: (ownerUid: ownerUid, gender: cachedGender),
      isReady: true,
    );
  }
  // Both signed-in and guest identities use the startup GET, never gender
  // from userInfo or a client-side opposite-gender mapping.
  var profile = personalization?.state.value;
  if (!waitForPersonalization &&
      personalization != null &&
      profile?.data == null &&
      profile?.error == null) {
    // The onboarding form may be disabled, but the feed still needs its data.
    unawaited(personalization.loadForOriginFeed());
    profile = personalization.state.value;
  }
  final sameOwner = profile?.uid == uid;
  final preference = sameOwner ? profile?.data?.profile.originFeedGender : null;
  return (
    audience: (
      ownerUid: ownerUid,
      gender: switch (preference) {
        'Male' || 'Female' || 'Non_binary' => preference,
        'All' => '',
        _ => null,
      },
    ),
    isReady:
        personalization == null ||
        (sameOwner && (profile?.data != null || profile?.error != null)),
  );
}
