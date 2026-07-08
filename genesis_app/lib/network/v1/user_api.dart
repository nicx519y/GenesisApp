import 'v1_api_resource.dart';

class UserV1Api extends V1ApiResource {
  const UserV1Api(super.client);

  /// POST /api/v1/user/oauth/google
  ///
  /// 提交参数:
  /// ```json
  /// {"id_token":"string","nonce":"string","name":"string","avatar":"string"}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_msg":"succ","data":{"token":"string","user":{"uid":"string","name":"string","avatar":"string","bio":"string","last_login_at":"string","create_at":"string","follower_cnt":0,"following_cnt":0,"friend_cnt":0,"create_origin_cnt":0,"launch_world_cnt":0,"join_world_cnt":0},"relation":{"is_self":true,"is_followed":false,"followed_me":false,"is_friend":false,"is_blocked":false}}}
  /// ```
  Future<Map<String, dynamic>> googleAuth({
    required String idToken,
    String? nonce,
    String? name,
    String? avatar,
  }) {
    return postMap(
      'user/oauth/google',
      v1Body({
        'id_token': idToken,
        'nonce': nonce,
        'name': name,
        'avatar': avatar,
      }),
    );
  }

  /// POST /api/v1/user/oauth/apple
  ///
  /// 提交参数:
  /// ```json
  /// {"id_token":"string","nonce":"string","name":"string","avatar":"string"}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_msg":"succ","data":{"token":"string","user":{"uid":"string","name":"string","avatar":"string","bio":"string","last_login_at":"string","create_at":"string","follower_cnt":0,"following_cnt":0,"friend_cnt":0,"create_origin_cnt":0,"launch_world_cnt":0,"join_world_cnt":0},"relation":{"is_self":true,"is_followed":false,"followed_me":false,"is_friend":false,"is_blocked":false}}}
  /// ```
  Future<Map<String, dynamic>> appleAuth({
    required String idToken,
    String? nonce,
    String? name,
    String? avatar,
    String? fullName,
  }) {
    return postMap(
      'user/oauth/apple',
      v1Body({
        'id_token': idToken,
        'nonce': nonce,
        'name': name ?? fullName,
        'avatar': avatar,
      }),
    );
  }

  /// POST /api/v1/user/logout
  ///
  /// 提交参数:
  /// ```json
  /// {}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_msg":"succ","data":{}}
  /// ```
  Future<void> logout({Map<String, String>? headers}) async {
    await postData('user/logout', const <String, Object?>{}, headers);
  }

  /// POST /api/v1/user/delete
  ///
  /// 提交参数:
  /// ```json
  /// {}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_msg":"succ","data":{}}
  /// ```
  Future<void> deleteAccount({Map<String, String>? headers}) async {
    await postData('user/delete', const <String, Object?>{}, headers);
  }

  /// GET /api/v1/user/info
  ///
  /// 提交参数:
  /// ```json
  /// {"uid":"string"}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_msg":"succ","data":{"token":"string","user":{"uid":"string","name":"string","avatar":"string","bio":"string","last_login_at":"string","create_at":"string","follower_cnt":0,"following_cnt":0,"friend_cnt":0,"create_origin_cnt":0,"launch_world_cnt":0,"join_world_cnt":0},"relation":{"is_self":true,"is_followed":false,"followed_me":false,"is_friend":false,"is_blocked":false}}}
  /// ```
  Future<Map<String, dynamic>> info({String? uid}) {
    return getMap('user/info', v1Query({'uid': uid}));
  }

  /// POST /api/v1/user/update
  ///
  /// 提交参数:
  /// ```json
  /// {"name":"string","avatar":"string","bio":"string"}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_str":"success","data":{"user":{"uid":"string","name":"string","avatar":"string","bio":"string","last_login_at":"string","create_at":"string","follower_cnt":0,"following_cnt":0,"friend_cnt":0,"create_origin_cnt":0,"launch_world_cnt":0,"join_world_cnt":0}}}
  /// ```
  Future<Map<String, dynamic>> update({
    String? name,
    String? avatar,
    String? bio,
  }) {
    return postMap(
      'user/update',
      v1Body({'name': name, 'avatar': avatar, 'bio': bio}),
    );
  }

  /// POST /api/v1/user/block
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
  Future<void> block({required String targetUid}) async {
    await postData('user/block', {'target_uid': targetUid});
  }

  /// POST /api/v1/user/unblock
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
  Future<void> unblock({required String targetUid}) async {
    await postData('user/unblock', {'target_uid': targetUid});
  }

  /// GET /api/v1/user/blocks
  ///
  /// 提交参数:
  /// ```json
  /// {"pn":1,"rn":10}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_msg":"succ","data":{"list":[{"user":{},"relation":{}}],"total":0,"pn":1,"rn":10}}
  /// ```
  Future<Map<String, dynamic>> blocks({int? pn, int? rn}) {
    return getMap('user/blocks', v1Query({'pn': pn, 'rn': rn}));
  }

  /// GET /api/v1/user/profile
  ///
  /// 提交参数:
  /// ```json
  /// {"uid":"string"}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_str":"success","data":{"user":{"uid":"string","name":"string","avatar":"string","bio":"string","last_login_at":"string","create_at":"string","follower_cnt":0,"following_cnt":0,"friend_cnt":0,"create_origin_cnt":0,"launch_world_cnt":0,"join_world_cnt":0},"relation":{"is_self":false,"i_followed":false,"followed_me":true,"is_friend":false,"is_blocked":false,"follow_button_state":"follow_back","dm_permission":"pingpong"}}}
  /// ```
  Future<Map<String, dynamic>> profile({required String uid}) {
    return getMap('user/profile', {'uid': uid});
  }

  /// GET /api/v1/user/origins
  ///
  /// 提交参数:
  /// ```json
  /// {"uid":"string","pn":1,"rn":10}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_str":"success","data":{"list":[{"oid":"string","status":1,"version_num":1,"name":"string","cover":"string","display_subtitle":"string","created_uid":"string","created_user_name":"string","created_at":"string","updated_at":"string","tags":[],"copy_cnt":0,"connect_cnt":0,"character_cnt":0}],"total":0}}
  /// ```
  Future<Map<String, dynamic>> origins({
    required String uid,
    int? pn,
    int? rn,
  }) {
    return getMap('user/origins', v1Query({'uid': uid, 'pn': pn, 'rn': rn}));
  }

  /// GET /api/v1/user/worlds
  ///
  /// 提交参数:
  /// ```json
  /// {"uid":"string","pn":1,"rn":10}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_str":"success","data":{"list":[{"oid":"string","origin_version_num":1,"wid":"string","status":1,"name":"string","cover":"string","display_subtitle":"string","created_uid":"string","created_user_name":"string","created_at":"string","updated_at":"string","tick_cnt":0,"connect_cnt":0,"ai_character_cnt":0,"player_cnt":0}],"total":0}}
  /// ```
  Future<Map<String, dynamic>> worlds({required String uid, int? pn, int? rn}) {
    return getMap('user/worlds', v1Query({'uid': uid, 'pn': pn, 'rn': rn}));
  }
}
