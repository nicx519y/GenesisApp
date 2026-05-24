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
import 'v1/genesis_v1_api.dart';
import '../app/config/platform_config.dart';
import '../platform/auth/auth_session.dart';
import '../platform/auth/google_firebase_auth_service.dart';
import '../platform/auth/identity_auth_service.dart';
import '../platform/device/device_id_service.dart';
import '../platform/device/method_channel_device_id_service.dart';
import '../platform/session/method_channel_user_session_store.dart';
import '../platform/session/user_session_store.dart';

class GenesisApi {
  static const String defaultBaseHost = 'http://47.77.195.140:5002';
  static const String defaultApiBaseUrl = '$defaultBaseHost/api/';
  static const String defaultAssetBaseUrl = 'https://af.hushie.ai/html/';
  static const String defaultChatroomWsBaseUrl = 'ws://47.77.195.140:5002/ws';

  GenesisApi({
    ApiClient? apiClient,
    ApiClient? healthClient,
    HttpTransport? transport,
    bool? useMock,
    PlatformConfig? platformConfig,
    DeviceIdService? deviceIdService,
    UserSessionStore? sessionStore,
    IdentityAuthService? identityAuthService,
  }) {
    final resolvedPlatformConfig =
        platformConfig ?? const DefaultPlatformConfig();
    _deviceIdService = deviceIdService ?? const NativeDeviceIdService();
    _sessionStore = sessionStore ?? NativeUserSessionStore();
    _identityAuthService =
        identityAuthService ?? const GoogleFirebaseAuthService();
    final resolvedTransport = _resolveTransport(
      transport: transport,
      useMock: useMock,
    );

    _apiClient =
        apiClient ??
        ApiClient(
          baseUrl: _normalizeBaseUrl(resolvedPlatformConfig.apiBaseUrl),
          defaultHeaders: {
            'content-type': 'application/json',
            'accept': 'application/json',
            'x-platform': resolvedPlatformConfig.platformHeader,
          },
          requestHeaderProvider: _runtimeRequestHeaders,
          transport: resolvedTransport,
          responseProcessor: _defaultGenesisProcessor,
        );
    _healthClient =
        healthClient ??
        ApiClient(
          baseUrl: _normalizeBaseUrl(defaultBaseHost),
          defaultHeaders: const {'accept': 'application/json'},
          requestHeaderProvider: _runtimeRequestHeaders,
          transport: resolvedTransport,
          responseProcessor: _defaultGenesisProcessor,
        );
    v1 = GenesisV1Api(_apiClient);
  }

  late final ApiClient _apiClient;
  late final ApiClient _healthClient;
  late final GenesisV1Api v1;
  late final DeviceIdService _deviceIdService;
  late final UserSessionStore _sessionStore;
  late final IdentityAuthService _identityAuthService;

  static final Map<int, String> _originIdToWorldview = <int, String>{};

  Future<Map<String, String>> _runtimeRequestHeaders() async {
    final headers = <String, String>{};
    final deviceId = await _readHeaderValue(_deviceIdService.getDeviceId);
    if (deviceId != null) headers['x-device-id'] = deviceId;

    final uid = await _readHeaderValue(_sessionStore.readUid);
    if (uid != null) headers['x-user-id'] = uid;

    final authToken = await _readHeaderValue(_sessionStore.readAuthToken);
    if (authToken != null) {
      headers['authorization'] = authToken.toLowerCase().startsWith('bearer ')
          ? authToken
          : 'Bearer $authToken';
    }
    return headers;
  }

  Future<String?> _readHeaderValue(Future<String?> Function() read) async {
    try {
      final value = (await read())?.trim();
      return value == null || value.isEmpty ? null : value;
    } catch (_) {
      return null;
    }
  }

  Future<String> ensureUid() => _ensureUid();

  Future<String> _ensureUid() async {
    final cached = await _sessionStore.readUid();
    if (cached != null && cached.trim().isNotEmpty) return cached;
    final user = await bindDevice();
    return user.uid;
  }

