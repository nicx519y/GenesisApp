import 'dart:async';

import '../../app/telemetry/firebase_analytics_monitoring.dart';
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
  /// {"err_no":0,"err_msg":"succ","data":{"list":["Campus","Romance"]}}
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

  /// GET /api/v1/origin/my_launch_preset_characters
  ///
  /// Returns preset characters that the current user previously selected when launching the specified origin and that still exist.
  /// Results are deduplicated by char_id and sorted by the most recent launch time in descending order.
  Future<List<Map<String, dynamic>>> myLaunchPresetCharacters({
    required String originId,
  }) async {
    final resolvedOriginId = originId.trim();
    if (resolvedOriginId.isEmpty) {
      throw ArgumentError.value(originId, 'originId', 'must not be empty');
    }
    final data = await getMap('origin/my_launch_preset_characters', {
      'origin_id': resolvedOriginId,
    });
    final list = data['list'];
    if (list is! List) return const <Map<String, dynamic>>[];
    return list.whereType<Map>().map(asJsonMap).toList(growable: false);
  }

  /// GET /api/v1/origin/list
  ///
  /// Request parameters:
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
  /// Request parameters:
  /// ```json
  /// {"origin_id":"string"}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_msg":"succ","data":{"show_opening_sheet":false,"info":{"origin_id":"string","origin_name":"string","origin_version":"1","origin_version_time":1779184800,"definition_version":2,"language":"zh-Hans","current_time":"Day 1, 08:30","owner_uid":"string","owner_name":"string","owner_user":{},"brief":"string","tags":[],"metric":{},"created_at":0,"cover":{},"map_url":"string","status":10},"stats":{"copy_cnt":0,"discuss_cnt":0,"character_cnt":0,"connect_cnt":0,"location_cnt":0,"max_tick_cnt":0},"init_location_group":{"location_id":"loc_1","initial_dialogue":[]},"characters":[{"char_id":"string","type":"ai","is_recommend":0}],"locations":[{"location_id":"string","location_summary":"string"}],"ticks":[{"tick_id":"string","tick_no":1,"sub_tick_no":1,"status":50,"tick_result":{"current_time":"string","narrator":"string","paragraphs":[]},"created_at":0}]}}
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

  /// GET /api/v1/origin/map
  ///
  /// `location_id=root` returns the main origin map; any other value returns the corresponding location map.
  /// The server returns an empty object when definition_version is not 2.
  Future<Map<String, dynamic>> map({
    required String originId,
    required String locationId,
  }) {
    final resolvedOriginId = originId.trim();
    final resolvedLocationId = locationId.trim();
    if (resolvedOriginId.isEmpty) {
      throw ArgumentError.value(originId, 'originId', 'must not be empty');
    }
    if (resolvedLocationId.isEmpty) {
      throw ArgumentError.value(locationId, 'locationId', 'must not be empty');
    }
    return getMapPreservingKeys('origin/map', {
      'origin_id': resolvedOriginId,
      'location_id': resolvedLocationId,
    });
  }

  /// GET /api/v1/origin/info
  ///
  /// Request parameters:
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

  /// POST /api/v1/origin/create
  ///
  /// Request parameters:
  /// ```json
  /// {"origin_name":"string","origin_version":"string","brief":"string","setting":"string","events":["string"],"tags":["string"],"metric":{"mode":"qualitative","label":"Goal Progress","label_note":"Measures how much the character trusts the player","unit":"%","range":[0,100],"default":0},"started_at":"string","tick_duration_time":"1 day","cover":"string","characters":[],"locations":[]}
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
  /// Request parameters:
  /// ```json
  /// {"origin_id":"string","origin_name":"string","origin_version":"string","brief":"string","setting":"string","events":["string"],"tags":["string"],"metric":{"mode":"qualitative","label":"Goal Progress","label_note":"Measures how much the character trusts the player","unit":"%","range":[0,100],"default":0},"started_at":"string","tick_duration_time":"1 day","cover":"string","characters":[],"locations":[],"update_notes":"string","deleted_char_ids":[],"deleted_location_ids":[]}
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
  /// Request parameters:
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
    final roleType = hasPreset ? 'preset' : 'custom';
    unawaited(
      FirebaseAnalyticsMonitoring.recordLaunch(
        originId: resolvedOriginId,
        roleType: roleType,
      ),
    );
    return _launchValidated(
      originId: resolvedOriginId,
      presetCharacterId: presetCharacterId,
      customRole: customRole,
      roleType: roleType,
    );
  }

  Future<Map<String, dynamic>> _launchValidated({
    required String originId,
    required String? presetCharacterId,
    required Map<String, dynamic>? customRole,
    required String roleType,
  }) async {
    final json = await client.post<Object?>(
      'v1/origin/launch',
      body: v1Body({
        'origin_id': originId,
        'preset_character_id': presetCharacterId,
        'custom_role': customRole,
      }),
    );
    final hasExplicitSuccess = _hasExplicitSuccessfulV1Envelope(json);
    final data = handleV1ResponseErrNo(json);
    final result = data == null ? <String, dynamic>{} : asJsonMap(data);
    if (hasExplicitSuccess) {
      final worldId = asString(result['world_id'] ?? result['wid']).trim();
      if (worldId.isNotEmpty) {
        unawaited(
          FirebaseAnalyticsMonitoring.recordLaunchSuccess(
            originId: originId,
            roleType: roleType,
            worldId: worldId,
          ),
        );
      }
    }
    return result;
  }

  /// GET /api/v1/origin/versionlist
  ///
  /// Request parameters:
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
  /// Request parameters:
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
  /// Request parameters:
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

bool _hasExplicitSuccessfulV1Envelope(Object? json) {
  if (json is! Map) return false;
  final map = asJsonMap(json);
  final Object? rawErrNo;
  if (map.containsKey('err_no')) {
    rawErrNo = map['err_no'];
  } else if (map.containsKey('errNo')) {
    rawErrNo = map['errNo'];
  } else {
    return false;
  }
  return _parseStrictV1ErrNo(rawErrNo) == 0;
}

int? _parseStrictV1ErrNo(Object? value) {
  if (value is int) return value;
  if (value is num && value.isFinite && value == value.toInt()) {
    return value.toInt();
  }
  if (value is String) return int.tryParse(value.trim());
  return null;
}
