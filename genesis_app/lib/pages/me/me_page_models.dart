part of 'me_page.dart';

class _MePageContent {
  const _MePageContent.signedOut() : data = null;
  const _MePageContent.signedIn(this.data);

  final UserProfileData? data;

  bool get isSignedIn => data != null;
}

@visibleForTesting
UserProfileData mergeRemoteUserInfoForRenderForTest(
  UserProfileData currentData,
  Map<String, dynamic> remoteUser,
) {
  return _mergeRemoteUserInfoForRender(currentData, remoteUser);
}

@visibleForTesting
bool sameRenderedUserInfoForTest(
  UserProfileData currentData,
  UserProfileData nextData,
) {
  return _sameRenderedUserInfo(currentData, nextData);
}

UserProfileData _mergeRemoteUserInfoForRender(
  UserProfileData currentData,
  Map<String, dynamic> remoteUser,
) {
  final backendName = _mapString(remoteUser, 'name');
  final backendAvatar = _resolvedBackendAvatar(remoteUser);
  final backendUid = _mapString(remoteUser, 'uid');
  final deleted = entityDeleted(remoteUser['deleted']);
  final resolvedUid = deleted
      ? deletedEntityDisplayText
      : (backendUid.isEmpty ? currentData.uid : backendUid);
  final resolvedDisplayName = deleted
      ? deletedEntityDisplayText
      : _hasMapKey(remoteUser, 'name')
      ? _profileDisplayNameFromBackend(
          backendName,
          resolvedUid,
          fallback: currentData.displayName,
        )
      : currentData.displayName;
  final resolvedAvatarUrl = _hasAvatarPayload(remoteUser)
      ? backendAvatar
      : currentData.avatarUrl;
  return currentData.copyWith(
    avatarUrl: resolvedAvatarUrl,
    displayName: resolvedDisplayName,
    uid: resolvedUid,
    followingCount:
        _mapIntOrNull(remoteUser, 'following_cnt') ??
        currentData.followingCount,
    followerCount:
        _mapIntOrNull(remoteUser, 'follower_cnt') ?? currentData.followerCount,
    deleted: deleted,
  );
}

String _profileDisplayNameFromBackend(
  String backendName,
  String uid, {
  required String fallback,
}) {
  final name = backendName.trim();
  if (name.isNotEmpty) return name;
  final cleanUid = uid.trim();
  if (cleanUid.isNotEmpty) return cleanUid;
  return fallback;
}

bool _hasAvatarPayload(Map<dynamic, dynamic> user) {
  return _hasMapKey(user, 'avatar') || _hasMapKey(user, 'avatar_url');
}

bool _hasMapKey(Map<dynamic, dynamic> map, String key) {
  return map.containsKey(key);
}

String _resolvedBackendAvatar(Map<dynamic, dynamic> user) {
  if (_hasMapKey(user, 'avatar')) {
    return asResolvedImageUrl(user['avatar'], resolveAssetUrl);
  }
  return asResolvedImageUrl(user['avatar_url'], resolveAssetUrl);
}

bool _sameRenderedUserInfo(
  UserProfileData currentData,
  UserProfileData nextData,
) {
  return currentData.avatarUrl == nextData.avatarUrl &&
      _sameRenderedUserInfoExceptAvatar(currentData, nextData);
}

bool _sameRenderedUserInfoExceptAvatar(
  UserProfileData currentData,
  UserProfileData nextData,
) {
  return currentData.displayName == nextData.displayName &&
      _sameRenderedUserInfoExceptAvatarAndDisplayName(currentData, nextData);
}

bool _sameRenderedUserInfoExceptAvatarAndDisplayName(
  UserProfileData currentData,
  UserProfileData nextData,
) {
  return currentData.uid == nextData.uid &&
      currentData.followingCount == nextData.followingCount &&
      currentData.followerCount == nextData.followerCount &&
      currentData.deleted == nextData.deleted;
}

bool _sameOriginItems(
  List<UserProfileOriginItem> current,
  List<UserProfileOriginItem> next,
) {
  if (identical(current, next)) return true;
  if (current.length != next.length) return false;
  for (var index = 0; index < current.length; index += 1) {
    final a = current[index];
    final b = next[index];
    if (a.originId != b.originId ||
        a.oid != b.oid ||
        a.title != b.title ||
        a.subtitle != b.subtitle ||
        a.deleted != b.deleted ||
        a.imageUrl != b.imageUrl ||
        a.copyCount != b.copyCount ||
        a.interactCount != b.interactCount ||
        a.characterCount != b.characterCount) {
      return false;
    }
  }
  return true;
}

bool _sameWorldItems(
  List<UserProfileWorldItem> current,
  List<UserProfileWorldItem> next,
) {
  if (identical(current, next)) return true;
  if (current.length != next.length) return false;
  for (var index = 0; index < current.length; index += 1) {
    final a = current[index];
    final b = next[index];
    if (a.wid != b.wid ||
        a.title != b.title ||
        a.subtitle != b.subtitle ||
        a.deleted != b.deleted ||
        a.imageUrl != b.imageUrl ||
        a.progressCount != b.progressCount ||
        a.subTickNo != b.subTickNo ||
        a.interactCount != b.interactCount ||
        a.characterCount != b.characterCount ||
        a.playerCount != b.playerCount ||
        a.ownerName != b.ownerName) {
      return false;
    }
  }
  return true;
}

UserProfileOriginItem _profileOriginItemFromSummary(OriginSummary item) {
  return UserProfileOriginItem(
    originId: item.id,
    oid: item.oid,
    title: item.name.trim().isEmpty ? item.oid : item.name.trim(),
    subtitle: _originSubtitle(item),
    deleted: item.deleted,
    imageUrl: resolveAssetUrl(item.mapImage),
    copyCount: item.copyCount,
    interactCount: item.interactCount,
    characterCount: item.characterCount,
  );
}

UserProfileWorldItem _profileWorldItemFromSummary(MyWorldSummary item) {
  return UserProfileWorldItem(
    wid: item.wid,
    title: item.name.trim().isEmpty ? item.wid : item.name.trim(),
    subtitle: _worldSubtitle(item.wid, item.ownerName, deleted: item.deleted),
    deleted: item.deleted,
    imageUrl: resolveAssetUrl(item.snapshotCoverUrl),
    progressCount: item.progressCount,
    subTickNo: item.subTickNo,
    interactCount: item.interactCount,
    characterCount: item.characterCount,
    playerCount: item.playerCount,
    ownerName: item.ownerName,
  );
}

String _originSubtitle(OriginSummary item) {
  final oid = deletedAwareIdLabel(item.oid, deleted: item.deleted);
  final originator = item.originator.trim().isEmpty
      ? '-'
      : formatUidForDisplay(item.originator);
  final version = item.versionNum <= 0 ? '-' : 'V${item.versionNum}';
  return 'OID: $oid  Originator: $originator\n'
      'Latest Version: $version';
}

String _worldSubtitle(String wid, String ownerName, {bool deleted = false}) {
  final displayWid = deletedAwareIdLabel(wid, deleted: deleted);
  final owner = formatUidForDisplay(ownerName, fallback: '-');
  return 'WID: $displayWid  Owner: $owner';
}
