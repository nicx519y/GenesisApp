part of 'genesis_api.dart';

OriginSummary _originSummaryFromV1ListItem(Map<String, dynamic> raw) {
  final origin = raw['info'] is Map ? asJsonMap(raw['info']) : raw;
  final stats = raw['stats'] is Map ? asJsonMap(raw['stats']) : raw;
  final oid = asString(origin['oid'], fallback: asString(origin['origin_id']));
  final cover = _resolveImageAssetUrl(
    origin['cover'],
    fallback: origin['map_url'],
  );
  final mapUrlRaw = asString(origin['map_url']).trim();
  final mapUrl = mapUrlRaw.isNotEmpty ? resolveAssetUrl(mapUrlRaw) : cover;

  return OriginSummary(
    id: asInt(origin['id'], fallback: _stableInt(oid)),
    oid: oid,
    name: asString(
      origin['name'],
      fallback: asString(origin['origin_name'], fallback: oid),
    ),
    description: asString(
      origin['display_subtitle'],
      fallback: asString(
        origin['brief'],
        fallback: asString(
          origin['setting'],
          fallback: asString(origin['world_setting']),
        ),
      ),
    ),
    mapImage: cover,
    worldMap: mapUrl,
    worldView: asString(
      origin['world_view'],
      fallback: asString(origin['setting']),
    ),
    deleted: entityDeleted(
      origin['deleted'],
      fallback: origin['origin_deleted'],
    ),
    originator: _originatorFromOriginMap(origin),
    versionNum: asInt(
      origin['version_num'],
      fallback: asInt(origin['origin_version']),
    ),
    copyCount: asInt(stats['copy_cnt']),
    interactCount: asInt(stats['connect_cnt']),
    characterCount: asInt(stats['character_cnt']),
    tags: _tagsFromV1(origin['tags']),
    createdAt: _apiDateTime(origin['created_at']),
    updatedAt: _apiDateTime(
      origin['updated_at'] ?? origin['origin_version_time'],
    ),
    characters: const <OriginCharacter>[],
    locations: const <OriginLocation>[],
  );
}

MyWorldSummary _myWorldSummaryFromV1ListItem(Map<String, dynamic> raw) {
  final world = raw['info'] is Map ? asJsonMap(raw['info']) : raw;
  final stats = raw['stats'] is Map ? asJsonMap(raw['stats']) : world;
  final wid = asString(world['wid'], fallback: asString(world['world_id']));
  final name = asString(
    world['name'],
    fallback: asString(world['world_name'], fallback: wid),
  );
  final cover = _resolveImageAssetUrl(
    world['snapshot_cover_url'],
    fallback: world['cover'] ?? world['map_url'] ?? world['cover_url'],
  );

  return MyWorldSummary(
    wid: wid,
    name: name,
    deleted: entityDeleted(
      raw['world_deleted'],
      fallback: entityDeleted(
        world['world_deleted'],
        fallback: world['deleted'],
      ),
    ),
    snapshotCoverUrl: cover,
    updatedAtText: _apiDateTimeText(
      world['last_active_at'] ?? world['updated_at'] ?? world['created_at'],
    ),
    ownerName: asString(
      world['owner_name'],
      fallback: asString(world['created_user_name']),
    ),
    progressCount: asInt(stats['tick_cnt']),
    interactCount: asInt(stats['connect_cnt']),
    characterCount: asInt(
      stats['ai_character_cnt'],
      fallback: asInt(stats['character_cnt']),
    ),
    playerCount: asInt(stats['player_cnt']),
  );
}

WorldSummaryLatestItem _worldSummaryLatestItemFromV1(Map<String, dynamic> raw) {
  return WorldSummaryLatestItem(
    worldId: asString(raw['world_id']),
    originId: asString(raw['origin_id']),
    deleted: entityDeleted(raw['world_deleted'], fallback: raw['deleted']),
    tickNo: asInt(raw['tick_no']),
    summary: asString(raw['summary']),
    tickTime: asInt(raw['tick_time']),
    createdAt: asInt(raw['created_at']),
  );
}

String _originatorFromOriginMap(Map<String, dynamic> origin) {
  return asString(
    origin['owner_name'],
    fallback: asString(
      origin['created_user_name'],
      fallback: asString(origin['originator']),
    ),
  );
}

