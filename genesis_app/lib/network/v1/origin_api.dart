import 'v1_api_resource.dart';

class OriginV1Api extends V1ApiResource {
  const OriginV1Api(super.client);

  /// GET /api/v1/origin/list
  ///
  /// 提交参数:
  /// ```json
  /// {"pn":1,"rn":10,"tag_id":1,"keyword":"string","uid":"string","tag_name":"string"}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_str":"success","data":{"list":[{"oid":"string","status":1,"version_num":1,"name":"string","cover":"string","display_subtitle":"string","world_view":"string","created_uid":"string","created_user_name":"string","created_at":"string","updated_at":"string","tags":[],"copy_cnt":0,"connect_cnt":0,"discuss_cnt":0,"character_cnt":0,"location_cnt":0}],"total":0}}
  /// ```
  Future<Map<String, dynamic>> list({
    String? scene,
    String? tag,
    int? tagId,
    String? keyword,
    String? uid,
    String? tagName,
    int? pn,
    int? rn,
  }) {
    return getMap(
      'origin/list',
      v1Query({
        'scene': scene,
        'tag_id': tagId,
        'keyword': keyword,
        'uid': uid,
        'tag_name': tagName ?? tag,
        'pn': pn,
        'rn': rn,
      }),
    );
  }

  /// GET /api/v1/origin/detail
  ///
  /// 提交参数:
  /// ```json
  /// {"origin_id":"string"}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_str":"success","data":{"origin":{"oid":"string","status":1,"version_num":1,"name":"string","cover":"string","display_subtitle":"string","world_view":"string","world_setting":"string","created_uid":"string","created_user_name":"string","created_at":"string","updated_at":"string","tags":[],"copy_cnt":0,"connect_cnt":0,"discuss_cnt":0,"character_cnt":0,"location_cnt":0,"start_time":"string","tick_duration_days":30},"character_list":[{"character_id":"string","name":"string","identity":"string","tagline":"string","description":"string","goal":"string","avatar":"string","location_id":"string"}],"metric":{"mode":"quantitative","label":"string","unit":"string","range":[0,100],"default":50},"location_list":[{"location_id":"string","name":"string","description":"string","image":"string","x_percent":0,"y_percent":0}],"event_list":[{"content":"string"}]}}
  /// ```
  Future<Map<String, dynamic>> detail({
    String? originId,
    String? oid,
    int? version,
  }) {
    final resolvedOriginId = (originId ?? oid ?? '').trim();
    if (resolvedOriginId.isEmpty) {
      throw ArgumentError.value(
        originId ?? oid,
        'originId',
        'must not be empty',
      );
    }
    return getMap('origin/detail', {'origin_id': resolvedOriginId});
  }

  /// POST /api/v1/origin/create
  ///
  /// 提交参数:
  /// ```json
  /// {"name":"string","world_view":"string","world_setting":"string","cover":"string","character_list":[],"location_list":[],"event_list":[],"metric":{}}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_str":"success","data":{"origin":{"oid":"string","status":1,"version_num":1,"name":"string","cover":"string","display_subtitle":"string","world_view":"string","world_setting":"string","created_uid":"string","created_user_name":"string","created_at":"string","updated_at":"string","tags":[],"copy_cnt":0,"connect_cnt":0,"discuss_cnt":0,"character_cnt":0,"location_cnt":0,"start_time":"string","tick_duration_days":30},"character_list":[{"character_id":"string","name":"string","identity":"string","tagline":"string","description":"string","goal":"string","avatar":"string","location_id":"string"}],"metric":{"mode":"quantitative","label":"string","unit":"string","range":[0,100],"default":50},"location_list":[{"location_id":"string","name":"string","description":"string","image":"string","x_percent":0,"y_percent":0}],"event_list":[{"content":"string"}]}}
  /// ```
  Future<Map<String, dynamic>> create({
    String? originId,
    required String name,
    required String worldView,
    required String cover,
    String? worldSetting,
    required List<Map<String, dynamic>> characterList,
    List<Map<String, dynamic>>? locationList,
    List<Map<String, dynamic>>? eventList,
    Map<String, dynamic>? metric,
  }) {
    return postMap(
      'origin/create',
      v1Body({
        'origin_id': originId,
        'name': name,
        'world_view': worldView,
        'world_setting': worldSetting,
        'cover': cover,
        'character_list': characterList,
        'location_list': locationList,
        'event_list': eventList,
        'metric': metric,
      }),
    );
  }

