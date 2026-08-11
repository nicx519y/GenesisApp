import '../../network/chatroom/world_chatroom_service.dart';

/// Returns `null` until the requested Tick message exists in the loaded
/// location queues. Once it exists, an empty set means that Tick has no Events.
Set<String>? worldCurrentTickEventLocationIds({
  required Map<String, List<WorldChatroomMessage>> messagesByLocation,
  required int tickNo,
  required int subTickNo,
}) {
  var matchedTick = false;
  final locationIds = <String>{};
  final seenMessages = <String>{};

  for (final messages in messagesByLocation.values) {
    for (final message in messages) {
      final payload = message.v2TickPayload;
      if (payload == null ||
          payload.tickNo != tickNo ||
          payload.subTickNo != subTickNo) {
        continue;
      }
      final identity = _tickMessageIdentity(message);
      if (identity.isNotEmpty && !seenMessages.add(identity)) continue;
      matchedTick = true;
      for (final event in payload.storyEvents) {
        final locationId = event.locationId.trim();
        if (locationId.isNotEmpty) locationIds.add(locationId);
      }
    }
  }

  return matchedTick ? Set<String>.unmodifiable(locationIds) : null;
}

String _tickMessageIdentity(WorldChatroomMessage message) {
  if (message.globalMessageId > 0) return 'global:${message.globalMessageId}';
  if (message.messageId > 0) return 'message:${message.messageId}';
  if (message.locationMessageId > 0) {
    return 'location:${message.locationId}:${message.locationMessageId}';
  }
  return '';
}
