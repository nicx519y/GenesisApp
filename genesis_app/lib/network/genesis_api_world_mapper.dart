part of 'genesis_api.dart';

WorldDetail _worldDetailFromV1(Map<String, dynamic> raw) {
  final world = asJsonMap(raw['info']);
  final ownerUser = world['owner_user'] is Map
      ? asJsonMap(world['owner_user'])
      : const <String, dynamic>{};
  final stats = asJsonMap(raw['stats']);
  final wid = asString(world['world_id']);
  final oid = asString(world['origin_id']);
  final worldId = _stableInt(wid);
  final originId = _stableInt(oid);
  final cover = _resolveImageAssetUrl(
    world['cover'],
    fallback: world['map_url'],
  );
  final mapUrlRaw = asString(world['map_url']).trim();
  final mapUrl = mapUrlRaw.isNotEmpty ? resolveAssetUrl(mapUrlRaw) : cover;
  final locationsRaw = raw['locations'];
  final locations = locationsRaw is List
      ? asJsonList(locationsRaw)
            .map((e) => _normalizeWorldLocation(asJsonMap(e)))
            .toList(growable: false)
      : const <Map<String, dynamic>>[];
  final locationTree = buildWorldLocationTree(locations, worldMapUrl: mapUrl);
  final charactersRaw = raw['characters'];
  final characters = charactersRaw is List
      ? asJsonList(charactersRaw)
            .map((e) => _worldCharacterFromV1(asJsonMap(e)))
            .toList(growable: false)
      : const <Map<String, dynamic>>[];
  final characterPositions = characters
      .map(_worldCharacterPositionFromV1)
      .whereType<Map<String, dynamic>>()
      .toList(growable: false);
  final userPositions = characters
      .map(_worldUserPositionFromV1)
      .whereType<Map<String, dynamic>>()
      .toList(growable: false);
  final ticksRaw = raw['tick_list'] ?? raw['ticks'];
  final ticks = ticksRaw is List
      ? asJsonList(ticksRaw).indexed
            .map((entry) => _worldTickFromV1(asJsonMap(entry.$2), entry.$1))
            .toList(growable: false)
      : const <Map<String, dynamic>>[];
  final lastTick = ticks.isNotEmpty ? ticks.last : const <String, dynamic>{};
  final lastTickResult = lastTick['tick_result'] is Map
      ? asJsonMap(lastTick['tick_result'])
      : const <String, dynamic>{};

  return WorldDetail(
    id: worldId,
    worldId: wid,
    originId: originId,
    ownerUid: asString(world['owner_uid']),
    ownerName: asString(world['owner_name']),
    definitionVersion: asInt(world['definition_version'], fallback: 1),
    name: asString(world['world_name']),
    brief: asString(world['brief'], fallback: asString(world['setting'])),
    cover: cover,
    deleted: entityDeleted(
      raw['world_deleted'],
      fallback: entityDeleted(
        world['world_deleted'],
        fallback: world['deleted'],
      ),
    ),
    ownerDeleted: entityDeleted(
      ownerUser['deleted'],
      fallback: world['owner_deleted'],
    ),
    tickCount: asInt(stats['tick_cnt']),
    connectCount: asInt(stats['connect_cnt']),
    characterCount: asInt(stats['character_cnt']),
    playerCount: asInt(stats['player_cnt']),
    currentTime: asString(world['current_time']),
    lastChatLocationId: world['last_chat_location_id'] is String
        ? asString(world['last_chat_location_id']).trim()
        : '',
    mapImageUrl: mapUrl,
    latestTickAt: _apiDateTime(lastTick['created_at'] ?? world['created_at']),
    latestNarrator: asString(lastTickResult['narrator']),
    isProgressing: asInt(world['status']) == 20,
    relationStatus: asString(raw['relation_status']),
    metric: world['metric'] is Map
        ? asJsonMap(world['metric'])
        : const <String, dynamic>{},
    inviteToken: wid,
    createdAt: _apiDateTime(world['created_at']),
    updatedAt: _apiDateTime(world['updated_at']),
    origin: OriginSummary(
      id: originId,
      oid: oid,
      name: asString(world['world_name']),
      description: asString(
        world['setting'],
        fallback: asString(world['brief']),
      ),
      mapImage: cover,
      worldMap: mapUrl,
      worldView: asString(world['setting']),
      deleted: entityDeleted(
        world['origin_deleted'],
        fallback: world['origin'] is Map
            ? asJsonMap(world['origin'])['deleted']
            : null,
      ),
      originator: asString(world['owner_name']),
      versionNum: asInt(world['origin_version']),
      copyCount: 0,
      interactCount: asInt(stats['connect_cnt']),
      characterCount: asInt(stats['character_cnt']),
      tags: _tagsFromV1(world['tags']),
      createdAt: _apiDateTime(world['created_at']),
      updatedAt: _apiDateTime(world['updated_at']),
      characters: const <OriginCharacter>[],
      locations: const <OriginLocation>[],
    ),
    characters: characters,
    ticks: ticks,
    locations: locations,
    locationTree: locationTree,
    processedLocationTree: processLocationTree(locationTree),
    characterPositions: characterPositions,
    userPositions: userPositions,
  );
}

