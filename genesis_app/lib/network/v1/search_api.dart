import '../json_utils.dart';
import '../models/search_v2.dart';
import 'v1_api_resource.dart';

class SearchV1Api extends V1ApiResource {
  const SearchV1Api(super.client);

  /// GET /api/v2/search
  ///
  /// Request parameters:
  /// ```json
  /// {"keyword":"string","type":"","pn":1,"rn":20}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_msg":"succ","data":{"keyword":"string","type":"","origins":{"list":[{"origin_id":"o_1","origin_name":"Origin","origin_version":"1","brief":"","language":"en","cover":{},"tags":[],"characters":[{"character_id":"c_1","name":"Alice"}],"owner":{},"stats":{},"matches":[{"field":"character_name","character_id":"c_1","highlight_ranges":[{"start":0,"length":5}]}],"matches_truncated":false}],"total":0,"pn":1,"rn":20},"worlds":{"list":[{"world_id":"w_1","world_name":"World","origin_id":"o_1","language":"en","cover":{},"owner":{},"stats":{"tick_cnt":0,"sub_tick_no":0,"connect_cnt":0,"player_cnt":0},"created_at":0,"matches":[{"field":"world_name","highlight_ranges":[{"start":0,"length":5}]}]}],"total":0,"pn":1,"rn":20},"users":{"list":[{"uid":"u_1","name":"User","avatar":{},"matches":[{"field":"user_name","highlight_ranges":[{"start":0,"length":4}]}]}],"total":0,"pn":1,"rn":20}}}
  /// ```
  Future<SearchV2Response> search({
    required String query,
    String? type,
    int? pn,
    int? rn,
  }) async {
    final json = await client.get<Object?>(
      'v2/search',
      query: v1Query({'keyword': query, 'type': type, 'pn': pn, 'rn': rn}),
    );
    final data = handleV1ResponseErrNo(json);
    return SearchV2Response.fromJson(asJsonMap(data));
  }

  /// GET /api/v1/search/suggest
  ///
  /// Request parameters:
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
