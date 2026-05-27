import 'v1_api_resource.dart';

class WorldV1Api extends V1ApiResource {
  const WorldV1Api(super.client);

  /// GET /api/v1/world/list
  ///
  /// 提交参数:
  /// ```json
  /// {"pn":1,"rn":10,"origin_id":"string","uid":"string","keyword":"string"}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_str":"success","data":{"list":[{"oid":"string","origin_version_num":1,"origin_version_create_at":"string","wid":"string","status":1,"name":"string","cover":"string","display_subtitle":"string","created_uid":"string","created_user_name":"string","created_at":"string","updated_at":"string","tags":[],"tick_cnt":0,"connect_cnt":0,"ai_character_cnt":0,"player_cnt":0,"location_cnt":0}],"total":0}}
  /// ```
  Future<Map<String, dynamic>> list({
    String? scene,
    String? originId,
    String? uid,
    String? keyword,
    int? pn,
    int? rn,
  }) {
    return getMap(
      'world/list',
      v1Query({
        'scene': scene,
        'origin_id': originId,
        'uid': uid,
        'keyword': keyword,
        'pn': pn,
        'rn': rn,
      }),
    );
  }

  /// GET /api/v1/world/detail
  ///
  /// 提交参数:
  /// ```json
  /// {"world_id":"string"}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_str":"success","data":{"info":{"world_id":"string","world_name":"string","origin_id":"string","origin_version":"1","origin_version_time":"string","brief":"string","setting":"string","events":[],"tags":[],"created_at":"string","created_uid":"string","created_user_name":"string","owner_uid":"string","owner_name":"string","updated_at":"string","last_progress_at":"string","last_progress_summary":"string","preview_images":[],"started_at":"string","tick_duration_days":30,"cover":"string","map_url":"string","status":1},"stats":{"character_cnt":0,"connect_cnt":0,"location_cnt":0,"tick_cnt":0,"player_cnt":0},"characters":[{"char_id":"string","type":"ai","player_uid":"string","name":"string","identity":"string","brief":"string","description":"string","goal":"string","avatar":"string","initial_location_id":"string","location_id":"string","metric_value":50}],"locations":[{"location_id":"string","location_pid":"string","location_name":"string","location_summary":"string","image":"string","map_url":"string","x_percent":0,"y_percent":0}],"ticks":[{"content":"string","created_at":"string"}]}}
  /// ```
  Future<Map<String, dynamic>> detail({String? worldId, String? wid}) {
    final resolvedWorldId = (worldId ?? wid ?? '').trim();
    if (resolvedWorldId.isEmpty) {
      throw ArgumentError.value(worldId ?? wid, 'worldId', 'must not be empty');
    }
    return getMap('world/detail', {'world_id': resolvedWorldId});
  }

  /// POST /api/v1/world/request
  ///
  /// 提交参数:
  /// ```json
  /// {"wid":"string"}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_str":"success","data":{}}
  /// ```
  Future<void> requestJoin({required String wid}) {
    return postVoid('world/request', {'wid': wid});
  }

  /// POST /api/v1/world/request/audit
  ///
  /// 提交参数:
  /// ```json
  /// {"request_id":"string","action":"approve"}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_str":"success","data":{}}
  /// ```
  Future<void> auditRequest({
    required String requestId,
    required String action,
  }) {
    return postVoid('world/request/audit', {
      'request_id': requestId,
      'action': action,
    });
  }

  /// POST /api/v1/world/join
  ///
  /// 提交参数:
  /// ```json
  /// {"wid":"string","preset_character_id":"string","custom_role":{}}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_str":"success","data":{"world":{"oid":"string","origin_version_num":1,"origin_version_create_at":"string","wid":"string","status":1,"is_join":1,"apply_status":"success","name":"string","cover":"string","display_subtitle":"string","world_view":"string","world_setting":"string","created_uid":"string","created_user_name":"string","created_at":"string","updated_at":"string","tags":[],"tick_cnt":0,"connect_cnt":0,"ai_character_cnt":0,"player_cnt":0,"location_cnt":0},"character_list":[{"type":"ai","status":10,"player_uid":"string","character_id":"string","name":"string","identity":"string","tagline":"string","description":"string","goal":"string","avatar":"string","location_id":"string"}],"metric":{"mode":"quantitative","label":"string","unit":"string","range":[0,100],"default":50},"location_list":[{"location_id":"string","name":"string","description":"string","image":"string","x_percent":0,"y_percent":0}],"tick_list":[],"action_button_state":"progress"}}
  /// ```
  Future<Map<String, dynamic>> join({
    required String wid,
    String? presetCharacterId,
    Map<String, dynamic>? customRole,
  }) {
    return postMap(
      'world/join',
      v1Body({
        'wid': wid,
        'preset_character_id': presetCharacterId,
        'custom_role': customRole,
      }),
    );
  }

  /// POST /api/v1/world/tick
  ///
  /// 提交参数:
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
  /// 提交参数:
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
  /// 提交参数:
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

  /// POST /api/v1/world/del
  ///
  /// 提交参数:
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
