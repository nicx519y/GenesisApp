part of 'agent_control_registry.dart';

Future<Map<String, Object?>> _agentWorldChat(
  AgentControlContext context,
  AgentControlRequest request,
) async {
  return _runAgentWorldChat(
    context,
    request,
    progress: _ignoreAgentProgress,
    isCancelled: () => false,
  );
}

Future<Map<String, Object?>> _agentWorldChatStart(
  AgentControlContext context,
  AgentControlRequest request,
) async {
  final jobId = 'job-${DateTime.now().microsecondsSinceEpoch}';
  final job = _AgentJob(jobId);
  _agentJobs[jobId] = job;
  unawaited(
    _runAgentWorldChat(
      context,
      request,
      progress: job.addLog,
      isCancelled: () => job.cancelled,
    ).then(job.complete).catchError((Object error) {
      job.fail(error);
    }),
  );
  return {'jobId': jobId, 'status': 'running'};
}

Future<Map<String, Object?>> _agentWorldChatStatus(
  AgentControlContext context,
  AgentControlRequest request,
) async {
  final jobId = _requiredString(request.params, const ['jobId', 'job_id']);
  final afterSeq = _intParam(request.params['afterSeq']);
  final job = _agentJobs[jobId];
  if (job == null) {
    throw AgentControlException(
      code: 'job_not_found',
      message: 'Agent job was not found.',
      details: {'jobId': jobId},
    );
  }
  return job.toJson(afterSeq: afterSeq);
}

Future<Map<String, Object?>> _agentWorldChatCancel(
  AgentControlContext context,
  AgentControlRequest request,
) async {
  final jobId = _requiredString(request.params, const ['jobId', 'job_id']);
  final job = _agentJobs[jobId];
  if (job == null) {
    throw AgentControlException(
      code: 'job_not_found',
      message: 'Agent job was not found.',
      details: {'jobId': jobId},
    );
  }
  job.cancel();
  return {'jobId': jobId, 'cancelled': true};
}

Future<Map<String, Object?>> _agentWorldChatOpen(
  AgentControlContext context,
  AgentControlRequest request,
) async {
  final contextLimit = _intParam(request.params['contextLimit']) <= 0
      ? 40
      : _intParam(request.params['contextLimit']);
  if (request.dryRun) {
    return {'dryRun': true, 'contextLimit': contextLimit};
  }

  final target = await _resolveAgentWorldChatTarget(
    context,
    request,
    progress: _ignoreAgentProgress,
  );
  final services = context.services;
  final identity = await _agentChatroomIdentity(services);
  final chatroom = WorldChatroomService(
    api: services.api,
    client: services.chatroom,
    messageStorage: services.chatroomMessages,
    refreshInitialSnapshotOnConnect: false,
  );

  try {
    chatroom.applyWorldSnapshot(target.world);
    await chatroom
        .connect(worldId: target.world.worldId, identity: identity)
        .timeout(const Duration(seconds: 30));
    await chatroom
        .join(locationId: target.locationId)
        .timeout(const Duration(seconds: 30));
    await chatroom.refreshLatestMessages(
      locationId: target.locationId,
      limit: contextLimit,
    );
    final messages =
        chatroom.state.messagesByLocation[target.locationId] ??
        const <WorldChatroomMessage>[];
    return {
      ..._agentWorldChatTargetJson(target),
      'contextLimit': contextLimit,
      'queueContext': _agentQueueContext(messages),
      'messages': _agentMessageContextRows(messages),
    };
  } finally {
    try {
      await chatroom.disconnect();
    } catch (_) {
      // The context result should not be hidden by socket shutdown errors.
    }
    await chatroom.dispose();
  }
}

