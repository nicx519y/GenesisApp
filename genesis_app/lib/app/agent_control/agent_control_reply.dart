part of 'agent_control_registry.dart';

String _agentMessageForTurn({
  required int turn,
  required WorldDetail world,
  required String locationName,
  required String lastReply,
  required String queueContext,
  required String? seedMessage,
}) {
  if (turn == 1) {
    final seed = seedMessage?.trim() ?? '';
    if (seed.isNotEmpty) return seed;
    if (queueContext.isNotEmpty) {
      return 'Turn $turn: I have arrived at $locationName in ${world.name}. Recent context: $queueContext. Continue from what is already happening here and give me a natural next action.';
    }
    return 'Turn $turn: I have arrived at $locationName in ${world.name}. What should I notice first?';
  }
  final context = _messageExcerpt(lastReply, limit: 120);
  final queue = queueContext.isEmpty
      ? ''
      : ' Recent queue context: ${_messageExcerpt(queueContext, limit: 180)}.';
  return 'Turn $turn: Based on your last reply "$context",$queue continue the scene and tell me what I should do or ask next.';
}

String _agentQueueContext(List<WorldChatroomMessage> messages) {
  final rows = messages
      .where((message) => message.content.trim().isNotEmpty)
      .toList(growable: false);
  if (rows.isEmpty) return '';
  rows.sort((a, b) {
    final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
    final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
    if (aTime != bTime) return aTime.compareTo(bTime);
    return a.messageId.compareTo(b.messageId);
  });
  final tail = rows.length <= 5 ? rows : rows.sublist(rows.length - 5);
  return tail
      .map((message) {
        final speaker = _firstNonEmpty([
          message.senderName,
          message.senderType,
          message.senderId,
          'unknown',
        ]);
        return '$speaker: ${_messageExcerpt(message.content, limit: 80)}';
      })
      .join(' | ');
}

Map<String, Object?> _agentWorldChatTargetJson(_AgentWorldChatTarget target) {
  return {
    'wid': target.world.worldId,
    'worldName': target.world.name,
    'relationStatusBefore': target.relationBefore,
    'relationStatusAfter': target.world.relationStatus,
    'authenticated': target.authenticated,
    'launchedByAgent': false,
    'launchPolls': 0,
    'locationId': target.locationId,
    'locationName': target.locationName,
    'isLeafLocation': target.location['isLeafLocation'] == true,
  };
}

List<Map<String, Object?>> _agentMessageContextRows(
  List<WorldChatroomMessage> messages, {
  int limit = 12,
}) {
  final rows = messages
      .where((message) => message.content.trim().isNotEmpty)
      .toList(growable: false);
  rows.sort((a, b) {
    final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
    final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
    if (aTime != bTime) return aTime.compareTo(bTime);
    return a.messageId.compareTo(b.messageId);
  });
  final tail = rows.length <= limit ? rows : rows.sublist(rows.length - limit);
  return [
    for (final message in tail)
      {
        'messageId': message.messageId,
        'globalMessageId': message.globalMessageId,
        'locationMessageId': message.locationMessageId,
        'conversationRoundId': message.conversationRoundId,
        'senderType': message.senderType,
        'senderId': message.senderId,
        'senderName': message.senderName,
        'streaming': message.streaming,
        'content': _messageExcerpt(message.content, limit: 500),
        'createdAt': message.createdAt?.toIso8601String(),
      },
  ];
}

Future<void> _ensureAgentChatroomReady(
  WorldChatroomService service, {
  required String worldId,
  required String locationId,
  required ChatroomConnectionIdentity identity,
  required _AgentProgress progress,
}) async {
  if (!service.state.connected) {
    progress('chatroom 已断开，重新连接 world chatroom', {'wid': worldId});
    await service
        .connect(worldId: worldId, identity: identity)
        .timeout(const Duration(seconds: 30));
  }
  if (service.state.joinedLocationId != locationId) {
    progress('重新加入 location chatroom', {'locationId': locationId});
    await service
        .join(locationId: locationId)
        .timeout(const Duration(seconds: 30));
  }
}

