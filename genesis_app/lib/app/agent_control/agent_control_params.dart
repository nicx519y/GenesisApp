part of 'agent_control_registry.dart';

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
