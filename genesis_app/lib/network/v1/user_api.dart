import '../json_utils.dart';
import '../api_exception.dart';
import '../models/world_history_settings.dart';
import 'v1_api_resource.dart';

typedef CurrentUserInfoSession = ({String uid, String authToken});
typedef CurrentUserInfoSessionProvider =
    Future<CurrentUserInfoSession?> Function();

class UserV1Api extends V1ApiResource {
  const UserV1Api(
    super.client, {
    CurrentUserInfoSessionProvider? currentUserInfoSessionProvider,
  }) : _currentUserInfoSessionProvider = currentUserInfoSessionProvider;

  final CurrentUserInfoSessionProvider? _currentUserInfoSessionProvider;

  /// POST /api/v1/user/oauth/google
  ///
  /// Request parameters:
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
  /// Request parameters:
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
  /// Request parameters:
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
  /// Request parameters:
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
  /// Request parameters:
  /// ```json
  /// {"uid":"string"}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_msg":"succ","data":{"token":"string","user":{"uid":"string","name":"string","avatar":"string","bio":"string","last_login_at":"string","create_at":"string","follower_cnt":0,"following_cnt":0,"friend_cnt":0,"create_origin_cnt":0,"launch_world_cnt":0,"join_world_cnt":0},"relation":{"is_self":true,"is_followed":false,"followed_me":false,"is_friend":false,"is_blocked":false},"uuid":"string","selected_model_code":"string"}}
  /// ```
  ///
  /// For the current account, UUID and selected model code are siblings of
  /// `user` in this result.
  Future<Map<String, dynamic>> info({String? uid}) async {
    final resolvedUid = uid?.trim() ?? '';
    if (resolvedUid.isNotEmpty) {
      return getMap('user/info', v1Query({'uid': resolvedUid}));
    }

    final session = await _currentUserInfoSessionProvider?.call();
    if (session == null) {
      throw ApiException(message: 'Authentication is required');
    }

    final response = await getMapWithHeaders(
      'user/info',
      query: {'uid': session.uid},
      headers: {'authorization': _bearerToken(session.authToken)},
    );
    _validateCurrentUserInfo(response, expectedUid: session.uid);
    return response;
  }

  String _bearerToken(String token) {
    return token.toLowerCase().startsWith('bearer ') ? token : 'Bearer $token';
  }

  void _validateCurrentUserInfo(
    Map<String, dynamic> response, {
    required String expectedUid,
  }) {
    final user = response['user'] is Map
        ? asJsonMap(response['user'])
        : const <String, dynamic>{};
    final relation = response['relation'] is Map
        ? asJsonMap(response['relation'])
        : const <String, dynamic>{};
    final responseUid = asString(
      user['uid'],
      fallback: asString(user['id']),
    ).trim();
    if (responseUid == expectedUid && asBool(relation['is_self'])) return;

    throw ApiException(
      message: 'Current user session could not be verified',
      statusCode: 401,
      kind: ApiExceptionKind.gatewayAuth,
    );
  }

  /// POST /api/v1/user/update
  ///
  /// Request parameters:
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
  /// Request parameters:
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
  /// Request parameters:
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
  /// Request parameters:
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

  /// GET /api/v1/user/world-history-settings
  Future<WorldHistorySettings> worldHistorySettings() async {
    final data = await getMap('user/world-history-settings');
    return WorldHistorySettings.fromJson(data);
  }

  /// PUT /api/v1/user/world-history-settings
  Future<WorldHistorySettings> updateWorldHistorySettings({
    required int highWatermark,
    required int lowWatermark,
  }) async {
    final json = await client.put<Object?>(
      'v1/user/world-history-settings',
      body: {'high_watermark': highWatermark, 'low_watermark': lowWatermark},
    );
    final data = handleV1ResponseErrNo(json);
    return WorldHistorySettings.fromJson(asJsonMap(data));
  }

  /// DELETE /api/v1/user/world-history-settings
  Future<WorldHistorySettings> resetWorldHistorySettings() async {
    final json = await client.delete<Object?>('v1/user/world-history-settings');
    final data = handleV1ResponseErrNo(json);
    return WorldHistorySettings.fromJson(asJsonMap(data));
  }

  /// GET /api/v1/user/profile
  ///
  /// Request parameters:
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
  /// Request parameters:
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
  /// Request parameters:
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