OriginCharacter _originCharacterFromV1(Map<String, dynamic> raw, int originId) {
  final playerUser = raw['player_user'] is Map
      ? asJsonMap(raw['player_user'])
      : const <String, dynamic>{};
  final characterId = asString(
    raw['character_id'],
    fallback: asString(raw['char_id']),
  );
  final currentLocationBusinessId = asString(raw['location_id']);
  final initialLocationBusinessId = asString(raw['initial_location_id']);
  final currentLocationId = _stableInt(
    currentLocationBusinessId.isNotEmpty
        ? currentLocationBusinessId
        : initialLocationBusinessId,
  );
  final initialLocationId = _stableInt(
    initialLocationBusinessId.isNotEmpty
        ? initialLocationBusinessId
        : currentLocationBusinessId,
  );
  final avatarResource = _resolveImageAssetResource(raw['avatar']);
  return OriginCharacter(
    id: asInt(raw['id'], fallback: _stableInt(characterId)),
    characterId: characterId,
    originId: originId,
    name: asString(raw['name']),
    type: asString(raw['type'], fallback: 'ai'),
    playerUid: asString(raw['player_uid']),
    playerUsername: asString(
      playerUser['name'],
      fallback: asString(raw['player_username']),
    ),
    playerDeleted: entityDeleted(
      playerUser['deleted'],
      fallback: raw['player_deleted'],
    ),
    playerUser: _originUserInfoFromV1(playerUser),
    playerJoinedAt: asInt(raw['player_joined_at']),
    avatar: avatarResource.displayUrl,
    avatarResource: avatarResource,
    tags: asString(raw['identity']),
    tagline: asString(raw['brief']),
    goal: asString(raw['goal']),
    currentLocationId: currentLocationId,
    initialLocationId: initialLocationId,
    currentLocationBusinessId: currentLocationBusinessId,
    initialLocationBusinessId: initialLocationBusinessId,
    metricValue: asInt(raw['metric_value']),
    delta: asInt(raw['delta']),
    isRecommend: asInt(raw['is_recommend']),
    createdAt: _apiDateTime(raw['created_at']),
    updatedAt: _apiDateTime(raw['updated_at']),
  );
}

OriginMyLaunchPresetCharacter _originMyLaunchPresetCharacterFromV1(
  Map<String, dynamic> raw,
) {
  final avatarResource = _resolveImageAssetResource(raw['avatar']);
  return OriginMyLaunchPresetCharacter(
    charId: asString(raw['char_id']),
    type: asString(raw['type'], fallback: 'ai'),
    name: asString(raw['name']),
    identity: asString(raw['identity']),
    brief: asString(raw['brief']),
    goal: asString(raw['goal']),
    avatar: avatarResource.displayUrl,
    avatarResource: avatarResource,
    initialLocationId: asString(raw['initial_location_id']),
    lastLaunchedAt: asInt(raw['last_launched_at']),
    worldId: asString(raw['world_id']),
    tickCount: asInt(raw['tick_no']),
    currentTime: asString(raw['current_time']),
  );
}

