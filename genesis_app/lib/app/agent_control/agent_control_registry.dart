import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../network/chatroom/chatroom_connection_controller.dart';
import '../../network/chatroom/chatroom_models.dart';
import '../../network/chatroom/world_chatroom_service.dart';
import '../../network/models/world.dart';
import '../../platform/app/app_metadata_service.dart';
import '../../routers/app_router.dart';
import '../bootstrap/app_services_scope.dart';
import '../bootstrap/service_registry.dart';
import '../config/app_config.dart';
import '../config/app_endpoint_overrides.dart';
import '../debug/location_chat_debug_hub.dart';
import '../debug_page_tracker.dart';
import '../genesis_navigator.dart';
import 'agent_control_models.dart';

typedef AgentControlHandler =
    FutureOr<Object?> Function(
      AgentControlContext context,
      AgentControlRequest request,
    );
typedef _AgentProgress =
    void Function(String goal, Map<String, Object?> details);
typedef _AgentCancelled = bool Function();

class AgentControlContext {
  const AgentControlContext({required this.services});

  final AppServices services;

  NavigatorState? get navigator => genesisNavigatorKey.currentState;

  Map<String, Object?> appState() {
    return {
      'route': genesisCurrentRouteName.value,
      'page': genesisCurrentPageClassName.value,
      'buildMode': _buildModeLabel,
      'agentControlEnabled': services.config.agentControlEnabled,
      'agentControlPort': services.config.agentControlPort,
      'apiBaseUrl': services.config.apiBaseUrl,
      'gatewayApiBaseUrl': services.config.gatewayApiBaseUrl,
      'chatroomHttpBaseUrl': services.config.chatroomHttpBaseUrl,
      'chatroomWsBaseUrl': services.config.chatroomWsBaseUrl,
    };
  }
}

class AgentControlRegistry {
  AgentControlRegistry({Map<String, AgentControlHandler>? handlers})
    : _handlers = {..._defaultHandlers, ...?handlers};

  final Map<String, AgentControlHandler> _handlers;

  Future<AgentControlResponse> execute(
    AgentControlRequest request,
    AgentControlContext context,
  ) async {
    final handler = _handlers[request.method];
    if (handler == null) {
      return _failure(
        request,
        context,
        const AgentControlException(
          code: 'unknown_method',
          message: 'Unknown agent control method.',
        ),
      );
    }
    try {
      final result = await Future<Object?>.sync(
        () => handler(context, request),
      ).timeout(Duration(milliseconds: request.timeoutMs));
      return AgentControlResponse(
        id: request.id,
        ok: true,
        result: result,
        appState: context.appState(),
      );
    } on TimeoutException {
      return _failure(
        request,
        context,
        AgentControlException(
          code: 'timeout',
          message: 'Command timed out after ${request.timeoutMs}ms.',
        ),
      );
    } on AgentControlException catch (error) {
      return _failure(request, context, error);
    } catch (error) {
      return _failure(
        request,
        context,
        AgentControlException(
          code: 'command_failed',
          message: error.toString(),
        ),
      );
    }
  }

  AgentControlResponse _failure(
    AgentControlRequest request,
    AgentControlContext context,
    AgentControlException error,
  ) {
    return AgentControlResponse(
      id: request.id,
      ok: false,
      error: error.toJson(),
      appState: context.appState(),
    );
  }
}

final Map<String, AgentControlHandler> _defaultHandlers = {
  'app.ping': _ping,
  'app.state': _state,
  'app.navigate': _navigate,
  'app.back': _back,
  'auth.state': _authState,
  'auth.clear': _authClear,
  'world.locations': _worldLocations,
  'agent.world_chat': _agentWorldChat,
  'agent.world_chat.open': _agentWorldChatOpen,
  'agent.world_chat.send': _agentWorldChatSend,
  'agent.world_chat.start': _agentWorldChatStart,
  'agent.world_chat.status': _agentWorldChatStatus,
  'agent.world_chat.cancel': _agentWorldChatCancel,
  'config.endpoint.set': _setEndpoint,
  'config.endpoint.clear': _clearEndpoint,
  'cache.clear': _clearCache,
  'diagnostics.snapshot': _diagnosticsSnapshot,
  if (LocationChatDebugHub.available) ...{
    'debug.locationChat.snapshot': _locationChatDebugSnapshot,
    'debug.locationChat.events': _locationChatDebugEvents,
    'debug.locationChat.clear': _locationChatDebugClear,
  },
};