OriginSummary _originSummaryFromV5(Map<String, dynamic> raw) {
  final tagsRaw = raw['Otags'];
  final tags = tagsRaw is List
      ? tagsRaw
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList(growable: false)
      : _splitTags(asString(tagsRaw));

  final worldviewId = asString(
    raw['worldviewId'],
    fallback: asString(raw['OidStr']),
  );
  final mapImage = _resolveImageAssetUrl(
    raw['Omap_image'],
    fallback: raw['Oworld_view_image'],
  );
  final id = asInt(raw['Oid'], fallback: _stableInt(worldviewId));

  return OriginSummary(
    id: id,
    oid: worldviewId,
    name: asString(raw['Oname']),
    description: asString(
      raw['Odescription'],
      fallback: asString(raw['Osubtitle']),
    ),
    mapImage: mapImage,
    worldMap: mapImage,
    worldView: asString(raw['Odescription']),
    copyCount: asInt(raw['Ocopycount']),
    interactCount: asInt(raw['Oconnectcount']),
    characterCount: _originCharactersFromV5(raw['Ocharacters'], id).length,
    tags: tags,
    createdAt: null,
    updatedAt: asDateTime(raw['Oupdated_time']),
    characters: _originCharactersFromV5(raw['Ocharacters'], id),
    locations: _originLocationsFromV5(raw['Omap_points'], id),
  );
}

List<OriginCharacter> _originCharactersFromV5(Object? raw, int originId) {
  if (raw is! List) return const <OriginCharacter>[];
  return raw
      .asMap()
      .entries
      .map((entry) {
        final i = entry.key;
        final c = asJsonMap(entry.value);
        return OriginCharacter(
          id: asInt(c['id'], fallback: i + 1),
          characterId: asString(c['character_id'], fallback: asString(c['id'])),
          originId: originId,
          name: asString(c['name']),
          avatar: _resolveImageAssetUrl(c['image']),
          tags: asString(c['identity']),
          tagline: asString(c['brief']),
          goal: asString(c['goal']),
          currentLocationId: _extractTrailingInt(asString(c['Ochar_point'])),
          initialLocationId: _extractTrailingInt(asString(c['Ochar_point'])),
          createdAt: null,
          updatedAt: null,
        );
      })
      .toList(growable: false);
}

List<OriginLocation> _originLocationsFromV5(Object? raw, int originId) {
  if (raw is! List) return const <OriginLocation>[];
  return raw
      .asMap()
      .entries
      .map((entry) {
        final i = entry.key;
        final p = asJsonMap(entry.value);
        var x = p['x'] is num
            ? (p['x'] as num).toDouble()
            : double.tryParse('${p['x']}') ?? 0;
        var y = p['y'] is num
            ? (p['y'] as num).toDouble()
            : double.tryParse('${p['y']}') ?? 0;
        if (x > 0 && x <= 1.0) x *= 100;
        if (y > 0 && y <= 1.0) y *= 100;

        final id = asInt(
          p['id'],
          fallback: _extractTrailingInt(asString(p['id']), fallback: i + 1),
        );
        return OriginLocation(
          id: id,
          originId: originId,
          name: asString(p['label']),
          icon: _resolveImageAssetUrl(p['image']),
          mapUrl: asString(p['map_url']),
          description: '',
          position: i + 1,
          isActive: true,
          xPercent: x,
          yPercent: y,
          createdAt: null,
          updatedAt: null,
          locationId: asString(p['location_id'], fallback: '$id'),
          parentLocationId: asString(p['location_pid']),
        );
      })
      .toList(growable: false);
}

Map<String, dynamic> _normalizeWorldLocation(Map<String, dynamic> location) {
  final locationId = asString(location['location_id']);
  final parentLocationId = asString(location['location_pid']);
  final pointId = asString(location['point_id'], fallback: locationId);
  final xPercentRaw = location['x_percent'];
  final yPercentRaw = location['y_percent'];

  double xPercent = xPercentRaw is num
      ? xPercentRaw.toDouble()
      : double.tryParse('$xPercentRaw') ?? 0;
  double yPercent = yPercentRaw is num
      ? yPercentRaw.toDouble()
      : double.tryParse('$yPercentRaw') ?? 0;

  final locationName = asString(
    location['location_name'],
    fallback: asString(location['name']),
  );
  final locationSummary = asString(
    location['location_summary'],
    fallback: asString(location['summary']),
  );
  final locationDescription = asString(
    location['location_description'],
    fallback: asString(location['description']),
  );

  return {
    'location_id': locationId,
    'location_pid': parentLocationId,
    'point_id': pointId,
    'location_name': locationName,
    'location_summary': locationSummary,
    'location_description': locationDescription,
    'location_paragraph': asString(location['location_paragraph']),
    'location_timestamp': asString(location['location_timestamp']),
    'image': location['image'],
    'icon': _resolveImageAssetUrl(location['image']),
    'map_url': asString(location['map_url']),
    'dialogue': location['dialogue'] is List
        ? asJsonList(
            location['dialogue'],
          ).map((e) => asJsonMap(e)).toList(growable: false)
        : const <Map<String, dynamic>>[],
    'x_percent': xPercent,
    'y_percent': yPercent,
  };
}

