import 'v1_api_resource.dart';

class DmV1Api extends V1ApiResource {
  const DmV1Api(super.client);

  /// GET /api/v1/direct_message/conversations
  ///
  /// 提交参数:
  /// ```json
  /// {"pn":1,"rn":20}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_msg":"succ","data":{"list":[{"conv_id":"string","peer":{},"last_message":"string","last_message_at":"string","last_sender_uid":"string","unread_cnt":0,"is_friend":true,"i_blocked_peer":false,"peer_blocked_me":false,"can_send_next_message":true}],"total":0,"pn":1,"rn":20}}
  /// ```
  Future<Map<String, dynamic>> conversations({int? pn, int? rn}) {
    return getMap(
      'direct_message/conversations',
      v1Query({'pn': pn, 'rn': rn}),
    );
  }

  /// GET /api/v1/direct_message/list
  ///
  /// 提交参数:
  /// ```json
  /// {"peer_uid":"string","pn":1,"rn":20}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_msg":"succ","data":{"list":[{"msg_id":"string","conv_id":"string","sender_uid":"string","receiver_uid":"string","content":"string","created_at":"2026-05-23 12:34:56"}],"total":0,"pn":1,"rn":20}}
  /// ```
  Future<Map<String, dynamic>> list({
    required String peerUid,
    int? pn,
    int? rn,
  }) {
    return getMap(
      'direct_message/list',
      v1Query({'peer_uid': peerUid, 'pn': pn, 'rn': rn}),
    );
  }

  /// POST /api/v1/direct_message/send
  ///
  /// 提交参数:
  /// ```json
  /// {"peer_uid":"string","content":"string"}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_msg":"succ","data":{"message":{"msg_id":"string","conv_id":"string","sender_uid":"string","receiver_uid":"string","content":"string","created_at":"2026-05-23 12:34:56"},"conversation":{}}}
  /// ```
  Future<Map<String, dynamic>> send({
    required String peerUid,
    required String content,
  }) {
    return postMap(
      'direct_message/send',
      v1Body({'peer_uid': peerUid, 'content': content}),
    );
  }

  /// POST /api/v1/direct_message/read
  ///
  /// 提交参数:
  /// ```json
  /// {"peer_uid":"string"}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_msg":"succ","data":{}}
  /// ```
  Future<void> markRead({required String peerUid}) {
    return postVoid('direct_message/read', {'peer_uid': peerUid});
  }

  /// GET /api/v1/direct_message/unread
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_msg":"succ","data":{"unread_cnt":3}}
  /// ```
  Future<Map<String, dynamic>> unread() {
    return getMap('direct_message/unread');
  }

  /// POST /api/v1/direct_message/block
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
  Future<void> block({required String targetUid}) {
    return postVoid('direct_message/block', {'target_uid': targetUid});
  }

  /// POST /api/v1/direct_message/unblock
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
  Future<void> unblock({required String targetUid}) {
    return postVoid('direct_message/unblock', {'target_uid': targetUid});
  }

  /// GET /api/v1/direct_message/blocks
  ///
  /// 提交参数:
  /// ```json
  /// {"pn":1,"rn":20}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_msg":"succ","data":{"list":[{}],"total":0,"pn":1,"rn":20}}
  /// ```
  Future<Map<String, dynamic>> blocks({int? pn, int? rn}) {
    return getMap('direct_message/blocks', v1Query({'pn': pn, 'rn': rn}));
  }
}