  Future<User> bindDevice({String? did}) async {
    final deviceId = did ?? await _deviceIdService.getDeviceId();
    final localUid = _guestUidFromDid(deviceId);

    try {
      final profileEnvelope = await v1.user.info();
      final profile = asJsonMap(profileEnvelope['user']);
      final uid = asString(
        profile['id'],
        fallback: asString(profile['uid'], fallback: localUid),
      );
      final user = User(
        id: _stableInt(uid),
        uid: uid,
        did: deviceId,
        nickname: asString(
          profile['display_name'],
          fallback: asString(profile['name']),
        ),
        avatar: asString(
          profile['avatar_url'],
          fallback: asString(profile['avatar']),
        ),
        createdAt: null,
      );
      await _sessionStore.saveUid(user.uid);
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
      await _sessionStore.saveUid(user.uid);
      return user;
    }
  }

  Future<bool> hasAuthenticatedSession({bool tryAutoRefresh = true}) async {
    try {
      final profileEnvelope = await v1.user.info();
      final profile = asJsonMap(profileEnvelope['user']);
      final uid = asString(profile['id'], fallback: asString(profile['uid']));
      if (uid.trim().isEmpty || uid.startsWith('guest_')) return false;
      await _sessionStore.saveUid(uid);
      return true;
    } on ApiException catch (e) {
      if (!tryAutoRefresh || !_isAuthFailureStatus(e.statusCode)) {
        return false;
      }

      debugPrint(
        '[Auth][GenesisApi] session check failed with ${e.statusCode}, trying silent refresh',
      );

      final session = await _identityAuthService.refreshSilently();
      if (session == null ||
          (!session.hasProviderToken && !session.hasFirebaseToken)) {
        debugPrint('[Auth][GenesisApi] silent refresh unavailable');
        return false;
      }

      try {
        await loginWithIdentity(session);
      } catch (reauthError, reauthStack) {
        debugPrint('[Auth][GenesisApi] backend re-login failed: $reauthError');
        debugPrint(
          '[Auth][GenesisApi] backend re-login stacktrace:\n$reauthStack',
        );
        return false;
      }

      return hasAuthenticatedSession(tryAutoRefresh: false);
    } catch (_) {
      return false;
    }
  }

  Future<User> getUser(String uid) async {
    final profileEnvelope = await v1.user.info(uid: uid);
    final profile = asJsonMap(profileEnvelope['user']);
    return User(
      id: _stableInt(uid),
      uid: asString(
        profile['id'],
        fallback: asString(profile['uid'], fallback: uid),
      ),
      did: '',
      nickname: asString(
        profile['display_name'],
        fallback: asString(profile['name']),
      ),
      avatar: asString(
        profile['avatar_url'],
        fallback: asString(profile['avatar']),
      ),
      createdAt: null,
    );
  }

  Future<String> getDisplayUserCode() async {
    final profileEnvelope = await v1.user.info();
    final profile = asJsonMap(profileEnvelope['user']);
    return asString(
      profile['user_code'],
      fallback: asString(profile['id'], fallback: asString(profile['uid'])),
    ).trim();
  }

  Future<User> loginWithGoogle({
    required String idToken,
    String? nonce,
    String? name,
    String? avatar,
  }) {
    return _loginWithGoogle(
      idToken: idToken,
      nonce: nonce,
      name: name,
      avatar: avatar,
    );
  }

  Future<User> loginWithIdentity(AuthSession session) {
    switch (session.provider) {
      case IdentityProvider.google:
        return _loginWithGoogle(
          idToken: session.providerIdToken,
          fallbackUid: session.identityUid,
          name: session.displayName,
          avatar: session.photoUrl,
        );
      case IdentityProvider.apple:
        return loginWithApple(
          identityToken: session.providerIdToken,
          firebaseIdToken: session.firebaseIdToken,
          fallbackUid: session.identityUid,
          name: session.displayName,
          avatar: session.photoUrl,
        );
    }
  }

