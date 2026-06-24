import '../json_utils.dart';
import 'v1_api_resource.dart';

class OriginV1Api extends V1ApiResource {
  const OriginV1Api(super.client);

  /// GET /api/v1/origin/homenav
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_msg":"succ","data":[{"name":"For you","scene":"foryou"}]}
  /// ```
  Future<List<Object?>> homeNav() async {
    final data = await getData('origin/homenav');
    return data is List ? data : const <Object?>[];
  }

  /// GET /api/v1/origin/hot_tags
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_msg":"succ","data":{"list":["校园","恋爱"]}}
  /// ```
  Future<List<String>> hotTags() async {
    final data = await getMap('origin/hot_tags');
    final list = data['list'];
    if (list is! List) return const <String>[];
    return list
        .map(asString)
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  /// GET /api/v1/origin/list
  ///
  /// 提交参数:
  /// ```json
  /// {"pn":1,"rn":10,"scene":"uid","uid":"string","tag":"string","keyword":"string"}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_msg":"succ","data":{"list":[{"info":{"origin_id":"string","origin_name":"string","brief":"string","cover":{},"status":10},"stats":{"copy_cnt":0,"discuss_cnt":0,"character_cnt":0,"connect_cnt":0,"location_cnt":0,"max_tick_cnt":0},"discusses":[]}],"total":0,"pn":1,"rn":10}}
  /// ```
  Future<Map<String, dynamic>> list({
    String? scene,
    String? tag,
    int? tagId,
    String? keyword,
    String? ownerUid,
    String? uid,
    String? tagName,
    int? pn,
    int? rn,
  }) {
    return getMap(
      'origin/list',
      v1Query({
        'scene': scene,
        'tag': tag,
        'tag_id': tagId,
        'keyword': keyword,
        'owner_uid': ownerUid,
        'uid': uid,
        'tag_name': tagName,
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
  /// {"err_no":0,"err_msg":"succ","data":{"info":{"origin_id":"string","origin_name":"string","origin_version":"1","origin_version_time":1779184800,"owner_uid":"string","owner_name":"string","brief":"string","setting":"string","events":[],"tags":[],"metric":{},"created_at":0,"started_at":"string","tick_duration_days":30,"cover":"string","map_url":"string","status":10},"stats":{"copy_cnt":0,"discuss_cnt":0,"character_cnt":0,"connect_cnt":0,"location_cnt":0,"max_tick_cnt":0},"characters":[],"locations":[],"ticks":[]}}
  /// ```
  Future<Map<String, dynamic>> detail({String? originId, String? oid}) {
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

  /// GET /api/v1/origin/info
  ///
  /// 提交参数:
  /// ```json
  /// {"origin_id":"string"}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_msg":"succ","data":{"info":{"origin_id":"string","origin_name":"string","brief":"string","cover":{},"status":10},"stats":{"copy_cnt":0,"discuss_cnt":0,"character_cnt":0,"connect_cnt":0,"location_cnt":0,"max_tick_cnt":0}}}
  /// ```
  Future<Map<String, dynamic>> info({String? originId, String? oid}) {
    final resolvedOriginId = (originId ?? oid ?? '').trim();
    if (resolvedOriginId.isEmpty) {
      throw ArgumentError.value(
        originId ?? oid,
        'originId',
        'must not be empty',
      );
    }
    return getMap('origin/info', {'origin_id': resolvedOriginId});
  }

  /// GET /api/v1/origin/foredit
  ///
  /// 提交参数:
  /// ```json
  /// {"origin_id":"string"}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_msg":"succ","data":{"origin_id":"o_A1B2C3","origin_name":"string","origin_version":"string","brief":"string","setting":"string","events":["string"],"tags":["string"],"metric":{"mode":"qualitative","label":"Goal Progress","label_note":"衡量角色对玩家的信任程度","unit":"%","range":[0,100],"default":0},"started_at":"string","tick_duration_time":"1 day","cover":"string","map_url":"string","characters":[],"locations":[]}}
  /// ```
  Future<Map<String, dynamic>> forEdit({String? originId, String? oid}) {
    final resolvedOriginId = (originId ?? oid ?? '').trim();
    if (resolvedOriginId.isEmpty) {
      throw ArgumentError.value(
        originId ?? oid,
        'originId',
        'must not be empty',
      );
    }
    return getMap('origin/foredit', {'origin_id': resolvedOriginId});
  }

  /// POST /api/v1/origin/create
  ///
  /// 提交参数:
  /// ```json
  /// {"origin_name":"string","origin_version":"string","brief":"string","setting":"string","events":["string"],"tags":["string"],"metric":{"mode":"qualitative","label":"Goal Progress","label_note":"衡量角色对玩家的信任程度","unit":"%","range":[0,100],"default":0},"started_at":"string","tick_duration_time":"1 day","cover":"string","characters":[],"locations":[]}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_msg":"succ","data":{"info":{"origin_id":"string","origin_name":"string","origin_version":"1","brief":"string","setting":"string","events":[],"tags":[],"metric":{},"created_at":0,"started_at":"string","tick_duration_days":30,"cover":"string","map_url":"string","status":10},"stats":{"copy_cnt":0,"discuss_cnt":0,"character_cnt":0,"connect_cnt":0,"location_cnt":0,"max_tick_cnt":0},"characters":[],"locations":[],"ticks":[]}}
  /// ```
  Future<Map<String, dynamic>> create({
    required String originName,
    String? originVersion,
    String? brief,
    String? setting,
    List<String>? events,
    List<String>? tags,
    Map<String, dynamic>? metric,
    String? startedAt,
    String? tickDurationTime,
    required String cover,
    required List<Map<String, dynamic>> characters,
    List<Map<String, dynamic>>? locations,
  }) {
    return postMap(
      'origin/create',
      v1Body({
        'origin_name': originName,
        'origin_version': originVersion,
        'brief': brief,
        'setting': setting,
        'events': events,
        'tags': tags,
        'metric': metric,
        'started_at': startedAt,
        'tick_duration_time': tickDurationTime,
        'cover': cover,
        'characters': characters,
        'locations': locations,
      }),
    );
  }

  /// POST /api/v1/origin/update
  ///
  /// 提交参数:
  /// ```json
  /// {"origin_id":"string","origin_name":"string","origin_version":"string","brief":"string","setting":"string","events":["string"],"tags":["string"],"metric":{"mode":"qualitative","label":"Goal Progress","label_note":"衡量角色对玩家的信任程度","unit":"%","range":[0,100],"default":0},"started_at":"string","tick_duration_time":"1 day","cover":"string","characters":[],"locations":[],"update_notes":"string","deleted_char_ids":[],"deleted_location_ids":[]}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_msg":"succ","data":{"info":{"origin_id":"string","origin_name":"string","origin_version":"1","brief":"string","setting":"string","events":[],"tags":[],"metric":{},"created_at":0,"started_at":"string","tick_duration_days":30,"cover":"string","map_url":"string","status":10},"stats":{"copy_cnt":0,"discuss_cnt":0,"character_cnt":0,"connect_cnt":0,"location_cnt":0,"max_tick_cnt":0},"characters":[],"locations":[],"ticks":[]}}
  /// ```
  Future<Map<String, dynamic>> update({
    required String originId,
    required String originName,
    String? originVersion,
    String? brief,
    String? setting,
    List<String>? events,
    List<String>? tags,
    Map<String, dynamic>? metric,
    String? startedAt,
    String? tickDurationTime,
    required String cover,
    required List<Map<String, dynamic>> characters,
    List<Map<String, dynamic>>? locations,
    List<String>? deletedCharIds,
    List<String>? deletedLocationIds,
    String? updateNotes,
  }) {
    return postMap(
      'origin/update',
      v1Body({
        'origin_id': originId,
        'origin_name': originName,
        'origin_version': originVersion,
        'brief': brief,
        'setting': setting,
        'events': events,
        'tags': tags,
        'metric': metric,
        'started_at': startedAt,
        'tick_duration_time': tickDurationTime,
        'cover': cover,
        'characters': characters,
        'locations': locations,
        'update_notes': updateNotes,
        'deleted_char_ids': deletedCharIds,
        'deleted_location_ids': deletedLocationIds,
      }),
    );
  }

  /// POST /api/v1/origin/launch
  ///
  /// 提交参数:
  /// ```json
  /// {"origin_id":"string","preset_character_id":"string","custom_role":{}}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_msg":"succ","data":{"world_id":"string"}}
  /// ```
  Future<Map<String, dynamic>> launch({
    String? originId,
    String? oid,
    String? presetCharacterId,
    Map<String, dynamic>? customRole,
  }) {
    final resolvedOriginId = (originId ?? oid ?? '').trim();
    if (resolvedOriginId.isEmpty) {
      throw ArgumentError.value(
        originId ?? oid,
        'originId',
        'must not be empty',
      );
    }
    final hasPreset = (presetCharacterId ?? '').trim().isNotEmpty;
    final hasCustomRole = customRole != null && customRole.isNotEmpty;
    if (hasPreset == hasCustomRole) {
      throw ArgumentError(
        'presetCharacterId and customRole must be exactly one of two',
      );
    }
    return postMap(
      'origin/launch',
      v1Body({
        'origin_id': resolvedOriginId,
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
