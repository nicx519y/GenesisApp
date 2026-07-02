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
  final seedMessage = _optionalString(request.params, const ['seedMessage']);
  progress('准备自动聊天参数', {
    'messageCount': messageCount,
    'replyTimeoutSeconds': replyTimeoutSeconds,
  });

  if (request.dryRun) {
    return {
      'dryRun': true,
      'messageCount': messageCount,
      'replyTimeoutSeconds': replyTimeoutSeconds,
    };
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
  progress('进入 LocationChatPage', {
    'wid': world.worldId,
    'locationId': locationId,
    'locationName': locationName,
  });
  await _navigateToRoute(context, RouteNames.locationChat, chatArgs);

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
  await Future<void>.delayed(Duration.zero);
}

Future<_WorldPickResult> _pickHomeWorld(
  AppServices services, {
  required _AgentProgress progress,
}) async {
  progress('查询我的 world 列表', {'scene': 'mine', 'limit': 20});
  final worlds = await services.api.getMyWorlds(scene: 'mine', limit: 20);
  for (final world in worlds) {
    if (!world.deleted && world.wid.trim().isNotEmpty) {
      progress('从我的 world 列表选择 world', {
        'wid': world.wid.trim(),
        'worldName': world.name,
      });
      return _WorldPickResult(wid: world.wid.trim());
    }
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
  required String? seedMessage,
}) {
  if (turn == 1) {
    final seed = seedMessage?.trim() ?? '';
    if (seed.isNotEmpty) return seed;
    return 'Turn $turn: I have arrived at $locationName in ${world.name}. What should I notice first?';
  }
  final context = _messageExcerpt(lastReply, limit: 120);
  return 'Turn $turn: Based on your last reply "$context", continue the scene and tell me what I should do or ask next.';
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