  /// POST /api/v1/origin/update
  ///
  /// 提交参数:
  /// ```json
  /// {"oid":"string","name":"string","world_view":"string","world_setting":"string","cover":"string","character_list":[],"location_list":[],"event_list":[],"metric":{},"update_notes":"string"}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_str":"success","data":{"origin":{"oid":"string","status":1,"version_num":1,"name":"string","cover":"string","display_subtitle":"string","world_view":"string","world_setting":"string","created_uid":"string","created_user_name":"string","created_at":"string","updated_at":"string","tags":[],"copy_cnt":0,"connect_cnt":0,"discuss_cnt":0,"character_cnt":0,"location_cnt":0,"start_time":"string","tick_duration_days":30},"character_list":[{"character_id":"string","name":"string","identity":"string","tagline":"string","description":"string","goal":"string","avatar":"string","location_id":"string"}],"metric":{"mode":"quantitative","label":"string","unit":"string","range":[0,100],"default":50},"location_list":[{"location_id":"string","name":"string","description":"string","image":"string","x_percent":0,"y_percent":0}],"event_list":[{"content":"string"}]}}
  /// ```
  Future<Map<String, dynamic>> update({
    required String oid,
    String? name,
    String? worldView,
    String? worldSetting,
    String? cover,
    List<Map<String, dynamic>>? characterList,
    List<Map<String, dynamic>>? locationList,
    List<Map<String, dynamic>>? eventList,
    Map<String, dynamic>? metric,
    String? updateNotes,
  }) {
    return postMap(
      'origin/update',
      v1Body({
        'oid': oid,
        'name': name,
        'world_view': worldView,
        'world_setting': worldSetting,
        'cover': cover,
        'character_list': characterList,
        'location_list': locationList,
        'event_list': eventList,
        'metric': metric,
        'update_notes': updateNotes,
      }),
    );
  }

  /// POST /api/v1/origin/launch
  ///
  /// 提交参数:
  /// ```json
  /// {"oid":"string","preset_character_id":"string","custom_role":{}}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_str":"success","data":{"wid":"string"}}
  /// ```
  Future<Map<String, dynamic>> launch({
    required String oid,
    String? presetCharacterId,
    Map<String, dynamic>? customRole,
  }) {
    return postMap(
      'origin/launch',
      v1Body({
        'oid': oid,
        'preset_character_id': presetCharacterId,
        'custom_role': customRole,
      }),
    );
  }

  /// GET /api/v1/origin/versionlist
  ///
  /// 提交参数:
  /// ```json
  /// {"oid":"string"}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_str":"success","data":{"list":[{"version_num":1,"update_notes":"string","status":2,"created_at":"string"}],"total":0}}
  /// ```
  Future<Map<String, dynamic>> versionList({required String oid}) {
    return getMap('origin/versionlist', {'oid': oid});
  }

  /// POST /api/v1/origin/publish
  ///
  /// 提交参数:
  /// ```json
  /// {"oid":"string","update_notes":"string"}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_str":"success","data":{"origin":{"oid":"string","status":2,"version_num":1,"name":"string","cover":"string","display_subtitle":"string","world_view":"string","world_setting":"string","created_uid":"string","created_user_name":"string","created_at":"string","updated_at":"string","tags":[],"copy_cnt":0,"connect_cnt":0,"discuss_cnt":0,"character_cnt":0,"location_cnt":0,"start_time":"string","tick_duration_days":30},"character_list":[{"character_id":"string","name":"string","identity":"string","tagline":"string","description":"string","goal":"string","avatar":"string","location_id":"string"}],"metric":{"mode":"quantitative","label":"string","unit":"string","range":[0,100],"default":50},"location_list":[{"location_id":"string","name":"string","description":"string","image":"string","x_percent":0,"y_percent":0}],"event_list":[{"content":"string"}]}}
  /// ```
  Future<Map<String, dynamic>> publish({
    required String oid,
    required String updateNotes,
  }) {
    return postMap('origin/publish', {'oid': oid, 'update_notes': updateNotes});
  }

  /// POST /api/v1/origin/del
  ///
  /// 提交参数:
  /// ```json
  /// {"oid":"string"}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_str":"success","data":{}}
  /// ```
  Future<void> delete({required String oid}) {
    return postVoid('origin/del', {'oid': oid});
  }
}
