import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'api_exception.dart';
import 'json_utils.dart';
import 'local_mock_genesis_transport.dart';
import 'models/origin.dart';
import 'models/paged_response.dart';
import 'models/user.dart';
import 'models/world.dart';
import 'models/world_message.dart';
import 'http_transport.dart';
import '../platform/device_id.dart';
import '../platform/user_session.dart';

class GenesisApi {
  static const String defaultBaseHost = 'http://47.77.195.140:5002';
  static const String defaultApiBaseUrl = '$defaultBaseHost/api/';
  static const String defaultAssetBaseUrl = 'https://af.hushie.ai/html/';

  GenesisApi({
    ApiClient? apiClient,
    ApiClient? healthClient,
    HttpTransport? transport,
    bool? useMock,
  }) : _apiClient =
           apiClient ??
           ApiClient(
             baseUrl: _normalizeBaseUrl(defaultApiBaseUrl),
             defaultHeaders: const {
               'content-type': 'application/json',
               'accept': 'application/json',
               'x-platform': 'android',
             },
             transport: _resolveTransport(
               transport: transport,
               useMock: useMock,
             ),
             responseProcessor: _defaultGenesisProcessor,
           ),
       _healthClient =
           healthClient ??
           ApiClient(
             baseUrl: _normalizeBaseUrl(defaultBaseHost),
             defaultHeaders: const {'accept': 'application/json'},
             transport: _resolveTransport(
               transport: transport,
               useMock: useMock,
             ),
             responseProcessor: _defaultGenesisProcessor,
           );

  final ApiClient _apiClient;
  final ApiClient _healthClient;

  static final Map<int, String> _originIdToWorldview = <int, String>{};

  Future<String> ensureUid() => _ensureUid();

  Future<String> _ensureUid() async {
    final cached = await UserSession.readUid();
    if (cached != null && cached.trim().isNotEmpty) return cached;
    final user = await bindDevice();
    return user.uid;
  }

  Future<User> bindDevice({String? did}) async {
    final deviceId = did ?? await DeviceId.androidId();
    final localUid = _guestUidFromDid(deviceId);

    try {
      final json = await _apiClient.get<Object?>('auth/me/public-profile');
      final profile = asJsonMap(json);
      final uid = asString(profile['id'], fallback: localUid);
      final user = User(
        id: _stableInt(uid),
        uid: uid,
        did: deviceId,
        nickname: asString(profile['display_name']),
        avatar: asString(
          profile['avatar_url'],
          fallback: asString(profile['avatar']),
        ),
        createdAt: null,
      );
      await UserSession.saveUid(user.uid);
      return user;
    } catch (_) {
      final user = User(
        id: _stableInt(localUid),
        uid: localUid,
        did: deviceId,
        nickname: 'Guest',
        avatar: '',
        createdAt: null,
      );
      await UserSession.saveUid(user.uid);
      return user;
    }
  }