Future<WorldChatroomMessage> _sendAgentMessageWithReconnect(
  WorldChatroomService service,
  String text, {
  required String clientMsgId,
  required String worldId,
  required String locationId,
  required ChatroomConnectionIdentity identity,
  required _AgentProgress progress,
}) async {
  late ChatroomSendHandle handle;
  try {
    handle = service.sendMessage(text, clientMsgId: clientMsgId);
    await handle.receipt.timeout(const Duration(seconds: 30));
  } catch (error) {
    if (!_isRetriableAgentReceiptFailure(error)) rethrow;
    service.cancelCanonicalMessageWait(clientMsgId, reason: error);
    progress('发送失败，重连 chatroom 后重试一次', {
      'error': error.toString(),
      'locationId': locationId,
    });
    try {
      await service.disconnect();
    } catch (_) {
      // Reconnect below is the recovery path.
    }
    await _ensureAgentChatroomReady(
      service,
      worldId: worldId,
      locationId: locationId,
      identity: identity,
      progress: progress,
    );
    try {
      handle = service.sendMessage(text, clientMsgId: clientMsgId);
      await handle.receipt.timeout(const Duration(seconds: 30));
    } catch (error) {
      service.cancelCanonicalMessageWait(clientMsgId, reason: error);
      rethrow;
    }
  }
  try {
    try {
      return await handle.canonicalMessage.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      await service.refreshLatestMessages(
        locationId: locationId,
        limit: 60,
        emitLatestFetched: false,
      );
      try {
        return await handle.canonicalMessage.timeout(
          const Duration(seconds: 5),
        );
      } on TimeoutException catch (error) {
        throw AgentControlException(
          code: 'message_echo_timeout',
          message: 'Timed out while waiting for the canonical user message.',
          details: {
            'locationId': locationId,
            'clientMsgId': clientMsgId,
            'cause': error.toString(),
          },
        );
      }
    }
  } finally {
    service.cancelCanonicalMessageWait(clientMsgId);
  }
}

bool _isRetriableAgentReceiptFailure(Object error) {
  if (error is TimeoutException || error is ChatroomProtocolException) {
    return true;
  }
  if (error is! ChatroomFailureEvent) return false;
  final code = error.code.trim().toLowerCase();
  return code == 'ack_timeout' || code.endsWith('_send_failed');
}

@visibleForTesting
bool isRetriableAgentReceiptFailureForTesting(Object error) =>
    _isRetriableAgentReceiptFailure(error);

Future<WorldChatroomMessage> _waitForAgentReply(
  WorldChatroomService service,
  WorldChatroomMessage sentMessage, {
  required String locationId,
  required ChatroomConnectionIdentity identity,
  required Duration timeout,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final reply = _findReplyMessage(
      service.state.messagesByLocation[locationId] ??
          const <WorldChatroomMessage>[],
      sentMessage,
      identity,
    );
    if (reply != null) return reply;

    await service.refreshLatestMessages(
      locationId: locationId,
      limit: 60,
      emitLatestFetched: false,
    );
    final refreshed = _findReplyMessage(
      service.state.messagesByLocation[locationId] ??
          const <WorldChatroomMessage>[],
      sentMessage,
      identity,
    );
    if (refreshed != null) return refreshed;
    await Future<void>.delayed(const Duration(seconds: 2));
  }
  throw AgentControlException(
    code: 'reply_timeout',
    message: 'Timed out while waiting for an AI reply.',
    details: {
      'locationId': locationId,
      'conversationRoundId': sentMessage.conversationRoundId,
      'timeoutSeconds': timeout.inSeconds,
    },
  );
}

WorldChatroomMessage? _findReplyMessage(
  List<WorldChatroomMessage> messages,
  WorldChatroomMessage sentMessage,
  ChatroomConnectionIdentity identity,
) {
  final candidates = messages
      .where((message) {
        if (message.conversationRoundId != sentMessage.conversationRoundId) {
          return false;
        }
        if (message.streaming) return false;
        if (message.content.trim().isEmpty) return false;
        final senderType = message.senderType.trim().toLowerCase();
        if (senderType == 'user') return false;
        if (message.senderId.trim() == identity.senderId.trim()) return false;
        if (message.userId.trim() == identity.userId.trim()) return false;
        return true;
      })
      .toList(growable: false);
  if (candidates.isEmpty) return null;
  candidates.sort((a, b) => a.messageId.compareTo(b.messageId));
  return candidates.last;
}
