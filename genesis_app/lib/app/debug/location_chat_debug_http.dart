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
    if (_isWorldMessagesRequest(request)) {
      _recordChatroomWorldMessagesResponse(request, response);
      return;
    }
    if (!_isLocationMessagesRequest(request)) return;
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
    if (!_isLocationMessagesRequest(request) &&
        !_isWorldMessagesRequest(request)) {
      return;
    }
    final query = request.uri.queryParameters;
    final action = _isWorldMessagesRequest(request)
        ? 'getWorldMessagesLatestFailed'
        : 'getMessagesFailed';
    LocationChatDebugHub.record(
      source: 'http',
      action: action,
      worldId: asString(query['world_id']),
      locationId: asString(query['location_id']),
      details: {
        'endpoint': '${request.method} ${request.uri.path}',
        'request': query,
        'error': '$error',
      },
    );
  }

  static void _recordChatroomWorldMessagesResponse(
    TransportRequest request,
    TransportResponse response,
  ) {
    final decoded = _decodeJson(response.body);
    final responseJson = decoded is Map
        ? Map<String, Object?>.from(asJsonMap(decoded))
        : const <String, Object?>{};
    ChatroomWorldMessagesResponse? parsed;
    try {
      final data = handleV1ResponseErrNo(decoded);
      parsed = ChatroomWorldMessagesResponse.fromJson(asJsonMap(data));
    } catch (_) {
      parsed = null;
    }
    final messages = parsed == null
        ? const <Map<String, Object?>>[]
        : parsed.locations
              .expand((location) => location.messages)
              .map(_debugHttpMessage)
              .toList(growable: false);
    final query = request.uri.queryParameters;
    final worldId = asString(query['world_id']);
    LocationChatDebugHub.record(
      source: 'http',
      action: 'getWorldMessagesLatest',
      worldId: worldId,
      locationId: '',
      details: {
        'endpoint': '${request.method} ${request.uri.path}',
        'request': query,
        'statusCode': response.statusCode,
        'locations': parsed?.locations.length ?? 0,
        'loaded': messages.length,
        'response': responseJson,
        'messages': messages,
      },
      snapshotKey: '$worldId|world|getWorldMessagesLatest',
      snapshot: {
        'endpoint': '${request.method} ${request.uri.path}',
        'worldId': worldId,
        'locationId': '',
        'action': 'getWorldMessagesLatest',
        'request': query,
        'statusCode': response.statusCode,
        'locations': parsed?.locations.length ?? 0,
        'loaded': messages.length,
        'response': responseJson,
        'messages': messages,
      },
    );
  }

  static bool _isLocationMessagesRequest(TransportRequest request) {
    return request.method.toUpperCase() == 'GET' &&
        request.uri.path.endsWith('/aitown-chat/api/messages');
  }

  static bool _isWorldMessagesRequest(TransportRequest request) {
    return request.method.toUpperCase() == 'GET' &&
        request.uri.path.endsWith('/aitown-chat/internal/world/messages');
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
