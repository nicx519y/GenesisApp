part of 'genesis_api.dart';

mixin _GenesisApiOriginOperations on _GenesisApiContext {
  Future<PagedResponse<OriginSummary>> getOrigins({
    String category = 'For you',
    int limit = 20,
    int offset = 0,
  }) async {
    final page = _pageFromOffset(limit: limit, offset: offset);
    final tagName = category.trim().isNotEmpty && category != 'For you'
        ? category.trim()
        : null;
    final map = await v1.origin.list(
      scene: tagName == null ? 'foryou' : 'tag',
      tag: tagName,
      pn: page,
      rn: limit,
    );
    final rawOrigins = map['list'];
    final list = (rawOrigins is List ? asJsonList(rawOrigins) : const [])
        .map((e) => _originSummaryFromV1ListItem(asJsonMap(e)))
        .toList(growable: false);

    for (final o in list) {
      _originIdToWorldview[o.id] = o.oid;
    }

    return PagedResponse(
      data: list,
      total: asInt(map['total'], fallback: list.length),
      limit: limit,
      offset: offset,
    );
  }

  Future<OriginDetail> getOrigin(String oid) async {
    final detail = _originDetailFromV1(await v1.origin.detail(oid: oid));
    _originIdToWorldview[detail.id] = detail.oid;
    return detail;
  }

  Future<TilemapDefinition> getOriginMap({
    required String originId,
    required String locationId,
  }) async {
    final map = await v1.origin.map(originId: originId, locationId: locationId);
    return TilemapDefinition.fromJson(map);
  }

  Future<OriginDetail> getOriginInfo(String oid) async {
    final detail = _originDetailFromV1(await v1.origin.info(oid: oid));
    _originIdToWorldview[detail.id] = detail.oid;
    return detail;
  }

  Future<List<OriginMyLaunchPresetCharacter>> getMyLaunchPresetCharacters(
    String originId,
  ) async {
    final items = await v1.origin.myLaunchPresetCharacters(originId: originId);
    return items
        .map(_originMyLaunchPresetCharacterFromV1)
        .toList(growable: false);
  }

  Future<PagedResponse<OriginSummary>> getMyLaunchedOrigins({
    String? uid,
    String scene = 'mine',
    int limit = 20,
    int offset = 0,
  }) async {
    final resolvedScene = _normalizeListScene(scene, ownScene: 'mine');
    final resolvedUid = resolvedScene == 'uid'
        ? uid ?? await _ensureUid()
        : null;
    final page = _pageFromOffset(limit: limit, offset: offset);
    final map = await v1.origin.list(
      scene: resolvedScene,
      uid: resolvedUid,
      pn: page,
      rn: limit,
    );
    final originsRaw = map['list'];
    final origins = (originsRaw is List ? asJsonList(originsRaw) : const [])
        .map((e) => _originSummaryFromV1ListItem(asJsonMap(e)))
        .toList(growable: false);

    return PagedResponse(
      data: origins,
      total: asInt(map['total'], fallback: origins.length),
      limit: limit,
      offset: offset,
    );
  }

  Future<List<MyWorldSummary>> getMyWorlds({
    String? uid,
    String? scene,
    int limit = 30,
    int offset = 0,
  }) async {
    final resolvedScene = _normalizeListScene(scene, ownScene: 'mine');
    final resolvedUid = resolvedScene == 'uid'
        ? uid ?? await _ensureUid()
        : null;
    final page = _pageFromOffset(limit: limit, offset: offset);
    final map = await v1.world.list(
      scene: resolvedScene,
      uid: resolvedUid,
      pn: page,
      rn: limit,
    );
    final worldsRaw = map['list'];
    return (worldsRaw is List ? asJsonList(worldsRaw) : const [])
        .map((item) => _myWorldSummaryFromV1ListItem(asJsonMap(item)))
        .toList(growable: false);
  }

  String _normalizeListScene(String? scene, {required String ownScene}) {
    final trimmed = (scene ?? '').trim();
    if (trimmed.isEmpty || trimmed == ownScene) return ownScene;
    if (trimmed == 'uid' || trimmed == 'tag') return trimmed;
    return 'uid';
  }

  Future<SearchResultBundle> search({
    required String query,
    int limit = 20,
  }) async {
    final resolvedUid = await _ensureUid();
    final q = query.trim();
    if (q.isEmpty) {
      return const SearchResultBundle(
        origins: <OriginSummary>[],
        worlds: <MyWorldSummary>[],
        users: <SearchUserSummary>[],
      );
    }

    Object? json;
    Object? lastError;
    final queryKeys = <String>['q', 'keyword', 'query'];
    for (final key in queryKeys) {
      try {
        json = await _apiClient.get<Object?>(
          'search',
          query: {key: q, 'limit': limit, 'user_id': resolvedUid},
        );
        lastError = null;
        break;
      } catch (e) {
        lastError = e;
      }
    }
    if (lastError != null) {
      throw lastError;
    }
    if (json == null) {
      return const SearchResultBundle(
        origins: <OriginSummary>[],
        worlds: <MyWorldSummary>[],
        users: <SearchUserSummary>[],
      );
    }
    final map = asJsonMap(json);

    final originsRaw =
        (map['origins'] ?? map['origin'] ?? map['origin_list']) as Object?;
    final worldsRaw =
        (map['worlds'] ?? map['world'] ?? map['world_list']) as Object?;
    final usersRaw =
        (map['users'] ?? map['user'] ?? map['user_list']) as Object?;

    final origins = (originsRaw is List ? asJsonList(originsRaw) : const [])
        .map((item) => _originSummaryFromSearchItem(asJsonMap(item)))
        .toList(growable: false);
    for (final o in origins) {
      _originIdToWorldview[o.id] = o.oid;
    }

    final worlds = (worldsRaw is List ? asJsonList(worldsRaw) : const [])
        .map((item) => _worldSummaryFromSearchItem(asJsonMap(item)))
        .toList(growable: false);

    final users = (usersRaw is List ? asJsonList(usersRaw) : const [])
        .map((item) => _userSummaryFromSearchItem(asJsonMap(item)))
        .toList(growable: false);

    return SearchResultBundle(
      origins: origins.take(limit).toList(growable: false),
      worlds: worlds.take(limit).toList(growable: false),
      users: users.take(limit).toList(growable: false),
    );
  }
}