  Future<bool> hasAuthenticatedSession() async {
    try {
      final json = await _apiClient.get<Object?>('auth/me/public-profile');
      final profile = asJsonMap(json);
      final uid = asString(profile['id']);
      if (uid.trim().isEmpty || uid.startsWith('guest_')) return false;
      await UserSession.saveUid(uid);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<User> getUser(String uid) async {
    final json = await _apiClient.get<Object?>('users/$uid/public');
    final profile = asJsonMap(json);
    return User(
      id: _stableInt(uid),
      uid: asString(profile['id'], fallback: uid),
      did: '',
      nickname: asString(profile['display_name']),
      avatar: asString(
        profile['avatar_url'],
        fallback: asString(profile['avatar']),
      ),
      createdAt: null,
    );
  }

  Future<String> getDisplayUserCode() async {
    final json = await _apiClient.get<Object?>('auth/me/public-profile');
    final profile = asJsonMap(json);
    return asString(
      profile['user_code'],
      fallback: asString(profile['id']),
    ).trim();
  }

  Future<User> loginWithGoogle({required String idToken}) async {
    debugPrint('[Auth][GenesisApi] POST /api/auth/google start');
    final json = await _apiClient.post<Object?>(
      'auth/google',
      body: {'id_token': idToken},
    );
    final map = asJsonMap(json);
    final userRaw = map['user'];
    final userMap = userRaw is Map ? asJsonMap(userRaw) : map;
    final uid = asString(userMap['id']);
    final user = User(
      id: _stableInt(uid),
      uid: uid,
      did: '',
      nickname: asString(userMap['display_name']),
      avatar: asString(
        userMap['avatar_url'],
        fallback: asString(
          userMap['avatar'],
          fallback: asString(userMap['picture']),
        ),
      ),
      createdAt: null,
    );
    if (user.uid.trim().isNotEmpty) {
      await UserSession.saveUid(user.uid);
    }
    debugPrint(
      '[Auth][GenesisApi] POST /api/auth/google success uid=${user.uid}',
    );
    return user;
  }

  Future<PagedResponse<OriginSummary>> getOrigins({
    String category = 'For you',
    int limit = 20,
    int offset = 0,
  }) async {
    final isPopular = category.trim().isNotEmpty && category != 'For you';
    final path = isPopular ? 'origins/popular' : 'origins';
    final query = isPopular ? <String, Object?>{'limit': limit} : null;

    final json = await _apiClient.get<Object?>(path, query: query);
    final map = asJsonMap(json);
    final rawOrigins = map['origins'];
    final list = (rawOrigins is List ? asJsonList(rawOrigins) : const [])
        .map((e) => _originSummaryFromV5(asJsonMap(e)))
        .toList(growable: false);

    for (final o in list) {
      _originIdToWorldview[o.id] = o.oid;
    }

    final sliced = list.skip(offset).take(limit).toList(growable: false);
    return PagedResponse(
      data: sliced,
      total: list.length,
      limit: limit,
      offset: offset,
    );
  }

  Future<OriginDetail> getOrigin(String oid) async {
    final worldviewId = oid.trim();
    final json = await _apiClient.get<Object?>('origins/$worldviewId/detail');
    final v5 = asJsonMap(json);
    final detail = _originDetailFromV5(v5);
    _originIdToWorldview[detail.id] = detail.oid;
    return detail;
  }

  Future<PagedResponse<OriginSummary>> getMyLaunchedOrigins({
    String? uid,
    int limit = 20,
    int offset = 0,
  }) async {
    final resolvedUid = uid ?? await _ensureUid();
    final json = await _apiClient.get<Object?>(
      'worlds',
      query: {'user_id': resolvedUid},
    );
    final map = asJsonMap(json);
    final worldsRaw = map['worlds'];
    final worlds = worldsRaw is List ? asJsonList(worldsRaw) : const [];

    final origins = worlds
        .map((e) {
          final w = asJsonMap(e);
          final worldviewId = asString(w['worldview_id']);
          final originId = _stableInt(worldviewId);
          return OriginSummary(
            id: originId,
            oid: worldviewId,
            name: asString(w['world_name']),
            description: '',
            mapImage: asString(w['snapshot_cover_url']),
            worldMap: asString(w['snapshot_cover_url']),
            worldView: '',
            copyCount: 0,
            interactCount: asInt(w['location_chat_user_send_count']),
            tags: const <String>[],
            createdAt: asDateTime(w['updated_at']),
            updatedAt: asDateTime(w['updated_at']),
            characters: const <OriginCharacter>[],
            locations: const <OriginLocation>[],
          );
        })
        .toList(growable: false);

    final sliced = origins.skip(offset).take(limit).toList(growable: false);
    return PagedResponse(
      data: sliced,
      total: origins.length,
      limit: limit,
      offset: offset,
    );
  }

  Future<List<MyWorldSummary>> getMyWorlds({
    String? uid,
    int limit = 30,
    int offset = 0,
  }) async {
    final resolvedUid = uid ?? await _ensureUid();
    final json = await _apiClient.get<Object?>(
      'worlds',
      query: {'user_id': resolvedUid},
    );
    final map = asJsonMap(json);
    final worldsRaw = map['worlds'];
    final worlds = worldsRaw is List ? asJsonList(worldsRaw) : const [];
    final sliced = worlds.skip(offset).take(limit);
    return sliced
        .map((item) {
          final world = asJsonMap(item);
          return MyWorldSummary(
            wid: asString(
              world['world_instance_id'],
              fallback: asString(world['wid']),
            ),
            name: asString(world['world_name']),
            snapshotCoverUrl: asString(world['snapshot_cover_url']),
            updatedAtText: asString(world['updated_at']),
          );
        })
        .toList(growable: false);
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

  Future<WorldDetail> getWorld(String wid) async {
    final resolvedUid = await _ensureUid();

    final tickJson = await _apiClient.get<Object?>(
      'tick',
      query: {'user_id': resolvedUid, 'wid': wid},
    );
    final tick = asJsonMap(tickJson);

    final worldviewId = asString(tick['current_worldview_id']);

    Map<String, dynamic> mapResp = const <String, dynamic>{};
    if (worldviewId.trim().isNotEmpty) {
      final mapJson = await _apiClient.get<Object?>(
        'worldview-map',
        query: {
          'user_id': resolvedUid,
          'worldview_id': worldviewId,
          'wid': wid,
        },
      );
      mapResp = asJsonMap(mapJson);
    }

    final charactersJson = await _apiClient.get<Object?>(
      'characters',
      query: {'user_id': resolvedUid, 'wid': wid},
    );
    final charactersResp = asJsonMap(charactersJson);

    final metaJson = await _apiClient.get<Object?>('worlds/$wid/public-meta');
    final meta = asJsonMap(metaJson);

    OriginSummary origin = const OriginSummary(
      id: 0,
      oid: '',
      name: '',
      description: '',
      mapImage: '',
      worldMap: '',
      worldView: '',
      copyCount: 0,
      interactCount: 0,
      tags: <String>[],
      createdAt: null,
      updatedAt: null,
      characters: <OriginCharacter>[],
      locations: <OriginLocation>[],
    );

    if (worldviewId.trim().isNotEmpty) {
      try {
        final originJson = await _apiClient.get<Object?>(
          'origins/$worldviewId/detail',
        );
        origin = _originSummaryFromV5(asJsonMap(originJson));
      } catch (_) {
        origin = origin.copyWith(
          name: asString(tick['current_worldview_name']),
        );
      }
    }

    final worldLocationsRaw = mapResp['merged_positions'] is List
        ? asJsonList(mapResp['merged_positions'])
        : (mapResp['positions'] is List
              ? asJsonList(mapResp['positions'])
              : const []);
    final worldLocations = worldLocationsRaw
        .map((e) => _normalizeWorldLocation(asJsonMap(e)))
        .toList(growable: false);

    final charactersById = <String, Map<String, dynamic>>{};
    if (charactersResp['characters_full'] is List) {
      for (final e in asJsonList(charactersResp['characters_full'])) {
        final c = asJsonMap(e);
        final id = asString(c['id']);
        if (id.isNotEmpty) {
          charactersById[id] = {
            'name': asString(c['name']),
            'avatar': asString(
              c['avatar_url'],
              fallback: asString(c['avatar']),
            ),
          };
        }
      }
    }

    final characterPositions = <Map<String, dynamic>>[];
    if (tick['scenes'] is List) {
      for (final sRaw in asJsonList(tick['scenes'])) {
        final s = asJsonMap(sRaw);
        final locationId = asString(s['location_id']);
        if (s['character_ids'] is! List) continue;
        for (final cid in asJsonList(s['character_ids'])) {
          final id = asString(cid);
          final c =
              charactersById[id] ?? <String, dynamic>{'name': id, 'avatar': ''};
          characterPositions.add({'location_id': locationId, 'character': c});
        }
      }
    }

    final userPositions = <Map<String, dynamic>>[];
    final slotMapRaw = tick['player_slot_last_location'];
    if (slotMapRaw is Map) {
      final slotMap = asJsonMap(slotMapRaw);
      slotMap.forEach((slot, location) {
        final locationId = asString(location);
        if (locationId.isNotEmpty) {
          userPositions.add({'slot': slot, 'location_id': locationId});
        }
      });
    }

    final tickHistory = tick['tick_history'] is List
        ? asJsonList(tick['tick_history'])
        : const [];
    final lastTick = tickHistory.isNotEmpty
        ? asJsonMap(tickHistory.last)
        : const <String, dynamic>{};

    final worldMutationRaw = tick['world_mutation'];
    final worldMutation = worldMutationRaw is Map
        ? asJsonMap(worldMutationRaw)
        : const <String, dynamic>{};

    return WorldDetail(
      id: _stableInt(wid),
      wid: wid,
      originId: _stableInt(worldviewId),
      ownerUid: asString(meta['owner_user_id']),
      name: asString(
        meta['world_name'],
        fallback: asString(tick['current_worldview_name']),
      ),
      progressCount: asInt(tick['tick_index']),
      interactCount: asInt(tick['location_chat_user_send_count']),
      lastProgressAt: asDateTime(lastTick['created_at']),
      lastProgressUpdate: asString(
        lastTick['global_narrative'],
        fallback: asString(tick['global_narrative']),
      ),
      isProgressing: asBool(worldMutation['busy']),
      inviteToken: asString(meta['display_wid_str'], fallback: wid),
      createdAt: null,
      updatedAt: asDateTime(lastTick['created_at']),
      origin: origin,
      worldLocations: worldLocations,
      characterPositions: characterPositions,
      userPositions: userPositions,
    );
  }

  Future<String> progressWorld(String wid) async {
    final resolvedUid = await _ensureUid();
    final json = await _apiClient.post<Object?>(
      'tick',
      query: {'user_id': resolvedUid, 'wid': wid},
      body: const <String, dynamic>{},
    );
    final map = asJsonMap(json);
    if (asInt(map['tick_index']) > 0) {
      return 'Tick ${asInt(map['tick_index'])}';
    }
    return asString(map['error'], fallback: 'Progress done');
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

  Future<String> updateUserPosition({
    required String wid,
    String? uid,
    required String locationId,
  }) async {
    final resolvedLocationId = locationId.trim();
    if (resolvedLocationId.isEmpty) return '';
    await _apiClient.post<Object?>('session/set-world', body: {'wid': wid});
    final json = await _apiClient.post<Object?>(
      'session/set-player-scene',
      body: {'location_id': resolvedLocationId},
    );
    final map = asJsonMap(json);
    if (!asBool(map['ok'], fallback: true)) {
      throw ApiException(
        message: asString(map['error'], fallback: 'set scene failed'),
      );
    }
    return 'ok';
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
    final json = await _healthClient.get<Object?>('health');
    final map = asJsonMap(json);
    return asString(map['status']) == 'ok';
  }

  Future<CreateOriginResult> createOrigin({
    required Map<String, dynamic> payload,
  }) async {
    final json = await _apiClient.post<Object?>('origins', body: payload);
    final map = asJsonMap(json);
    if (!asBool(map['ok'], fallback: true)) {
      throw ApiException(
        message: asString(map['error'], fallback: 'create origin failed'),
      );
    }
    final detail = map['detail'] is Map
        ? asJsonMap(map['detail'])
        : const <String, dynamic>{};
    return CreateOriginResult(
      worldviewId: asString(map['worldview_id']),
      oid: asInt(detail['Oid']),
    );
  }
}

class CreateOriginResult {
  const CreateOriginResult({required this.worldviewId, required this.oid});

  final String worldviewId;
  final int oid;
}

class MyWorldSummary {
  const MyWorldSummary({
    required this.wid,
    required this.name,
    required this.snapshotCoverUrl,
    required this.updatedAtText,
  });

  final String wid;
  final String name;
  final String snapshotCoverUrl;
  final String updatedAtText;
}

class SearchResultBundle {
  const SearchResultBundle({
    required this.origins,
    required this.worlds,
    required this.users,
  });

  final List<OriginSummary> origins;
  final List<MyWorldSummary> worlds;
  final List<SearchUserSummary> users;
}

class SearchUserSummary {
  const SearchUserSummary({
    required this.uid,
    required this.displayName,
    required this.avatarUrl,
    required this.userCode,
  });

  final String uid;
  final String displayName;
  final String avatarUrl;
  final String userCode;
}

HttpTransport? _resolveTransport({
  required HttpTransport? transport,
  required bool? useMock,
}) {
  if (transport != null) return transport;
  const forceRealApi = bool.fromEnvironment(
    'GENESIS_USE_REAL_API',
    defaultValue: false,
  );
  final enabled = useMock ?? (kDebugMode && !forceRealApi);
  if (!enabled) return null;
  return LocalMockGenesisTransport.instance;
}

Object? _defaultGenesisProcessor(ApiResponse response) {
  final ok = response.statusCode >= 200 && response.statusCode < 300;
  if (ok) return response.data;

  final data = response.data;
  if (data is Map) {
    final error = data['error'];
    if (error != null && error.toString().trim().isNotEmpty) {
      throw ApiException(
        message: error.toString(),
        statusCode: response.statusCode,
        responseBody: response.body,
        responseHeaders: response.headers,
        uri: response.uri,
      );
    }
  }

  throw ApiException(
    message: 'HTTP error',
    statusCode: response.statusCode,
    responseBody: response.body,
    responseHeaders: response.headers,
    uri: response.uri,
  );
}

String _normalizeBaseUrl(String url) {
  return normalizeRemoteUrl(url);
}

String normalizeRemoteUrl(String url) {
  final noBackticks = url.replaceAll('`', '').trim();
  return noBackticks.replaceAll(
    RegExp(r'[\u00A0\u2000-\u200B\u202F\u205F\u3000]'),
    '',
  );
}

String resolveAssetUrl(String raw) {
  final value = normalizeRemoteUrl(raw);
  if (value.isEmpty) return '';
  if (value.startsWith('http://') || value.startsWith('https://')) return value;

  final base = GenesisApi.defaultAssetBaseUrl;
  if (value.startsWith('/')) return '$base${value.substring(1)}';
  return '$base$value';
}

OriginSummary _originSummaryFromV5(Map<String, dynamic> raw) {
  final tagsRaw = raw['Otags'];
  final tags = tagsRaw is List
      ? tagsRaw
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList(growable: false)
      : _splitTags(asString(tagsRaw));

  final worldviewId = asString(
    raw['worldviewId'],
    fallback: asString(raw['OidStr']),
  );
  final mapImage = asString(
    raw['Omap_image'],
    fallback: asString(raw['Oworld_view_image']),
  );
  final id = asInt(raw['Oid'], fallback: _stableInt(worldviewId));

  return OriginSummary(
    id: id,
    oid: worldviewId,
    name: asString(raw['Oname']),
    description: asString(
      raw['Odescription'],
      fallback: asString(raw['Osubtitle']),
    ),
    mapImage: mapImage,
    worldMap: mapImage,
    worldView: asString(raw['Odescription']),
    copyCount: asInt(raw['Ocopycount']),
    interactCount: asInt(raw['Oconnectcount']),
    tags: tags,
    createdAt: null,
    updatedAt: asDateTime(raw['Oupdated_time']),
    characters: _originCharactersFromV5(raw['Ocharacters'], id),
    locations: _originLocationsFromV5(raw['Omap_points'], id),
  );
}

OriginDetail _originDetailFromV5(Map<String, dynamic> raw) {
  final summary = _originSummaryFromV5(raw);
  return OriginDetail(
    id: summary.id,
    oid: summary.oid,
    name: summary.name,
    description: summary.description,
    mapImage: summary.mapImage,
    worldMap: summary.worldMap,
    worldView: summary.worldView,
    copyCount: summary.copyCount,
    interactCount: summary.interactCount,
    tags: summary.tags,
    createdAt: summary.createdAt,
    updatedAt: summary.updatedAt,
    characters: summary.characters,
    locations: summary.locations,
  );
}

List<OriginCharacter> _originCharactersFromV5(Object? raw, int originId) {
  if (raw is! List) return const <OriginCharacter>[];
  return raw
      .asMap()
      .entries
      .map((entry) {
        final i = entry.key;
        final c = asJsonMap(entry.value);
        return OriginCharacter(
          id: asInt(c['id'], fallback: i + 1),
          originId: originId,
          name: asString(c['name']),
          avatar: asString(c['image']),
          tags: asString(c['identity']),
          description: asString(c['intro']),
          currentLocationId: _extractTrailingInt(asString(c['Ochar_point'])),
          initialLocationId: _extractTrailingInt(asString(c['Ochar_point'])),
          createdAt: null,
          updatedAt: null,
        );
      })
      .toList(growable: false);
}

List<OriginLocation> _originLocationsFromV5(Object? raw, int originId) {
  if (raw is! List) return const <OriginLocation>[];
  return raw
      .asMap()
      .entries
      .map((entry) {
        final i = entry.key;
        final p = asJsonMap(entry.value);
        var x = p['x'] is num
            ? (p['x'] as num).toDouble()
            : double.tryParse('${p['x']}') ?? 0;
        var y = p['y'] is num
            ? (p['y'] as num).toDouble()
            : double.tryParse('${p['y']}') ?? 0;
        if (x > 0 && x <= 1.0) x *= 100;
        if (y > 0 && y <= 1.0) y *= 100;

        final id = asInt(
          p['id'],
          fallback: _extractTrailingInt(asString(p['id']), fallback: i + 1),
        );
        return OriginLocation(
          id: id,
          originId: originId,
          name: asString(p['label']),
          icon: asString(p['image']),
          description: '',
          position: i + 1,
          isActive: true,
          xPercent: x,
          yPercent: y,
          createdAt: null,
          updatedAt: null,
        );
      })
      .toList(growable: false);
}

Map<String, dynamic> _normalizeWorldLocation(Map<String, dynamic> location) {
  final locationId = asString(location['location_id']);
  final pointId = asString(location['point_id'], fallback: locationId);
  final xPercentRaw = location['x_percent'];
  final yPercentRaw = location['y_percent'];

  double xPercent = xPercentRaw is num
      ? xPercentRaw.toDouble()
      : double.tryParse('$xPercentRaw') ?? 0;
  double yPercent = yPercentRaw is num
      ? yPercentRaw.toDouble()
      : double.tryParse('$yPercentRaw') ?? 0;

  if ((xPercent <= 0 || yPercent <= 0) &&
      location['x'] != null &&
      location['y'] != null) {
    final x = location['x'] is num
        ? (location['x'] as num).toDouble()
        : double.tryParse('${location['x']}') ?? 0;
    final y = location['y'] is num
        ? (location['y'] as num).toDouble()
        : double.tryParse('${location['y']}') ?? 0;
    if (x > 0 && x <= 1.0) {
      xPercent = x * 100;
    } else {
      xPercent = x;
    }
    if (y > 0 && y <= 1.0) {
      yPercent = y * 100;
    } else {
      yPercent = y;
    }
  }

  return {
    'location_id': locationId,
    'point_id': pointId,
    'id': pointId,
    'name': asString(
      location['location_name'],
      fallback: asString(location['label']),
    ),
    'description': asString(location['state']),
    'icon': asString(
      location['image'],
      fallback: asString(location['building_sprite']),
    ),
    'x_percent': xPercent,
    'y_percent': yPercent,
  };
}

WorldMessage _worldMessageFromV5(
  Map<String, dynamic> msg, {
  required String wid,
  required String pointId,
  required String locationId,
}) {
  return WorldMessage.fromJson({
    'id': asString(msg['id'], fallback: '${asInt(msg['chat_seq'])}'),
    'world_id': wid,
    'location_id': locationId.isNotEmpty ? locationId : pointId,
    'uid': asString(
      msg['api_user_id'],
      fallback: asString(
        msg['author_user_id'],
        fallback: asString(
          msg['player_id'],
          fallback: asString(msg['speaker']),
        ),
      ),
    ),
    'content': asString(msg['content'], fallback: asString(msg['text'])),
    'message_type': asString(
      msg['role'],
      fallback: asString(
        msg['message_state'],
        fallback: asString(msg['send_state']),
      ),
    ),
    'created_at': asString(msg['created_at'], fallback: asString(msg['ts'])),
  });
}

OriginSummary _originSummaryFromSearchItem(Map<String, dynamic> raw) {
  final looksLikeV5 =
      raw.containsKey('Oname') || raw.containsKey('worldviewId');
  if (looksLikeV5) {
    return _originSummaryFromV5(raw);
  }

  final oid = asString(
    raw['oid'],
    fallback: asString(
      raw['worldview_id'],
      fallback: asString(raw['worldviewId']),
    ),
  );
  final mapImage = asString(
    raw['map_image'],
    fallback: asString(raw['snapshot_cover_url']),
  );
  final id = asInt(raw['id'], fallback: _stableInt(oid));

  return OriginSummary(
    id: id,
    oid: oid,
    name: asString(raw['name']),
    description: asString(
      raw['description'],
      fallback: asString(raw['subtitle']),
    ),
    mapImage: mapImage,
    worldMap: asString(raw['world_map'], fallback: mapImage),
    worldView: asString(raw['world_view']),
    copyCount: asInt(raw['copy_count'], fallback: asInt(raw['copyCount'])),
    interactCount: asInt(
      raw['interact_count'],
      fallback: asInt(
        raw['connect_count'],
        fallback: asInt(raw['interactCount']),
      ),
    ),
    tags: _splitTags(asString(raw['tags'])),
    createdAt: asDateTime(raw['created_at']),
    updatedAt: asDateTime(raw['updated_at']),
    characters: const <OriginCharacter>[],
    locations: const <OriginLocation>[],
  );
}

MyWorldSummary _worldSummaryFromSearchItem(Map<String, dynamic> raw) {
  return MyWorldSummary(
    wid: asString(
      raw['world_instance_id'],
      fallback: asString(raw['wid'], fallback: asString(raw['id'])),
    ),
    name: asString(raw['world_name'], fallback: asString(raw['name'])),
    snapshotCoverUrl: asString(
      raw['snapshot_cover_url'],
      fallback: asString(raw['cover_url']),
    ),
    updatedAtText: asString(raw['updated_at']),
  );
}

SearchUserSummary _userSummaryFromSearchItem(Map<String, dynamic> raw) {
  final uid = asString(raw['id'], fallback: asString(raw['uid']));
  return SearchUserSummary(
    uid: uid,
    displayName: asString(
      raw['display_name'],
      fallback: asString(raw['nickname'], fallback: asString(raw['name'])),
    ),
    avatarUrl: asString(raw['avatar_url'], fallback: asString(raw['avatar'])),
    userCode: asString(raw['user_code'], fallback: uid),
  );
}

String _guestUidFromDid(String did) {
  final digest = base64Url.encode(utf8.encode(did)).replaceAll('=', '');
  final suffix = digest.length > 10 ? digest.substring(0, 10) : digest;
  return 'guest_$suffix';
}

int _stableInt(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return 0;
  var hash = 0;
  for (final unit in trimmed.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return hash;
}

int _extractTrailingInt(String value, {int fallback = 0}) {
  final match = RegExp(r'(\\d+)').allMatches(value).toList(growable: false);
  if (match.isEmpty) return fallback;
  return int.tryParse(match.last.group(1) ?? '') ?? fallback;
}

List<String> _splitTags(String tags) {
  if (tags.trim().isEmpty) return const <String>[];
  return tags
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList(growable: false);
}

extension on OriginSummary {
  OriginSummary copyWith({
    int? id,
    String? oid,
    String? name,
    String? description,
    String? mapImage,
    String? worldMap,
    String? worldView,
    int? copyCount,
    int? interactCount,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<OriginCharacter>? characters,
    List<OriginLocation>? locations,
  }) {
    return OriginSummary(
      id: id ?? this.id,
      oid: oid ?? this.oid,
      name: name ?? this.name,
      description: description ?? this.description,
      mapImage: mapImage ?? this.mapImage,
      worldMap: worldMap ?? this.worldMap,
      worldView: worldView ?? this.worldView,
      copyCount: copyCount ?? this.copyCount,
      interactCount: interactCount ?? this.interactCount,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      characters: characters ?? this.characters,
      locations: locations ?? this.locations,
    );
  }
}
