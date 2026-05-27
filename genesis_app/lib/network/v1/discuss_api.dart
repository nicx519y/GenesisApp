import 'v1_api_resource.dart';

class DiscussV1Api extends V1ApiResource {
  const DiscussV1Api(super.client);

  /// GET /api/v1/discuss/list
  ///
  /// 提交参数:
  /// ```json
  /// {"biz_type":1,"biz_id":"ori_a1b2c3","pn":1,"rn":10}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_msg":"succ","data":{"list":[{"comment":{"discuss_id":"dis_X9KQ4M2A1B2C"},"latest_replies":[]}],"top_total":12,"total_all":47,"pn":1,"rn":10}}
  /// ```
  Future<Map<String, dynamic>> list({
    required String bizId,
    int bizType = 1,
    int? pn,
    int? rn,
  }) {
    return getMap(
      'discuss/list',
      v1Query({'biz_type': bizType, 'biz_id': bizId, 'pn': pn, 'rn': rn}),
    );
  }

  /// POST /api/v1/discuss/post
  ///
  /// 提交参数:
  /// ```json
  /// {"biz_type":1,"biz_id":"ori_a1b2c3","content":"first!","images":[],"root_discuss_id":"","parent_discuss_id":""}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_msg":"succ","data":{"discuss_id":"dis_X9KQ4M2A1B2C","root_discuss_id":"","level":1}}
  /// ```
  Future<Map<String, dynamic>> post({
    required String bizId,
    int bizType = 1,
    String? content,
    List<String>? images,
    String? rootDiscussId,
    String? parentDiscussId,
  }) {
    return postMap(
      'discuss/post',
      v1Body({
        'biz_type': bizType,
        'biz_id': bizId,
        'content': content,
        'images': images,
        'root_discuss_id': rootDiscussId,
        'parent_discuss_id': parentDiscussId,
      }),
    );
  }

  /// POST /api/v1/discuss/delete
  ///
  /// 提交参数:
  /// ```json
  /// {"discuss_id":"dis_X9KQ4M2A1B2C"}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_msg":"succ","data":{}}
  /// ```
  Future<void> delete({required String discussId}) {
    return postVoid('discuss/delete', {'discuss_id': discussId});
  }

  /// POST /api/v1/discuss/like
  ///
  /// 提交参数:
  /// ```json
  /// {"discuss_id":"dis_X9KQ4M2A1B2C"}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_msg":"succ","data":{}}
  /// ```
  Future<void> like({required String discussId}) {
    return postVoid('discuss/like', {'discuss_id': discussId});
  }

  /// POST /api/v1/discuss/unlike
  ///
  /// 提交参数:
  /// ```json
  /// {"discuss_id":"dis_X9KQ4M2A1B2C"}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_msg":"succ","data":{}}
  /// ```
  Future<void> unlike({required String discussId}) {
    return postVoid('discuss/unlike', {'discuss_id': discussId});
  }
}
