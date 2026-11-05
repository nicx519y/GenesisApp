part of 'world_chatroom_service.dart';

extension _WorldChatroomQueueMonitor on WorldChatroomService {
  ChatroomQueueMessageInfo _queueMessageInfo(WorldChatroomMessage m) =>
      ChatroomQueueMessageInfo(
        globalMessageId: m.globalMessageId,
        messageId: m.messageId,
        locationMessageId: m.locationMessageId,
        conversationRoundId: m.conversationRoundNumber,
        clientMsgId: m.clientMsgId,
        type: m.businessType,
        streamType: m.streamType,
        gatewayRequestId: m.llmAttempt?.generation.request ?? '',
        attemptNo: m.llmAttempt?.number,
      );

  void _resetQueueAnomalyMonitor() {
    _queueAnomalyMonitor.reset(
      worldId: _worldId,
      connectionGeneration: _messageSyncGeneration,
    );
    for (final entry in _state.messagesByLocation.entries) {
      _queueAnomalyMonitor.replaceQueue(
        entry.key,
        entry.value.map(_queueMessageInfo),
      );
      _queueAnomalyMonitor.rebuildBaseline(entry.key);
    }
  }

  void _syncQueueAnomalyIndexes(
    WorldChatroomState before,
    WorldChatroomState after,
  ) {
    for (final entry in after.messagesByLocation.entries) {
      if (identical(before.messagesByLocation[entry.key], entry.value)) {
        continue;
      }
      if (before.messagesByLocation[entry.key]?.length == entry.value.length &&
          !_queueIdentityChanges.contains(entry.key) &&
          !_queueBaselineRebuilds.contains(entry.key)) {
        continue;
      }
      _queueAnomalyMonitor.replaceQueue(
        entry.key,
        entry.value.map(_queueMessageInfo),
      );
    }
    for (final location in before.messagesByLocation.keys) {
      if (after.messagesByLocation.containsKey(location)) continue;
      _queueAnomalyMonitor.replaceQueue(location, const []);
      _queueAnomalyMonitor.rebuildBaseline(location);
    }
    for (final location in _queueBaselineRebuilds) {
      _queueAnomalyMonitor.rebuildBaseline(location);
    }
    _queueBaselineRebuilds.clear();
    _queueIdentityChanges.clear();
  }

  ChatroomQueueMessageInfo _streamQueueInfo(
    ChatroomStreamIdentity i,
    int locationMessageId,
    String type,
    String streamType,
  ) => ChatroomQueueMessageInfo(
    globalMessageId: i.globalMessageId,
    messageId: i.messageId,
    locationMessageId: locationMessageId,
    conversationRoundId: int.tryParse(i.conversationRoundId) ?? 0,
    type: type,
    streamType: streamType,
    gatewayRequestId: i.gatewayRequestId,
    attemptNo: i.attemptNo,
  );

  List<ChatroomQueueObservation> _inspectSocketQueueEvent(ChatroomEvent event) {
    late final String world, location;
    late final ChatroomQueueMessageInfo info;
    switch (event) {
      case ChatroomMessageEvent e:
        if (!e.ok) return const [];
        world = e.worldId;
        location = e.locationId;
        info = ChatroomQueueMessageInfo(
          globalMessageId: e.globalMessageId,
          messageId: e.messageId,
          locationMessageId: e.locationMessageId,
          conversationRoundId: int.tryParse(e.conversationRoundId) ?? 0,
          clientMsgId: e is ChatroomUserMessage ? e.clientMsgId : '',
          type: e.businessType.isEmpty ? e.senderType : e.businessType,
          streamType: e.streamType,
        );
      case ChatroomAiStreamStart e:
        world = e.worldId;
        location = e.locationId;
        info = _streamQueueInfo(
          e.identity,
          e.locationMessageId,
          e.businessType,
          e.streamType,
        );
      case ChatroomAiStreamChunk e:
        world = e.worldId;
        location = e.locationId;
        info = _streamQueueInfo(
          e.identity,
          e.locationMessageId,
          e.businessType,
          e.streamType,
        );
      case ChatroomAiStreamEnd e:
        world = e.worldId;
        location = e.locationId;
        info = _streamQueueInfo(
          e.identity,
          e.locationMessageId,
          e.businessType,
          e.streamType,
        );
      default:
        return const [];
    }
    if (_disposed || world != _worldId || !info.hasIdentity) return const [];
    // Only canonical location messages. Legacy projected Tick/movement events
    // with no formal location identity cannot be compared to a location cursor.
    final locations = location.trim().isNotEmpty
        ? [location.trim()]
        : event is ChatroomTickAdvanceMessage ||
              event is ChatroomCharactersMovedMessage
        ? _tickAdvanceLocationIds('')
        : const <String>[];
    final observations = <ChatroomQueueObservation>[];
    for (final target in locations) {
      if (!_shouldStoreMessageForLocation(target) ||
          _deletedMessageIds[target]?.contains(info.globalMessageId) == true) {
        continue;
      }
      final observation = _queueAnomalyMonitor.inspect(
        location: target,
        incoming: info,
        context: {
          'connected': _state.connected,
          'reconnecting': _state.reconnecting,
          'latest_sync_verified':
              _entryNetworkVerified[target] == _historyTicket(target),
        },
      );
      if (observation != null) observations.add(observation);
    }
    return observations;
  }
}
