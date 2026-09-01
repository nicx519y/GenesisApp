part of 'genesis_api.dart';

mixin _GenesisApiWorldOperations on _GenesisApiContext {
  Future<World> launchWorld({
    required int originId,
    String? ownerUid,
    String? worldviewId,
    String? worldName,
  }) async {
    final resolvedUid = ownerUid ?? await _ensureUid();
    final resolvedWorldviewId =
        worldviewId ?? _originIdToWorldview[originId] ?? '$originId';
    final resolvedWorldName = worldName?.trim().isNotEmpty == true
        ? worldName!.trim()
        : 'World $resolvedWorldviewId';

    final json = await _apiClient.post<Object?>(
      'worlds/launch',
      body: {
        'user_id': resolvedUid,
        'worldview_id': resolvedWorldviewId,
        'world_name': resolvedWorldName,
      },
    );

    final map = asJsonMap(json);
    final ok = asBool(map['ok']);
    if (!ok) {
      throw ApiException(
        message: asString(map['error'], fallback: 'launch failed'),
      );
    }

    return World(
      id: _stableInt(asString(map['wid'])),
      wid: asString(map['wid']),
      originId: originId,
      ownerUid: resolvedUid,
      name: resolvedWorldName,
      progressCount: 0,
      interactCount: 0,
      inviteToken: asString(map['wid_str'], fallback: asString(map['wid'])),
      createdAt: null,
    );
  }

  Future<WorldDetail> getWorld(
    String wid, {
    ApiRequestTracePolicy tracePolicy = ApiRequestTracePolicy.standard,
  }) async {
    return _worldDetailFromV1(
      await v1.world.detail(worldId: wid, tracePolicy: tracePolicy),
    );
  }

  Future<TilemapDefinition> getWorldMap({
    required String worldId,
    required String locationId,
  }) async {
    final map = await v1.world.map(worldId: worldId, locationId: locationId);
    return TilemapDefinition.fromJson(map);
  }

  Future<WorldDetail> getWorldInfo(String wid) async {
    return _worldDetailFromV1(await v1.world.info(worldId: wid));
  }

  Future<PagedResponse<Map<String, dynamic>>> getWorldTicks({
    required String wid,
    int limit = 10,
    int offset = 0,
  }) async {
    final page = _pageFromOffset(limit: limit, offset: offset);
    final map = await v1.world.tickList(worldId: wid, pn: page, rn: limit);
    final ticksRaw = map['list'];
    final ticks = (ticksRaw is List ? asJsonList(ticksRaw) : const []).indexed
        .map((entry) => _worldTickFromV1(asJsonMap(entry.$2), entry.$1))
        .toList(growable: false);
    return PagedResponse(
      data: ticks,
      total: asInt(map['total'], fallback: ticks.length),
      limit: limit,
      offset: offset,
    );
  }

  Future<List<WorldSummaryLatestItem>> getLatestWorldSummaries({
    String? originId,
    String? worldId,
  }) async {
    final map = await v1.world.summaryLatest(
      originId: originId,
      worldId: worldId,
    );
    final summariesRaw = map['list'];
    return (summariesRaw is List ? asJsonList(summariesRaw) : const [])
        .map((item) => _worldSummaryLatestItemFromV1(asJsonMap(item)))
        .toList(growable: false);
  }

  Future<String> requestWorld(String wid) async {
    await v1.world.apply(worldId: wid);
    return '';
  }

  Future<String> joinApprovedWorld(
    String wid, {
    String? presetCharacterId,
    Map<String, dynamic>? customRole,
  }) async {
    await v1.world.join(
      worldId: wid,
      presetCharacterId: presetCharacterId,
      customRole: customRole,
    );
    return '';
  }

  Future<String> progressWorld(String wid) async {
    final result = await progressWorldResult(wid);
    return result.message;
  }

  Future<WorldProgressResult> progressWorldResult(String wid) async {
    final map = await v1.world.tick(worldId: wid);
    final tickCount = asInt(map['tick_cnt']);
    final message = tickCount > 0
        ? 'Tick $tickCount'
        : asString(map['status'], fallback: 'Progress complete');
    return WorldProgressResult(message: message, tickCount: tickCount);
  }

  Future<JoinedWorld> joinWorld({
    required String inviteToken,
    String? uid,
  }) async {
    final resolvedUid = uid ?? await _ensureUid();
    final wid = inviteToken.trim();
    final json = await _apiClient.post<Object?>(
      'worlds/$wid/join-requests',
      body: const {'message': ''},
    );
    final map = asJsonMap(json);
    if (!asBool(map['ok'])) {
      throw ApiException(
        message: asString(map['error'], fallback: 'join failed'),
      );
    }
    return JoinedWorld(id: _stableInt(wid), wid: wid, name: resolvedUid);
  }

  Future<List<WorldMember>> getWorldMembers(String wid) async {
    final resolvedUid = await _ensureUid();
    final json = await _apiClient.get<Object?>(
      'characters',
      query: {'user_id': resolvedUid, 'wid': wid},
    );
    final map = asJsonMap(json);
    final players = map['players'] is List
        ? asJsonList(map['players'])
        : const [];
    return players
        .map((e) {
          final p = asJsonMap(e);
          final uid = asString(p['api_user_id']);
          return WorldMember(
            id: _stableInt(uid),
            worldId: _stableInt(wid),
            uid: uid,
            roleAvatar: '',
            roleNickname: asString(
              p['user_name'],
              fallback: asString(p['display_name']),
            ),
            joinedAt: null,
          );
        })
        .toList(growable: false);
  }

  Future<WorldMessage> sendMessage({
    required String wid,
    String? uid,
    required String pointId,
    required String locationId,
    required String content,
  }) async {
    final resolvedUid = uid ?? await _ensureUid();
    final body = {
      'user_id': resolvedUid,
      'wid': wid,
      'location_id': locationId,
      'text': content,
      'player_id': 'player1',
      'client_send_index': DateTime.now().microsecondsSinceEpoch,
      'idempotency_key':
          '${DateTime.now().millisecondsSinceEpoch}-$resolvedUid',
    };

    final json = await _apiClient.post<Object?>(
      'points/$pointId/messages/enqueue',
      body: body,
    );
    final map = asJsonMap(json);
    if (!asBool(map['ok'], fallback: true)) {
      throw ApiException(
        message: asString(map['error'], fallback: 'send failed'),
      );
    }

    final message = map['user_message'] is Map
        ? asJsonMap(map['user_message'])
        : <String, dynamic>{};
    return WorldMessage.fromJson({
      'id': asString(
        message['id'],
        fallback: '${DateTime.now().millisecondsSinceEpoch}',
      ),
      'world_id': wid,
      'location_id': locationId,
      'uid': resolvedUid,
      'content': content,
      'message_type': 'user',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<PagedResponse<WorldMessage>> getLocationMessages({
    required String wid,
    required String pointId,
    String? locationId,
    int limit = 50,
    int offset = 0,
  }) async {
    final resolvedUid = await _ensureUid();
    final query = <String, Object?>{
      'user_id': resolvedUid,
      'wid': wid,
      'limit': limit,
    };
    final resolvedLocationId = locationId?.trim() ?? '';
    if (resolvedLocationId.isNotEmpty) {
      query['location_id'] = resolvedLocationId;
    }

    final json = await _apiClient.get<Object?>(
      'points/$pointId/messages',
      query: query,
    );
    final map = asJsonMap(json);
    final messages = map['messages'] is List
        ? asJsonList(map['messages'])
        : const [];
    final items = messages
        .map(
          (e) => _worldMessageFromV5(
            asJsonMap(e),
            wid: wid,
            pointId: pointId,
            locationId: resolvedLocationId,
          ),
        )
        .toList(growable: false);

    return PagedResponse(
      data: items,
      total: items.length,
      limit: limit,
      offset: offset,
    );
  }

  Future<bool> health() async {
    final json = await _healthClient.get<Object?>('v1/heartbeat');
    final map = asJsonMap(json);
    if (map.containsKey('err_no') || map.containsKey('errNo')) {
      return asInt(map.containsKey('err_no') ? map['err_no'] : map['errNo']) ==
          0;
    }
    return asString(map['status']) == 'ok';
  }
}
