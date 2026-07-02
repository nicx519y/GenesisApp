import 'dart:convert';

import '../../network/api_client.dart';
import '../../network/chatroom/chatroom_http_models.dart';
import '../../network/http_transport.dart';
import '../../network/json_utils.dart';
import '../../network/v1/v1_api_resource.dart';
import 'location_chat_debug_hub.dart';

class LocationChatDebugHttp {
  const LocationChatDebugHttp._();

  static ApiRequestInterceptor? wrapChatroomHttpInterceptor(
    ApiRequestInterceptor? delegate,
  ) {
    if (!LocationChatDebugHub.enabled) return delegate;
    return (request, send) async {
      try {
        final response = delegate == null
            ? await send(request)
            : await delegate(request, send);
        _recordChatroomMessagesResponse(request, response);
        return response;
      } catch (error) {
        _recordChatroomMessagesFailure(request, error);
        rethrow;
      }
    };
  }

  static void _recordChatroomMessagesResponse(
    TransportRequest request,
    TransportResponse response,
  ) {
    if (!_isMessagesRequest(request)) return;
    final decoded = _decodeJson(response.body);
    final responseJson = decoded is Map
        ? Map<String, Object?>.from(asJsonMap(decoded))
        : const <String, Object?>{};
    ChatroomMessageListResponse? parsed;
    try {
      final data = handleV1ResponseErrNo(decoded);
      parsed = ChatroomMessageListResponse.fromJson(asJsonMap(data));
    } catch (_) {
      parsed = null;
    }
    final messages = parsed == null
        ? const <Map<String, Object?>>[]
        : parsed.messages.map(_debugHttpMessage).toList(growable: false);
    final query = request.uri.queryParameters;
    final worldId = asString(query['world_id']);
    final locationId = asString(query['location_id']);
    final hasSince = asString(query['since']).trim().isNotEmpty;
    final action = hasSince ? 'getMessagesOlder' : 'getMessagesLatest';
    LocationChatDebugHub.record(
      source: 'http',
      action: action,
      worldId: worldId,
      locationId: locationId,
      details: {
        'endpoint': '${request.method} ${request.uri.path}',
        'request': query,
        'statusCode': response.statusCode,
        'loaded': parsed?.messages.length ?? 0,
        'hasMore': parsed?.hasMore,
        'newestMessageId': parsed?.newestMessageId,
        'response': responseJson,
        'messages': messages,
      },
      snapshotKey: '$worldId|$locationId|$action',
      snapshot: {
        'endpoint': '${request.method} ${request.uri.path}',
        'worldId': worldId,
        'locationId': locationId,
        'action': action,
        'request': query,
        'statusCode': response.statusCode,
        'loaded': parsed?.messages.length ?? 0,
        'hasMore': parsed?.hasMore,
        'newestMessageId': parsed?.newestMessageId,
        'response': responseJson,
        'messages': messages,
      },
    );
  }

  static void _recordChatroomMessagesFailure(
    TransportRequest request,
    Object error,
  ) {
    if (!_isMessagesRequest(request)) return;
    final query = request.uri.queryParameters;
    LocationChatDebugHub.record(
      source: 'http',
      action: 'getMessagesFailed',
      worldId: asString(query['world_id']),
      locationId: asString(query['location_id']),
      details: {
        'endpoint': '${request.method} ${request.uri.path}',
        'request': query,
        'error': '$error',
      },
    );
  }

  static bool _isMessagesRequest(TransportRequest request) {
    return request.method.toUpperCase() == 'GET' &&
        request.uri.path.endsWith('/aitown-chat/api/messages');
  }

  static Object? _decodeJson(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  static Map<String, Object?> _debugHttpMessage(ChatroomHttpMessage message) {
    return <String, Object?>{
      'globalMsgId': message.globalMessageId,
      'msgId': message.messageId,
      'locationMsgId': message.locationMessageId,
      'location_msg_id': message.locationMessageId,
      'location_message_id': message.locationMessageId,
      'queueMsgId': message.locationMessageId > 0
          ? message.locationMessageId
          : message.messageId,
      'locationId': message.locationId,
      'roundId': message.conversationRoundId,
      'tickNo': message.tickNo,
      'senderType': message.senderType,
      'senderId': message.senderId,
      'senderName': message.senderName,
      'userId': message.userId,
      'contentPreview': _preview(message.content),
      'currentTime': message.currentTime,
      'createdAt': message.createdAt?.toIso8601String(),
    };
  }

  static String _preview(String value) {
    final trimmed = value.trim();
    if (trimmed.length <= 80) return trimmed;
    return '${trimmed.substring(0, 80)}...';
  }
}
