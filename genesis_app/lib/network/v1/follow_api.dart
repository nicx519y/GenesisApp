import 'v1_api_resource.dart';

class FollowV1Api extends V1ApiResource {
  const FollowV1Api(super.client);

  /// POST /api/v1/user/follow
  ///
  /// 提交参数:
  /// ```json
  /// {"target_uid":"string"}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_msg":"succ","data":{}}
  /// ```
  Future<Map<String, dynamic>> follow({required String uid}) {
    return postMap('user/follow', {'target_uid': uid});
  }

  /// POST /api/v1/user/unfollow
  ///
  /// 提交参数:
  /// ```json
  /// {"target_uid":"string"}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_msg":"succ","data":{}}
  /// ```
  Future<Map<String, dynamic>> unfollow({required String uid}) {
    return postMap('user/unfollow', {'target_uid': uid});
  }

  /// GET /api/v1/user/following
  ///
  /// 提交参数:
  /// ```json
  /// {"uid":"string","pn":1,"rn":10}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_msg":"succ","data":{"total":0,"pn":1,"rn":10,"list":[{"user":{},"relation":{}}]}}
  /// ```
  Future<Map<String, dynamic>> following({
    required String uid,
    int? pn,
    int? rn,
  }) {
    return getMap('user/following', v1Query({'uid': uid, 'pn': pn, 'rn': rn}));
  }

  /// GET /api/v1/user/followers
  ///
  /// 提交参数:
  /// ```json
  /// {"uid":"string","pn":1,"rn":10}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_msg":"succ","data":{"total":0,"pn":1,"rn":10,"list":[{"user":{},"relation":{}}]}}
  /// ```
  Future<Map<String, dynamic>> followers({
    required String uid,
    int? pn,
    int? rn,
  }) {
    return getMap('user/followers', v1Query({'uid': uid, 'pn': pn, 'rn': rn}));
  }

  /// Legacy relation-status endpoint retained for screens not covered by the
  /// current Apifox document.
  Future<Map<String, dynamic>> relations({
    String? uid,
    required String type,
    int? pn,
    int? rn,
  }) {
    return getMap(
      'user/relations',
      v1Query({'uid': uid, 'type': type, 'pn': pn, 'rn': rn}),
    );
  }

  /// POST /api/v1/users/relations/status
  ///
  /// 提交参数:
  /// ```json
  /// {"uids":["U_KALFO"]}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_str":"success","data":{"relations":{"U_KALFO":{"target_user_id":"string","i_followed":true,"followed_me":false,"is_friend":false,"follow_button_state":"following","can_send_dm":true,"dm_permission":"pingpong"}}}}
  /// ```
  Future<Map<String, dynamic>> status({required List<String> uids}) {
    return postMap('users/relations/status', {'uids': uids});
  }
}