final Map<String, _AgentJob> _agentJobs = <String, _AgentJob>{};

Future<Map<String, Object?>> _ping(
  AgentControlContext context,
  AgentControlRequest request,
) async {
  return {'message': 'pong'};
}

Future<Map<String, Object?>> _state(
  AgentControlContext context,
  AgentControlRequest request,
) async {
  final uid = await context.services.sessionStore.readUid();
  final token = await context.services.sessionStore.readAuthToken();
  return {
    ...context.appState(),
    'uid': _redactedValue(uid),
    'hasAuthToken': token?.trim().isNotEmpty == true,
  };
}

Future<Map<String, Object?>> _navigate(
  AgentControlContext context,
  AgentControlRequest request,
) async {
  final route = _requiredString(request.params, const ['route', 'name']);
  if (!_allowedRoutes.contains(route)) {
    throw AgentControlException(
      code: 'route_not_allowed',
      message: 'Route is not allowed for agent control.',
      details: {'route': route},
    );
  }
  final arguments =
      _mapParam(request.params['arguments']) ?? _routeArguments(request.params);
  if (request.dryRun) {
    return {'route': route, 'arguments': arguments, 'dryRun': true};
  }
  final navigator = context.navigator;
  if (navigator == null) {
    throw const AgentControlException(
      code: 'navigator_unavailable',
      message: 'Navigator is not available yet.',
    );
  }
  final clearStack = _boolParam(request.params['clearStack']);
  final replace = _boolParam(request.params['replace']);
  if (clearStack) {
    unawaited(
      navigator.pushNamedAndRemoveUntil(
        route,
        (_) => false,
        arguments: arguments,
      ),
    );
  } else if (replace) {
    unawaited(navigator.pushReplacementNamed(route, arguments: arguments));
  } else {
    unawaited(navigator.pushNamed(route, arguments: arguments));
  }
  await Future<void>.delayed(Duration.zero);
  return {'route': route, 'arguments': arguments};
}

Future<Map<String, Object?>> _back(
  AgentControlContext context,
  AgentControlRequest request,
) async {
  if (request.dryRun) return {'canPop': context.navigator?.canPop() ?? false};
  final navigator = context.navigator;
  if (navigator == null) {
    throw const AgentControlException(
      code: 'navigator_unavailable',
      message: 'Navigator is not available yet.',
    );
  }
  final didPop = await navigator.maybePop();
  return {'didPop': didPop};
}

Future<Map<String, Object?>> _authState(
  AgentControlContext context,
  AgentControlRequest request,
) async {
  final uid = await context.services.sessionStore.readUid();
  final token = await context.services.sessionStore.readAuthToken();
  return {
    'uid': _redactedValue(uid),
    'hasUid': uid?.trim().isNotEmpty == true,
    'hasAuthToken': token?.trim().isNotEmpty == true,
  };
}

Future<Map<String, Object?>> _authClear(
  AgentControlContext context,
  AgentControlRequest request,
) async {
  if (!request.dryRun) {
    await context.services.sessionStore.clearUid();
    context.services.notifySessionChanged();
  }
  return {'cleared': !request.dryRun, 'dryRun': request.dryRun};
}