OriginDetail _originDetailFromV1(Map<String, dynamic> raw) {
  final origin = raw['origin'] is Map
      ? asJsonMap(raw['origin'])
      : asJsonMap(raw['info']);
  final ownerUser = origin['owner_user'] is Map
      ? asJsonMap(origin['owner_user'])
      : const <String, dynamic>{};
  final stats = raw['stats'] is Map ? asJsonMap(raw['stats']) : origin;
  final oid = asString(origin['oid'], fallback: asString(origin['origin_id']));
  final id = _stableInt(oid);
  final coverResource = _resolveImageAssetResource(
    origin['cover'],
    fallback: origin['map_url'],
  );
  final cover = coverResource.displayUrl;
  final mapUrlRaw = asString(origin['map_url']).trim();
  final mapUrl = mapUrlRaw.isNotEmpty ? resolveAssetUrl(mapUrlRaw) : cover;
  final charactersRaw = raw['character_list'] ?? raw['characters'];
  final characters = charactersRaw is List
      ? asJsonList(charactersRaw)
            .map((e) => _originCharacterFromV1(asJsonMap(e), id))
            .toList(growable: false)
      : const <OriginCharacter>[];
  final locationsRaw = raw['location_list'] ?? raw['locations'];
  final locations = locationsRaw is List
      ? asJsonList(locationsRaw)
            .map((e) => _originLocationFromV1(asJsonMap(e), id))
            .toList(growable: false)
      : const <OriginLocation>[];
  final locationTree = buildOriginLocationTree(
    locations,
    originMapUrl: mapUrl,
    originId: id,
  );
  final events = _originEventsFromV1(raw);
  final ticks = _originTicksFromV1(raw);

  return OriginDetail(
    id: id,
    oid: oid,
    name: asString(
      origin['name'],
      fallback: asString(origin['origin_name'], fallback: oid),
    ),
    description: asString(
      origin['brief'],
      fallback: asString(
        origin['world_setting'],
        fallback: asString(
          origin['display_subtitle'],
          fallback: asString(origin['setting']),
        ),
      ),
    ),
    mapImage: cover,
    worldMap: mapUrl,
    worldView: asString(
      origin['brief'],
      fallback: asString(
        origin['world_view'],
        fallback: asString(origin['setting']),
      ),
    ),
    deleted: entityDeleted(
      origin['deleted'],
      fallback: origin['origin_deleted'],
    ),
    ownerDeleted: entityDeleted(
      ownerUser['deleted'],
      fallback: origin['owner_deleted'],
    ),
    ownerUid: asString(
      origin['owner_uid'],
      fallback: asString(origin['created_uid']),
    ),
    originator: asString(
      origin['owner_name'],
      fallback: asString(
        origin['created_user_name'],
        fallback: asString(origin['originator']),
      ),
    ),
    ownerUser: _originUserInfoFromV1(ownerUser),
    originVersion: asString(
      origin['origin_version'],
      fallback: asString(
        origin['version_num'],
        fallback: asString(origin['origin_version_num']),
      ),
    ),
    originVersionTime: _apiDateTime(origin['origin_version_time']),
    versionNum: asInt(
      origin['version_num'],
      fallback: asInt(
        origin['origin_version'],
        fallback: asInt(origin['origin_version_num']),
      ),
    ),
    definitionVersion: asInt(origin['definition_version'], fallback: 1),
    language: asString(origin['language']),
    currentTime: asString(origin['current_time']),
    status: asInt(origin['status']),
    startTime: asString(
      origin['started_at'],
      fallback: asString(origin['start_time']),
    ),
    showOpeningSheet: asBool(raw['show_opening_sheet']),
    copyCount: asInt(stats['copy_cnt']),
    interactCount: asInt(stats['connect_cnt']),
    discussCount: asInt(stats['discuss_cnt']),
    characterCount: asInt(
      stats['character_cnt'],
      fallback: asInt(stats['ai_character_cnt'], fallback: characters.length),
    ),
    locationCount: asInt(stats['location_cnt'], fallback: locations.length),
    maxTickCount: asInt(stats['max_tick_cnt']),
    tags: _tagsFromV1(origin['tags']),
    createdAt: _apiDateTime(origin['created_at']),
    updatedAt: _apiDateTime(
      origin['updated_at'] ?? origin['origin_version_time'],
    ),
    characters: characters,
    locations: buildOriginLocationHierarchy(locations),
    allLocations: locations,
    locationTree: locationTree,
    processedLocationTree: processLocationTree(locationTree),
    events: events,
    ticks: ticks,
    metric: origin['metric'] is Map
        ? asJsonMap(origin['metric'])
        : const <String, dynamic>{},
    coverResource: coverResource,
    initLocationGroup: OriginInitLocationGroup.fromJsonOrNull(
      raw['init_location_group'] ?? origin['init_location_group'],
    ),
  );
}

