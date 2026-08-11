import 'v1_api_resource.dart';

class WorldV1Api extends V1ApiResource {
  const WorldV1Api(super.client);

  /// GET /api/v1/world/list
  ///
  /// Request parameters:
  /// ```json
  /// {"pn":1,"rn":10,"scene":"uid","uid":"string","tag":"string","origin_id":"string","keyword":"string"}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_str":"success","data":{"list":[{"oid":"string","origin_version_num":1,"origin_version_create_at":"string","wid":"string","status":1,"name":"string","cover":"string","display_subtitle":"string","created_uid":"string","created_user_name":"string","created_at":"string","updated_at":"string","last_tick":{"narrator":"string"},"tags":[],"tick_cnt":0,"connect_cnt":0,"ai_character_cnt":0,"player_cnt":0,"location_cnt":0}],"total":0}}
  /// ```
  Future<Map<String, dynamic>> list({
    String? scene,
    String? tag,
    String? originId,
    String? ownerUid,
    String? uid,
    String? keyword,
    int? pn,
    int? rn,
  }) {
    return getMap(
      'world/list',
      v1Query({
        'scene': scene,
        'tag': tag,
        'origin_id': originId,
        'owner_uid': ownerUid,
        'uid': uid,
        'keyword': keyword,
        'pn': pn,
        'rn': rn,
      }),
    );
  }

  /// GET /api/v1/world/detail
  ///
  /// Request parameters:
  /// ```json
  /// {"world_id":"string"}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_msg":"succ","data":{"info":{"world_id":"string","world_name":"string","origin_id":"string","origin_version":"1","origin_version_time":"string","definition_version":2,"current_time":"Day 7, 19:10","last_chat_location_id":"loc_1_2","owner_uid":"string","owner_name":"string","brief":"string","metric":{},"created_at":0,"cover":"string","map_url":"string","status":10},"stats":{"character_cnt":0,"connect_cnt":0,"location_cnt":0,"tick_cnt":0,"player_cnt":0},"relation_status":"owner","characters":[],"locations":[]}}
  /// ```
  Future<Map<String, dynamic>> detail({required String worldId}) {
    final resolvedWorldId = worldId.trim();
    if (resolvedWorldId.isEmpty) {
      throw ArgumentError.value(worldId, 'worldId', 'must not be empty');
    }
    return getMap('world/detail', {'world_id': resolvedWorldId});
  }

  /// GET /api/v1/world/map
  ///
  /// `location_id=root` returns the main world map; any other value returns the corresponding location map.
  /// The server returns an empty object when definition_version is not 2.
  Future<Map<String, dynamic>> map({
    required String worldId,
    required String locationId,
  }) {
    final resolvedWorldId = worldId.trim();
    final resolvedLocationId = locationId.trim();
    if (resolvedWorldId.isEmpty) {
      throw ArgumentError.value(worldId, 'worldId', 'must not be empty');
    }
    if (resolvedLocationId.isEmpty) {
      throw ArgumentError.value(locationId, 'locationId', 'must not be empty');
    }
    return getMapPreservingKeys('world/map', {
      'world_id': resolvedWorldId,
      'location_id': resolvedLocationId,
    });
  }

  /// GET /api/v1/world/info
  ///
  /// Request parameters:
  /// ```json
  /// {"world_id":"string"}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_msg":"succ","data":{"info":{"world_id":"string","world_name":"string","origin_id":"string","brief":"string","cover":{},"status":10},"stats":{"character_cnt":0,"connect_cnt":0,"location_cnt":0,"tick_cnt":0,"player_cnt":0}}}
  /// ```
  Future<Map<String, dynamic>> info({required String worldId}) {
    final resolvedWorldId = worldId.trim();
    if (resolvedWorldId.isEmpty) {
      throw ArgumentError.value(worldId, 'worldId', 'must not be empty');
    }
    return getMap('world/info', {'world_id': resolvedWorldId});
  }

  /// GET /api/v1/world/origin_progress
  ///
  /// Request parameters:
  /// ```json
  /// {"uid":"u_a1b2c3","origin_id":"ori_a1b2c3"}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_msg":"succ","data":{"world_id":"w_a1b2c3","tick_cnt":12}}
  /// ```
  Future<Map<String, dynamic>> originProgress({
    required String uid,
    required String originId,
  }) {
    return getMap(
      'world/origin_progress',
      v1Query({'uid': uid.trim(), 'origin_id': originId.trim()}),
    );
  }

  /// GET /api/v1/world/summary/latest
  ///
  /// Request parameters:
  /// ```json
  /// {"origin_id":"O_A1B2C3","world_id":"W_A1B2C3"}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_msg":"succ","data":{"list":[{"world_id":"W_A1B2C3","origin_id":"O_A1B2C3","tick_no":12,"summary":"Lotus Hall became peaceful again after the twelfth tick.","tick_time":1780000000,"created_at":1780000010}]}}
  /// ```
  Future<Map<String, dynamic>> summaryLatest({
    String? originId,
    String? worldId,
  }) {
    final resolvedOriginId = originId?.trim();
    final resolvedWorldId = worldId?.trim();
    if ((resolvedOriginId == null || resolvedOriginId.isEmpty) &&
        (resolvedWorldId == null || resolvedWorldId.isEmpty)) {
      throw ArgumentError('originId or worldId must be provided');
    }
    return getMap(
      'world/summary/latest',
      v1Query({'origin_id': resolvedOriginId, 'world_id': resolvedWorldId}),
    );
  }