OriginLocation _originLocationFromV1(Map<String, dynamic> raw, int originId) {
  final locationId = asString(raw['location_id']);
  final parentLocationId = asString(raw['location_pid']);
  final imageResource = _resolveImageAssetResource(raw['image']);
  return OriginLocation(
    id: asInt(raw['id'], fallback: _stableInt(locationId)),
    originId: originId,
    name: asString(raw['name'], fallback: asString(raw['location_name'])),
    icon: imageResource.displayUrl,
    mapUrl: resolveAssetUrl(asString(raw['map_url'])),
    description: asString(
      raw['location_description'],
      fallback: asString(
        raw['description'],
        fallback: asString(raw['location_summary']),
      ),
    ),
    level: asInt(raw['level']),
    locationParagraph: asString(
      raw['location_paragraph'],
      fallback: asString(raw['location_garagraph']),
    ),
    locationTimestamp: asString(raw['location_timestamp']),
    locationSummary: asString(raw['location_summary']),
    position: asInt(raw['position']),
    isActive: true,
    xPercent: _asDouble(raw['x_percent']),
    yPercent: _asDouble(raw['y_percent']),
    x: _asDouble(raw['x']),
    y: _asDouble(raw['y']),
    imageResource: imageResource,
    createdAt: _apiDateTime(raw['created_at']),
    updatedAt: _apiDateTime(raw['updated_at']),
    locationId: locationId,
    parentLocationId: parentLocationId,
    dialogue: raw['dialogue'] is List
        ? asJsonList(raw['dialogue'])
              .whereType<Map>()
              .map((item) => OriginDialogueLine.fromJson(asJsonMap(item)))
              .toList(growable: false)
        : const <OriginDialogueLine>[],
  );
}

OriginUserInfo _originUserInfoFromV1(Map<String, dynamic> raw) {
  final avatarResource = _resolveImageAssetResource(raw['avatar']);
  return OriginUserInfo(
    uid: asString(raw['uid']),
    name: asString(raw['name']),
    avatar: avatarResource.displayUrl,
    avatarResource: avatarResource,
    deleted: entityDeleted(raw['deleted']),
    followerCount: asInt(raw['follower_cnt']),
    followingCount: asInt(raw['following_cnt']),
    friendCount: asInt(raw['friend_cnt']),
    createOriginCount: asInt(raw['create_origin_cnt']),
    launchWorldCount: asInt(raw['launch_world_cnt']),
    joinWorldCount: asInt(raw['join_world_cnt']),
  );
}

Map<String, dynamic>? _worldCharacterPositionFromV1(Map<String, dynamic> raw) {
  final locationId = asString(raw['location_id']);
  if (locationId.isEmpty) return null;
  return {
    'location_id': locationId,
    'character': {
      'id': asString(raw['char_id']),
      'name': asString(raw['name']),
      'type': asString(raw['type']),
      'player_uid': asString(raw['player_uid']),
      'player_username': asString(raw['player_username']),
      'player_deleted': raw['player_deleted'],
      'identity': asString(raw['identity']),
      'tagline': asString(raw['brief']),
      'description': asString(raw['description']),
      'avatar': _resolveImageAssetUrl(raw['avatar']),
    },
  };
}

Map<String, dynamic> _worldCharacterFromV1(Map<String, dynamic> raw) {
  final playerUser = raw['player_user'] is Map
      ? asJsonMap(raw['player_user'])
      : const <String, dynamic>{};
  return {
    'char_id': asString(raw['char_id']),
    'type': asString(raw['type']),
    'player_uid': asString(raw['player_uid']),
    'player_username': asString(
      playerUser['name'],
      fallback: asString(raw['player_username']),
    ),
    'player_user': playerUser,
    'player_deleted': entityDeleted(
      playerUser['deleted'],
      fallback: raw['player_deleted'],
    ),
    'name': asString(raw['name']),
    'identity': asString(raw['identity']),
    'brief': asString(raw['brief']),
    'description': asString(raw['description']),
    'goal': asString(raw['goal']),
    'avatar': _resolveImageAssetUrl(raw['avatar']),
    'initial_location_id': asString(raw['initial_location_id']),
    'location_id': asString(raw['location_id']),
    'player_joined_at': asInt(raw['player_joined_at']),
    'metric_value': raw['metric_value'],
  };
}