List<Map<String, dynamic>> _originTicksFromV1(Map<String, dynamic> raw) {
  final ticksRaw = raw['tick_list'] ?? raw['ticks'];
  if (ticksRaw is! List) return const <Map<String, dynamic>>[];
  return asJsonList(ticksRaw)
      .whereType<Map>()
      .indexed
      .map((entry) {
        final index = entry.$1;
        final tick = asJsonMap(entry.$2);
        final result = tick['tick_result'] is Map
            ? asJsonMap(tick['tick_result'])
            : tick;
        final paragraphsRaw = result['paragraphs'];
        final paragraphs = paragraphsRaw is List
            ? asJsonList(paragraphsRaw)
                  .whereType<Map>()
                  .map((e) => asJsonMap(e))
                  .toList(growable: false)
            : const <Map<String, dynamic>>[];
        final locationGroupsRaw = result['location_groups'];
        final locationGroups = locationGroupsRaw is List
            ? asJsonList(locationGroupsRaw)
                  .whereType<Map>()
                  .map((e) => asJsonMap(e))
                  .toList(growable: false)
            : const <Map<String, dynamic>>[];

        return <String, dynamic>{
          'tick_id': asString(tick['tick_id']),
          'tick_no': asInt(tick['tick_no'], fallback: index + 1),
          'sub_tick_no': asInt(tick['sub_tick_no'], fallback: 1),
          'status': asInt(tick['status']),
          'created_at': tick['created_at'],
          'tick_result': <String, dynamic>{
            'current_time': asString(
              result['current_time'],
              fallback: asString(tick['current_time']),
            ),
            'narrator': asString(
              result['narrator'],
              fallback: asString(
                tick['narrator'],
                fallback: asString(tick['summary']),
              ),
            ),
            'paragraphs': paragraphs,
            if (locationGroupsRaw is List) 'location_groups': locationGroups,
          },
        };
      })
      .toList(growable: false);
}

List<OriginEvent> _originEventsFromV1(Map<String, dynamic> raw) {
  final info = raw['info'] is Map ? asJsonMap(raw['info']) : const {};
  final eventsRaw = raw['event_list'] ?? raw['events'] ?? info['events'];
  if (eventsRaw is List) {
    return asJsonList(eventsRaw)
        .map(_originEventFromV1)
        .where((event) => event.content.trim().isNotEmpty)
        .toList(growable: false);
  }

  final ticksRaw = raw['tick_list'] ?? raw['ticks'];
  if (ticksRaw is! List) return const <OriginEvent>[];

  final events = <OriginEvent>[];
  for (final tick in asJsonList(ticksRaw)) {
    final tickMap = asJsonMap(tick);
    final tickResult = tickMap['tick_result'] is Map
        ? asJsonMap(tickMap['tick_result'])
        : tickMap;
    final narrator = asString(
      tickResult['narrator'],
      fallback: asString(
        tickMap['narrator'],
        fallback: asString(tickMap['summary']),
      ),
    );
    if (narrator.trim().isNotEmpty) {
      events.add(
        OriginEvent(
          label: 'Global',
          timestamp: asString(tickMap['created_at']),
          content: narrator,
        ),
      );
    }

    final paragraphs = tickResult['paragraphs'];
    if (paragraphs is List) {
      for (final paragraph in asJsonList(paragraphs)) {
        final event = OriginEvent.fromJson(asJsonMap(paragraph));
        if (event.content.trim().isNotEmpty) events.add(event);
      }
    }
  }
  return events;
}

OriginEvent _originEventFromV1(Object? raw) {
  if (raw is Map) return OriginEvent.fromJson(asJsonMap(raw));
  return OriginEvent(label: '', timestamp: '', content: asString(raw));
}