  /// GET /api/v1/world/tick/list
  ///
  /// Request parameters:
  /// ```json
  /// {"world_id":"string","pn":1,"rn":10}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_msg":"succ","data":{"list":[{"tick_id":"string","tick_no":1,"sub_tick_no":1,"status":50,"tick_result":{"current_time":"string","narrator":"string","paragraphs":[],"location_groups":[]},"created_at":0}],"total":0,"pn":1,"rn":10}}
  /// ```
  Future<Map<String, dynamic>> tickList({
    required String worldId,
    int? pn,
    int? rn,
  }) {
    final resolvedWorldId = worldId.trim();
    if (resolvedWorldId.isEmpty) {
      throw ArgumentError.value(worldId, 'worldId', 'must not be empty');
    }
    return getMap(
      'world/tick/list',
      v1Query({'world_id': resolvedWorldId, 'pn': pn, 'rn': rn}),
    );
  }

  /// POST /api/v1/world/apply
  ///
  /// Request parameters:
  /// ```json
  /// {"world_id":"string","message":"I would like to join this world"}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_msg":"succ","data":{"apply_id":"apl_a1b2c3","status":10}}
  /// ```
  Future<Map<String, dynamic>> apply({
    required String worldId,
    String? message,
  }) {
    return postMap(
      'world/apply',
      v1Body({'world_id': worldId, 'message': message}),
    );
  }

  /// GET /api/v1/world/apply/list
  ///
  /// Request parameters:
  /// ```json
  /// {"pn":1,"rn":20,"world_id":"string","status":10}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_msg":"succ","data":{"list":[{"apply_id":"string","world_id":"string","applicant_uid":"string","message":"string","status":10,"reviewer_uid":"string","review_msg":"string","reviewed_at":0,"joined_at":0,"created_at":0}],"total":0,"pn":1,"rn":20}}
  /// ```
  Future<Map<String, dynamic>> applyList({
    int? pn,
    int? rn,
    String? worldId,
    int? status,
  }) {
    return getMap(
      'world/apply/list',
      v1Query({'pn': pn, 'rn': rn, 'world_id': worldId, 'status': status}),
    );
  }

  /// POST /api/v1/world/apply/review
  ///
  /// Request parameters:
  /// ```json
  /// {"apply_id":"apl_a1b2c3","action":"approve","review_msg":"string"}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_msg":"succ","data":{"apply_id":"string","status":20}}
  /// ```
  Future<Map<String, dynamic>> reviewApply({
    required String applyId,
    required String action,
    String? reviewMsg,
  }) {
    return postMap('world/apply/review', {
      'apply_id': applyId,
      'action': action,
      if (reviewMsg != null) 'review_msg': reviewMsg,
    });
  }

  /// POST /api/v1/world/join
  ///
  /// Request parameters:
  /// ```json
  /// {"world_id":"string","preset_character_id":"char_1","custom_role":{}}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_msg":"succ","data":{"world_id":"w_a1b2c3","char_id":"char_U_KALFO"}}
  /// ```
  Future<Map<String, dynamic>> join({
    required String worldId,
    String? presetCharacterId,
    Map<String, dynamic>? customRole,
  }) {
    return postMap(
      'world/join',
      v1Body({
        'world_id': worldId,
        'preset_character_id': presetCharacterId,
        'custom_role': customRole,
      }),
    );
  }

  /// POST /api/v1/world/tick
  ///
  /// Request parameters:
  /// ```json
  /// {"world_id":"string"}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_str":"success","data":{"world_id":"string","tick_cnt":1,"last_tick":{}}}
  /// ```
  Future<Map<String, dynamic>> tick({required String worldId}) {
    return postMap('world/tick', v1Body({'world_id': worldId}));
  }

  /// POST /api/v1/world/synclastorigin
  ///
  /// Request parameters:
  /// ```json
  /// {"wid":"string"}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_str":"success","data":{}}
  /// ```
  Future<void> syncLatestOrigin({required String wid}) {
    return postVoid('world/synclastorigin', {'wid': wid});
  }

  /// POST /api/v1/world/close
  ///
  /// Request parameters:
  /// ```json
  /// {"wid":"string"}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_str":"success","data":{}}
  /// ```
  Future<void> close({required String wid}) {
    return postVoid('world/close', {'wid': wid});
  }

  /// POST /api/v1/world/delete
  ///
  /// Request parameters:
  /// ```json
  /// {"world_id":"string"}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_msg":"succ","data":{}}
  /// ```
  Future<void> deleteLaunched({required String worldId}) {
    final resolvedWorldId = worldId.trim();
    if (resolvedWorldId.isEmpty) {
      throw ArgumentError.value(worldId, 'worldId', 'must not be empty');
    }
    return postVoid('world/delete', v1Body({'world_id': resolvedWorldId}));
  }

  /// POST /api/v1/world/del
  ///
  /// Request parameters:
  /// ```json
  /// {"wid":"string"}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_str":"success","data":{}}
  /// ```
  Future<void> delete({required String wid}) {
    return postVoid('world/del', {'wid': wid});
  }
}
