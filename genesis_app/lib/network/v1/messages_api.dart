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

  /// GET /api/v1/message/notifications
  ///
  /// 提交参数:
  /// ```json
  /// {"block":"world_apply","pn":1,"rn":20}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_msg":"succ","data":{"list":[{"notification_id":"ntf_AB12CD34","notice_block":"world_apply","notice_type":"world_apply","sender":{},"biz_type":2,"biz_id":"w_a1b2c3","obj_id":"apl_a1b2c3","content":"string","is_read":true,"created_at":0}],"total":0,"pn":1,"rn":20}}
  /// ```
  Future<Map<String, dynamic>> notifications({
    required String block,
    int? pn,
    int? rn,
  }) {
    return getMap(
      'message/notifications',
      v1Query({'block': block, 'pn': pn, 'rn': rn}),
    );
  }

  /// POST /api/v1/message/read
  ///
  /// 提交参数:
  /// ```json
  /// {"block":"world_apply"}
  /// {"notification_id":"ntf_AB12CD34"}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_msg":"succ","data":{}}
  /// ```
  Future<void> markNotificationsRead({String? block, String? notificationId}) {
    return postVoid(
      'message/read',
      v1Body({'notification_id': notificationId, 'block': block}),
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
