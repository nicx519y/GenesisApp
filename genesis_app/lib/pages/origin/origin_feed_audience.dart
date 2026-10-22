import 'dart:async';

import '../../app/onboarding/personalization_store.dart';
import '../../platform/session/user_session_store.dart';
import 'origin_feed_cache_store.dart';

/// A fixed audience for one paginated list and its first-page cache.
typedef OriginFeedAudience = ({String? ownerUid, String? gender});

/// Ready from local state; remote configuration never gates the feed.
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
  // Defers only the background GET (until Config / the form gate handles it),
  // never readiness of the local audience or the first list request.
  bool waitForPersonalization = false,
  Future<String?> Function(String ownerUid)? loadCachedGender,
  Future<String?> Function(String ownerUid)? loadManualGender,
}) async {
  try {
    return await _readOriginFeedAudience(
      store,
      personalization,
      waitForPersonalization,
      loadCachedGender,
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
  bool waitForPersonalization,
  Future<String?> Function(String ownerUid)? loadCachedGender,
  Future<String?> Function(String ownerUid)? loadManualGender,
) async {
  final uid = await store.readLoginUid();
  final ownerUid = uid ?? OriginFeedCacheStore.anonymousOwnerUid;
  final manualGender = await _readCachedGender(loadManualGender, ownerUid);
  if (manualGender != null) {
    return (
      audience: (ownerUid: ownerUid, gender: manualGender),
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
  final confirmed = sameOwner && profile?.data != null;
  final cachedGender = confirmed
      ? null
      : await _readCachedGender(loadCachedGender, ownerUid);
  return (
    audience: (
      ownerUid: ownerUid,
      gender: switch (preference) {
        'Male' || 'Female' || 'Non_binary' => preference,
        'All' => '',
        _ => confirmed ? '' : cachedGender ?? '',
      },
    ),
    isReady: true,
  );
}

Future<String?> _readCachedGender(
  Future<String?> Function(String ownerUid)? read,
  String ownerUid,
) async {
  try {
    return await read
        ?.call(ownerUid)
        .timeout(const Duration(milliseconds: 500));
  } catch (_) {
    return null;
  }
}