Map<String, dynamic> _worldTickFromV1(Map<String, dynamic> raw, int index) {
  final result = raw['tick_result'] is Map
      ? asJsonMap(raw['tick_result'])
      : const <String, dynamic>{};
  final paragraphsRaw = result['paragraphs'];
  final paragraphs = paragraphsRaw is List
      ? asJsonList(
          paragraphsRaw,
        ).map((e) => asJsonMap(e)).toList(growable: false)
      : const <Map<String, dynamic>>[];
  final locationGroupsRaw = result['location_groups'];
  final locationGroups = locationGroupsRaw is List
      ? asJsonList(
          locationGroupsRaw,
        ).map((e) => asJsonMap(e)).toList(growable: false)
      : const <Map<String, dynamic>>[];
  final createdAt = raw['created_at'];
  return {
    'tick_id': asString(raw['tick_id']),
    'tick_no': asInt(raw['tick_no'], fallback: index + 1),
    'sub_tick_no': asInt(raw['sub_tick_no'], fallback: 1),
    'status': asInt(raw['status']),
    'created_at': createdAt,
    'tick_result': {
      'current_time': asString(result['current_time']),
      'narrator': asString(result['narrator']),
      'paragraphs': paragraphs,
      'location_groups': locationGroups,
    },
  };
}

Map<String, dynamic>? _worldUserPositionFromV1(Map<String, dynamic> raw) {
  final playerUid = asString(raw['player_uid']);
  if (playerUid.isEmpty) return null;
  final locationId = asString(raw['location_id']);
  if (locationId.isEmpty) return null;
  final playerUser = raw['player_user'] is Map
      ? asJsonMap(raw['player_user'])
      : const <String, dynamic>{};
  return {
    'uid': playerUid,
    'location_id': locationId,
    'deleted': entityDeleted(
      playerUser['deleted'],
      fallback: raw['player_deleted'],
    ),
  };
}

List<String> _tagsFromV1(Object? raw) {
  if (raw is List) {
    return raw
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }
  return _splitTags(asString(raw));
}

double _asDouble(Object? raw) {
  return raw is num ? raw.toDouble() : double.tryParse('$raw') ?? 0;
}

DateTime? _apiDateTime(Object? raw) {
  if (raw is DateTime) return raw;
  if (raw is num) {
    final value = raw.toInt();
    if (value <= 0) return null;
    final millis = value > 100000000000 ? value : value * 1000;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }
  if (raw is String) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final numeric = int.tryParse(trimmed);
    if (numeric != null) return _apiDateTime(numeric);
    return DateTime.tryParse(trimmed);
  }
  return asDateTime(raw);
}

String _apiDateTimeText(Object? raw) {
  final parsed = _apiDateTime(raw);
  if (parsed != null) return parsed.toIso8601String();
  return asString(raw);
}

WorldMessage _worldMessageFromV5(
  Map<String, dynamic> msg, {
  required String wid,
  required String pointId,
  required String locationId,
}) {
  return WorldMessage.fromJson({
    'id': asString(msg['id'], fallback: '${asInt(msg['chat_seq'])}'),
    'world_id': wid,
    'location_id': locationId.isNotEmpty ? locationId : pointId,
    'uid': asString(
      msg['api_user_id'],
      fallback: asString(
        msg['author_user_id'],
        fallback: asString(
          msg['player_id'],
          fallback: asString(msg['speaker']),
        ),
      ),
    ),
    'content': asString(msg['content'], fallback: asString(msg['text'])),
    'message_type': asString(
      msg['role'],
      fallback: asString(
        msg['message_state'],
        fallback: asString(msg['send_state']),
      ),
    ),
    'created_at': asString(msg['created_at'], fallback: asString(msg['ts'])),
  });
}
