import '../models/unread_summary.dart';
import 'v1_api_resource.dart';

class MessagesV1Api extends V1ApiResource {
  const MessagesV1Api(super.client);

  /// GET /api/v1/message/unread
  ///
  /// 提交参数: 无
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_msg":"succ","data":{"total_unread":12,"world_apply_unread":2,"follow_unread":3,"interaction_unread":4,"direct_message_unread":3}}
  /// ```
  Future<UnreadSummary> unreadSummary() async {
    return UnreadSummary.fromJson(await getMap('message/unread'));
  }

  /// GET /api/v1/messages/notifications
  ///
  /// 提交参数:
  /// ```json
  /// {"category":"system","kind":"world_join_request","pn":1,"rn":10}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_str":"success","data":{"list":[{"id":12,"category":"system","kind":"world_join_request","wid":"string","owner_uid":"string","apply_uid":"string","apply_user_name":"string","apply_user_avatar":"string","message":"string","status":"pending","is_read":false,"created_at":"string"}],"total":0}}
  /// ```
  Future<Map<String, dynamic>> notifications({
    required String category,
    String? kind,
    int? pn,
    int? rn,
  }) {
    return getMap(
      'messages/notifications',
      v1Query({'category': category, 'kind': kind, 'pn': pn, 'rn': rn}),
    );
  }

  /// POST /api/v1/messages/notifications/read
  ///
  /// 提交参数:
  /// ```json
  /// {"category":"system","notification_ids":["12"]}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_str":"success","data":{}}
  /// ```
  Future<void> markNotificationsRead({
    String? category,
    List<String>? notificationIds,
  }) {
    return postVoid(
      'messages/notifications/read',
      v1Body({'category': category, 'notification_ids': notificationIds}),
    );
  }

  /// GET /api/v1/messages/followers
  ///
  /// 提交参数:
  /// ```json
  /// {"pn":1,"rn":20}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_str":"success","data":{"list":[{"uid":"string","name":"string","avatar":"string","bio":"string","created_at":"string","is_read":false,"relation":{"is_self":false,"i_followed":false,"followed_me":true,"is_friend":false,"follow_button_state":"follow_back","can_send_dm":true,"dm_permission":"pingpong"}}],"total":0}}
  /// ```
  Future<Map<String, dynamic>> followers({int? pn, int? rn}) {
    return getMap('messages/followers', v1Query({'pn': pn, 'rn': rn}));
  }
}
