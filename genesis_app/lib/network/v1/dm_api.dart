import 'v1_api_resource.dart';

class DmV1Api extends V1ApiResource {
  const DmV1Api(super.client);

  /// GET /api/v1/dm/chatlist
  ///
  /// 提交参数:
  /// ```json
  /// {"pn":1,"rn":20}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_str":"success","data":{"list":[{"conversation_id":"string","peer_name":"string","peer_uid":"string","peer_avatar":"string","last_message_text":"string","last_message_at":"string","last_message_sender_uid":"string","unread_cnt":0,"dm_permission":"unlimited"}],"total":0}}
  /// ```
  Future<Map<String, dynamic>> chatList({int? pn, int? rn}) {
    return getMap('dm/chatlist', v1Query({'pn': pn, 'rn': rn}));
  }

  /// GET /api/v1/dm/messagelist
  ///
  /// 提交参数:
  /// ```json
  /// {"conversation_id":"string","before_seq":24,"rn":20}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_str":"success","data":{"conversation_id":"string","peer_name":"string","peer_uid":"string","peer_avatar":"string","dm_permission":"unlimited","messages":[{"message_id":"string","conversation_id":"string","seq":1,"sender_uid":"string","message_type":"text","content":"string","invite_world_id":"string","invite_origin_id":"string","invite_world_name":"string","inviter_user_name":"string","invite_status":"pending","create_time":"string"}],"has_more":true}}
  /// ```
  Future<Map<String, dynamic>> messageList({
    required String conversationId,
    int? beforeSeq,
    int? rn,
  }) {
    return getMap(
      'dm/messagelist',
      v1Query({
        'conversation_id': conversationId,
        'before_seq': beforeSeq,
        'rn': rn,
      }),
    );
  }

  /// POST /api/v1/dm/send
  ///
  /// 提交参数:
  /// ```json
  /// {"target_uid":"string","conversation_id":"string","content":"string","client_msg_id":"string"}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_str":"success","data":{"message":{"message_id":"string","conversation_id":"string","seq":1,"sender_uid":"string","message_type":"text","content":"string","create_time":"string"},"permission":{"relation_type":"friend","dm_permission":"unlimited","can_send_now":true,"block_reason":"string","latest_sender_uid":"string","conversation_id":"string"}}}
  /// ```
  Future<Map<String, dynamic>> send({
    String? targetUid,
    String? conversationId,
    required String content,
    required String clientMsgId,
  }) {
    return postMap(
      'dm/send',
      v1Body({
        'target_uid': targetUid,
        'conversation_id': conversationId,
        'content': content,
        'client_msg_id': clientMsgId,
      }),
    );
  }

  /// POST /api/v1/dm/delchat
  ///
  /// 提交参数:
  /// ```json
  /// {"conversation_id":"string"}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_str":"success","data":{}}
  /// ```
  Future<void> deleteChat({required String conversationId}) {
    return postVoid('dm/delchat', {'conversation_id': conversationId});
  }

  /// POST /api/v1/dm/delmessage
  ///
  /// 提交参数:
  /// ```json
  /// {"conversation_id":"string","message_id":"string"}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_str":"success","data":{}}
  /// ```
  Future<void> deleteMessage({
    required String conversationId,
    required String messageId,
  }) {
    return postVoid('dm/delmessage', {
      'conversation_id': conversationId,
      'message_id': messageId,
    });
  }

  /// POST /api/v1/dm/read
  ///
  /// 提交参数:
  /// ```json
  /// {"conversation_id":"string","last_read_seq":25}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_str":"success","data":{}}
  /// ```
  Future<void> markRead({
    required String conversationId,
    required int lastReadSeq,
  }) {
    return postVoid('dm/read', {
      'conversation_id': conversationId,
      'last_read_seq': lastReadSeq,
    });
  }

  /// POST /api/v1/dm/inviteworldcard
  ///
  /// 提交参数:
  /// ```json
  /// {"conversation_id":"string","world_instance_id":"string","origin_id":"string","client_msg_id":"string"}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_str":"success","data":{"message":{"message_id":"string","conversation_id":"string","seq":1,"sender_uid":"string","message_type":"invite","invite_world_id":"string","invite_origin_id":"string","invite_world_name":"string","invite_origin_name":"string","inviter_user_name":"string","invite_status":"pending","create_time":"string"}}}
  /// ```
  Future<Map<String, dynamic>> inviteWorldCard({
    required String conversationId,
    required String worldInstanceId,
    required String originId,
    required String clientMsgId,
  }) {
    return postMap('dm/inviteworldcard', {
      'conversation_id': conversationId,
      'world_instance_id': worldInstanceId,
      'origin_id': originId,
      'client_msg_id': clientMsgId,
    });
  }

  /// POST /api/v1/dm/respondworldcard
  ///
  /// 提交参数:
  /// ```json
  /// {"invite_id":"string","action":"accept"}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_str":"success","data":{"invite_id":"string","invite_status":"accepted","world_instance_id":"string","origin_id":"string"}}
  /// ```
  Future<Map<String, dynamic>> respondWorldCard({
    required String inviteId,
    required String action,
  }) {
    return postMap('dm/respondworldcard', {
      'invite_id': inviteId,
      'action': action,
    });
  }
}