  Future<User> _loginWithGoogle({
    required String idToken,
    String fallbackUid = '',
    String? nonce,
    String? name,
    String? avatar,
  }) async {
    debugPrint('[Auth][GenesisApi] POST /api/v1/user/oauth/google start');
    final json = await v1.user.googleAuth(
      idToken: idToken,
      nonce: nonce,
      name: name,
      avatar: avatar,
    );
    final user = await _persistLoginResponse(json, fallbackUid: fallbackUid);
    debugPrint(
      '[Auth][GenesisApi] POST /api/v1/user/oauth/google success uid=${user.uid}',
    );
    return user;
  }

  Future<User> loginWithApple({
    required String identityToken,
    required String firebaseIdToken,
    String fallbackUid = '',
    String? name,
    String? avatar,
  }) async {
    debugPrint('[Auth][GenesisApi] POST /api/v1/user/oauth/apple start');
    final trimmedIdentityToken = identityToken.trim();
    final trimmedFirebaseIdToken = firebaseIdToken.trim();
    final idToken = trimmedIdentityToken.isNotEmpty
        ? trimmedIdentityToken
        : trimmedFirebaseIdToken;
    final json = await v1.user.appleAuth(
      idToken: idToken,
      name: name,
      avatar: avatar,
    );
    final user = await _persistLoginResponse(json, fallbackUid: fallbackUid);
    debugPrint(
      '[Auth][GenesisApi] POST /api/v1/user/oauth/apple success uid=${user.uid}',
    );
    return user;
  }

  Future<void> logout() async {
    debugPrint('[Auth][GenesisApi] POST /api/v1/user/logout start');
    await v1.user.logout();
    debugPrint('[Auth][GenesisApi] POST /api/v1/user/logout success');
  }

  Future<User> _persistLoginResponse(
    Object? json, {
    String fallbackUid = '',
  }) async {
    final map = asJsonMap(json);
    final userRaw = map['user'];
    final userMap = userRaw is Map ? asJsonMap(userRaw) : map;
    final uid = _loginResponseUid(userMap, fallbackUid: fallbackUid);
    final user = User(
      id: _stableInt(uid),
      uid: uid,
      did: '',
      nickname: asString(
        userMap['display_name'],
        fallback: asString(userMap['name']),
      ),
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
      await _sessionStore.saveUid(user.uid);
    }
    final authToken = asString(
      map['token'],
      fallback: asString(map['access_token'], fallback: asString(map['jwt'])),
    ).trim();
    if (authToken.isNotEmpty) {
      await _sessionStore.saveAuthToken(authToken);
    }
    return user;
  }

  Future<PagedResponse<OriginSummary>> getOrigins({
    String category = 'For you',
    int limit = 20,
    int offset = 0,
  }) async {
    final page = _pageFromOffset(limit: limit, offset: offset);
    final tagName = category.trim().isNotEmpty && category != 'For you'
        ? category.trim()
        : null;
    final map = await v1.origin.list(tagName: tagName, pn: page, rn: limit);
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

  Future<PagedResponse<OriginSummary>> getMyLaunchedOrigins({
    String? uid,
    int limit = 20,
    int offset = 0,
  }) async {
    final resolvedUid = uid ?? await _ensureUid();
    final page = _pageFromOffset(limit: limit, offset: offset);
    final map = await v1.origin.list(uid: resolvedUid, pn: page, rn: limit);
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
    int limit = 30,
    int offset = 0,
  }) async {
    final resolvedUid = uid ?? await _ensureUid();
    final page = _pageFromOffset(limit: limit, offset: offset);
    final map = await v1.world.list(uid: resolvedUid, pn: page, rn: limit);
    final worldsRaw = map['list'];
    return (worldsRaw is List ? asJsonList(worldsRaw) : const [])
        .map((item) => _myWorldSummaryFromV1ListItem(asJsonMap(item)))
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
    return _worldDetailFromV1(await v1.world.detail(wid: wid));
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
    required this.ownerName,
    required this.progressCount,
    required this.interactCount,
    required this.characterCount,
    required this.playerCount,
  });

  final String wid;
  final String name;
  final String snapshotCoverUrl;
  final String updatedAtText;
  final String ownerName;
  final int progressCount;
  final int interactCount;
  final int characterCount;
  final int playerCount;
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
  const apiEnvironment = String.fromEnvironment('GENESIS_API_ENV');
  final environmentUseMock = _mockEnabledByApiEnvironment(apiEnvironment);
  const forceRealApi = bool.fromEnvironment(
    'GENESIS_USE_REAL_API',
    defaultValue: false,
  );
  final enabled =
      useMock ?? environmentUseMock ?? (kDebugMode && !forceRealApi);
  if (!enabled) return null;
  return LocalMockGenesisTransport.instance;
}