Future<Map<String, Object?>> _agentWorldChatSend(
  AgentControlContext context,
  AgentControlRequest request,
) async {
  final text = _requiredString(request.params, const ['message', 'text']);
  final replyTimeoutSeconds =
      _intParam(request.params['replyTimeoutSeconds']) <= 0
      ? 120
      : _intParam(request.params['replyTimeoutSeconds']);
  final contextLimit = _intParam(request.params['contextLimit']) <= 0
      ? 60
      : _intParam(request.params['contextLimit']);
  if (request.dryRun) {
    return {
      'dryRun': true,
      'message': _messageExcerpt(text, limit: 120),
      'replyTimeoutSeconds': replyTimeoutSeconds,
      'contextLimit': contextLimit,
    };
  }

  final target = await _resolveAgentWorldChatTarget(
    context,
    request,
    progress: _ignoreAgentProgress,
  );
  final services = context.services;
  final identity = await _agentChatroomIdentity(services);
  final chatroom = WorldChatroomService(
    api: services.api,
    client: services.chatroom,
    messageStorage: services.chatroomMessages,
    refreshInitialSnapshotOnConnect: false,
  );

  try {
    chatroom.applyWorldSnapshot(target.world);
    await chatroom
        .connect(worldId: target.world.worldId, identity: identity)
        .timeout(const Duration(seconds: 30));
    await chatroom
        .join(locationId: target.locationId)
        .timeout(const Duration(seconds: 30));
    await chatroom.refreshLatestMessages(
      locationId: target.locationId,
      limit: contextLimit,
    );
    final beforeMessages =
        chatroom.state.messagesByLocation[target.locationId] ??
        const <WorldChatroomMessage>[];
    final clientMsgId = 'agent-manual-${DateTime.now().microsecondsSinceEpoch}';
    final sentMessage = await _sendAgentMessageWithReconnect(
      chatroom,
      text,
      clientMsgId: clientMsgId,
      worldId: target.world.worldId,
      locationId: target.locationId,
      identity: identity,
      progress: _ignoreAgentProgress,
    );
    final reply = await _waitForAgentReply(
      chatroom,
      sentMessage,
      locationId: target.locationId,
      identity: identity,
      timeout: Duration(seconds: replyTimeoutSeconds),
    );
    final afterMessages =
        chatroom.state.messagesByLocation[target.locationId] ??
        const <WorldChatroomMessage>[];
    return {
      ..._agentWorldChatTargetJson(target),
      'replyTimeoutSeconds': replyTimeoutSeconds,
      'contextLimit': contextLimit,
      'sent': _messageExcerpt(text, limit: 240),
      'clientMsgId': clientMsgId,
      'sentMessageId': sentMessage.messageId,
      'conversationRoundId': sentMessage.conversationRoundId,
      'replyMessageId': reply.messageId,
      'replySender': reply.senderName,
      'reply': _messageExcerpt(reply.content, limit: 500),
      'queueContextBefore': _agentQueueContext(beforeMessages),
      'queueContext': _agentQueueContext(afterMessages),
      'messages': _agentMessageContextRows(afterMessages),
    };
  } finally {
    try {
      await chatroom.disconnect();
    } catch (_) {
      // The send result should not be hidden by socket shutdown errors.
    }
    await chatroom.dispose();
  }
}

