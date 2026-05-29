import 'v1_api_resource.dart';

class SearchV1Api extends V1ApiResource {
  const SearchV1Api(super.client);

  /// GET /api/v1/search
  ///
  /// 提交参数:
  /// ```json
  /// {"keyword":"string","type":"","pn":1,"rn":20}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_msg":"succ","data":{"keyword":"string","type":"","origins":{"list":[{"info":{},"stats":{}}],"total":0,"pn":1,"rn":20},"worlds":{"list":[{"info":{},"stats":{},"last_tick":{}}],"total":0,"pn":1,"rn":20},"users":{"list":[{"user":{},"relation":{}}],"total":0,"pn":1,"rn":20}}}
  /// ```
  Future<Map<String, dynamic>> search({
    required String query,
    String? type,
    int? pn,
    int? rn,
  }) {
    return getMap(
      'search',
      v1Query({'keyword': query, 'type': type, 'pn': pn, 'rn': rn}),
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