bool? _mockEnabledByApiEnvironment(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty) return null;
  if (normalized == 'mock' || normalized == 'local' || normalized == 'debug') {
    return true;
  }
  if (normalized == 'production' ||
      normalized == 'prod' ||
      normalized == 'real') {
    return false;
  }
  return null;
}

bool _isAuthFailureStatus(int? statusCode) {
  return statusCode == 401 || statusCode == 403;
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

int _pageFromOffset({required int limit, required int offset}) {
  if (limit <= 0 || offset <= 0) return 1;
  return (offset ~/ limit) + 1;
}

OriginSummary _originSummaryFromV1ListItem(Map<String, dynamic> raw) {
  final origin = raw['info'] is Map ? asJsonMap(raw['info']) : raw;
  final stats = raw['stats'] is Map ? asJsonMap(raw['stats']) : raw;
  final oid = asString(origin['oid'], fallback: asString(origin['origin_id']));
  final cover = resolveAssetUrl(
    asString(origin['cover'], fallback: asString(origin['map_url'])),
  );

  return OriginSummary(
    id: asInt(origin['id'], fallback: _stableInt(oid)),
    oid: oid,
    name: asString(
      origin['name'],
      fallback: asString(origin['origin_name'], fallback: oid),
    ),
    description: asString(
      origin['display_subtitle'],
      fallback: asString(
        origin['brief'],
        fallback: asString(
          origin['setting'],
          fallback: asString(origin['world_setting']),
        ),
      ),
    ),
    mapImage: cover,
    worldMap: cover,
    worldView: asString(
      origin['world_view'],
      fallback: asString(origin['setting']),
    ),
    originator: asString(
      origin['created_user_name'],
      fallback: asString(origin['originator']),
    ),
    versionNum: asInt(
      origin['version_num'],
      fallback: asInt(origin['origin_version']),
    ),
    copyCount: asInt(stats['copy_cnt']),
    interactCount: asInt(stats['connect_cnt']),
    characterCount: asInt(stats['character_cnt']),
    tags: _tagsFromV1(origin['tags']),
    createdAt: _apiDateTime(origin['created_at']),
    updatedAt: _apiDateTime(
      origin['updated_at'] ?? origin['origin_version_time'],
    ),
    characters: const <OriginCharacter>[],
    locations: const <OriginLocation>[],
  );
}

MyWorldSummary _myWorldSummaryFromV1ListItem(Map<String, dynamic> raw) {
  final world = raw['info'] is Map ? asJsonMap(raw['info']) : raw;
  final stats = raw['stats'] is Map ? asJsonMap(raw['stats']) : world;
  final wid = asString(world['wid'], fallback: asString(world['world_id']));
  final name = asString(
    world['name'],
    fallback: asString(world['world_name'], fallback: wid),
  );
  final cover = resolveAssetUrl(
    asString(
      world['snapshot_cover_url'],
      fallback: asString(
        world['cover'],
        fallback: asString(
          world['map_url'],
          fallback: asString(world['cover_url']),
        ),
      ),
    ),
  );

  return MyWorldSummary(
    wid: wid,
    name: name,
    snapshotCoverUrl: cover,
    updatedAtText: _apiDateTimeText(world['updated_at'] ?? world['created_at']),
    ownerName: asString(
      world['owner_name'],
      fallback: asString(world['created_user_name']),
    ),
    progressCount: asInt(stats['tick_cnt']),
    interactCount: asInt(stats['connect_cnt']),
    characterCount: asInt(
      stats['ai_character_cnt'],
      fallback: asInt(stats['character_cnt']),
    ),
    playerCount: asInt(stats['player_cnt']),
  );
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
    characterCount: _originCharactersFromV5(raw['Ocharacters'], id).length,
    tags: tags,
    createdAt: null,
    updatedAt: asDateTime(raw['Oupdated_time']),
    characters: _originCharactersFromV5(raw['Ocharacters'], id),
    locations: _originLocationsFromV5(raw['Omap_points'], id),
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
      fallback: asString(
        location['label'],
        fallback: asString(location['name']),
      ),
    ),
    'description': asString(
      location['state'],
      fallback: asString(
        location['description'],
        fallback: asString(location['location_summary']),
      ),
    ),
    'icon': asString(
      location['image'],
      fallback: asString(
        location['building_sprite'],
        fallback: asString(
          location['icon'],
          fallback: asString(location['map']),
        ),
      ),
    ),
    'x_percent': xPercent,
    'y_percent': yPercent,
  };
}

