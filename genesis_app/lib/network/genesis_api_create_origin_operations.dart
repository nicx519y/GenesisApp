part of 'genesis_api.dart';

mixin _GenesisApiCreateOriginOperations on _GenesisApiContext {
  Future<CreateOriginResult> createOrigin({
    required Map<String, dynamic> payload,
  }) async {
    final events = _createOriginEventStrings(payload['event_list']);
    final created = await v1.origin.create(
      originName: asString(payload['name']),
      originVersion: _createOriginOptionalString(payload['origin_version']),
      brief: asString(payload['world_view']),
      setting: asString(payload['world_setting']),
      events: events.isEmpty ? null : events,
      tags: _createOriginStringList(payload['tags']),
      metric: payload['metric'] is Map ? asJsonMap(payload['metric']) : null,
      startedAt: _createOriginOptionalString(payload['started_at']),
      tickDurationTime: _createOriginTickDurationTime(payload),
      cover: asString(payload['cover']),
      characters: _createOriginCharacters(payload),
      locations: _createOriginLocations(payload),
    );
    final detail = created['info'] is Map
        ? asJsonMap(created['info'])
        : created['origin'] is Map
        ? asJsonMap(created['origin'])
        : created;
    final oid = asString(
      detail['origin_id'],
      fallback: asString(
        detail['oid'],
        fallback: asString(created['origin_id']),
      ),
    );
    return CreateOriginResult(worldviewId: oid, oid: oid);
  }

  Future<CreateOriginResult> createOriginV2({
    required Map<String, dynamic> payload,
  }) async {
    final events = _createOriginEventStrings(payload['event_list']);
    final created = await v2.origin.create(
      originName: asString(payload['name']),
      originVersion: _createOriginOptionalString(payload['origin_version']),
      definitionVersion: _createOriginOptionalInt(
        payload['definition_version'],
      ),
      brief: asString(payload['world_view']),
      setting: asString(payload['world_setting']),
      events: events.isEmpty ? null : events,
      tags: _createOriginStringList(payload['tags']),
      metric: payload['metric'] is Map ? asJsonMap(payload['metric']) : null,
      startedAt: _createOriginOptionalString(payload['started_at']),
      tickDurationTime: _createOriginTickDurationTime(payload),
      cover: _createOriginImageInput(payload['cover']),
      mapUrl: _createOriginOptionalString(payload['map_url']),
      tileTypes: payload['tile_types'] is Map
          ? asJsonMap(payload['tile_types'])
          : null,
      characters: _createOriginCharacters(payload, includeRecommendation: true),
      locations: _createOriginLocations(payload),
      initLocationGroup: payload['init_location_group'] is Map
          ? asJsonMap(payload['init_location_group'])
          : null,
    );
    final oid = _originIdFromUpsert(created);
    return CreateOriginResult(worldviewId: oid, oid: oid);
  }

  Future<CreateOriginResult> updateOrigin({
    required String oid,
    required Map<String, dynamic> payload,
  }) async {
    final events = _createOriginEventStrings(payload['event_list']);
    final updated = await v1.origin.update(
      originId: asString(payload['origin_id'], fallback: oid),
      originName: asString(payload['name']),
      originVersion: _createOriginOptionalString(payload['origin_version']),
      brief: asString(payload['world_view']),
      setting: asString(payload['world_setting']),
      events: events.isEmpty ? null : events,
      tags: _createOriginStringList(payload['tags']),
      metric: payload['metric'] is Map ? asJsonMap(payload['metric']) : null,
      startedAt: _createOriginOptionalString(payload['started_at']),
      tickDurationTime: _createOriginTickDurationTime(payload),
      cover: asString(payload['cover']),
      characters: _createOriginCharacters(payload),
      locations: _createOriginLocations(payload),
      deletedCharIds:
          _createOriginStringList(payload['deleted_char_ids']) ??
          const <String>[],
      deletedLocationIds:
          _createOriginStringList(payload['deleted_location_ids']) ??
          const <String>[],
      updateNotes: _createOriginOptionalString(payload['update_notes']),
    );
    final detail = updated['info'] is Map
        ? asJsonMap(updated['info'])
        : updated['origin'] is Map
        ? asJsonMap(updated['origin'])
        : updated;
    final updatedOid = asString(
      detail['origin_id'],
      fallback: asString(
        detail['oid'],
        fallback: asString(updated['origin_id'], fallback: oid),
      ),
    );
    return CreateOriginResult(worldviewId: updatedOid, oid: updatedOid);
  }

  Future<CreateOriginResult> updateOriginV2({
    required String oid,
    required Map<String, dynamic> payload,
  }) async {
    final events = _createOriginEventStrings(payload['event_list']);
    final updated = await v2.origin.update(
      originId: asString(payload['origin_id'], fallback: oid),
      originName: asString(payload['name']),
      originVersion: _createOriginOptionalString(payload['origin_version']),
      definitionVersion: _createOriginOptionalInt(
        payload['definition_version'],
      ),
      brief: asString(payload['world_view']),
      setting: payload.containsKey('world_setting')
          ? asString(payload['world_setting'])
          : null,
      events: payload['event_list'] is List ? events : null,
      tags: _createOriginStringList(payload['tags']),
      metric: payload['metric'] is Map ? asJsonMap(payload['metric']) : null,
      startedAt: _createOriginOptionalString(payload['started_at']),
      tickDurationTime: _createOriginTickDurationTime(payload),
      cover: _createOriginImageInput(payload['cover']),
      mapUrl: _createOriginOptionalString(payload['map_url']),
      tileTypes: payload['tile_types'] is Map
          ? asJsonMap(payload['tile_types'])
          : null,
      characters: _createOriginCharacters(payload, includeRecommendation: true),
      locations: _createOriginLocations(payload),
      deletedCharIds:
          _createOriginStringList(payload['deleted_char_ids']) ??
          const <String>[],
      deletedLocationIds:
          _createOriginStringList(payload['deleted_location_ids']) ??
          const <String>[],
      updateNotes: _createOriginOptionalString(payload['update_notes']),
      initLocationGroup: payload['init_location_group'] is Map
          ? asJsonMap(payload['init_location_group'])
          : null,
    );
    final updatedOid = _originIdFromUpsert(updated, fallback: oid);
    return CreateOriginResult(worldviewId: updatedOid, oid: updatedOid);
  }
}
