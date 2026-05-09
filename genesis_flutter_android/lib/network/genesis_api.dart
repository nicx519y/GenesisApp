import 'api_client.dart';
import 'api_exception.dart';
import 'json_utils.dart';
import 'models/origin.dart';
import 'models/paged_response.dart';
import 'models/user.dart';
import 'models/world.dart';
import 'models/world_message.dart';
import '../platform/device_id.dart';
import '../platform/user_session.dart';

class GenesisApi {
  static const String defaultBaseHost = 'http://47.77.195.140:6001';
  static const String defaultApiBaseUrl = '$defaultBaseHost/api/v1/';
  static const String defaultAssetBaseUrl = 'https://af.hushie.ai/html/';

  GenesisApi({
    ApiClient? apiClient,
    ApiClient? healthClient,
  })  : _apiClient = apiClient ??
            ApiClient(
              baseUrl: _normalizeBaseUrl(defaultApiBaseUrl),
              defaultHeaders: const {
                'content-type': 'application/json',
                'accept': 'application/json',
              },
              responseProcessor: _defaultGenesisProcessor,
            ),
        _healthClient = healthClient ??
            ApiClient(
              baseUrl: _normalizeBaseUrl(defaultBaseHost),
              defaultHeaders: const {
                'accept': 'application/json',
              },
              responseProcessor: _defaultGenesisProcessor,
            );

  final ApiClient _apiClient;
  final ApiClient _healthClient;

  Future<String> ensureUid() => _ensureUid();

  Future<String> _ensureUid() async {
    final cached = await UserSession.readUid();
    if (cached != null && cached.trim().isNotEmpty) return cached;
    final user = await bindDevice();
    return user.uid;
  }

  Future<User> bindDevice({String? did}) async {
    final deviceId = did ?? await DeviceId.androidId();
    final json = await _apiClient.post<Object?>(
      'users/bind',
      body: {'did': deviceId},
    );
    final user = User.fromJson(_unwrapDataMap(json));
    await UserSession.saveUid(user.uid);
    return user;
  }

  Future<User> getUser(String uid) async {
    final json = await _apiClient.get<Object?>('users/$uid');
    return User.fromJson(_unwrapDataMap(json));
  }

  Future<PagedResponse<OriginSummary>> getOrigins({
    String category = 'For you',
    int limit = 20,
    int offset = 0,
  }) async {
    final json = await _apiClient.get<Object?>(
      'origins',
      query: {
        'category': category,
        'limit': limit,
        'offset': offset,
      },
    );
    final map = asJsonMap(json);
    final page = OriginListResponse.fromJson(
      map,
      limitFallback: limit,
      offsetFallback: offset,
    );
    return PagedResponse(
      data: page.data,
      total: page.total,
      limit: page.limit,
      offset: page.offset,
    );
  }

  Future<OriginDetail> getOrigin(String oid) async {
    final json = await _apiClient.get<Object?>('origins/$oid');
    final map = asJsonMap(json);
    final data = map['data'];
    return OriginDetail.fromJson(
      data is Map ? asJsonMap(data) : map,
    );
  }

  Future<PagedResponse<OriginSummary>> getMyLaunchedOrigins({
    String? uid,
    int limit = 20,
    int offset = 0,
  }) async {
    final resolvedUid = uid ?? await _ensureUid();
    final json = await _apiClient.get<Object?>(
      'origins/my/launched',
      query: {
        'uid': resolvedUid,
        'limit': limit,
        'offset': offset,
      },
    );
    final map = asJsonMap(json);
    final page = OriginListResponse.fromJson(
      map,
      limitFallback: limit,
      offsetFallback: offset,
    );
    return PagedResponse(
      data: page.data,
      total: page.total,
      limit: page.limit,
      offset: page.offset,
    );
  }

  Future<World> launchWorld({
    required int originId,
    String? ownerUid,
  }) async {
    final resolvedUid = ownerUid ?? await _ensureUid();
    final json = await _apiClient.post<Object?>(
      'worlds/launch',
      body: {
        'origin_id': originId,
        'owner_uid': resolvedUid,
      },
    );
    return World.fromJson(_unwrapDataMap(json));
  }

  Future<WorldDetail> getWorld(String wid) async {
    final json = await _apiClient.get<Object?>('worlds/$wid');
    return WorldDetail.fromJson(_unwrapDataMap(json));
  }

  Future<String> progressWorld(String wid) async {
    final json = await _apiClient.post<Object?>('worlds/$wid/progress');
    final map = asJsonMap(json);
    return asString(map['message']);
  }

  Future<JoinedWorld> joinWorld({
    required String inviteToken,
    String? uid,
  }) async {
    final resolvedUid = uid ?? await _ensureUid();
    final json = await _apiClient.post<Object?>(
      'worlds/join',
      body: {
        'invite_token': inviteToken,
        'uid': resolvedUid,
      },
    );
    return JoinedWorld.fromJson(_unwrapDataMap(json));
  }

  Future<String> updateUserPosition({
    required String wid,
    String? uid,
    required int locationId,
  }) async {
    final resolvedUid = uid ?? await _ensureUid();
    final json = await _apiClient.put<Object?>(
      'worlds/$wid/position',
      body: {
        'uid': resolvedUid,
        'location_id': locationId,
      },
    );
    final map = asJsonMap(json);
    return asString(map['message']);
  }

  Future<List<WorldMember>> getWorldMembers(String wid) async {
    final json = await _apiClient.get<Object?>('worlds/$wid/members');
    final data = _unwrapDataList(json);
    return data.map((e) => WorldMember.fromJson(asJsonMap(e))).toList(growable: false);
  }

  Future<WorldMessage> sendMessage({
    required String wid,
    String? uid,
    required int locationId,
    required String content,
  }) async {
    final resolvedUid = uid ?? await _ensureUid();
    final json = await _apiClient.post<Object?>(
      'worlds/$wid/messages',
      body: {
        'uid': resolvedUid,
        'location_id': locationId,
        'content': content,
      },
    );
    return WorldMessage.fromJson(_unwrapDataMap(json));
  }

  Future<PagedResponse<WorldMessage>> getLocationMessages({
    required String wid,
    required int locationId,
    int limit = 50,
    int offset = 0,
  }) async {
    final json = await _apiClient.get<Object?>(
      'worlds/$wid/locations/$locationId/messages',
      query: {
        'limit': limit,
        'offset': offset,
      },
    );
    final map = asJsonMap(json);
    final items = asJsonList(map['data'])
        .map((e) => WorldMessage.fromJson(asJsonMap(e)))
        .toList(growable: false);
    return PagedResponse(
      data: items,
      total: asInt(map['total'], fallback: items.length),
      limit: asInt(map['limit'], fallback: limit),
      offset: asInt(map['offset'], fallback: offset),
    );
  }

  Future<bool> health() async {
    final json = await _healthClient.get<Object?>('health');
    final map = asJsonMap(json);
    return asString(map['status']) == 'ok';
  }
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

Map<String, dynamic> _unwrapDataMap(Object? json) {
  final map = asJsonMap(json);
  final data = map['data'];
  return asJsonMap(data);
}

List _unwrapDataList(Object? json) {
  final map = asJsonMap(json);
  return asJsonList(map['data']);
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