OriginDetail _originDetailFromV1(Map<String, dynamic> raw) {
  final origin = raw['origin'] is Map
      ? asJsonMap(raw['origin'])
      : asJsonMap(raw['info']);
  final stats = raw['stats'] is Map ? asJsonMap(raw['stats']) : origin;
  final oid = asString(origin['oid'], fallback: asString(origin['origin_id']));
  final id = _stableInt(oid);
  final cover = resolveAssetUrl(
    asString(origin['cover'], fallback: asString(origin['map_url'])),
  );
  final charactersRaw = raw['character_list'] ?? raw['characters'];
  final characters = charactersRaw is List
      ? asJsonList(charactersRaw)
            .map((e) => _originCharacterFromV1(asJsonMap(e), id))
            .toList(growable: false)
      : const <OriginCharacter>[];
  final locationsRaw = raw['location_list'] ?? raw['locations'];
  final locations = locationsRaw is List
      ? asJsonList(locationsRaw)
            .map((e) => _originLocationFromV1(asJsonMap(e), id))
            .toList(growable: false)
      : const <OriginLocation>[];

  return OriginDetail(
    id: id,
    oid: oid,
    name: asString(
      origin['name'],
      fallback: asString(origin['origin_name'], fallback: oid),
    ),
    description: asString(
      origin['world_setting'],
      fallback: asString(
        origin['display_subtitle'],
        fallback: asString(
          origin['setting'],
          fallback: asString(origin['brief']),
        ),
      ),
    ),
    mapImage: cover,
    worldMap: cover,
    worldView: asString(
      origin['world_view'],
      fallback: asString(origin['setting']),
    ),
    copyCount: asInt(stats['copy_cnt']),
    interactCount: asInt(stats['connect_cnt']),
    tags: _tagsFromV1(origin['tags']),
    createdAt: _apiDateTime(origin['created_at']),
    updatedAt: _apiDateTime(
      origin['updated_at'] ?? origin['origin_version_time'],
    ),
    characters: characters,
    locations: locations,
  );
}

