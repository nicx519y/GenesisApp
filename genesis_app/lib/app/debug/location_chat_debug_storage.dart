import '../../network/chatroom/chatroom_message_storage.dart';
import '../../network/json_utils.dart';
import 'location_chat_debug_hub.dart';

class LocationChatDebugChatroomMessageStorage
    implements ChatroomMessageStorage {
  LocationChatDebugChatroomMessageStorage(this._delegate);

  final ChatroomMessageStorage _delegate;

  static ChatroomMessageStorage wrap(ChatroomMessageStorage delegate) {
    if (!LocationChatDebugHub.enabled) return delegate;
    if (delegate is LocationChatDebugChatroomMessageStorage) return delegate;
    return LocationChatDebugChatroomMessageStorage(delegate);
  }

  @override
  Future<List<Map<String, dynamic>>> loadLatestMessages({
    required String ownerUid,
    required String worldId,
    required String locationId,
    required int limit,
  }) async {
    final messages = await _delegate.loadLatestMessages(
      ownerUid: ownerUid,
      worldId: worldId,
      locationId: locationId,
      limit: limit,
    );
    _record(
      action: 'loadLatest',
      ownerUid: ownerUid,
      worldId: worldId,
      locationId: locationId,
      messages: messages,
      details: {'limit': limit, 'loaded': messages.length},
    );
    return messages;
  }

  @override
  Future<List<Map<String, dynamic>>> loadMessagesBefore({
    required String ownerUid,
    required String worldId,
    required String locationId,
    required int beforeMessageId,
    required int limit,
  }) async {
    final messages = await _delegate.loadMessagesBefore(
      ownerUid: ownerUid,
      worldId: worldId,
      locationId: locationId,
      beforeMessageId: beforeMessageId,
      limit: limit,
    );
    _record(
      action: 'loadBefore',
      ownerUid: ownerUid,
      worldId: worldId,
      locationId: locationId,
      messages: messages,
      details: {
        'beforeMessageId': beforeMessageId,
        'limit': limit,
        'loaded': messages.length,
      },
    );
    return messages;
  }

  @override
  Future<void> mergeMessages({
    required String ownerUid,
    required String worldId,
    required String locationId,
    required List<Map<String, dynamic>> messages,
    int maxMessagesPerLocation = 200,
  }) async {
    await _delegate.mergeMessages(
      ownerUid: ownerUid,
      worldId: worldId,
      locationId: locationId,
      messages: messages,
      maxMessagesPerLocation: maxMessagesPerLocation,
    );
    await _recordLatestSnapshot(
      action: 'merge',
      ownerUid: ownerUid,
      worldId: worldId,
      locationId: locationId,
      limit: maxMessagesPerLocation,
      details: {
        'incoming': messages.length,
        'maxMessagesPerLocation': maxMessagesPerLocation,
      },
    );
  }

  @override
  Future<void> upsertMessage({
    required String ownerUid,
    required String worldId,
    required String locationId,
    required Map<String, dynamic> message,
    int maxMessagesPerLocation = 200,
  }) async {
    await _delegate.upsertMessage(
      ownerUid: ownerUid,
      worldId: worldId,
      locationId: locationId,
      message: message,
      maxMessagesPerLocation: maxMessagesPerLocation,
    );
    await _recordLatestSnapshot(
      action: 'upsert',
      ownerUid: ownerUid,
      worldId: worldId,
      locationId: locationId,
      limit: maxMessagesPerLocation,
      details: {'maxMessagesPerLocation': maxMessagesPerLocation},
    );
  }

  @override
  Future<void> clearCache(String ownerUid) async {
    await _delegate.clearCache(ownerUid);
    LocationChatDebugHub.record(
      source: 'storage',
      action: 'clear',
      details: {'ownerUid': ownerUid},
    );
  }

  Future<void> _recordLatestSnapshot({
    required String action,
    required String ownerUid,
    required String worldId,
    required String locationId,
    required int limit,
    required Map<String, Object?> details,
  }) async {
    if (!LocationChatDebugHub.enabled) return;
    final messages = await _delegate.loadLatestMessages(
      ownerUid: ownerUid,
      worldId: worldId,
      locationId: locationId,
      limit: limit,
    );
    _record(
      action: action,
      ownerUid: ownerUid,
      worldId: worldId,
      locationId: locationId,
      messages: messages,
      details: {
        ...details,
        'snapshotLimit': limit,
        'snapshotCount': messages.length,
      },
    );
  }

  void _record({
    required String action,
    required String ownerUid,
    required String worldId,
    required String locationId,
    required Iterable<Map<String, dynamic>> messages,
    Map<String, Object?> details = const <String, Object?>{},
  }) {
    if (!LocationChatDebugHub.enabled) return;
    final queue = _storageDebugQueue(messages);
    LocationChatDebugHub.record(
      source: 'storage',
      action: action,
      worldId: worldId,
      locationId: locationId,
      details: <String, Object?>{
        'ownerUid': ownerUid,
        ...details,
        'queue': queue,
      },
      snapshotKey: '$ownerUid|$worldId|$locationId',
      snapshot: <String, Object?>{
        'ownerUid': ownerUid,
        'worldId': worldId,
        'locationId': locationId,
        'count': queue.length,
        'messages': queue,
      },
    );
  }
}

List<Map<String, Object?>> _storageDebugQueue(
  Iterable<Map<String, dynamic>> messages,
) {
  return _sortMessageJson(messages)
      .map(
        (message) => <String, Object?>{
          'globalMsgId': _globalMessageId(message),
          'msgId': _messageId(message),
          'locationMsgId': _locationMessageId(message),
          'location_msg_id': _locationMessageId(message),
          'location_message_id': _locationMessageId(message),
          'queueMsgId': _locationQueueMessageId(message),
          'locationId': asString(message['location_id']),
          'senderType': asString(message['sender_type']),
          'senderId': asString(message['sender_id']),
          'clientMsgId': asString(message['client_msg_id']),
          'contentPreview': _preview(asString(message['content'])),
          'currentTime': asString(message['current_time']),
          'createdAt':
              (asDateTime(message['created_at']) ?? asDateTime(message['ts']))
                  ?.toIso8601String(),
        },
      )
      .toList(growable: false);
}

List<Map<String, dynamic>> _sortMessageJson(
  Iterable<Map<String, dynamic>> messages,
) {
  final sorted = messages
      .map((message) => Map<String, dynamic>.from(message))
      .toList(growable: false);
  sorted.sort((a, b) {
    final byLocationMessage = _locationQueueMessageId(
      a,
    ).compareTo(_locationQueueMessageId(b));
    if (byLocationMessage != 0) return byLocationMessage;
    return _messageId(a).compareTo(_messageId(b));
  });
  return sorted;
}

int _messageId(Map<String, dynamic> message) {
  return asInt(message['msg_id'], fallback: asInt(message['message_id']));
}

int _globalMessageId(Map<String, dynamic> message) {
  return asInt(
    message['global_msg_id'],
    fallback: asInt(message['global_message_id']),
  );
}

int _locationMessageId(Map<String, dynamic> message) {
  return asInt(
    message['location_msg_id'],
    fallback: asInt(message['location_message_id']),
  );
}

int _locationQueueMessageId(Map<String, dynamic> message) {
  final locationMessageId = _locationMessageId(message);
  return locationMessageId > 0 ? locationMessageId : _messageId(message);
}

String _preview(String value) {
  final trimmed = value.trim();
  if (trimmed.length <= 80) return trimmed;
  return '${trimmed.substring(0, 80)}...';
}
