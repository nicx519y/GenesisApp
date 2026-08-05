import 'v2_api_resource.dart';

class OriginV2Api extends V2ApiResource {
  const OriginV2Api(super.client);

  /// GET /api/v2/origin/foredit
  ///
  /// Returns the owned Origin's complete detail using the same nested
  /// `info/stats/init_location_group/characters/locations/ticks` shape as
  /// GET /api/v1/origin/detail. Each character includes integer
  /// `is_recommend` (`0` or `1`).
  Future<Map<String, dynamic>> forEdit({required String originId}) {
    final resolvedOriginId = originId.trim();
    if (resolvedOriginId.isEmpty) {
      throw ArgumentError.value(originId, 'originId', 'must not be empty');
    }
    return getMap('origin/foredit', {'origin_id': resolvedOriginId});
  }

  /// POST /api/v2/origin/create
  ///
  /// Uses the automatic 2.5D map generation flow. The server ignores
  /// [definitionVersion] and [tileTypes], persists definition version 2, and
  /// returns a lightweight OriginUpsertResp while map generation continues.
  /// Character entries include integer `is_recommend` (`0` or `1`).
  Future<Map<String, dynamic>> create({
    required String originName,
    String? originVersion,
    int? definitionVersion,
    String? brief,
    String? setting,
    List<String>? events,
    List<String>? tags,
    Map<String, dynamic>? metric,
    String? startedAt,
    String? tickDurationTime,
    Object? cover,
    String? mapUrl,
    Map<String, dynamic>? tileTypes,
    List<Map<String, dynamic>>? characters,
    List<Map<String, dynamic>>? locations,
    Map<String, dynamic>? initLocationGroup,
  }) {
    return postMap(
      'origin/create',
      v2Body({
        'origin_name': originName,
        'origin_version': originVersion,
        'definition_version': definitionVersion,
        'brief': brief,
        'setting': setting,
        'events': events,
        'tags': tags,
        'metric': metric,
        'started_at': startedAt,
        'tick_duration_time': tickDurationTime,
        'cover': cover,
        'map_url': mapUrl,
        'tile_types': tileTypes,
        'characters': characters,
        'locations': locations,
        'init_location_group': initLocationGroup,
      }),
    );
  }

  /// POST /api/v2/origin/update
  ///
  /// Updates an owned Origin and asynchronously regenerates its complete 2.5D
  /// map. Omitting [initLocationGroup] tells the server to clear the previous
  /// initial dialogue. Character entries include integer `is_recommend`
  /// (`0` or `1`).
  Future<Map<String, dynamic>> update({
    required String originId,
    required String originName,
    String? originVersion,
    int? definitionVersion,
    String? brief,
    String? setting,
    List<String>? events,
    List<String>? tags,
    Map<String, dynamic>? metric,
    String? startedAt,
    String? tickDurationTime,
    Object? cover,
    String? mapUrl,
    Map<String, dynamic>? tileTypes,
    List<Map<String, dynamic>>? characters,
    List<Map<String, dynamic>>? locations,
    List<String>? deletedCharIds,
    List<String>? deletedLocationIds,
    String? updateNotes,
    Map<String, dynamic>? initLocationGroup,
  }) {
    return postMap(
      'origin/update',
      v2Body({
        'origin_id': originId,
        'origin_name': originName,
        'origin_version': originVersion,
        'definition_version': definitionVersion,
        'brief': brief,
        'setting': setting,
        'events': events,
        'tags': tags,
        'metric': metric,
        'started_at': startedAt,
        'tick_duration_time': tickDurationTime,
        'cover': cover,
        'map_url': mapUrl,
        'tile_types': tileTypes,
        'characters': characters,
        'locations': locations,
        'update_notes': updateNotes,
        'deleted_char_ids': deletedCharIds,
        'deleted_location_ids': deletedLocationIds,
        'init_location_group': initLocationGroup,
      }),
    );
  }
}