Future<Map<String, Object?>> _worldLocations(
  AgentControlContext context,
  AgentControlRequest request,
) async {
  final wid = _requiredString(request.params, const ['wid', 'world_id']);
  final world = await context.services.api.getWorld(wid);
  final locations = _worldLocationRows(world);
  final leafLocations = locations
      .where((location) => location['isLeafLocation'] == true)
      .toList(growable: false);
  final firstLeafLocationId = leafLocations.isEmpty
      ? ''
      : leafLocations.first['locationId']?.toString() ?? '';
  return {
    'wid': wid,
    'worldId': world.worldId,
    'worldName': world.name,
    'locationCount': locations.length,
    'leafLocationCount': leafLocations.length,
    'firstLeafLocationId': firstLeafLocationId,
    'locations': locations,
  };
}

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
    final ack = await _sendAgentMessageWithReconnect(
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
      ack,
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
      'ackMessageId': ack.messageId,
      'conversationRoundId': ack.conversationRoundId,
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
      progress('发送消息并等待 ack', {
        'turn': index + 1,
        'total': messageCount,
        'message': _messageExcerpt(text, limit: 80),
      });
      final ack = await _sendAgentMessageWithReconnect(
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
        'conversationRoundId': ack.conversationRoundId,
      });
      final reply = await _waitForAgentReply(
        chatroom,
        ack,
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
        'ackMessageId': ack.messageId,
        'conversationRoundId': ack.conversationRoundId,
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
        progress('在当前 location 发送消息并等待 ack', {
          'turn': globalTurn,
          'locationTurn': turn + 1,
          'total': messageCount,
          'locationId': locationId,
          'message': _messageExcerpt(text, limit: 80),
        });
        final ack = await _sendAgentMessageWithReconnect(
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
          ack,
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
          'ackMessageId': ack.messageId,
          'conversationRoundId': ack.conversationRoundId,
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

Future<Map<String, Object?>> _setEndpoint(
  AgentControlContext context,
  AgentControlRequest request,
) async {
  final apiInput = _optionalString(request.params, const ['api', 'apiBaseUrl']);
  final gatewayInput = _optionalString(request.params, const [
    'gateway',
    'gatewayApiBaseUrl',
  ]);
  final chatWsInput = _optionalString(request.params, const [
    'chatWs',
    'chatroomWsBaseUrl',
  ]);
  final overrides = AppEndpointOverrides(
    apiBaseUrl: AppEndpointOverrideStore.normalizeHttpsApiBaseUrl(
      apiInput ?? '',
    ),
    gatewayApiBaseUrl: AppEndpointOverrideStore.normalizeHttpsGatewayApiBaseUrl(
      gatewayInput ?? apiInput ?? '',
    ),
    chatroomHttpBaseUrl: AppEndpointOverrideStore.normalizeHttpsBaseUrl(
      apiInput ?? '',
    ),
    chatroomWsBaseUrl: AppEndpointOverrideStore.normalizeWssBaseUrl(
      chatWsInput ?? gatewayInput ?? apiInput ?? '',
    ),
  );
  if (!overrides.hasAny) {
    throw const AgentControlException(
      code: 'invalid_endpoint',
      message: 'At least one endpoint value is required.',
    );
  }
  if (!request.dryRun) {
    final appContext = genesisNavigatorKey.currentContext;
    if (appContext == null) {
      throw const AgentControlException(
        code: 'context_unavailable',
        message: 'App context is not available yet.',
      );
    }
    await AppEndpointOverrideStore.save(overrides);
    if (!appContext.mounted) {
      throw const AgentControlException(
        code: 'context_unavailable',
        message: 'App context is no longer available.',
      );
    }
    AppServicesScope.replaceWithConfig(
      appContext,
      overrides.applyTo(const AppConfig()),
    );
  }
  return _endpointResult(overrides, dryRun: request.dryRun);
}

Future<Map<String, Object?>> _clearEndpoint(
  AgentControlContext context,
  AgentControlRequest request,
) async {
  if (!request.dryRun) {
    final appContext = genesisNavigatorKey.currentContext;
    if (appContext == null) {
      throw const AgentControlException(
        code: 'context_unavailable',
        message: 'App context is not available yet.',
      );
    }
    await AppEndpointOverrideStore.clear();
    if (!appContext.mounted) {
      throw const AgentControlException(
        code: 'context_unavailable',
        message: 'App context is no longer available.',
      );
    }
    AppServicesScope.replaceWithConfig(appContext, const AppConfig());
  }
  return {'cleared': !request.dryRun, 'dryRun': request.dryRun};
}

Future<Map<String, Object?>> _clearCache(
  AgentControlContext context,
  AgentControlRequest request,
) async {
  final target = _optionalString(request.params, const ['target']) ?? 'all';
  if (!_cacheTargets.contains(target)) {
    throw AgentControlException(
      code: 'cache_target_not_allowed',
      message: 'Cache target is not allowed.',
      details: {'target': target},
    );
  }
  if (request.dryRun) return {'target': target, 'dryRun': true};
  if (target == 'all' || target == 'image') {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    await CachedNetworkImageProvider.defaultCacheManager.emptyCache();
  }
  if (target == 'all' || target == 'directMessage') {
    await context.services.directMessageConversations.clearCache();
    await context.services.directMessageMessages.clearCache();
  }
  return {'target': target, 'cleared': true};
}

Future<Map<String, Object?>> _diagnosticsSnapshot(
  AgentControlContext context,
  AgentControlRequest request,
) async {
  final uid = await context.services.sessionStore.readUid();
  final token = await context.services.sessionStore.readAuthToken();
  final appVersion = await AppMetadataService.appVersion();
  return {
    ...context.appState(),
    'version': appVersion.versionName,
    'uid': _redactedValue(uid),
    'hasAuthToken': token?.trim().isNotEmpty == true,
  };
}

Future<Map<String, Object?>> _locationChatDebugSnapshot(
  AgentControlContext context,
  AgentControlRequest request,
) async {
  return LocationChatDebugHub.snapshot();
}

Future<Map<String, Object?>> _locationChatDebugEvents(
  AgentControlContext context,
  AgentControlRequest request,
) async {
  return LocationChatDebugHub.eventsAfter(
    _intParam(request.params['cursor']),
    limit: _intParam(request.params['limit']),
  );
}

Future<Map<String, Object?>> _locationChatDebugClear(
  AgentControlContext context,
  AgentControlRequest request,
) async {
  LocationChatDebugHub.clear();
  return LocationChatDebugHub.snapshot();
}

Future<void> _ensureAgentLocationChatPage(
  AgentControlContext context, {
  required String worldId,
  required String locationId,
  required Map<String, Object?> arguments,
  required _AgentProgress progress,
}) async {
  final current = _currentAgentLocationChatTarget();
  if (current != null &&
      current.worldId == worldId &&
      current.locationId == locationId) {
    progress('已在目标 LocationChatPage，复用当前页面', {
      'wid': worldId,
      'locationId': locationId,
    });
    await _waitForAgentRouteFrame();
    return;
  }

  if (current != null) {
    progress('退出当前 LocationChatPage 后再切换 location', {
      'previousWid': current.worldId,
      'previousLocationId': current.locationId,
      'nextWid': worldId,
      'nextLocationId': locationId,
    });
    await _leaveLocationChatPage(context, worldId);
  }

  if (!_currentWorldRouteMatches(worldId)) {
    await _navigateToRoute(context, RouteNames.world, {
      'wid': worldId,
    }, clearStack: true);
  }
  await _navigateToRoute(context, RouteNames.locationChat, arguments);
}

Future<void> _navigateToRoute(
  AgentControlContext context,
  String route,
  Map<String, Object?> arguments, {
  bool clearStack = false,
}) async {
  final navigator = context.navigator;
  if (navigator == null) {
    throw const AgentControlException(
      code: 'navigator_unavailable',
      message: 'Navigator is not available yet.',
    );
  }
  if (clearStack) {
    unawaited(
      navigator.pushNamedAndRemoveUntil(
        route,
        (_) => false,
        arguments: arguments,
      ),
    );
  } else {
    unawaited(navigator.pushNamed(route, arguments: arguments));
  }
  await _waitForAgentRouteFrame();
}

Future<void> _waitForAgentRouteFrame() async {
  final binding = WidgetsBinding.instance;
  for (var index = 0; index < 2; index += 1) {
    binding.scheduleFrame();
    await binding.endOfFrame;
  }
  await Future<void>.delayed(const Duration(milliseconds: 150));
}

Future<void> _updateAgentUserPosition(
  AppServices services, {
  required String wid,
  required String locationId,
  required _AgentProgress progress,
}) async {
  progress('更新用户位置到目标 location', {'wid': wid, 'locationId': locationId});
  try {
    await services.api
        .updateUserPosition(wid: wid, locationId: locationId)
        .timeout(const Duration(seconds: 15));
  } catch (error) {
    progress('更新用户位置失败，继续进入 location', {
      'wid': wid,
      'locationId': locationId,
      'error': error.toString(),
    });
  }
}

Future<_AgentWorldChatTarget> _resolveAgentWorldChatTarget(
  AgentControlContext context,
  AgentControlRequest request, {
  required _AgentProgress progress,
}) async {
  final services = context.services;
  progress('检查登录态，auth token 为空则停止并等待人工登录', {});
  final authenticated = await services.api.hasAuthenticatedSession();
  if (authenticated) services.notifySessionChanged();
  await _requireAuthenticatedAgentSession(services);

  final requestedWid = _optionalString(request.params, const [
    'wid',
    'world_id',
  ]);
  if (requestedWid == null) {
    progress('进入首页，确保从 HomePage 开始选择 world', {'route': RouteNames.home});
    await _navigateToRoute(
      context,
      RouteNames.home,
      const <String, Object?>{},
      clearStack: true,
    );
  }
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

  final currentLocationChat = _currentAgentLocationChatTarget();
  if (currentLocationChat == null || currentLocationChat.worldId != wid) {
    progress('先进入 WorldPage', {'wid': wid});
    await _navigateToRoute(context, RouteNames.world, {
      'wid': wid,
    }, clearStack: true);
  }

  progress('在 WorldPage 后拉取 world 详情', {'wid': wid});
  final world = await services.api.getWorld(wid);
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

  return _AgentWorldChatTarget(
    world: world,
    relationBefore: relationBefore,
    locationId: locationId,
    locationName: locationName,
    location: location,
    authenticated: authenticated,
  );
}

Future<_WorldPickResult> _pickHomeWorld(
  AppServices services, {
  required _AgentProgress progress,
}) async {
  progress('查询我的 world 列表', {'scene': 'mine', 'limit': 20});
  final worlds = await services.api.getMyWorlds(scene: 'mine', limit: 20);
  final candidates = worlds
      .where((world) => !world.deleted && world.wid.trim().isNotEmpty)
      .toList(growable: false);
  if (candidates.isNotEmpty) {
    final world = candidates[math.Random().nextInt(candidates.length)];
    progress('从我的 world 列表随机选择 world', {
      'wid': world.wid.trim(),
      'worldName': world.name,
      'candidateCount': candidates.length,
    });
    return _WorldPickResult(wid: world.wid.trim());
  }
  throw const AgentControlException(
    code: 'world_not_found',
    message:
        'No existing my world was found. Launch is disabled for this command.',
  );
}

Future<void> _requireAuthenticatedAgentSession(AppServices services) async {
  final token = (await services.sessionStore.readAuthToken())?.trim() ?? '';
  if (token.isNotEmpty) return;
  final uid = (await services.sessionStore.readUid())?.trim() ?? '';
  throw AgentControlException(
    code: 'auth_required',
    message: 'Auth token is empty. Please log in in the app, then retry.',
    details: {'uid': _redactedValue(uid), 'hasAuthToken': false},
  );
}

bool _isLaunchedRelation(String relation) {
  return relation == 'owner' || relation == 'joined';
}

Map<String, Object?> _chooseLocation(
  List<Map<String, Object?>> locations,
  String? requestedLocationId,
) {
  if (locations.isEmpty) return const <String, Object?>{};
  final requested = requestedLocationId?.trim() ?? '';
  if (requested.isNotEmpty) {
    for (final location in locations) {
      if ((location['locationId']?.toString().trim() ?? '') == requested) {
        return location;
      }
    }
    throw AgentControlException(
      code: 'location_not_found',
      message: 'Requested location was not found in the selected world.',
      details: {'locationId': requested},
    );
  }

  final leaves = locations
      .where((location) => location['isLeafLocation'] == true)
      .toList(growable: false);
  final candidates = leaves.isEmpty ? locations : leaves;
  return candidates[math.Random().nextInt(candidates.length)];
}

List<Map<String, Object?>> _chooseLocations(
  List<Map<String, Object?>> locations,
  String? requestedLocationId,
  int requestedCount,
) {
  if (locations.isEmpty) return const <Map<String, Object?>>[];
  final leaves = locations
      .where((location) => location['isLeafLocation'] == true)
      .toList(growable: false);
  final candidates = (leaves.isEmpty ? locations : leaves)
      .where(
        (location) =>
            (location['locationId']?.toString().trim() ?? '').isNotEmpty,
      )
      .toList(growable: false);
  if (candidates.isEmpty) return const <Map<String, Object?>>[];

  final selected = <Map<String, Object?>>[];
  final seen = <String>{};
  final requested = requestedLocationId?.trim() ?? '';
  if (requested.isNotEmpty) {
    Map<String, Object?>? requestedLocation;
    for (final location in candidates) {
      if ((location['locationId']?.toString().trim() ?? '') == requested) {
        requestedLocation = location;
        break;
      }
    }
    if (requestedLocation == null) {
      throw AgentControlException(
        code: 'location_not_found',
        message: 'Requested location was not found in the selected world.',
        details: {'locationId': requested},
      );
    }
    selected.add(requestedLocation);
    seen.add(requested);
  }

  final shuffled = candidates.toList(growable: false)..shuffle(math.Random());
  for (final location in shuffled) {
    if (selected.length >= requestedCount) break;
    final locationId = location['locationId']?.toString().trim() ?? '';
    if (locationId.isEmpty || !seen.add(locationId)) continue;
    selected.add(location);
  }
  return selected;
}

List<int> _distributedMessageCounts(int messageCount, int locationCount) {
  if (locationCount <= 0) return const <int>[];
  final total = messageCount < 0 ? 0 : messageCount;
  final base = total ~/ locationCount;
  var remainder = total % locationCount;
  return [
    for (var index = 0; index < locationCount; index += 1)
      base + (remainder-- > 0 ? 1 : 0),
  ];
}

Map<String, Object?> _agentLocationChatArgs(
  WorldDetail world,
  Map<String, Object?> location,
) {
  final locationId = location['locationId']?.toString().trim() ?? '';
  final locationName = location['locationName']?.toString().trim() ?? '';
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
  return chatArgs;
}

Future<void> _leaveLocationChatPage(
  AgentControlContext context,
  String worldId,
) async {
  final navigator = context.navigator;
  if (navigator == null) {
    throw const AgentControlException(
      code: 'navigator_unavailable',
      message: 'Navigator is not available yet.',
    );
  }

  for (var popCount = 0; popCount < 8; popCount += 1) {
    if (_currentAgentLocationChatTarget() == null) return;
    final didPop = await navigator.maybePop();
    if (!didPop) break;
    await _waitForAgentRouteFrame();
  }

  if (_currentAgentLocationChatTarget() != null) {
    await _navigateToRoute(context, RouteNames.world, {
      'wid': worldId,
    }, clearStack: true);
  }
}

Future<ChatroomConnectionIdentity> _agentChatroomIdentity(
  AppServices services,
) async {
  final uid = (await services.sessionStore.readUid())?.trim() ?? '';
  final userInfo = await services.sessionStore.readUserInfo();
  final profile = services.identityAuth.currentProfile();
  final senderId = _firstNonEmpty([
    uid,
    _jsonString(userInfo, const ['uid', 'id']),
    profile?.uid,
    'local-user',
  ]);
  final senderName = _firstNonEmpty([
    profile?.displayName,
    profile?.email,
    _jsonString(userInfo, const ['display_name', 'nickname', 'name']),
    senderId == 'local-user'
        ? null
        : 'User ${_messageExcerpt(senderId, limit: 6)}',
    'Me',
  ]);
  return ChatroomConnectionIdentity(
    userId: senderId,
    senderId: senderId,
    senderName: senderName,
  );
}

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

Future<ChatroomAck> _sendAgentMessageWithReconnect(
  WorldChatroomService service,
  String text, {
  required String clientMsgId,
  required String worldId,
  required String locationId,
  required ChatroomConnectionIdentity identity,
  required _AgentProgress progress,
}) async {
  try {
    return await service
        .sendMessage(text, clientMsgId: clientMsgId)
        .timeout(const Duration(seconds: 30));
  } catch (error) {
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
    return service
        .sendMessage(text, clientMsgId: clientMsgId)
        .timeout(const Duration(seconds: 30));
  }
}

Future<WorldChatroomMessage> _waitForAgentReply(
  WorldChatroomService service,
  ChatroomAck ack, {
  required String locationId,
  required ChatroomConnectionIdentity identity,
  required Duration timeout,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final reply = _findReplyMessage(
      service.state.messagesByLocation[locationId] ??
          const <WorldChatroomMessage>[],
      ack,
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
      ack,
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
      'conversationRoundId': ack.conversationRoundId,
      'timeoutSeconds': timeout.inSeconds,
    },
  );
}

WorldChatroomMessage? _findReplyMessage(
  List<WorldChatroomMessage> messages,
  ChatroomAck ack,
  ChatroomConnectionIdentity identity,
) {
  final candidates = messages
      .where((message) {
        if (message.conversationRoundId != ack.conversationRoundId) {
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

Map<String, Object?> _endpointResult(
  AppEndpointOverrides overrides, {
  required bool dryRun,
}) {
  return {
    'dryRun': dryRun,
    'apiBaseUrl': overrides.apiBaseUrl,
    'gatewayApiBaseUrl': overrides.gatewayApiBaseUrl,
    'chatroomHttpBaseUrl': overrides.chatroomHttpBaseUrl,
    'chatroomWsBaseUrl': overrides.chatroomWsBaseUrl,
  };
}

Map<String, Object?>? _mapParam(Object? value) {
  if (value is! Map) return null;
  return Map<String, Object?>.from(value);
}

Map<String, Object?> _routeArguments(Map<String, Object?> params) {
  final args = <String, Object?>{};
  for (final entry in params.entries) {
    if (_reservedNavigateParams.contains(entry.key)) continue;
    args[entry.key] = entry.value;
  }
  return args;
}

String _requiredString(Map<String, Object?> params, List<String> keys) {
  final value = _optionalString(params, keys);
  if (value != null) return value;
  throw AgentControlException(
    code: 'missing_param',
    message: '${keys.first} is required.',
  );
}

String? _optionalString(Map<String, Object?> params, List<String> keys) {
  for (final key in keys) {
    final text = params[key]?.toString().trim() ?? '';
    if (text.isNotEmpty) return text;
  }
  return null;
}

_AgentLocationChatPageTarget? _currentAgentLocationChatTarget() {
  return _agentLocationChatTargetFrom(
    genesisCurrentRouteName.value,
    genesisCurrentRouteArguments.value,
  );
}

_AgentLocationChatPageTarget? _agentLocationChatTargetFrom(
  String routeName,
  Object? routeArguments,
) {
  if (routeName != RouteNames.locationChat) return null;
  final args = _mapParam(routeArguments);
  if (args == null) return null;
  final worldId = _optionalString(args, const ['wid', 'world_id', 'worldId']);
  final locationId = _optionalString(args, const [
    'location_id',
    'locationId',
    'scene_id',
    'sceneId',
    'point_id',
    'pointId',
  ]);
  if (worldId == null || locationId == null) return null;
  return _AgentLocationChatPageTarget(worldId: worldId, locationId: locationId);
}

bool _currentWorldRouteMatches(String worldId) {
  if (genesisCurrentRouteName.value != RouteNames.world) return false;
  final args = _mapParam(genesisCurrentRouteArguments.value);
  if (args == null) return false;
  return _optionalString(args, const ['wid', 'world_id', 'worldId']) == worldId;
}

@visibleForTesting
bool agentControlShouldReuseLocationChatPageForTesting({
  required String currentRouteName,
  required Object? currentRouteArguments,
  required String worldId,
  required String locationId,
}) {
  final current = _agentLocationChatTargetFrom(
    currentRouteName,
    currentRouteArguments,
  );
  return current != null &&
      current.worldId == worldId.trim() &&
      current.locationId == locationId.trim();
}

bool _boolParam(Object? value) {
  if (value is bool) return value;
  final text = value?.toString().trim().toLowerCase() ?? '';
  return text == 'true' || text == '1' || text == 'yes';
}

int _intParam(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString().trim() ?? '') ?? 0;
}

String? _redactedValue(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  if (text.length <= 8) return '***';
  return '${text.substring(0, 4)}...${text.substring(text.length - 4)}';
}

String _firstNonEmpty(List<String?> values) {
  for (final value in values) {
    final text = value?.trim() ?? '';
    if (text.isNotEmpty) return text;
  }
  return '';
}

String _jsonString(Map<String, dynamic>? map, List<String> keys) {
  if (map == null) return '';
  return _worldMapString(map, keys);
}

String _messageExcerpt(String value, {required int limit}) {
  final text = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (text.length <= limit) return text;
  return '${text.substring(0, limit)}...';
}

List<Map<String, Object?>> _worldLocationRows(dynamic world) {
  final nodes = world.processedLocationTree.flattened;
  if (nodes.isNotEmpty) {
    return [
      for (final node in nodes)
        if (node.id.toString().trim().isNotEmpty)
          _worldLocationRow(
            node.value,
            locationId: node.id.toString().trim(),
            parentId: node.parentId.toString().trim(),
            depth: node.depth,
            isLeafLocation: node.children.isEmpty,
          ),
    ];
  }

  final locations = world.locations as List<Map<String, dynamic>>;
  final parentIds = locations
      .map((location) => _worldMapString(location, const ['location_pid']))
      .where((locationId) => locationId.isNotEmpty)
      .toSet();
  return [
    for (final location in locations)
      if (_worldMapString(location, const ['location_id', 'id']).isNotEmpty)
        _worldLocationRow(
          location,
          locationId: _worldMapString(location, const ['location_id', 'id']),
          parentId: _worldMapString(location, const ['location_pid']),
          depth: 0,
          isLeafLocation: !parentIds.contains(
            _worldMapString(location, const ['location_id', 'id']),
          ),
        ),
  ];
}

Map<String, Object?> _worldLocationRow(
  Map<String, dynamic> location, {
  required String locationId,
  required String parentId,
  required int depth,
  required bool isLeafLocation,
}) {
  final pointId = _worldMapString(location, const ['point_id']);
  return {
    'locationId': locationId,
    'locationName': _worldMapString(location, const [
      'location_name',
      'name',
    ], fallback: locationId),
    'parentId': parentId,
    'pointId': pointId,
    'depth': depth,
    'isLeafLocation': isLeafLocation,
    'localMessageLocationIds': _orderedNonEmptyStrings([
      pointId,
      locationId,
      _worldMapString(location, const ['location_id', 'id']),
    ]),
  };
}

String _worldMapString(
  Map<String, dynamic> map,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final value = map[key];
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) return text;
  }
  return fallback;
}

List<String> _orderedNonEmptyStrings(Iterable<String> values) {
  final seen = <String>{};
  final result = <String>[];
  for (final value in values) {
    final text = value.trim();
    if (text.isEmpty || !seen.add(text)) continue;
    result.add(text);
  }
  return result;
}

const _buildModeLabel = kReleaseMode
    ? 'release'
    : kProfileMode
    ? 'profile'
    : 'debug';

const Set<String> _allowedRoutes = {
  RouteNames.home,
  RouteNames.origin,
  RouteNames.originWorld,
  RouteNames.discuss,
  RouteNames.world,
  RouteNames.chat,
  RouteNames.locationChat,
  RouteNames.search,
  RouteNames.create,
  RouteNames.edit,
  RouteNames.messages,
  RouteNames.me,
  RouteNames.notifications,
  RouteNames.newFollowers,
  RouteNames.comments,
  RouteNames.userInfo,
  RouteNames.follows,
  RouteNames.legal,
  RouteNames.shell,
};

const Set<String> _reservedNavigateParams = {
  'route',
  'name',
  'arguments',
  'replace',
  'clearStack',
};

const Set<String> _cacheTargets = {'all', 'image', 'directMessage'};

class _WorldPickResult {
  const _WorldPickResult({required this.wid});

  final String wid;
}

class _AgentWorldChatTarget {
  const _AgentWorldChatTarget({
    required this.world,
    required this.relationBefore,
    required this.locationId,
    required this.locationName,
    required this.location,
    required this.authenticated,
  });

  final WorldDetail world;
  final String relationBefore;
  final String locationId;
  final String locationName;
  final Map<String, Object?> location;
  final bool authenticated;
}

class _AgentLocationChatPageTarget {
  const _AgentLocationChatPageTarget({
    required this.worldId,
    required this.locationId,
  });

  final String worldId;
  final String locationId;
}

void _ignoreAgentProgress(String goal, Map<String, Object?> details) {}

void _throwIfAgentCancelled(_AgentCancelled isCancelled) {
  if (!isCancelled()) return;
  throw const AgentControlException(
    code: 'cancelled',
    message: 'Agent job was cancelled.',
  );
}

class _AgentJob {
  _AgentJob(this.jobId);

  final String jobId;
  final List<Map<String, Object?>> logs = <Map<String, Object?>>[];
  bool cancelled = false;
  bool completed = false;
  Object? result;
  Map<String, Object?>? error;

  String get status {
    if (cancelled && !completed) return 'cancelling';
    if (error != null) return 'failed';
    if (completed) return 'completed';
    return 'running';
  }

  void addLog(String goal, Map<String, Object?> details) {
    logs.add({
      'seq': logs.length + 1,
      'time': DateTime.now().toIso8601String(),
      'goal': goal,
      'details': details,
    });
  }

  void complete(Object? value) {
    result = value;
    completed = true;
    addLog('任务完成', {});
  }

  void fail(Object errorObject) {
    completed = true;
    error = _agentJobError(errorObject);
    addLog('任务失败', {'error': error?['message'] ?? errorObject.toString()});
  }

  void cancel() {
    cancelled = true;
    addLog('收到取消请求', {});
  }

  Map<String, Object?> toJson({required int afterSeq}) {
    return {
      'jobId': jobId,
      'status': status,
      'cancelled': cancelled,
      'completed': completed,
      'logs': logs
          .where((entry) => (entry['seq'] as int? ?? 0) > afterSeq)
          .toList(growable: false),
      if (result != null) 'result': result,
      if (error != null) 'error': error,
    };
  }
}

Map<String, Object?> _agentJobError(Object error) {
  if (error is AgentControlException) return error.toJson();
  return {'code': 'command_failed', 'message': error.toString()};
}
