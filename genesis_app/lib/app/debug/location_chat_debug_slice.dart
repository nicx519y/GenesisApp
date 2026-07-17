import '../../components/chat/shared/chat_ui.dart';
import '../../network/chatroom/world_chatroom_service.dart';
import 'location_chat_debug_hub.dart';

class LocationChatDebugSlice {
  const LocationChatDebugSlice._();

  static bool get enabled => LocationChatDebugHub.enabled;

  static void recordEvent({
    required String source,
    required String action,
    String worldId = '',
    String locationId = '',
    Map<String, Object?> details = const <String, Object?>{},
    String snapshotKey = '',
    Map<String, Object?>? snapshot,
  }) {
    LocationChatDebugHub.record(
      source: source,
      action: action,
      worldId: worldId,
      locationId: locationId,
      details: details,
      snapshotKey: snapshotKey,
      snapshot: snapshot,
    );
  }

  static void recordServiceQueue({
    required String action,
    required String worldId,
    required String locationId,
    required WorldChatroomState state,
    Map<String, Object?> details = const <String, Object?>{},
  }) {
    if (!enabled) return;
    final resolvedLocationId = locationId.trim();
    final queue =
        state.messagesByLocation[resolvedLocationId] ??
        const <WorldChatroomMessage>[];
    final messages = debugWorldMessageQueue(queue);
    LocationChatDebugHub.record(
      source: 'service',
      action: action,
      worldId: worldId,
      locationId: resolvedLocationId,
      details: <String, Object?>{
        ...details,
        'joinedLocationId': state.joinedLocationId,
        'connected': state.connected,
        'joining': state.joining,
        'reconnecting': state.reconnecting,
        'inputBlocked': state.inputBlocked,
        'queueCount': queue.length,
        'queue': messages,
      },
      snapshotKey: '$worldId|$resolvedLocationId',
      snapshot: <String, Object?>{
        'worldId': worldId,
        'locationId': resolvedLocationId,
        'joinedLocationId': state.joinedLocationId,
        'connected': state.connected,
        'joining': state.joining,
        'reconnecting': state.reconnecting,
        'inputBlocked': state.inputBlocked,
        'count': queue.length,
        'messages': messages,
      },
    );
  }

  static void recordPanel({
    required String action,
    required String worldId,
    required String locationId,
    required String locationName,
    required bool active,
    required bool isLeafLocation,
    required WorldChatroomState state,
    required Iterable<WorldChatroomMessage> sourceMessages,
    required Iterable<ChatMessageVm> renderMessages,
    required Map<String, Object?> scroll,
    required Map<String, Object?> details,
    required bool hasMoreOlderMessages,
    required bool loadingOlderMessages,
    required int unseenIncomingCount,
    required bool awaitingAiResponse,
  }) {
    if (!enabled) return;
    final source = sourceMessages.toList(growable: false);
    final render = renderMessages.toList(growable: false);
    LocationChatDebugHub.record(
      source: 'panel',
      action: action,
      worldId: worldId,
      locationId: locationId,
      details: <String, Object?>{
        ...details,
        'active': active,
        'isLeafLocation': isLeafLocation,
        'joinedLocationId': state.joinedLocationId,
        'connected': state.connected,
        'joining': state.joining,
        'inputBlocked': state.inputBlocked,
        'sourceCount': source.length,
        'vmCount': render.length,
        'hasMoreOlderMessages': hasMoreOlderMessages,
        'loadingOlderMessages': loadingOlderMessages,
        'unseenIncomingCount': unseenIncomingCount,
        'awaitingAiResponse': awaitingAiResponse,
        'scroll': scroll,
      },
      snapshotKey: '$worldId|$locationId',
      snapshot: <String, Object?>{
        'worldId': worldId,
        'locationId': locationId,
        'locationName': locationName,
        'active': active,
        'isLeafLocation': isLeafLocation,
        'joinedLocationId': state.joinedLocationId,
        'connected': state.connected,
        'joining': state.joining,
        'inputBlocked': state.inputBlocked,
        'awaitingAiResponse': awaitingAiResponse,
        'sourceCount': source.length,
        'vmCount': render.length,
        'sourceMessages': debugWorldMessageQueue(source),
        'renderMessages': debugRenderMessageQueue(render),
        'scroll': scroll,
      },
    );
  }

  static List<Map<String, Object?>> debugWorldMessageQueue(
    Iterable<WorldChatroomMessage> messages,
  ) {
    return messages.map(debugWorldMessage).toList(growable: false);
  }

  static Map<String, Object?> debugWorldMessage(WorldChatroomMessage message) {
    return <String, Object?>{
      'globalMsgId': message.globalMessageId,
      'msgId': message.messageId,
      'locationMsgId': message.locationMessageId,
      'location_msg_id': message.locationMessageId,
      'location_message_id': message.locationMessageId,
      'queueMsgId': message.locationQueueMessageId,
      'locationId': message.locationId,
      'roundId': message.conversationRoundId,
      'tickNo': message.tickNo,
      'senderType': message.senderType,
      'senderId': message.senderId,
      'senderName': message.senderName,
      'clientMsgId': message.clientMsgId,
      'streaming': message.streaming,
      'contentPreview': _preview(message.content),
      'currentTime': message.currentTime,
      'createdAt': message.createdAt?.toIso8601String(),
    };
  }

  static List<Map<String, Object?>> debugRenderMessageQueue(
    Iterable<ChatMessageVm> messages,
  ) {
    return messages.map(debugRenderMessage).toList(growable: false);
  }

  static Map<String, Object?> debugRenderMessage(ChatMessageVm message) {
    return <String, Object?>{
      'localId': message.localId,
      'clientMsgId': message.clientMsgId,
      'globalMsgId': message.globalMessageId,
      'global_message_id': message.globalMessageId,
      'messageId': message.messageId,
      'locationMsgId': message.locationMessageId,
      'location_msg_id': message.locationMessageId,
      'location_message_id': message.locationMessageId,
      'roundId': message.roundId,
      'tickNo': message.tickNo,
      'senderId': message.senderId,
      'senderName': message.senderName,
      'senderType': message.senderType,
      'isMe': message.isMe,
      'status': message.status,
      'error': message.error,
      'contentPreview': _preview(message.text),
      'currentTime': message.currentTime,
      'createdAt': message.createdAt.toIso8601String(),
    };
  }

  static String _preview(String value) {
    final trimmed = value.trim();
    if (trimmed.length <= 80) return trimmed;
    return '${trimmed.substring(0, 80)}...';
  }
}
