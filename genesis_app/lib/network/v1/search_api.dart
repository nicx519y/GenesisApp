import 'v1_api_resource.dart';

class SearchV1Api extends V1ApiResource {
  const SearchV1Api(super.client);

  /// GET /api/v1/search
  ///
  /// 提交参数:
  /// ```json
  /// {"query":"string","type":"all","pn":1,"rn":20}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_str":"success","data":{"intent":{"raw_query":"string","normalized_query":"string","strict_code_or_id":true,"detected_type":"user","detected_field":"short_code"},"groups":[{"type":"user","total":0,"list":[{"type":"user","entity_id":"string","short_code":"string","title":"string","subtitle":"string","cover_image":"string","relation":{"target_user_id":"string","i_followed":false,"followed_me":true,"is_friend":false,"follow_button_state":"follow_back","can_send_dm":true,"dm_permission":"pingpong"}}]},{"type":"origin","total":0,"list":[{"type":"origin","entity_id":"string","short_code":"string","title":"string","subtitle":"string","cover_image":"string","tags":[],"copy_cnt":0,"connect_cnt":0}]},{"type":"world","total":0,"list":[{"type":"world","entity_id":"string","short_code":"string","title":"string","subtitle":"string","cover_image":"string","tick_cnt":0,"player_cnt":0}]}],"pn":1,"rn":20}}
  /// ```
  Future<Map<String, dynamic>> search({
    required String query,
    String? type,
    int? pn,
    int? rn,
  }) {
    return getMap(
      'search',
      v1Query({'query': query, 'type': type, 'pn': pn, 'rn': rn}),
    );
  }

  /// GET /api/v1/search/suggest
  ///
  /// 提交参数:
  /// ```json
  /// {"query":"string","type":"all","limit":10}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_str":"success","data":{"list":[{"type":"user","entity_id":"string","short_code":"string","title":"string","subtitle":"string","cover_image":"string"}]}}
  /// ```
  Future<Map<String, dynamic>> suggest({
    required String query,
    String? type,
    int? limit,
  }) {
    return getMap(
      'search/suggest',
      v1Query({'query': query, 'type': type, 'limit': limit}),
    );
  }
}
