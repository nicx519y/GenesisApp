part of 'genesis_api.dart';

OriginSummary _originSummaryFromSearchItem(Map<String, dynamic> raw) {
  final looksLikeV5 =
      raw.containsKey('Oname') || raw.containsKey('worldviewId');
  if (looksLikeV5) {
    return _originSummaryFromV5(raw);
  }

  final oid = asString(
    raw['oid'],
    fallback: asString(
      raw['worldview_id'],
      fallback: asString(raw['worldviewId']),
    ),
  );
  final mapImage = _resolveImageAssetUrl(
    raw['map_image'],
    fallback: raw['snapshot_cover_url'],
  );
  final id = asInt(raw['id'], fallback: _stableInt(oid));

  return OriginSummary(
    id: id,
    oid: oid,
    name: asString(raw['name']),
    description: asString(
      raw['description'],
      fallback: asString(raw['subtitle']),
    ),
    mapImage: mapImage,
    worldMap: _resolveImageAssetUrl(raw['world_map'], fallback: mapImage),
    worldView: asString(raw['world_view']),
    deleted: entityDeleted(raw['deleted'], fallback: raw['origin_deleted']),
    originator: _originatorFromOriginMap(raw),
    versionNum: asInt(raw['version_num']),
    copyCount: asInt(raw['copy_count'], fallback: asInt(raw['copyCount'])),
    interactCount: asInt(
      raw['interact_count'],
      fallback: asInt(
        raw['connect_count'],
        fallback: asInt(raw['interactCount']),
      ),
    ),
    characterCount: asInt(raw['character_cnt']),
    tags: _splitTags(asString(raw['tags'])),
    createdAt: asDateTime(raw['created_at']),
    updatedAt: asDateTime(raw['updated_at']),
    characters: const <OriginCharacter>[],
    locations: const <OriginLocation>[],
  );
}

MyWorldSummary _worldSummaryFromSearchItem(Map<String, dynamic> raw) {
  return MyWorldSummary(
    wid: asString(
      raw['world_instance_id'],
      fallback: asString(raw['wid'], fallback: asString(raw['id'])),
    ),
    name: asString(raw['world_name'], fallback: asString(raw['name'])),
    deleted: entityDeleted(raw['world_deleted'], fallback: raw['deleted']),
    snapshotCoverUrl: _resolveImageAssetUrl(
      raw['snapshot_cover_url'],
      fallback: raw['cover_url'] ?? raw['cover'],
    ),
    updatedAtText: asString(raw['updated_at']),
    ownerName: asString(
      raw['owner_name'],
      fallback: asString(raw['created_user_name']),
    ),
    progressCount: asInt(raw['tick_cnt']),
    interactCount: asInt(raw['connect_cnt']),
    characterCount: asInt(
      raw['ai_character_cnt'],
      fallback: asInt(raw['character_cnt']),
    ),
    playerCount: asInt(raw['player_cnt']),
  );
}

SearchUserSummary _userSummaryFromSearchItem(Map<String, dynamic> raw) {
  final uid = asString(raw['id'], fallback: asString(raw['uid']));
  return SearchUserSummary(
    uid: uid,
    displayName: asString(
      raw['display_name'],
      fallback: asString(raw['nickname'], fallback: asString(raw['name'])),
    ),
    avatarUrl: asImageUrl(raw['avatar_url'], fallback: raw['avatar']),
    userCode: asString(raw['user_code'], fallback: uid),
    deleted: entityDeleted(raw['deleted']),
  );
}

String _loginResponseUid(Map<String, dynamic> userMap) {
  return asString(
    userMap['id'],
    fallback: asString(
      userMap['uid'],
      fallback: asString(
        userMap['user_id'],
        fallback: asString(userMap['api_user_id']),
      ),
    ),
  ).trim();
}

int _stableInt(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return 0;
  var hash = 0;
  for (final unit in trimmed.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return hash;
}

int _extractTrailingInt(String value, {int fallback = 0}) {
  final match = RegExp(r'(\\d+)').allMatches(value).toList(growable: false);
  if (match.isEmpty) return fallback;
  return int.tryParse(match.last.group(1) ?? '') ?? fallback;
}

List<String> _splitTags(String tags) {
  if (tags.trim().isEmpty) return const <String>[];
  return tags
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList(growable: false);
}
