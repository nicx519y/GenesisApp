part of 'agent_control_registry.dart';

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
  if (clearStack && route == RouteNames.world) {
    openWorldFromMyWorldsRoot(navigator, arguments: arguments);
  } else if (clearStack) {
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
  final senderId = _firstNonEmpty([
    uid,
    _jsonString(userInfo, const ['uid', 'id']),
    'local-user',
  ]);
  final senderName = _firstNonEmpty([
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