Future<Map<String, Object?>> _runAgentWorldChat(
  AgentControlContext context,
  AgentControlRequest request, {
  required _AgentProgress progress,
  required _AgentCancelled isCancelled,
}) async {
  final count = _intParam(
    request.params['count'] ?? request.params['messages'],
  );
  final messageCount = count <= 0 ? 100 : count;
  final replyTimeoutSeconds =
      _intParam(request.params['replyTimeoutSeconds']) <= 0
      ? 120
      : _intParam(request.params['replyTimeoutSeconds']);
  final locationCount = _intParam(
    request.params['locationCount'] ?? request.params['locations'],
  );
  final requestedLocationCount = locationCount <= 0 ? 1 : locationCount;
  final seedMessage = _optionalString(request.params, const ['seedMessage']);
  progress('准备自动聊天参数', {
    'messageCount': messageCount,
    'locationCount': requestedLocationCount,
    'replyTimeoutSeconds': replyTimeoutSeconds,
  });

  if (request.dryRun) {
    return {
      'dryRun': true,
      'messageCount': messageCount,
      'locationCount': requestedLocationCount,
      'replyTimeoutSeconds': replyTimeoutSeconds,
    };
  }

  if (requestedLocationCount > 1) {
    return _runAgentWorldChatAcrossLocations(
      context,
      request,
      progress: progress,
      isCancelled: isCancelled,
      messageCount: messageCount,
      requestedLocationCount: requestedLocationCount,
      replyTimeoutSeconds: replyTimeoutSeconds,
      seedMessage: seedMessage,
    );
  }

  _throwIfAgentCancelled(isCancelled);
  progress('进入首页，确保从 HomePage 开始选择 world', {'route': RouteNames.home});
  await _navigateToRoute(
    context,
    RouteNames.home,
    const <String, Object?>{},
    clearStack: true,
  );

  final services = context.services;
  progress('检查登录态，auth token 为空则停止并等待人工登录', {});
  final authenticated = await services.api.hasAuthenticatedSession();
  if (authenticated) services.notifySessionChanged();
  await _requireAuthenticatedAgentSession(services);
  _throwIfAgentCancelled(isCancelled);
  final requestedWid = _optionalString(request.params, const [
    'wid',
    'world_id',
  ]);
  progress('选择要进入的 world', {'requestedWid': requestedWid ?? ''});
  final worldPick = requestedWid == null
      ? await _pickHomeWorld(services, progress: progress)
      : _WorldPickResult(wid: requestedWid);
  final wid = worldPick.wid;
  if (wid.isEmpty) {
    throw const AgentControlException(
      code: 'world_not_found',
      message: 'No world was found from home or my worlds.',
    );
  }

  _throwIfAgentCancelled(isCancelled);
  progress('先进入 WorldPage', {'wid': wid});
  await _navigateToRoute(context, RouteNames.world, {
    'wid': wid,
  }, clearStack: true);

  _throwIfAgentCancelled(isCancelled);
  progress('在 WorldPage 后拉取 world 详情', {'wid': wid});
  var world = await services.api.getWorld(wid);
  final relationBefore = world.relationStatus;
  final relation = relationBefore.trim().toLowerCase();
  progress('确认不执行 launch，仅检查 world 是否可聊天', {
    'wid': world.worldId,
    'worldName': world.name,
    'relationStatus': relationBefore,
    'isProgressing': world.isProgressing,
  });
  if (!_isLaunchedRelation(relation)) {
    throw AgentControlException(
      code: 'world_not_chat_ready',
      message:
          'Selected world is not launched/joined. Launch is disabled for this command.',
      details: {'wid': world.worldId, 'relationStatus': relationBefore},
    );
  }

  final locations = _worldLocationRows(world);
  final requestedLocationId = _optionalString(request.params, const [
    'locationId',
    'location_id',
  ]);
  progress('获取叶子 location 并选择一个进入聊天', {
    'locationCount': locations.length,
    'requestedLocationId': requestedLocationId ?? '',
  });
  final location = _chooseLocation(locations, requestedLocationId);
  final locationId = location['locationId']?.toString().trim() ?? '';
  final locationName = location['locationName']?.toString().trim() ?? '';
  if (locationId.isEmpty) {
    throw AgentControlException(
      code: 'location_not_found',
      message: 'No usable location was found for the selected world.',
      details: {'wid': world.worldId},
    );
  }

  final chatArgs = <String, Object?>{
    'wid': world.worldId,
    'location_id': locationId,
    'worldName': world.name,
    'locationName': locationName,
    'isLeafLocation': location['isLeafLocation'] == true,
  };
  final aliases = location['localMessageLocationIds'];
  if (aliases is List && aliases.isNotEmpty) {
    chatArgs['localMessageLocationIds'] = aliases.join(',');
  }
  await _updateAgentUserPosition(
    services,
    wid: world.worldId,
    locationId: locationId,
    progress: progress,
  );
  progress('进入 LocationChatPage', {
    'wid': world.worldId,
    'locationId': locationId,
    'locationName': locationName,
  });
  await _ensureAgentLocationChatPage(
    context,
    worldId: world.worldId,
    locationId: locationId,
    arguments: chatArgs,
    progress: progress,
  );

  _throwIfAgentCancelled(isCancelled);
  progress('准备 chatroom 身份并连接 websocket', {'locationId': locationId});
  final identity = await _agentChatroomIdentity(services);
  final chatroom = WorldChatroomService(
    api: services.api,
    client: services.chatroom,
    messageStorage: services.chatroomMessages,
    refreshInitialSnapshotOnConnect: false,
  );

  final transcript = <Map<String, Object?>>[];
  var lastReply = '';
  var sentCount = 0;
  try {
    chatroom.applyWorldSnapshot(world);
    progress('连接 world chatroom', {'wid': world.worldId});
    await chatroom
        .connect(worldId: world.worldId, identity: identity)
        .timeout(const Duration(seconds: 30));
    progress('加入 location chatroom', {'locationId': locationId});
    await chatroom
        .join(locationId: locationId)
        .timeout(const Duration(seconds: 30));
    progress('刷新最近消息作为上下文', {'locationId': locationId, 'limit': 40});
    await chatroom.refreshLatestMessages(locationId: locationId, limit: 40);
    var queueContext = _agentQueueContext(
      chatroom.state.messagesByLocation[locationId] ??
          const <WorldChatroomMessage>[],
    );

    for (var index = 0; index < messageCount; index += 1) {
      _throwIfAgentCancelled(isCancelled);
      await _ensureAgentChatroomReady(
        chatroom,
        worldId: world.worldId,
        locationId: locationId,
        identity: identity,
        progress: progress,
      );
      final text = _agentMessageForTurn(
        turn: index + 1,
        world: world,
        locationName: locationName,
        lastReply: lastReply,
        queueContext: queueContext,
        seedMessage: seedMessage,
      );
      final clientMsgId =
          'agent-${DateTime.now().microsecondsSinceEpoch}-$index';
      progress('发送消息并等待确认与正式回声', {
        'turn': index + 1,
        'total': messageCount,
        'message': _messageExcerpt(text, limit: 80),
      });
      final sentMessage = await _sendAgentMessageWithReconnect(
        chatroom,
        text,
        clientMsgId: clientMsgId,
        worldId: world.worldId,
        locationId: locationId,
        identity: identity,
        progress: progress,
      );
      sentCount += 1;
      progress('等待同一轮 AI 回复', {
        'turn': index + 1,
        'total': messageCount,
        'conversationRoundId': sentMessage.conversationRoundId,
      });
      final reply = await _waitForAgentReply(
        chatroom,
        sentMessage,
        locationId: locationId,
        identity: identity,
        timeout: Duration(seconds: replyTimeoutSeconds),
      );
      lastReply = reply.content.trim();
      queueContext = _agentQueueContext(
        chatroom.state.messagesByLocation[locationId] ??
            const <WorldChatroomMessage>[],
      );
      progress('收到 AI 回复，准备下一轮', {
        'turn': index + 1,
        'total': messageCount,
        'replyMessageId': reply.messageId,
        'reply': _messageExcerpt(lastReply, limit: 120),
      });
      transcript.add({
        'turn': index + 1,
        'sent': _messageExcerpt(text, limit: 80),
        'sentMessageId': sentMessage.messageId,
        'conversationRoundId': sentMessage.conversationRoundId,
        'replyMessageId': reply.messageId,
        'replySender': reply.senderName,
        'reply': _messageExcerpt(lastReply, limit: 120),
      });
    }
  } finally {
    try {
      await chatroom.disconnect();
    } catch (_) {
      // The automation result should not be hidden by socket shutdown errors.
    }
    await chatroom.dispose();
  }

  return {
    'wid': world.worldId,
    'worldName': world.name,
    'relationStatusBefore': relationBefore,
    'relationStatusAfter': world.relationStatus,
    'authenticated': authenticated,
    'launchedByAgent': false,
    'launchPolls': 0,
    'locationId': locationId,
    'locationName': locationName,
    'requestedMessageCount': messageCount,
    'sentCount': sentCount,
    'replyCount': transcript.length,
    'lastReply': _messageExcerpt(lastReply, limit: 200),
    'transcriptTail': transcript.length <= 5
        ? transcript
        : transcript.sublist(transcript.length - 5),
  };
}

