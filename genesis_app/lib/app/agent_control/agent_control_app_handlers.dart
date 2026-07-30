part of 'agent_control_registry.dart';

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
    await GenesisHttp2CacheManager().emptyCache();
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
