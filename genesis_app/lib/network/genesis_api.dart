import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'api_exception.dart';
import 'app_request_headers.dart';
import 'chatroom/chatroom_http_api.dart';
import 'gateway_auth.dart';
import 'json_utils.dart';
import 'local_mock_genesis_transport.dart';
import 'models/location_tree.dart';
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
import '../utils/entity_deleted.dart';
import '../utils/genesis_image_resource.dart';

class GenesisApi {
  static const String defaultBaseHost = 'https://dev.hushie.ai';
  static const String defaultApiBaseUrl = '$defaultBaseHost/api/';
  static const String defaultGatewayApiBaseUrl = '$defaultBaseHost/apix/';
  static const String defaultAssetBaseUrl = 'https://af.hushie.ai/html/';
  static const String defaultChatroomWsBaseUrl =
      'wss://dev.hushie.ai/aitown-chat/ws';
  static const String defaultChatroomHttpBaseUrl = 'https://dev.hushie.ai/';

  GenesisApi({
    ApiClient? apiClient,
    ApiClient? gatewayApiClient,
    ApiClient? healthClient,
    ApiClient? chatroomHttpClient,
    HttpTransport? transport,
    bool? useMock,
    PlatformConfig? platformConfig,
    String? gatewayApiBaseUrl,
    String? chatroomHttpBaseUrl,
    DeviceIdService? deviceIdService,
    UserSessionStore? sessionStore,
    IdentityAuthService? identityAuthService,
    RequestHeaderProvider? appHeaderProvider,
    GatewayRequestInterceptor? gatewayRequestInterceptor,
    Future<void> Function(String message)? onSessionExpired,
  }) {
    final resolvedPlatformConfig =
        platformConfig ?? const DefaultPlatformConfig();
    _deviceIdService = deviceIdService ?? const NativeDeviceIdService();
    _sessionStore = sessionStore ?? NativeUserSessionStore();
    _identityAuthService =
        identityAuthService ?? const GoogleFirebaseAuthService();
    _appHeaderProvider =
        appHeaderProvider ?? AppRequestHeaderProvider().headers;
    _onSessionExpired = onSessionExpired;
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
          },
          requestHeaderProvider: _runtimeRequestHeaders,
          requestInterceptor: gatewayRequestInterceptor?.call,
          transport: resolvedTransport,
          responseProcessor: _processGenesisResponse,
        );
    final gatewayClient =
        gatewayApiClient ??
        ApiClient(
          baseUrl: _normalizeBaseUrl(
            gatewayApiBaseUrl ?? defaultGatewayApiBaseUrl,
          ),
          defaultHeaders: {
            'content-type': 'application/json',
            'accept': 'application/json',
          },
          requestHeaderProvider: _runtimeRequestHeaders,
          requestInterceptor: gatewayRequestInterceptor?.call,
          transport: resolvedTransport,
          responseProcessor: _processGenesisResponse,
        );
    _healthClient = healthClient ?? gatewayClient;
    _chatroomHttpClient =
        chatroomHttpClient ??
        ApiClient(
          baseUrl: _normalizeBaseUrl(
            chatroomHttpBaseUrl ?? defaultChatroomHttpBaseUrl,
          ),
          defaultHeaders: const {
            'content-type': 'application/json',
            'accept': 'application/json',
          },
          requestHeaderProvider: _runtimeRequestHeaders,
          requestInterceptor: gatewayRequestInterceptor?.call,
          transport: resolvedTransport,
          responseProcessor: _processGenesisResponse,
        );
    v1 = GenesisV1Api(_apiClient);
    chatroomHttp = ChatroomHttpApi(_chatroomHttpClient);
  }

  late final ApiClient _apiClient;
  late final ApiClient _healthClient;
  late final ApiClient _chatroomHttpClient;
  late final GenesisV1Api v1;
  late final ChatroomHttpApi chatroomHttp;
  late final DeviceIdService _deviceIdService;
  late final UserSessionStore _sessionStore;
  late final IdentityAuthService _identityAuthService;
  late final RequestHeaderProvider _appHeaderProvider;
  late final Future<void> Function(String message)? _onSessionExpired;

  static final Map<int, String> _originIdToWorldview = <int, String>{};

  Future<Map<String, String>> _runtimeRequestHeaders() async {
    final headers = <String, String>{...await _safeAppHeaders()};

    final authToken = await _readHeaderValue(_sessionStore.readAuthToken);
    if (authToken != null) {
      headers['authorization'] = authToken.toLowerCase().startsWith('bearer ')
          ? authToken
          : 'Bearer $authToken';
    }
    return headers;
  }

  Future<Map<String, String>> _safeAppHeaders() async {
    try {
      return stripLegacyAppPublicHeaders(await _appHeaderProvider());
    } catch (_) {
      return const <String, String>{};
    }
  }

  Future<String?> _readHeaderValue(Future<String?> Function() read) async {
    try {
      final value = (await read())?.trim();
      return value == null || value.isEmpty ? null : value;
    } catch (_) {
      return null;
    }
  }

  Object? _processGenesisResponse(ApiResponse response) {
    _throwIfSessionExpired(response);
    return _defaultGenesisProcessor(response);
  }

  void _throwIfSessionExpired(ApiResponse response) {
    final data = response.data;
    if (data is! Map) return;
    final map = asJsonMap(data);
    final errNoRaw = map.containsKey('err_no') ? map['err_no'] : map['errNo'];
    final errNo = asInt(errNoRaw);
    if (errNo != 10001) return;

    const message = 'Your account is logged in on another device.';
    final handler = _onSessionExpired;
    if (handler != null) unawaited(handler(message));
    throw ApiException(
      message: message,
      code: errNo,
      statusCode: response.statusCode,
      responseBody: response.body,
      responseHeaders: response.headers,
      uri: response.uri,
    );
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
        avatar: _resolveImageAssetUrl(
          profile['avatar_url'],
          fallback: profile['avatar'],
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
      avatar: _resolveImageAssetUrl(
        profile['avatar_url'],
        fallback: profile['avatar'],
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

  Future<void> logout({Map<String, String>? headers}) async {
    debugPrint('[Auth][GenesisApi] POST /api/v1/user/logout start');
    await v1.user.logout(headers: headers);
    debugPrint('[Auth][GenesisApi] POST /api/v1/user/logout success');
  }

  Future<void> deleteAccount({Map<String, String>? headers}) async {
    debugPrint('[Auth][GenesisApi] POST /api/v1/user/delete start');
    await v1.user.deleteAccount(headers: headers);
    debugPrint('[Auth][GenesisApi] POST /api/v1/user/delete success');
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
      avatar: _resolveImageAssetUrl(
        userMap['avatar_url'],
        fallback: userMap['avatar'] ?? userMap['picture'],
      ),
      createdAt: null,
    );
    if (user.uid.trim().isNotEmpty) {
      await _sessionStore.saveUid(user.uid);
    }
    final cachedUserInfo = Map<String, dynamic>.from(userMap);
    cachedUserInfo['uid'] = user.uid;
    if (user.nickname.trim().isNotEmpty) {
      cachedUserInfo.putIfAbsent('name', () => user.nickname);
    }
    if (user.avatar.trim().isNotEmpty) {
      cachedUserInfo.putIfAbsent('avatar', () => user.avatar);
    }
    await _sessionStore.saveUserInfo(cachedUserInfo);
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

  Future<OriginDetail> getOriginInfo(String oid) async {
    final detail = _originDetailFromV1(await v1.origin.info(oid: oid));
    _originIdToWorldview[detail.id] = detail.oid;
    return detail;
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
    return _worldDetailFromV1(await v1.world.detail(worldId: wid));
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
    final map = await v1.world.tick(worldId: wid);
    final tickCount = asInt(map['tick_cnt']);
    if (tickCount > 0) {
      return 'Tick $tickCount';
    }
    return asString(map['status'], fallback: 'Progress complete');
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
    final json = await _healthClient.get<Object?>('v1/heartbeat');
    final map = asJsonMap(json);
    if (map.containsKey('err_no') || map.containsKey('errNo')) {
      return asInt(map.containsKey('err_no') ? map['err_no'] : map['errNo']) ==
          0;
    }
    return asString(map['status']) == 'ok';
  }

  Future<CreateOriginResult> createOrigin({
    required Map<String, dynamic> payload,
  }) async {
    final events = _createOriginEventStrings(payload['event_list']);
    final created = await v1.origin.create(
      originName: asString(payload['name']),
      originVersion: _createOriginOptionalString(payload['origin_version']),
      brief: asString(payload['world_view']),
      setting: asString(payload['world_setting']),
      events: events.isEmpty ? null : events,
      tags: _createOriginStringList(payload['tags']),
      metric: payload['metric'] is Map ? asJsonMap(payload['metric']) : null,
      startedAt: _createOriginOptionalString(payload['started_at']),
      tickDurationTime: _createOriginTickDurationTime(payload),
      cover: asString(payload['cover']),
      characters: _createOriginCharacters(payload),
      locations: _createOriginLocations(payload),
    );
    final detail = created['info'] is Map
        ? asJsonMap(created['info'])
        : created['origin'] is Map
        ? asJsonMap(created['origin'])
        : created;
    final oid = asString(
      detail['origin_id'],
      fallback: asString(
        detail['oid'],
        fallback: asString(created['origin_id']),
      ),
    );
    return CreateOriginResult(worldviewId: oid, oid: oid);
  }

  Future<CreateOriginResult> updateOrigin({
    required String oid,
    required Map<String, dynamic> payload,
  }) async {
    final events = _createOriginEventStrings(payload['event_list']);
    final updated = await v1.origin.update(
      originId: asString(payload['origin_id'], fallback: oid),
      originName: asString(payload['name']),
      originVersion: _createOriginOptionalString(payload['origin_version']),
      brief: asString(payload['world_view']),
      setting: asString(payload['world_setting']),
      events: events.isEmpty ? null : events,
      tags: _createOriginStringList(payload['tags']),
      metric: payload['metric'] is Map ? asJsonMap(payload['metric']) : null,
      startedAt: _createOriginOptionalString(payload['started_at']),
      tickDurationTime: _createOriginTickDurationTime(payload),
      cover: asString(payload['cover']),
      characters: _createOriginCharacters(payload),
      locations: _createOriginLocations(payload),
      deletedCharIds:
          _createOriginStringList(payload['deleted_char_ids']) ??
          const <String>[],
      deletedLocationIds:
          _createOriginStringList(payload['deleted_location_ids']) ??
          const <String>[],
      updateNotes: _createOriginOptionalString(payload['update_notes']),
    );
    final detail = updated['info'] is Map
        ? asJsonMap(updated['info'])
        : updated['origin'] is Map
        ? asJsonMap(updated['origin'])
        : updated;
    final updatedOid = asString(
      detail['origin_id'],
      fallback: asString(
        detail['oid'],
        fallback: asString(updated['origin_id'], fallback: oid),
      ),
    );
    return CreateOriginResult(worldviewId: updatedOid, oid: updatedOid);
  }
}

class CreateOriginResult {
  const CreateOriginResult({required this.worldviewId, required this.oid});

  final String worldviewId;
  final String oid;
}

class MyWorldSummary {
  const MyWorldSummary({
    required this.wid,
    required this.name,
    this.deleted = false,
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
  final bool deleted;
  final String snapshotCoverUrl;
  final String updatedAtText;
  final String ownerName;
  final int progressCount;
  final int interactCount;
  final int characterCount;
  final int playerCount;
}

class WorldSummaryLatestItem {
  const WorldSummaryLatestItem({
    required this.worldId,
    required this.originId,
    this.deleted = false,
    required this.tickNo,
    required this.summary,
    required this.tickTime,
    required this.createdAt,
  });

  final String worldId;
  final String originId;
  final bool deleted;
  final int tickNo;
  final String summary;
  final int tickTime;
  final int createdAt;
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
    this.deleted = false,
  });

  final String uid;
  final String displayName;
  final String avatarUrl;
  final String userCode;
  final bool deleted;
}

HttpTransport? _resolveTransport({
  required HttpTransport? transport,
  required bool? useMock,
}) {
  if (transport != null) return transport;
  const apiEnvironment = String.fromEnvironment('GENESIS_API_ENV');
  final environmentUseMock = _mockEnabledByApiEnvironment(apiEnvironment);
  final enabled = useMock ?? environmentUseMock ?? false;
  if (!enabled) return null;
  return LocalMockGenesisTransport.instance;
}

List<Map<String, dynamic>> _payloadMapList(Object? raw) {
  if (raw is! List) return const <Map<String, dynamic>>[];
  return raw.map((item) => asJsonMap(item)).toList(growable: false);
}

List<String>? _createOriginStringList(Object? raw) {
  if (raw is! List) return null;
  final values = raw
      .map((item) => '$item'.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
  return values.isEmpty ? null : values;
}

List<String> _createOriginEventStrings(Object? raw) {
  if (raw is! List) return const <String>[];
  return raw
      .map((item) {
        if (item is Map) {
          return asString(item['content'], fallback: asString(item['event']));
        }
        return '$item';
      })
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

String? _createOriginOptionalString(Object? raw) {
  final value = asString(raw).trim();
  return value.isEmpty ? null : value;
}

int? _createOriginOptionalInt(Object? raw) {
  if (raw == null) return null;
  if (raw is String && raw.trim().isEmpty) return null;
  return asInt(raw);
}

String? _createOriginTickDurationTime(Map<String, dynamic> payload) {
  final value = _createOriginOptionalString(payload['tick_duration_time']);
  if (value != null) return value;
  final days = _createOriginOptionalInt(payload['tick_duration_days']);
  if (days == null) return null;
  return days == 1 ? '1 day' : '$days days';
}

List<Map<String, dynamic>> _createOriginCharacters(
  Map<String, dynamic> payload,
) {
  final locations = _payloadMapList(payload['location_list']);
  final initialLocationByCharacter = <String, String>{};
  for (final location in locations) {
    final locationId = asString(location['location_id']).trim();
    final characterIds = location['initial_character_ids'];
    if (locationId.isEmpty || characterIds is! List) continue;
    for (final charIdRaw in characterIds) {
      final charId = '$charIdRaw'.trim();
      if (charId.isNotEmpty) initialLocationByCharacter[charId] = locationId;
    }
  }

  return _payloadMapList(payload['character_list'])
      .map((item) {
        final charId = asString(item['char_id']).trim();
        return <String, dynamic>{
          if (charId.isNotEmpty) 'char_id': charId,
          'name': asString(item['name']),
          'identity': asString(item['identity']),
          'personality': asString(
            item['personality'],
            fallback: asString(
              item['tagline'],
              fallback: asString(item['brief']),
            ),
          ),
          'bio': asString(item['bio'], fallback: asString(item['description'])),
          'goal': asString(item['goal']),
          'avatar': asString(item['avatar']),
          'initial_location_id': asString(
            item['initial_location_id'],
            fallback: initialLocationByCharacter[charId] ?? '',
          ),
        };
      })
      .toList(growable: false);
}

List<Map<String, dynamic>> _createOriginLocations(
  Map<String, dynamic> payload,
) {
  final rawLocations = _payloadMapList(payload['location_list']);
  return rawLocations
      .map((item) {
        return <String, dynamic>{
          if (asString(item['location_id']).trim().isNotEmpty)
            'location_id': asString(item['location_id']).trim(),
          'level': asInt(item['level']),
          'location_name': asString(
            item['location_name'],
            fallback: asString(item['name']),
          ),
          'location_description': asString(
            item['location_description'],
            fallback: asString(
              item['description'],
              fallback: asString(item['location_summary']),
            ),
          ),
          'location_summary': asString(item['location_summary']),
          'image': asString(item['image'], fallback: asString(item['icon'])),
          'x_percent': asInt(item['x_percent']),
          'y_percent': asInt(item['y_percent']),
          'map_url': asString(item['map_url']),
        };
      })
      .toList(growable: false);
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
    message: 'Something went wrong',
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

const Map<String, String> _predataDefaultImageAssets = <String, String>{
  'https://cdn-001.worldo.ai/predata/root_default.webp':
      'assets/images/mock_maps/root_default.webp',
  'https://cdn-001.worldo.ai/predata/l1_default.webp':
      'assets/images/mock_maps/l1_default.webp',
  'https://cdn-001.worldo.ai/predata/l2_default.webp':
      'assets/images/mock_maps/l2_default.webp',
  'https://cdn-001.worldo.ai/predata/location_default.webp':
      'assets/images/mock_maps/location_default.webp',
};

String resolveAssetUrl(String raw) {
  final value = normalizeRemoteUrl(raw);
  if (value.isEmpty) return '';
  if (value.startsWith('assets/')) return value;
  final predataDefaultAsset = _predataDefaultImageAssets[value];
  if (predataDefaultAsset != null) return predataDefaultAsset;
  if (value.startsWith('http://') || value.startsWith('https://')) return value;

  final base = GenesisApi.defaultAssetBaseUrl;
  if (value.startsWith('/')) return '$base${value.substring(1)}';
  return '$base$value';
}

String _resolveImageAssetUrl(Object? raw, {Object? fallback}) {
  final resource = GenesisImageResource.fromJson(
    raw,
    fallback: fallback,
  ).mapUrls(resolveAssetUrl);
  return GenesisImageResourceRegistry.register(resource).displayUrl;
}

int _pageFromOffset({required int limit, required int offset}) {
  if (limit <= 0 || offset <= 0) return 1;
  return (offset ~/ limit) + 1;
}

OriginSummary _originSummaryFromV1ListItem(Map<String, dynamic> raw) {
  final origin = raw['info'] is Map ? asJsonMap(raw['info']) : raw;
  final stats = raw['stats'] is Map ? asJsonMap(raw['stats']) : raw;
  final oid = asString(origin['oid'], fallback: asString(origin['origin_id']));
  final cover = _resolveImageAssetUrl(
    origin['cover'],
    fallback: origin['map_url'],
  );
  final mapUrlRaw = asString(origin['map_url']).trim();
  final mapUrl = mapUrlRaw.isNotEmpty ? resolveAssetUrl(mapUrlRaw) : cover;

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
    worldMap: mapUrl,
    worldView: asString(
      origin['world_view'],
      fallback: asString(origin['setting']),
    ),
    deleted: entityDeleted(
      origin['deleted'],
      fallback: origin['origin_deleted'],
    ),
    originator: _originatorFromOriginMap(origin),
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
  final cover = _resolveImageAssetUrl(
    world['snapshot_cover_url'],
    fallback: world['cover'] ?? world['map_url'] ?? world['cover_url'],
  );

  return MyWorldSummary(
    wid: wid,
    name: name,
    deleted: entityDeleted(
      raw['world_deleted'],
      fallback: entityDeleted(
        world['world_deleted'],
        fallback: world['deleted'],
      ),
    ),
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

WorldSummaryLatestItem _worldSummaryLatestItemFromV1(Map<String, dynamic> raw) {
  return WorldSummaryLatestItem(
    worldId: asString(raw['world_id']),
    originId: asString(raw['origin_id']),
    deleted: entityDeleted(raw['world_deleted'], fallback: raw['deleted']),
    tickNo: asInt(raw['tick_no']),
    summary: asString(raw['summary']),
    tickTime: asInt(raw['tick_time']),
    createdAt: asInt(raw['created_at']),
  );
}

String _originatorFromOriginMap(Map<String, dynamic> origin) {
  return asString(
    origin['owner_name'],
    fallback: asString(
      origin['created_user_name'],
      fallback: asString(origin['originator']),
    ),
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
  final mapImage = _resolveImageAssetUrl(
    raw['Omap_image'],
    fallback: raw['Oworld_view_image'],
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
          characterId: asString(c['character_id'], fallback: asString(c['id'])),
          originId: originId,
          name: asString(c['name']),
          avatar: _resolveImageAssetUrl(c['image']),
          tags: asString(c['identity']),
          tagline: asString(c['tagline']),
          description: asString(c['intro']),
          goal: asString(c['goal']),
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
          icon: _resolveImageAssetUrl(p['image']),
          mapUrl: asString(p['map_url']),
          description: '',
          position: i + 1,
          isActive: true,
          xPercent: x,
          yPercent: y,
          createdAt: null,
          updatedAt: null,
          locationId: asString(p['location_id'], fallback: '$id'),
          parentLocationId: asString(p['location_pid']),
        );
      })
      .toList(growable: false);
}

Map<String, dynamic> _normalizeWorldLocation(Map<String, dynamic> location) {
  final locationId = asString(location['location_id']);
  final parentLocationId = asString(location['location_pid']);
  final pointId = asString(location['point_id'], fallback: locationId);
  final xPercentRaw = location['x_percent'];
  final yPercentRaw = location['y_percent'];

  double xPercent = xPercentRaw is num
      ? xPercentRaw.toDouble()
      : double.tryParse('$xPercentRaw') ?? 0;
  double yPercent = yPercentRaw is num
      ? yPercentRaw.toDouble()
      : double.tryParse('$yPercentRaw') ?? 0;

  final locationName = asString(
    location['location_name'],
    fallback: asString(location['name']),
  );
  final locationSummary = asString(
    location['location_summary'],
    fallback: asString(location['summary']),
  );
  final locationDescription = asString(
    location['location_description'],
    fallback: asString(location['description']),
  );

  return {
    'location_id': locationId,
    'location_pid': parentLocationId,
    'point_id': pointId,
    'location_name': locationName,
    'location_summary': locationSummary,
    'location_description': locationDescription,
    'location_paragraph': asString(location['location_paragraph']),
    'location_timestamp': asString(location['location_timestamp']),
    'image': location['image'],
    'icon': _resolveImageAssetUrl(location['image']),
    'map_url': asString(location['map_url']),
    'dialogue': location['dialogue'] is List
        ? asJsonList(
            location['dialogue'],
          ).map((e) => asJsonMap(e)).toList(growable: false)
        : const <Map<String, dynamic>>[],
    'x_percent': xPercent,
    'y_percent': yPercent,
  };
}

OriginDetail _originDetailFromV1(Map<String, dynamic> raw) {
  final origin = raw['origin'] is Map
      ? asJsonMap(raw['origin'])
      : asJsonMap(raw['info']);
  final ownerUser = origin['owner_user'] is Map
      ? asJsonMap(origin['owner_user'])
      : const <String, dynamic>{};
  final stats = raw['stats'] is Map ? asJsonMap(raw['stats']) : origin;
  final oid = asString(origin['oid'], fallback: asString(origin['origin_id']));
  final id = _stableInt(oid);
  final cover = _resolveImageAssetUrl(
    origin['cover'],
    fallback: origin['map_url'],
  );
  final mapUrlRaw = asString(origin['map_url']).trim();
  final mapUrl = mapUrlRaw.isNotEmpty ? resolveAssetUrl(mapUrlRaw) : cover;
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
  final locationTree = buildOriginLocationTree(
    locations,
    originMapUrl: mapUrl,
    originId: id,
  );
  final events = _originEventsFromV1(raw);
  final ticks = _originTicksFromV1(raw);

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
    worldMap: mapUrl,
    worldView: asString(
      origin['brief'],
      fallback: asString(
        origin['world_view'],
        fallback: asString(origin['setting']),
      ),
    ),
    deleted: entityDeleted(
      origin['deleted'],
      fallback: origin['origin_deleted'],
    ),
    ownerDeleted: entityDeleted(
      ownerUser['deleted'],
      fallback: origin['owner_deleted'],
    ),
    ownerUid: asString(
      origin['owner_uid'],
      fallback: asString(origin['created_uid']),
    ),
    originator: asString(
      origin['owner_name'],
      fallback: asString(
        origin['created_user_name'],
        fallback: asString(origin['originator']),
      ),
    ),
    versionNum: asInt(
      origin['version_num'],
      fallback: asInt(
        origin['origin_version'],
        fallback: asInt(origin['origin_version_num']),
      ),
    ),
    startTime: asString(
      origin['started_at'],
      fallback: asString(origin['start_time']),
    ),
    copyCount: asInt(stats['copy_cnt']),
    interactCount: asInt(stats['connect_cnt']),
    discussCount: asInt(stats['discuss_cnt']),
    characterCount: asInt(
      stats['character_cnt'],
      fallback: asInt(stats['ai_character_cnt'], fallback: characters.length),
    ),
    tags: _tagsFromV1(origin['tags']),
    createdAt: _apiDateTime(origin['created_at']),
    updatedAt: _apiDateTime(
      origin['updated_at'] ?? origin['origin_version_time'],
    ),
    characters: characters,
    locations: buildOriginLocationHierarchy(locations),
    allLocations: locations,
    locationTree: locationTree,
    processedLocationTree: processLocationTree(locationTree),
    events: events,
    ticks: ticks,
  );
}

List<Map<String, dynamic>> _originTicksFromV1(Map<String, dynamic> raw) {
  final ticksRaw = raw['tick_list'] ?? raw['ticks'];
  if (ticksRaw is! List) return const <Map<String, dynamic>>[];
  return asJsonList(ticksRaw).indexed
      .map((entry) {
        final index = entry.$1;
        final tick = asJsonMap(entry.$2);
        final result = tick['tick_result'] is Map
            ? asJsonMap(tick['tick_result'])
            : tick;
        final paragraphsRaw = result['paragraphs'];
        final paragraphs = paragraphsRaw is List
            ? asJsonList(
                paragraphsRaw,
              ).map((e) => asJsonMap(e)).toList(growable: false)
            : const <Map<String, dynamic>>[];
        final locationGroupsRaw = result['location_groups'];
        final locationGroups = locationGroupsRaw is List
            ? asJsonList(
                locationGroupsRaw,
              ).map((e) => asJsonMap(e)).toList(growable: false)
            : const <Map<String, dynamic>>[];

        return <String, dynamic>{
          'tick_id': asString(tick['tick_id']),
          'tick_no': asInt(tick['tick_no'], fallback: index + 1),
          'status': asInt(tick['status']),
          'created_at': tick['created_at'],
          'tick_result': <String, dynamic>{
            'current_time': asString(
              result['current_time'],
              fallback: asString(tick['current_time']),
            ),
            'narrator': asString(
              result['narrator'],
              fallback: asString(
                tick['narrator'],
                fallback: asString(tick['summary']),
              ),
            ),
            'paragraphs': paragraphs,
            'location_groups': locationGroups,
          },
        };
      })
      .toList(growable: false);
}

List<OriginEvent> _originEventsFromV1(Map<String, dynamic> raw) {
  final info = raw['info'] is Map ? asJsonMap(raw['info']) : const {};
  final eventsRaw = raw['event_list'] ?? raw['events'] ?? info['events'];
  if (eventsRaw is List) {
    return asJsonList(eventsRaw)
        .map(_originEventFromV1)
        .where((event) => event.content.trim().isNotEmpty)
        .toList(growable: false);
  }

  final ticksRaw = raw['tick_list'] ?? raw['ticks'];
  if (ticksRaw is! List) return const <OriginEvent>[];

  final events = <OriginEvent>[];
  for (final tick in asJsonList(ticksRaw)) {
    final tickMap = asJsonMap(tick);
    final tickResult = tickMap['tick_result'] is Map
        ? asJsonMap(tickMap['tick_result'])
        : tickMap;
    final narrator = asString(
      tickResult['narrator'],
      fallback: asString(
        tickMap['narrator'],
        fallback: asString(tickMap['summary']),
      ),
    );
    if (narrator.trim().isNotEmpty) {
      events.add(
        OriginEvent(
          label: 'Global',
          timestamp: asString(tickMap['created_at']),
          content: narrator,
        ),
      );
    }

    final paragraphs = tickResult['paragraphs'];
    if (paragraphs is List) {
      for (final paragraph in asJsonList(paragraphs)) {
        final event = OriginEvent.fromJson(asJsonMap(paragraph));
        if (event.content.trim().isNotEmpty) events.add(event);
      }
    }
  }
  return events;
}

OriginEvent _originEventFromV1(Object? raw) {
  if (raw is Map) return OriginEvent.fromJson(asJsonMap(raw));
  return OriginEvent(label: '', timestamp: '', content: asString(raw));
}

WorldDetail _worldDetailFromV1(Map<String, dynamic> raw) {
  final world = asJsonMap(raw['info']);
  final ownerUser = world['owner_user'] is Map
      ? asJsonMap(world['owner_user'])
      : const <String, dynamic>{};
  final stats = asJsonMap(raw['stats']);
  final wid = asString(world['world_id']);
  final oid = asString(world['origin_id']);
  final worldId = _stableInt(wid);
  final originId = _stableInt(oid);
  final cover = _resolveImageAssetUrl(
    world['cover'],
    fallback: world['map_url'],
  );
  final mapUrlRaw = asString(world['map_url']).trim();
  final mapUrl = mapUrlRaw.isNotEmpty ? resolveAssetUrl(mapUrlRaw) : cover;
  final locationsRaw = raw['locations'];
  final locations = locationsRaw is List
      ? asJsonList(locationsRaw)
            .map((e) => _normalizeWorldLocation(asJsonMap(e)))
            .toList(growable: false)
      : const <Map<String, dynamic>>[];
  final locationTree = buildWorldLocationTree(locations, worldMapUrl: mapUrl);
  final charactersRaw = raw['characters'];
  final characters = charactersRaw is List
      ? asJsonList(charactersRaw)
            .map((e) => _worldCharacterFromV1(asJsonMap(e)))
            .toList(growable: false)
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
      ? asJsonList(ticksRaw).indexed
            .map((entry) => _worldTickFromV1(asJsonMap(entry.$2), entry.$1))
            .toList(growable: false)
      : const <Map<String, dynamic>>[];
  final lastTick = ticks.isNotEmpty ? ticks.last : const <String, dynamic>{};
  final lastTickResult = lastTick['tick_result'] is Map
      ? asJsonMap(lastTick['tick_result'])
      : const <String, dynamic>{};

  return WorldDetail(
    id: worldId,
    worldId: wid,
    originId: originId,
    ownerUid: asString(world['owner_uid']),
    ownerName: asString(world['owner_name']),
    name: asString(world['world_name']),
    brief: asString(world['brief'], fallback: asString(world['setting'])),
    cover: cover,
    deleted: entityDeleted(
      raw['world_deleted'],
      fallback: entityDeleted(
        world['world_deleted'],
        fallback: world['deleted'],
      ),
    ),
    ownerDeleted: entityDeleted(
      ownerUser['deleted'],
      fallback: world['owner_deleted'],
    ),
    tickCount: asInt(stats['tick_cnt']),
    connectCount: asInt(stats['connect_cnt']),
    characterCount: asInt(stats['character_cnt']),
    playerCount: asInt(stats['player_cnt']),
    currentTime: asString(world['current_time']),
    mapImageUrl: mapUrl,
    latestTickAt: _apiDateTime(lastTick['created_at'] ?? world['created_at']),
    latestNarrator: asString(lastTickResult['narrator']),
    isProgressing: asInt(world['status']) == 20,
    relationStatus: asString(raw['relation_status']),
    metric: world['metric'] is Map
        ? asJsonMap(world['metric'])
        : const <String, dynamic>{},
    inviteToken: wid,
    createdAt: _apiDateTime(world['created_at']),
    updatedAt: _apiDateTime(world['updated_at']),
    origin: OriginSummary(
      id: originId,
      oid: oid,
      name: asString(world['world_name']),
      description: asString(
        world['setting'],
        fallback: asString(world['brief']),
      ),
      mapImage: cover,
      worldMap: mapUrl,
      worldView: asString(world['setting']),
      deleted: entityDeleted(
        world['origin_deleted'],
        fallback: world['origin'] is Map
            ? asJsonMap(world['origin'])['deleted']
            : null,
      ),
      originator: asString(world['owner_name']),
      versionNum: asInt(world['origin_version']),
      copyCount: 0,
      interactCount: asInt(stats['connect_cnt']),
      characterCount: asInt(stats['character_cnt']),
      tags: _tagsFromV1(world['tags']),
      createdAt: _apiDateTime(world['created_at']),
      updatedAt: _apiDateTime(world['updated_at']),
      characters: const <OriginCharacter>[],
      locations: const <OriginLocation>[],
    ),
    characters: characters,
    ticks: ticks,
    locations: locations,
    locationTree: locationTree,
    processedLocationTree: processLocationTree(locationTree),
    characterPositions: characterPositions,
    userPositions: userPositions,
  );
}

OriginCharacter _originCharacterFromV1(Map<String, dynamic> raw, int originId) {
  final playerUser = raw['player_user'] is Map
      ? asJsonMap(raw['player_user'])
      : const <String, dynamic>{};
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
    characterId: characterId,
    originId: originId,
    name: asString(raw['name']),
    playerUid: asString(raw['player_uid']),
    playerUsername: asString(
      playerUser['name'],
      fallback: asString(raw['player_username']),
    ),
    playerDeleted: entityDeleted(
      playerUser['deleted'],
      fallback: raw['player_deleted'],
    ),
    avatar: _resolveImageAssetUrl(raw['avatar']),
    tags: asString(raw['identity']),
    tagline: asString(raw['tagline'], fallback: asString(raw['brief'])),
    description: asString(
      raw['description'],
      fallback: asString(raw['brief'], fallback: asString(raw['tagline'])),
    ),
    goal: asString(raw['goal']),
    currentLocationId: stableLocationId,
    initialLocationId: stableLocationId,
    createdAt: _apiDateTime(raw['created_at']),
    updatedAt: _apiDateTime(raw['updated_at']),
  );
}

OriginLocation _originLocationFromV1(Map<String, dynamic> raw, int originId) {
  final locationId = asString(raw['location_id']);
  final parentLocationId = asString(raw['location_pid']);
  return OriginLocation(
    id: asInt(raw['id'], fallback: _stableInt(locationId)),
    originId: originId,
    name: asString(raw['name'], fallback: asString(raw['location_name'])),
    icon: _resolveImageAssetUrl(raw['image']),
    mapUrl: resolveAssetUrl(asString(raw['map_url'])),
    description: asString(
      raw['location_description'],
      fallback: asString(
        raw['description'],
        fallback: asString(raw['location_summary']),
      ),
    ),
    locationParagraph: asString(
      raw['location_paragraph'],
      fallback: asString(raw['location_garagraph']),
    ),
    position: asInt(raw['position']),
    isActive: true,
    xPercent: _asDouble(raw['x_percent']),
    yPercent: _asDouble(raw['y_percent']),
    createdAt: _apiDateTime(raw['created_at']),
    updatedAt: _apiDateTime(raw['updated_at']),
    locationId: locationId,
    parentLocationId: parentLocationId,
  );
}

Map<String, dynamic>? _worldCharacterPositionFromV1(Map<String, dynamic> raw) {
  final locationId = asString(raw['location_id']);
  if (locationId.isEmpty) return null;
  return {
    'location_id': locationId,
    'character': {
      'id': asString(raw['char_id']),
      'name': asString(raw['name']),
      'type': asString(raw['type']),
      'player_uid': asString(raw['player_uid']),
      'player_username': asString(raw['player_username']),
      'player_deleted': raw['player_deleted'],
      'identity': asString(raw['identity']),
      'tagline': asString(raw['brief']),
      'description': asString(raw['description']),
      'avatar': _resolveImageAssetUrl(raw['avatar']),
    },
  };
}

Map<String, dynamic> _worldCharacterFromV1(Map<String, dynamic> raw) {
  final playerUser = raw['player_user'] is Map
      ? asJsonMap(raw['player_user'])
      : const <String, dynamic>{};
  return {
    'char_id': asString(raw['char_id']),
    'type': asString(raw['type']),
    'player_uid': asString(raw['player_uid']),
    'player_username': asString(
      playerUser['name'],
      fallback: asString(raw['player_username']),
    ),
    'player_user': playerUser,
    'player_deleted': entityDeleted(
      playerUser['deleted'],
      fallback: raw['player_deleted'],
    ),
    'name': asString(raw['name']),
    'identity': asString(raw['identity']),
    'brief': asString(raw['brief']),
    'description': asString(raw['description']),
    'goal': asString(raw['goal']),
    'avatar': _resolveImageAssetUrl(raw['avatar']),
    'initial_location_id': asString(raw['initial_location_id']),
    'location_id': asString(raw['location_id']),
    'metric_value': raw['metric_value'],
  };
}

Map<String, dynamic> _worldTickFromV1(Map<String, dynamic> raw, int index) {
  final result = raw['tick_result'] is Map
      ? asJsonMap(raw['tick_result'])
      : const <String, dynamic>{};
  final paragraphsRaw = result['paragraphs'];
  final paragraphs = paragraphsRaw is List
      ? asJsonList(
          paragraphsRaw,
        ).map((e) => asJsonMap(e)).toList(growable: false)
      : const <Map<String, dynamic>>[];
  final locationGroupsRaw = result['location_groups'];
  final locationGroups = locationGroupsRaw is List
      ? asJsonList(
          locationGroupsRaw,
        ).map((e) => asJsonMap(e)).toList(growable: false)
      : const <Map<String, dynamic>>[];
  final createdAt = raw['created_at'];
  return {
    'tick_id': asString(raw['tick_id']),
    'tick_no': asInt(raw['tick_no'], fallback: index + 1),
    'status': asInt(raw['status']),
    'created_at': createdAt,
    'tick_result': {
      'narrator': asString(result['narrator']),
      'paragraphs': paragraphs,
      'location_groups': locationGroups,
    },
  };
}

Map<String, dynamic>? _worldUserPositionFromV1(Map<String, dynamic> raw) {
  final playerUid = asString(raw['player_uid']);
  if (playerUid.isEmpty) return null;
  final locationId = asString(raw['location_id']);
  if (locationId.isEmpty) return null;
  final playerUser = raw['player_user'] is Map
      ? asJsonMap(raw['player_user'])
      : const <String, dynamic>{};
  return {
    'uid': playerUid,
    'location_id': locationId,
    'deleted': entityDeleted(
      playerUser['deleted'],
      fallback: raw['player_deleted'],
    ),
  };
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
  final mapImage = _resolveImageAssetUrl(
    raw['map_image'],
    fallback: raw['snapshot_cover_url'],
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
    worldMap: _resolveImageAssetUrl(raw['world_map'], fallback: mapImage),
    worldView: asString(raw['world_view']),
    deleted: entityDeleted(raw['deleted'], fallback: raw['origin_deleted']),
    originator: _originatorFromOriginMap(raw),
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
    deleted: entityDeleted(raw['world_deleted'], fallback: raw['deleted']),
    snapshotCoverUrl: _resolveImageAssetUrl(
      raw['snapshot_cover_url'],
      fallback: raw['cover_url'] ?? raw['cover'],
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
    avatarUrl: asImageUrl(raw['avatar_url'], fallback: raw['avatar']),
    userCode: asString(raw['user_code'], fallback: uid),
    deleted: entityDeleted(raw['deleted']),
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
