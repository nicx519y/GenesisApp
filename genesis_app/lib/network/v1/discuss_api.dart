import 'v1_api_resource.dart';

class DiscussV1Api extends V1ApiResource {
  const DiscussV1Api(super.client);

  /// GET /api/v1/discuss/list
  ///
  /// 提交参数:
  /// ```json
  /// {"biz_id":"string","biz_type":"origin","post_id":"string","pn":1,"rn":10}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_str":"success","data":{"list":[{"post_id":"string","uid":"string","user_name":"string","user_avatar":"string","create_at":1716000000,"content":"string","images":[],"liked_by_me":true,"like_cnt":0,"reply_cnt":0,"best_tick_cnt":0,"best_wid":"string","comment_list":[{"post_id":"string","uid":"string","user_name":"string","user_avatar":"string","create_at":1716000000,"content":"string","images":[],"liked_by_me":false,"like_cnt":0,"reply_cnt":0,"best_tick_cnt":0,"best_wid":"string"}]}],"total":0}}
  /// ```
  Future<Map<String, dynamic>> list({
    required String bizId,
    String bizType = 'origin',
    String? postId,
    int? pn,
    int? rn,
  }) {
    return getMap(
      'discuss/list',
      v1Query({
        'biz_id': bizId,
        'biz_type': bizType,
        'post_id': postId,
        'pn': pn,
        'rn': rn,
      }),
    );
  }

  /// POST /api/v1/discuss/post
  ///
  /// 提交参数:
  /// ```json
  /// {"biz_id":"string","biz_type":"origin","content":"string","images":[]}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_str":"success","data":{"post_id":"string"}}
  /// ```
  Future<Map<String, dynamic>> post({
    required String bizId,
    String bizType = 'origin',
    required String content,
    List<String>? images,
  }) {
    return postMap(
      'discuss/post',
      v1Body({
        'biz_id': bizId,
        'biz_type': bizType,
        'content': content,
        'images': images,
      }),
    );
  }

  /// GET /api/v1/discuss/detail
  ///
  /// 提交参数:
  /// ```json
  /// {"post_id":"string","pn":1,"rn":20}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_str":"success","data":{"post":{"post_id":"string","uid":"string","user_name":"string","user_avatar":"string","create_at":1716000000,"content":"string","images":[],"liked_by_me":true,"like_cnt":0,"reply_cnt":0,"best_tick_cnt":0,"best_wid":"string"},"reply_list":[{"post_id":"string","uid":"string","user_name":"string","user_avatar":"string","create_at":1716100000,"content":"string","images":[],"liked_by_me":false,"like_cnt":0,"reply_cnt":0,"best_tick_cnt":0,"best_wid":"string"}],"total":0}}
  /// ```
  Future<Map<String, dynamic>> detail({
    required String postId,
    int? pn,
    int? rn,
  }) {
    return getMap(
      'discuss/detail',
      v1Query({'post_id': postId, 'pn': pn, 'rn': rn}),
    );
  }

  /// POST /api/v1/discuss/reply
  ///
  /// 提交参数:
  /// ```json
  /// {"comment_id":"string","content":"string","images":[]}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_str":"success","data":{"post_id":"string"}}
  /// ```
  Future<Map<String, dynamic>> reply({
    required String commentId,
    required String content,
    List<String>? images,
  }) {
    return postMap(
      'discuss/reply',
      v1Body({'comment_id': commentId, 'content': content, 'images': images}),
    );
  }

  /// POST /api/v1/discuss/like
  ///
  /// 提交参数:
  /// ```json
  /// {"comment_id":"string","action":"like"}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_str":"success","data":{"comment_id":"string","liked_by_me":true,"like_cnt":0}}
  /// ```
  Future<Map<String, dynamic>> like({
    required String commentId,
    required String action,
  }) {
    return postMap('discuss/like', {'comment_id': commentId, 'action': action});
  }

  /// POST /api/v1/discuss/del
  ///
  /// 提交参数:
  /// ```json
  /// {"comment_id":"string"}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_str":"success","data":{}}
  /// ```
  Future<void> delete({required String commentId}) {
    return postVoid('discuss/del', {'comment_id': commentId});
  }
}