WorldDetail _worldDetailFromV1(Map<String, dynamic> raw) {
  final world = raw['world'] is Map
      ? asJsonMap(raw['world'])
      : asJsonMap(raw['info']);
  final stats = raw['stats'] is Map ? asJsonMap(raw['stats']) : world;
  final wid = asString(world['wid'], fallback: asString(world['world_id']));
  final oid = asString(world['oid'], fallback: asString(world['origin_id']));
  final worldId = _stableInt(wid);
  final originId = _stableInt(oid);
  final cover = resolveAssetUrl(
    asString(world['cover'], fallback: asString(world['map_url'])),
  );
  final locationsRaw = raw['location_list'] ?? raw['locations'];
  final locations = locationsRaw is List
      ? asJsonList(locationsRaw)
            .map((e) => _normalizeWorldLocation(asJsonMap(e)))
            .toList(growable: false)
      : const <Map<String, dynamic>>[];
  final charactersRaw = raw['character_list'] ?? raw['characters'];
  final characters = charactersRaw is List
      ? asJsonList(
          charactersRaw,
        ).map((e) => asJsonMap(e)).toList(growable: false)
      : const <Map<String, dynamic>>[];
  final characterPositions = characters
      .map(_worldCharacterPositionFromV1)
      .whereType<Map<String, dynamic>>()
      .toList(growable: false);
  final userPositions = characters
      .map(_worldUserPositionFromV1)
      .whereType<Map<String, dynamic>>()
      .toList(growable: false);
  final ticksRaw = raw['tick_list'] ?? raw['ticks'];
  final ticks = ticksRaw is List
      ? asJsonList(ticksRaw).map((e) => asJsonMap(e)).toList(growable: false)
      : const <Map<String, dynamic>>[];
  final lastTick = ticks.isNotEmpty ? ticks.last : const <String, dynamic>{};

  return WorldDetail(
    id: worldId,
    wid: wid,
    originId: originId,
    ownerUid: asString(world['created_uid']),
    name: asString(
      world['name'],
      fallback: asString(world['world_name'], fallback: wid),
    ),
    progressCount: asInt(stats['tick_cnt']),
    interactCount: asInt(stats['connect_cnt']),
    lastProgressAt: _apiDateTime(
      lastTick['created_at'] ?? lastTick['created_time'] ?? world['updated_at'],
    ),
    lastProgressUpdate: asString(
      lastTick['content'],
      fallback: asString(
        lastTick['summary'],
        fallback: asString(lastTick['narrator']),
      ),
    ),
    isProgressing:
        asString(raw['action_button_state']) == 'progressing' ||
        asInt(world['status']) == 20,
    inviteToken: wid,
    createdAt: _apiDateTime(world['created_at']),
    updatedAt: _apiDateTime(world['updated_at']),
    origin: OriginSummary(
      id: originId,
      oid: oid,
      name: asString(
        world['name'],
        fallback: asString(world['world_name'], fallback: oid),
      ),
      description: asString(
        world['world_setting'],
        fallback: asString(
          world['display_subtitle'],
          fallback: asString(
            world['setting'],
            fallback: asString(world['brief']),
          ),
        ),
      ),
      mapImage: cover,
      worldMap: cover,
      worldView: asString(
        world['world_view'],
        fallback: asString(world['setting']),
      ),
      originator: asString(world['created_user_name']),
      versionNum: asInt(
        world['origin_version_num'],
        fallback: asInt(world['version_num']),
      ),
      copyCount: asInt(world['copy_cnt']),
      interactCount: asInt(stats['connect_cnt']),
      characterCount: asInt(
        stats['character_cnt'],
        fallback: asInt(stats['ai_character_cnt']),
      ),
      tags: _tagsFromV1(world['tags']),
      createdAt: _apiDateTime(world['created_at']),
      updatedAt: _apiDateTime(world['updated_at']),
      characters: const <OriginCharacter>[],
      locations: const <OriginLocation>[],
    ),
    worldLocations: locations,
    characterPositions: characterPositions,
    userPositions: userPositions,
  );
}

OriginCharacter _originCharacterFromV1(Map<String, dynamic> raw, int originId) {
  final characterId = asString(
    raw['character_id'],
    fallback: asString(raw['char_id']),
  );
  final locationId = asString(
    raw['location_id'],
    fallback: asString(raw['initial_location_id']),
  );
  final stableLocationId = _stableInt(locationId);
  return OriginCharacter(
    id: asInt(raw['id'], fallback: _stableInt(characterId)),
    originId: originId,
    name: asString(raw['name']),
    avatar: resolveAssetUrl(asString(raw['avatar'])),
    tags: asString(raw['identity']),
    description: asString(
      raw['description'],
      fallback: asString(raw['brief'], fallback: asString(raw['tagline'])),
    ),
    currentLocationId: stableLocationId,
    initialLocationId: stableLocationId,
    createdAt: _apiDateTime(raw['created_at']),
    updatedAt: _apiDateTime(raw['updated_at']),
  );
}