Future<Map<String, Object?>> _runAgentWorldChatAcrossLocations(
  AgentControlContext context,
  AgentControlRequest request, {
  required _AgentProgress progress,
  required _AgentCancelled isCancelled,
  required int messageCount,
  required int requestedLocationCount,
  required int replyTimeoutSeconds,
  required String? seedMessage,
}) async {
  _throwIfAgentCancelled(isCancelled);
  progress('进入首页，确保从 HomePage 开始选择 world', {'route': RouteNames.home});
  await _navigateToRoute(
    context,
    RouteNames.home,
    const <String, Object?>{},
    clearStack: true,
  );

  final services = context.services;
  progress('检查登录态，auth token 为空则停止并等待人工登录', {});
  final authenticated = await services.api.hasAuthenticatedSession();
  if (authenticated) services.notifySessionChanged();
  await _requireAuthenticatedAgentSession(services);

  _throwIfAgentCancelled(isCancelled);
  final requestedWid = _optionalString(request.params, const [
    'wid',
    'world_id',
  ]);
  progress('选择要进入的 world', {'requestedWid': requestedWid ?? ''});
  final worldPick = requestedWid == null
      ? await _pickHomeWorld(services, progress: progress)
      : _WorldPickResult(wid: requestedWid);
  final wid = worldPick.wid;
  if (wid.isEmpty) {
    throw const AgentControlException(
      code: 'world_not_found',
      message: 'No world was found from home or my worlds.',
    );
  }

  _throwIfAgentCancelled(isCancelled);
  progress('进入 WorldPage，后续在多个 location 间切换', {'wid': wid});
  await _navigateToRoute(context, RouteNames.world, {
    'wid': wid,
  }, clearStack: true);

  progress('拉取 world 详情并检查是否可聊天', {'wid': wid});
  final world = await services.api.getWorld(wid);
  final relationBefore = world.relationStatus;
  final relation = relationBefore.trim().toLowerCase();
  if (!_isLaunchedRelation(relation)) {
    throw AgentControlException(
      code: 'world_not_chat_ready',
      message:
          'Selected world is not launched/joined. Launch is disabled for this command.',
      details: {'wid': world.worldId, 'relationStatus': relationBefore},
    );
  }

  final locations = _worldLocationRows(world);
  final requestedLocationId = _optionalString(request.params, const [
    'locationId',
    'location_id',
  ]);
  final selectedLocations = _chooseLocations(
    locations,
    requestedLocationId,
    requestedLocationCount,
  );
  if (selectedLocations.isEmpty) {
    throw AgentControlException(
      code: 'location_not_found',
      message: 'No usable location was found for the selected world.',
      details: {'wid': world.worldId},
    );
  }
  final perLocationMessageCounts = _distributedMessageCounts(
    messageCount,
    selectedLocations.length,
  );
  progress('已选择多个 location，准备依次进入/退出并发消息', {
    'requestedLocationCount': requestedLocationCount,
    'selectedLocationCount': selectedLocations.length,
    'messageCount': messageCount,
    'locations': [
      for (final location in selectedLocations)
        {
          'locationId': location['locationId'],
          'locationName': location['locationName'],
        },
    ],
  });

  final identity = await _agentChatroomIdentity(services);
  final chatroom = WorldChatroomService(
    api: services.api,
    client: services.chatroom,
    messageStorage: services.chatroomMessages,
    refreshInitialSnapshotOnConnect: false,
  );

  final transcript = <Map<String, Object?>>[];
  var sentCount = 0;
  var replyCount = 0;
  var lastReply = '';
  try {
    chatroom.applyWorldSnapshot(world);
    progress('连接 world chatroom', {'wid': world.worldId});
    await chatroom
        .connect(worldId: world.worldId, identity: identity)
        .timeout(const Duration(seconds: 30));

    for (
      var locationIndex = 0;
      locationIndex < selectedLocations.length;
      locationIndex += 1
    ) {
      _throwIfAgentCancelled(isCancelled);
      final location = selectedLocations[locationIndex];
      final locationId = location['locationId']?.toString().trim() ?? '';
      final locationName = location['locationName']?.toString().trim() ?? '';
      final locationMessageCount = perLocationMessageCounts[locationIndex];

      final previousJoinedLocationId = chatroom.state.joinedLocationId.trim();
      if (previousJoinedLocationId.isNotEmpty &&
          previousJoinedLocationId != locationId) {
        progress('离开上一个 location chatroom', {
          'previousLocationId': previousJoinedLocationId,
          'nextLocationId': locationId,
        });
        try {
          await chatroom.leave().timeout(const Duration(seconds: 15));
        } catch (error) {
          progress('离开上一个 location chatroom 失败，继续切换', {
            'previousLocationId': previousJoinedLocationId,
            'nextLocationId': locationId,
            'error': error.toString(),
          });
        }
      }

      await _updateAgentUserPosition(
        services,
        wid: world.worldId,
        locationId: locationId,
        progress: progress,
      );

      progress('进入 location', {
        'index': locationIndex + 1,
        'total': selectedLocations.length,
        'locationId': locationId,
        'locationName': locationName,
        'messageCount': locationMessageCount,
      });
      await _ensureAgentLocationChatPage(
        context,
        worldId: world.worldId,
        locationId: locationId,
        arguments: _agentLocationChatArgs(world, location),
        progress: progress,
      );
      await _ensureAgentChatroomReady(
        chatroom,
        worldId: world.worldId,
        locationId: locationId,
        identity: identity,
        progress: progress,
      );
      await chatroom.refreshLatestMessages(locationId: locationId, limit: 40);
      var queueContext = _agentQueueContext(
        chatroom.state.messagesByLocation[locationId] ??
            const <WorldChatroomMessage>[],
      );

      for (var turn = 0; turn < locationMessageCount; turn += 1) {
        _throwIfAgentCancelled(isCancelled);
        final globalTurn = sentCount + 1;
        final text = _agentMessageForTurn(
          turn: turn + 1,
          world: world,
          locationName: locationName,
          lastReply: lastReply,
          queueContext: queueContext,
          seedMessage: sentCount == 0 ? seedMessage : null,
        );
        final clientMsgId =
            'agent-${DateTime.now().microsecondsSinceEpoch}-$globalTurn';
        progress('在当前 location 发送消息并等待确认与正式回声', {
          'turn': globalTurn,
          'locationTurn': turn + 1,
          'total': messageCount,
          'locationId': locationId,
          'message': _messageExcerpt(text, limit: 80),
        });
        final sentMessage = await _sendAgentMessageWithReconnect(
          chatroom,
          text,
          clientMsgId: clientMsgId,
          worldId: world.worldId,
          locationId: locationId,
          identity: identity,
          progress: progress,
        );
        sentCount += 1;
        final reply = await _waitForAgentReply(
          chatroom,
          sentMessage,
          locationId: locationId,
          identity: identity,
          timeout: Duration(seconds: replyTimeoutSeconds),
        );
        replyCount += 1;
        lastReply = reply.content.trim();
        queueContext = _agentQueueContext(
          chatroom.state.messagesByLocation[locationId] ??
              const <WorldChatroomMessage>[],
        );
        transcript.add({
          'turn': globalTurn,
          'locationIndex': locationIndex + 1,
          'locationId': locationId,
          'locationName': locationName,
          'sent': _messageExcerpt(text, limit: 80),
          'sentMessageId': sentMessage.messageId,
          'conversationRoundId': sentMessage.conversationRoundId,
          'replyMessageId': reply.messageId,
          'replySender': reply.senderName,
          'reply': _messageExcerpt(lastReply, limit: 120),
        });
      }

      progress('退出 location，回到 WorldPage', {
        'index': locationIndex + 1,
        'total': selectedLocations.length,
        'locationId': locationId,
      });
      await _leaveLocationChatPage(context, world.worldId);
    }
  } finally {
    try {
      await chatroom.disconnect();
    } catch (_) {
      // The automation result should not be hidden by socket shutdown errors.
    }
    await chatroom.dispose();
  }

  return {
    'wid': world.worldId,
    'worldName': world.name,
    'relationStatusBefore': relationBefore,
    'relationStatusAfter': world.relationStatus,
    'authenticated': authenticated,
    'launchedByAgent': false,
    'launchPolls': 0,
    'requestedLocationCount': requestedLocationCount,
    'visitedLocationCount': selectedLocations.length,
    'locations': [
      for (final location in selectedLocations)
        {
          'locationId': location['locationId'],
          'locationName': location['locationName'],
        },
    ],
    'requestedMessageCount': messageCount,
    'sentCount': sentCount,
    'replyCount': replyCount,
    'lastReply': _messageExcerpt(lastReply, limit: 200),
    'transcriptTail': transcript.length <= 5
        ? transcript
        : transcript.sublist(transcript.length - 5),
  };
}