OriginLocation _originLocationFromV1(Map<String, dynamic> raw, int originId) {
  final locationId = asString(raw['location_id']);
  return OriginLocation(
    id: asInt(raw['id'], fallback: _stableInt(locationId)),
    originId: originId,
    name: asString(raw['name'], fallback: asString(raw['location_name'])),
    icon: resolveAssetUrl(
      asString(raw['image'], fallback: asString(raw['map'])),
    ),
    description: asString(
      raw['description'],
      fallback: asString(raw['location_summary']),
    ),
    position: asInt(raw['position']),
    isActive: true,
    xPercent: _asDouble(raw['x_percent']),
    yPercent: _asDouble(raw['y_percent']),
    createdAt: _apiDateTime(raw['created_at']),
    updatedAt: _apiDateTime(raw['updated_at']),
  );
}

Map<String, dynamic>? _worldCharacterPositionFromV1(Map<String, dynamic> raw) {
  final locationId = asString(raw['location_id']);
  if (locationId.isEmpty) return null;
  return {
    'location_id': locationId,
    'character': {
      'name': asString(raw['name']),
      'avatar': resolveAssetUrl(asString(raw['avatar'])),
    },
  };
}

Map<String, dynamic>? _worldUserPositionFromV1(Map<String, dynamic> raw) {
  final playerUid = asString(raw['player_uid']);
  if (playerUid.isEmpty) return null;
  final locationId = asString(raw['location_id']);
  if (locationId.isEmpty) return null;
  return {'uid': playerUid, 'location_id': locationId};
}

List<String> _tagsFromV1(Object? raw) {
  if (raw is List) {
    return raw
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }
  return _splitTags(asString(raw));
}

double _asDouble(Object? raw) {
  return raw is num ? raw.toDouble() : double.tryParse('$raw') ?? 0;
}

DateTime? _apiDateTime(Object? raw) {
  if (raw is DateTime) return raw;
  if (raw is num) {
    final value = raw.toInt();
    if (value <= 0) return null;
    final millis = value > 100000000000 ? value : value * 1000;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }
  if (raw is String) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final numeric = int.tryParse(trimmed);
    if (numeric != null) return _apiDateTime(numeric);
    return DateTime.tryParse(trimmed);
  }
  return asDateTime(raw);
}

String _apiDateTimeText(Object? raw) {
  final parsed = _apiDateTime(raw);
  if (parsed != null) return parsed.toIso8601String();
  return asString(raw);
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
    originator: asString(
      raw['created_user_name'],
      fallback: asString(raw['originator']),
    ),
    versionNum: asInt(raw['version_num']),
    copyCount: asInt(raw['copy_count'], fallback: asInt(raw['copyCount'])),
    interactCount: asInt(
      raw['interact_count'],
      fallback: asInt(
        raw['connect_count'],
        fallback: asInt(raw['interactCount']),
      ),
    ),
    characterCount: asInt(raw['character_cnt']),
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
    ownerName: asString(
      raw['owner_name'],
      fallback: asString(raw['created_user_name']),
    ),
    progressCount: asInt(raw['tick_cnt']),
    interactCount: asInt(raw['connect_cnt']),
    characterCount: asInt(
      raw['ai_character_cnt'],
      fallback: asInt(raw['character_cnt']),
    ),
    playerCount: asInt(raw['player_cnt']),
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

String _loginResponseUid(
  Map<String, dynamic> userMap, {
  required String fallbackUid,
}) {
  return asString(
    userMap['id'],
    fallback: asString(
      userMap['uid'],
      fallback: asString(
        userMap['user_id'],
        fallback: asString(userMap['api_user_id'], fallback: fallbackUid),
      ),
    ),
  ).trim();
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
