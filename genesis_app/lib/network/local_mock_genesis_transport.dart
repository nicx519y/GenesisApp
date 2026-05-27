import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'http_transport.dart';
import 'mock_data/mock_message_data.dart';
import 'mock_data/mock_origin_data.dart';
import 'mock_data/mock_profile_data.dart';
import 'mock_data/mock_v1_data.dart';
import 'mock_data/mock_world_data.dart';

class LocalMockGenesisTransport implements HttpTransport {
  LocalMockGenesisTransport._();

  static final LocalMockGenesisTransport instance =
      LocalMockGenesisTransport._();

  final _state = _MockState();

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    final path = request.uri.path;
    final query = request.uri.queryParameters;
    final method = request.method.toUpperCase();
    final body = _decodeBody(request.bodyBytes);

    if (path == '/health') {
      return _ok({'status': 'ok'});
    }

    final apiPath = path.startsWith('/api/')
        ? path.substring('/api/'.length)
        : path;

    if (apiPath.startsWith('v1/')) {
      return _handleV1(method, apiPath.substring('v1/'.length), query, body);
    }

    if (method == 'GET' && apiPath == 'auth/me/public-profile') {
      if (!_state.isAuthenticated) {
        return _error(401, 'unauthorized');
      }
      return _ok(_state.me);
    }

    if (method == 'POST' &&
        (apiPath == 'auth/google' || apiPath == 'auth/apple')) {
      _state.markAuthenticated();
      return _ok({
        'token': 'mock-jwt-token',
        'user': _state.googleUserPayload(),
      });
    }

    if (method == 'POST' && apiPath == 'auth/logout') {
      _state.markLoggedOut();
      return _ok({'ok': true});
    }

    if (method == 'GET' && apiPath == 'origins') {
      return _ok({'origins': _state.origins});
    }

    if (method == 'GET' && apiPath == 'origins/create-limits') {
      return _ok({
        'ok': true,
        'ai_characters_max': 8,
        'locations_max': 10,
        'events_max': 20,
      });
    }

    if (method == 'POST' && apiPath == 'origins') {
      final created = _state.createOrigin(body);
      return _ok({'ok': true, ...created});
    }

    if (method == 'GET' && apiPath == 'origins/popular') {
      final limit = int.tryParse(query['limit'] ?? '') ?? 20;
      final items = _state.origins.take(limit).toList(growable: false);
      return _ok({'origins': items});
    }

    final detailMatch = RegExp(r'^origins/([^/]+)/detail$').firstMatch(apiPath);
    if (method == 'GET' && detailMatch != null) {
      final worldviewId = detailMatch.group(1) ?? '';
      final origin = _state.originByWorldview(worldviewId);
      if (origin == null) return _error(404, 'origin not found');
      return _ok(origin);
    }

    if (method == 'POST' && apiPath == 'worlds/launch') {
      final uid = '${body['user_id'] ?? _state.me['id']}';
      final worldviewId = '${body['worldview_id'] ?? ''}';
      final worldName = '${body['world_name'] ?? 'World'}';
      final launched = _state.launchWorld(
        userId: uid,
        worldviewId: worldviewId,
        worldName: worldName,
      );
      return _ok({'ok': true, ...launched});
    }

    final worldMetaMatch = RegExp(
      r'^worlds/([^/]+)/public-meta$',
    ).firstMatch(apiPath);
    if (method == 'GET' && worldMetaMatch != null) {
      final wid = worldMetaMatch.group(1) ?? '';
      final world = _state.worldByWid(wid);
      if (world == null) return _error(404, 'world not found');
      return _ok({
        'ok': true,
        'is_owner': true,
        'owner_user_id': world['owner_user_id'],
        'owner_display_name': _state.me['display_name'],
        'owner_user_code': _state.me['user_code'],
        'world_name': world['world_name'],
        'display_wid_str': world['display_wid_str'],
        'has_entered': true,
        'join_status': 'approved',
        'can_request_join': false,
        'can_enter': true,
        'is_full': false,
      });
    }

    if (method == 'GET' && apiPath == 'tick') {
      final wid = query['wid'] ?? '';
      final tick = _state.tickByWid(wid);
      if (tick == null) return _error(404, 'tick not found');
      return _ok(tick);
    }

    if (method == 'POST' && apiPath == 'tick') {
      final wid = query['wid'] ?? '';
      final updated = _state.progressTick(wid);
      if (updated == null) return _error(404, 'tick not found');
      return _ok(updated);
    }

    if (method == 'GET' && apiPath == 'worldview-map') {
      final wid = query['wid'] ?? '';
      final map = _state.worldMapByWid(wid);
      if (map == null) return _error(404, 'map not found');
      return _ok(map);
    }

    if (method == 'GET' && apiPath == 'characters') {
      final wid = query['wid'] ?? '';
      final chars = _state.charactersByWid(wid);
      if (chars == null) return _error(404, 'characters not found');
      return _ok(chars);
    }

    if (method == 'POST' && apiPath == 'session/set-world') {
      return _ok({'ok': true});
    }

    if (method == 'POST' && apiPath == 'session/set-player-scene') {
      return _ok({'ok': true});
    }

    final pointMessagesMatch = RegExp(
      r'^points/([^/]+)/messages$',
    ).firstMatch(apiPath);
    if (method == 'GET' && pointMessagesMatch != null) {
      final pointId = pointMessagesMatch.group(1) ?? '';
      final limit = int.tryParse(query['limit'] ?? '') ?? 50;
      final messages = _state.messagesForPoint(pointId, limit: limit);
      return _ok({'messages': messages, 'has_more': false});
    }

    final enqueueMatch = RegExp(
      r'^points/([^/]+)/messages/enqueue$',
    ).firstMatch(apiPath);
    if (method == 'POST' && enqueueMatch != null) {
      final pointId = enqueueMatch.group(1) ?? '';
      final wid = '${body['wid'] ?? ''}';
      final message = _state.enqueuePointMessage(
        wid: wid,
        pointId: pointId,
        locationId: '${body['location_id'] ?? ''}',
        userId: '${body['user_id'] ?? _state.me['id']}',
        text: '${body['text'] ?? ''}',
      );
      return _ok({
        'ok': true,
        'user_message': {'id': message['id']},
      });
    }

    if (method == 'GET' && apiPath == 'worlds') {
      final userId = query['user_id'] ?? _state.me['id'];
      final worlds = _state.worldsForUser('$userId');
      return _ok({'worlds': worlds});
    }

    if (method == 'GET' && apiPath == 'search') {
      final raw = query['q'] ?? query['keyword'] ?? query['query'] ?? '';
      final q = raw.toString().trim();
      final result = _state.search(q);
      return _ok(result);
    }

    final joinMatch = RegExp(
      r'^worlds/([^/]+)/join-requests$',
    ).firstMatch(apiPath);
    if (method == 'POST' && joinMatch != null) {
      return _ok({'ok': true});
    }

    return _error(404, 'mock route not found: $method $path');
  }

  Future<TransportResponse> _handleV1(
    String method,
    String path,
    Map<String, String> query,
    Map<String, dynamic> body,
  ) async {
    if (method == 'POST' &&
        (path == 'user/oauth/google' || path == 'user/oauth/apple')) {
      _state.markAuthenticated();
      return _v1Ok(_state.v1AuthPayload());
    }

    if (method == 'POST' && path == 'user/logout') {
      _state.markLoggedOut();
      return _v1Ok(<String, dynamic>{});
    }

    if (method == 'GET' && path == 'user/info') {
      return _v1Ok(_state.v1UserInfo(query['uid']));
    }

    if (method == 'POST' && path == 'user/update') {
      return _v1Ok({'user': _state.updateV1User(body)});
    }

    if (method == 'GET' && path == 'user/profile') {
      return _v1Ok(_state.v1UserProfile(query['uid']));
    }

    if (method == 'GET' && path == 'user/origins') {
      return _v1Ok(_paged(_state.v1OriginSummaries(), query));
    }

    if (method == 'GET' && path == 'user/worlds') {
      return _v1Ok(_paged(_state.v1WorldSummaries(), query));
    }

    if (method == 'POST' && path == 'user/follow') {
      _state.v1FollowResult(followed: true);
      return _v1Ok(<String, dynamic>{});
    }

    if (method == 'POST' && path == 'user/unfollow') {
      _state.v1FollowResult(followed: false);
      return _v1Ok(<String, dynamic>{});
    }

    if (method == 'GET' && path == 'user/following') {
      return _v1Ok(_state.v1UserList(query, type: 'following'));
    }

    if (method == 'GET' && path == 'user/followers') {
      return _v1Ok(_state.v1UserList(query, type: 'followers'));
    }

    if (method == 'GET' && path == 'user/relations') {
      return _v1Ok(_paged(_state.v1Relations(), query));
    }

    if (method == 'POST' && path == 'users/relations/status') {
      final uids = body['uids'] is List
          ? body['uids'] as List
          : const <Object?>[];
      return _v1Ok({'relations': _state.v1RelationStatus(uids)});
    }

    if (method == 'GET' && path == 'origin/list') {
      return _v1Ok(_state.v1OriginContractList(query));
    }

    if (method == 'GET' && path == 'origin/detail') {
      return _v1Ok(
        _state.v1OriginContractDetail(query['origin_id'] ?? query['oid']),
      );
    }

    if (method == 'POST' && path == 'origin/create') {
      return _v1Ok(_state.createV1Origin(body));
    }

    if (method == 'POST' && path == 'origin/update') {
      return _v1Ok(_state.updateV1Origin(body));
    }

    if (method == 'POST' && path == 'origin/launch') {
      return _v1Ok({'wid': _state.launchV1World('${body['oid'] ?? ''}')});
    }

    if (method == 'GET' && path == 'origin/versionlist') {
      return _v1Ok(_state.v1OriginVersionList(query['oid']));
    }

    if (method == 'POST' && path == 'origin/publish') {
      return _v1Ok(_state.publishV1Origin('${body['oid'] ?? ''}'));
    }

    if (method == 'POST' && path == 'origin/del') {
      _state.deleteV1Origin('${body['oid'] ?? ''}');
      return _v1Ok(<String, dynamic>{});
    }

    if (method == 'GET' && path == 'world/list') {
      return _v1Ok(_state.v1WorldContractList(query));
    }

    if (method == 'GET' && path == 'world/detail') {
      return _v1Ok(_state.v1WorldContractDetail(query['world_id']));
    }

    if (method == 'POST' && path == 'world/request') {
      return _v1Ok(<String, dynamic>{});
    }

    if (method == 'POST' && path == 'world/request/audit') {
      return _v1Ok(<String, dynamic>{});
    }

    if (method == 'POST' && path == 'world/join') {
      return _v1Ok(_state.v1WorldDetail('${body['wid'] ?? ''}'));
    }

    if (method == 'POST' && path == 'world/tick') {
      await Future<void>.delayed(const Duration(seconds: 3));
      return _v1Ok(_state.tickV1World('${body['world_id'] ?? ''}'));
    }

    if (method == 'POST' &&
        (path == 'world/synclastorigin' ||
            path == 'world/close' ||
            path == 'world/del')) {
      return _v1Ok(<String, dynamic>{});
    }

    if (method == 'GET' && path == 'messages/unread-summary') {
      return _v1Ok(_state.v1UnreadSummary());
    }

    if (method == 'GET' && path == 'messages/notifications') {
      final category = query['category']?.trim();
      final items = _state.v1Notifications().where((item) {
        return category == null ||
            category.isEmpty ||
            item['category']?.toString() == category;
      }).toList();
      return _v1Ok(_paged(items, query));
    }

    if (method == 'POST' && path == 'messages/notifications/read') {
      final notificationIds = body['notification_ids'] is List
          ? body['notification_ids'] as List
          : const <Object?>[];
      _state.markV1NotificationsRead(
        category: body['category']?.toString(),
        notificationIds: notificationIds.map((id) => '$id').toList(),
      );
      return _v1Ok(<String, dynamic>{});
    }

    if (method == 'GET' && path == 'messages/followers') {
      return _v1Ok(_paged(_state.v1FollowerMessages(), query));
    }

    if (method == 'GET' && path == 'dm/chatlist') {
      return _v1Ok(_paged(_state.v1DmChatList(), query));
    }

    if (method == 'GET' && path == 'dm/messagelist') {
      return _v1Ok(_state.v1DmMessageList(query['conversation_id']));
    }

    if (method == 'POST' && path == 'dm/send') {
      return _v1Ok(_state.sendV1Dm(body));
    }

    if (method == 'POST' &&
        (path == 'dm/delchat' ||
            path == 'dm/delmessage' ||
            path == 'dm/read')) {
      return _v1Ok(<String, dynamic>{});
    }

    if (method == 'POST' && path == 'dm/inviteworldcard') {
      return _v1Ok(_state.v1InviteWorldCard(body));
    }

    if (method == 'POST' && path == 'dm/respondworldcard') {
      final action = '${body['action'] ?? 'accept'}';
      return _v1Ok({
        'invite_id': '${body['invite_id'] ?? 'invite_mock_001'}',
        'invite_status': action == 'accept' ? 'accepted' : 'rejected',
        'world_instance_id': 'w_mock_001',
        'origin_id': 'o_mock_001',
      });
    }

    if (method == 'GET' && path == 'discuss/list') {
      return _v1Ok(_state.v1DiscussList(query));
    }

    if (method == 'POST' && path == 'discuss/post') {
      return _v1Ok(_state.addV1Discuss(body));
    }

    if (method == 'POST' && path == 'discuss/like') {
      _state.likeV1Discuss('${body['discuss_id'] ?? ''}');
      return _v1Ok(<String, dynamic>{});
    }

    if (method == 'POST' && path == 'discuss/unlike') {
      _state.unlikeV1Discuss('${body['discuss_id'] ?? ''}');
      return _v1Ok(<String, dynamic>{});
    }

    if (method == 'POST' && path == 'discuss/delete') {
      _state.deleteV1Discuss('${body['discuss_id'] ?? ''}');
      return _v1Ok(<String, dynamic>{});
    }

    if (method == 'GET' && path == 'search') {
      if (kDebugMode) {
        debugPrint('[LocalMockGenesisTransport] GET /api/v1/search $query');
      }
      return _v1Ok(_state.v1Search(query));
    }

    if (method == 'GET' && path == 'search/suggest') {
      if (kDebugMode) {
        debugPrint(
          '[LocalMockGenesisTransport] GET /api/v1/search/suggest $query',
        );
      }
      return _v1Ok(_state.v1SearchSuggest(query));
    }

    if (method == 'GET' && path == 'home') {
      return _v1Ok(_state.v1Home());
    }

    if (method == 'GET' && path == 'home/following') {
      return _v1Ok(
        _paged(_state.v1FollowingFeed(), query)..['has_more'] = false,
      );
    }

    if (method == 'POST' && path == 'upload/image') {
      final now = DateTime.now();
      final y = now.year.toString().padLeft(4, '0');
      final m = now.month.toString().padLeft(2, '0');
      final d = now.day.toString().padLeft(2, '0');
      final objectKey = 'uploads/$y$m$d/mock_${now.microsecondsSinceEpoch}.png';
      return _v1Ok({
        'url': 'https://mock.local/$objectKey',
        'object_key': objectKey,
      });
    }

    if (method == 'POST' && path == 'common/upload') {
      return _v1Ok({
        'file_id': 'file_mock_${DateTime.now().millisecondsSinceEpoch}',
        'biz_type': 'mock',
        'file_url': 'https://mock.local/upload/mock.png',
        'width': 120,
        'height': 120,
        'file_size': 1024,
      });
    }

    if (method == 'POST' && path == 'common/drafts') {
      return _v1Ok(_state.saveV1Draft(body));
    }

    if (method == 'GET' && path == 'common/drafts') {
      return _v1Ok(_state.readV1Draft(query['draft_type']));
    }

    if (method == 'POST' && path == 'common/drafts/del') {
      _state.deleteV1Draft('${body['draft_id'] ?? ''}');
      return _v1Ok(<String, dynamic>{});
    }

    if (method == 'POST' && path == 'common/devices/register') {
      return _v1Ok(<String, dynamic>{});
    }

    return _v1Error(404, 'mock v1 route not found: $method /api/v1/$path');
  }

  TransportResponse _ok(Map<String, dynamic> data) {
    return TransportResponse(
      statusCode: 200,
      headers: const {'content-type': 'application/json'},
      body: jsonEncode(data),
    );
  }

  TransportResponse _error(int code, String message) {
    return TransportResponse(
      statusCode: code,
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({'error': message}),
    );
  }

  TransportResponse _v1Ok(Object? data) {
    return _ok({'err_no': 0, 'err_msg': 'succ', 'data': data});
  }

  TransportResponse _v1Error(int code, String message) {
    return TransportResponse(
      statusCode: code,
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({'err_no': code, 'err_msg': message, 'data': {}}),
    );
  }

  Map<String, dynamic> _paged(
    List<Map<String, dynamic>> items,
    Map<String, String> query,
  ) {
    final parsedPage = int.tryParse(query['pn'] ?? '') ?? 1;
    final parsedSize = int.tryParse(query['rn'] ?? '') ?? items.length;
    final page = parsedPage < 1 ? 1 : parsedPage;
    final size = parsedSize < 1 ? items.length : parsedSize;
    final rawStart = (page - 1) * size;
    final start = rawStart > items.length ? items.length : rawStart;
    final rawEnd = start + size;
    final end = rawEnd > items.length ? items.length : rawEnd;
    return {
      'list': items.sublist(start, end).map(_deepCopyMap).toList(),
      'total': items.length,
    };
  }

  Map<String, dynamic> _decodeBody(List<int>? bytes) {
    if (bytes == null || bytes.isEmpty) return const <String, dynamic>{};
    final decodedText = utf8.decode(bytes, allowMalformed: true);
    Object? decoded;
    try {
      decoded = jsonDecode(decodedText);
    } catch (_) {
      return const <String, dynamic>{};
    }
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return decoded.map((k, v) => MapEntry('$k', v));
    }
    return const <String, dynamic>{};
  }
}

class _MockState {
  bool _authenticated = false;

  bool get isAuthenticated => _authenticated;

  final Map<String, dynamic> me = _deepCopyMap(kMockMeProfile);

  final List<Map<String, dynamic>> origins = kMockOrigins
      .map((item) => _deepCopyMap(item))
      .toList(growable: true);

  final Map<String, Map<String, dynamic>> _worlds = kMockWorlds.map(
    (key, value) => MapEntry(key, _deepCopyMap(value)),
  );

  final Map<String, int> _tickByWorld = Map<String, int>.from(kMockTickByWorld);

  final Map<String, List<Map<String, dynamic>>> _messagesByPoint =
      kMockMessagesByPoint.map(
        (key, value) =>
            MapEntry(key, value.map((item) => _deepCopyMap(item)).toList()),
      );

  final Map<String, dynamic> _v1User = _deepCopyMap(kMockV1User);
  final Map<String, dynamic> _v1PeerUser = _deepCopyMap(kMockV1PeerUser);
  final List<Map<String, dynamic>> _v1Origins = _expandMockV1Origins()
      .map((item) => _deepCopyMap(item))
      .toList(growable: true);
  final List<Map<String, dynamic>> _v1Worlds = _expandMockV1Worlds()
      .map((item) => _deepCopyMap(item))
      .toList(growable: true);
  final List<Map<String, dynamic>> _v1SearchUsers = _expandMockV1SearchUsers()
      .map((item) => _deepCopyMap(item))
      .toList(growable: true);
  final List<Map<String, dynamic>> _v1DmMessages = kMockV1DmMessages
      .map((item) => _deepCopyMap(item))
      .toList(growable: true);
  final List<Map<String, dynamic>> _v1DiscussPosts = kMockV1DiscussPosts
      .map((item) => _deepCopyMap(item))
      .toList(growable: true);
  final List<Map<String, dynamic>> _v1DiscussReplies = kMockV1DiscussReplies
      .map((item) => _deepCopyMap(item))
      .toList(growable: true);
  final List<Map<String, dynamic>> _v1Notifications = kMockV1Notifications
      .map((item) => _deepCopyMap(item))
      .toList(growable: true);
  final Map<String, Map<String, dynamic>> _v1Drafts =
      <String, Map<String, dynamic>>{};

  _MockState() {
    _ensureV1DiscussCoverage();
  }

  Map<String, dynamic> get _v1Origin => _v1Origins.first;

  Map<String, dynamic> get _v1World => _v1Worlds.first;

  void markAuthenticated() {
    _authenticated = true;
  }

  void markLoggedOut() {
    _authenticated = false;
  }

  Map<String, dynamic> googleUserPayload() {
    return {
      'id': me['id'],
      'display_name': me['display_name'],
      'avatar_url': me['avatar_url'],
      'user_code': me['user_code'],
    };
  }

  Map<String, dynamic>? originByWorldview(String worldviewId) {
    for (final origin in origins) {
      if ('${origin['worldviewId']}' == worldviewId) return origin;
    }
    return null;
  }

  Map<String, dynamic> launchWorld({
    required String userId,
    required String worldviewId,
    required String worldName,
  }) {
    final seq = _worlds.length + 1;
    final wid = 'wid_mock_${seq.toString().padLeft(3, '0')}';
    _worlds[wid] = {
      'wid': wid,
      'display_wid_str': 'W_MOCK_${seq.toString().padLeft(3, '0')}',
      'world_name': worldName,
      'worldview_id': worldviewId,
      'owner_user_id': userId,
    };
    _tickByWorld[wid] = 0;
    return {'wid': wid, 'wid_str': _worlds[wid]!['display_wid_str']};
  }

  Map<String, dynamic> createOrigin(Map<String, dynamic> body) {
    final seq = origins.length + 1000;
    final oid = seq;
    final worldviewId = 'wv_mock_${seq.toString().padLeft(4, '0')}';
    final now = DateTime.now().toUtc().toIso8601String();
    final detail = <String, dynamic>{
      'Oid': oid,
      'worldviewId': worldviewId,
      'Oname': '${body['title'] ?? 'Untitled Origin'}',
      'Odescription': '${body['description'] ?? ''}',
      'Oworld_view_image': '${body['cover_image_url'] ?? ''}',
      'Omap_image': '',
      'Ocopycount': 0,
      'Oconnectcount': 0,
      'Oupdated_time': now,
      'Ocharacters': (body['npcs'] is List) ? body['npcs'] : const <dynamic>[],
      'Omap_points': (body['locations'] is List)
          ? (body['locations'] as List)
                .map(
                  (item) => {
                    'id': '${item is Map ? item['name'] ?? '' : ''}',
                    'name': '${item is Map ? item['name'] ?? '' : ''}',
                  },
                )
                .toList(growable: false)
          : const <dynamic>[],
      'Oevents': (body['events'] is List) ? body['events'] : const <dynamic>[],
    };
    origins.insert(0, detail);
    return {'worldview_id': worldviewId, 'detail': detail};
  }

  Map<String, dynamic>? worldByWid(String wid) => _worlds[wid];

  Map<String, dynamic>? tickByWid(String wid) {
    final world = _worlds[wid];
    if (world == null) return null;
    final tick = _tickByWorld[wid] ?? 0;
    return {
      'tick_index': tick,
      'current_day': 1,
      'current_time': '18:00',
      'current_worldview_id': world['worldview_id'],
      'current_worldview_name': world['world_name'],
      'global_narrative': 'The city adjusts to your last choice at tick $tick.',
      'location_chat_user_send_count': 42,
      'world_mutation': {'busy': false},
      'player_slot_last_location': {'player1': 'loc_hub'},
      'scenes': [
        {
          'location_id': 'loc_hub',
          'location_name': 'Central Hub',
          'character_ids': ['c_1'],
        },
        {
          'location_id': 'loc_gate',
          'location_name': 'Rail Gate',
          'character_ids': ['c_2'],
        },
      ],
      'tick_history': [
        {
          'tick_index': tick,
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'global_narrative': 'Tick $tick completed.',
        },
      ],
    };
  }

  Map<String, dynamic>? progressTick(String wid) {
    if (!_worlds.containsKey(wid)) return null;
    _tickByWorld[wid] = (_tickByWorld[wid] ?? 0) + 1;
    return tickByWid(wid);
  }

  Map<String, dynamic>? worldMapByWid(String wid) {
    if (!_worlds.containsKey(wid)) return null;
    final positions = kMockWorldMapPositions
        .map((item) => _deepCopyMap(item))
        .toList(growable: false);
    return {'positions': positions, 'merged_positions': positions};
  }

  Map<String, dynamic>? charactersByWid(String wid) {
    if (!_worlds.containsKey(wid)) return null;
    return {
      'my_player_slot': 'player1',
      'characters_full': kMockCharactersFull
          .map((item) => _deepCopyMap(item))
          .toList(growable: false),
      'players': kMockPlayers
          .map((item) => _deepCopyMap(item))
          .toList(growable: false),
    };
  }

  List<Map<String, dynamic>> messagesForPoint(
    String pointId, {
    required int limit,
  }) {
    final list = _messagesByPoint[pointId] ?? const <Map<String, dynamic>>[];
    final newestFirst = list.reversed.toList(growable: false);
    return newestFirst.take(limit).map((item) => _deepCopyMap(item)).toList();
  }

  Map<String, dynamic> enqueuePointMessage({
    required String wid,
    required String pointId,
    required String locationId,
    required String userId,
    required String text,
  }) {
    final queue = _messagesByPoint.putIfAbsent(
      pointId,
      () => <Map<String, dynamic>>[],
    );
    final nextSeq = queue.isEmpty
        ? 1
        : (queue.last['chat_seq'] as int? ?? 0) + 1;
    final msg = {
      'id': 'm_${DateTime.now().millisecondsSinceEpoch}',
      'chat_seq': nextSeq,
      'role': 'user',
      'api_user_id': userId,
      'player_id': 'player1',
      'speaker': '${me['display_name']}',
      'content': text,
      'location_id': locationId,
      'wid': wid,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    queue.add(msg);
    return _deepCopyMap(msg);
  }

  List<Map<String, dynamic>> worldsForUser(String userId) {
    return _worlds.values
        .where((w) => '${w['owner_user_id']}' == userId)
        .map(
          (w) => {
            'world_instance_id': w['wid'],
            'display_wid_str': w['display_wid_str'],
            'worldview_id': w['worldview_id'],
            'world_name': w['world_name'],
            'owner_id': w['owner_user_id'],
            'updated_at': DateTime.now().toUtc().toIso8601String(),
            'location_chat_user_send_count': 42,
          },
        )
        .map((item) => _deepCopyMap(item))
        .toList(growable: false);
  }

  Map<String, dynamic> search(String query) {
    final keyword = query.trim().toLowerCase();
    if (keyword.isEmpty) {
      return const {
        'origins': <Map<String, dynamic>>[],
        'worlds': <Map<String, dynamic>>[],
        'users': <Map<String, dynamic>>[],
      };
    }

    bool containsAny(String input) => input.toLowerCase().contains(keyword);

    final originMatches = origins
        .where((item) {
          final name = '${item['Oname'] ?? ''}';
          final subtitle = '${item['Osubtitle'] ?? ''}';
          final description = '${item['Odescription'] ?? ''}';
          return containsAny(name) ||
              containsAny(subtitle) ||
              containsAny(description);
        })
        .map((item) => _deepCopyMap(item))
        .toList(growable: false);

    final worldMatches = _worlds.values
        .where((item) {
          final name = '${item['world_name'] ?? ''}';
          final wid = '${item['wid'] ?? ''}';
          return containsAny(name) || containsAny(wid);
        })
        .map(
          (item) => {
            'world_instance_id': item['wid'],
            'wid': item['wid'],
            'world_name': item['world_name'],
            'snapshot_cover_url': '',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
        )
        .map((item) => _deepCopyMap(item))
        .toList(growable: false);

    final userMatches = <Map<String, dynamic>>[];
    final displayName = '${me['display_name'] ?? ''}';
    final uid = '${me['id'] ?? ''}';
    final userCode = '${me['user_code'] ?? ''}';
    if (containsAny(displayName) || containsAny(uid) || containsAny(userCode)) {
      userMatches.add(
        _deepCopyMap({
          'id': uid,
          'display_name': displayName,
          'avatar_url': '${me['avatar_url'] ?? ''}',
          'user_code': userCode,
        }),
      );
    }

    return {
      'origins': originMatches,
      'worlds': worldMatches,
      'users': userMatches,
    };
  }

  Map<String, dynamic> v1AuthPayload() {
    return v1UserInfo(null);
  }

  Map<String, dynamic> v1UserInfo(String? uid) {
    final profile = v1UserProfile(uid);
    return {
      'token': 'mock-v1-token',
      'user': profile['user'],
      'relation': profile['relation'],
    };
  }

  Map<String, dynamic> updateV1User(Map<String, dynamic> body) {
    for (final key in ['name', 'avatar', 'bio']) {
      final value = body[key];
      if (value != null) _v1User[key] = value;
    }
    return _deepCopyMap(_v1User);
  }

  Map<String, dynamic> v1UserProfile(String? uid) {
    final isSelf = uid == null || uid.isEmpty || uid == _v1User['uid'];
    return {
      'user': _deepCopyMap(isSelf ? _v1User : _v1PeerUser),
      'relation': _deepCopyMap(
        isSelf ? kMockV1SelfRelation : kMockV1PeerRelation,
      ),
    };
  }

  List<Map<String, dynamic>> v1OriginSummaries() {
    return _v1Origins.map(_v1OriginSummary).toList();
  }

  Map<String, dynamic> v1OriginContractList(Map<String, String> query) {
    return _v1Paged(_v1Origins.map(_v1OriginContractItem).toList(), query);
  }

  Map<String, dynamic> v1OriginDetail(String? oid) {
    final origin = _findV1Origin(oid);
    return _originDetailPayload(origin);
  }

  Map<String, dynamic> v1OriginContractDetail(String? originId) {
    final origin = _findV1Origin(originId);
    return {
      ..._v1OriginContractItem(origin),
      'characters': kMockV1Characters.map(_contractCharacter).toList(),
      'locations': kMockV1Locations.map(_contractLocation).toList(),
      'ticks': kMockV1Ticks.map(_contractTick).toList(),
    };
  }

  Map<String, dynamic> createV1Origin(Map<String, dynamic> body) {
    final oid = 'o_mock_${DateTime.now().millisecondsSinceEpoch}';
    final created = {
      ..._deepCopyMap(_v1Origin),
      'oid': oid,
      'name': '${body['name'] ?? _v1Origin['name']}',
      'world_view': '${body['world_view'] ?? _v1Origin['world_view']}',
      'world_setting': '${body['world_setting'] ?? _v1Origin['world_setting']}',
      'cover': '${body['cover'] ?? _v1Origin['cover']}',
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    _v1Origins.insert(0, created);
    return _originDetailPayload(created);
  }

  Map<String, dynamic> updateV1Origin(Map<String, dynamic> body) {
    final origin = _findV1Origin('${body['oid'] ?? ''}');
    for (final key in ['name', 'world_view', 'world_setting', 'cover']) {
      final value = body[key];
      if (value != null) origin[key] = value;
    }
    origin['updated_at'] = DateTime.now().toUtc().toIso8601String();
    return _originDetailPayload(origin);
  }

  Map<String, dynamic> publishV1Origin(String oid) {
    final origin = _findV1Origin(oid);
    origin['status'] = 2;
    return _originDetailPayload(origin);
  }

  void deleteV1Origin(String oid) {
    final origin = _findV1Origin(oid);
    if (oid.isNotEmpty && oid == origin['oid']) {
      origin['status'] = 0;
    }
  }

  Map<String, dynamic> v1OriginVersionList(String? oid) {
    final origin = _findV1Origin(oid);
    return {
      'list': [
        {
          'version_num': origin['version_num'],
          'update_notes': 'Initial mock version for ${oid ?? origin['oid']}',
          'status': origin['status'],
          'created_at': origin['created_at'],
        },
      ],
      'total': 1,
    };
  }

  String launchV1World(String oid) {
    if (oid.isNotEmpty) _v1World['oid'] = oid;
    return '${_v1World['wid']}';
  }

  List<Map<String, dynamic>> v1WorldSummaries() {
    return _v1Worlds.map(_v1WorldSummary).toList();
  }

  Map<String, dynamic> v1WorldContractList(Map<String, String> query) {
    final uid = (query['uid'] ?? '').trim();
    final worlds = uid.isEmpty
        ? _v1Worlds
        : _v1Worlds
              .where(
                (world) =>
                    '${world['owner_uid'] ?? world['created_uid']}'.trim() ==
                    uid,
              )
              .toList(growable: false);
    return _v1Paged(worlds.map(_v1WorldContractItem).toList(), query);
  }

  Map<String, dynamic> v1WorldDetail(String? wid) {
    final world = _findV1World(wid);
    return {
      'world': _deepCopyMap(world),
      'character_list': kMockV1Characters.map(_deepCopyMap).toList(),
      'metric': _deepCopyMap(kMockV1Metric),
      'location_list': kMockV1Locations.map(_deepCopyMap).toList(),
      'tick_list': kMockV1Ticks.map(_deepCopyMap).toList(),
      'action_button_state': 'progress',
    };
  }

  Map<String, dynamic> v1WorldContractDetail(String? worldId) {
    final world = _findV1World(worldId);
    return {
      ..._v1WorldContractItem(world),
      'characters': kMockV1Characters.map(_contractCharacter).toList(),
      'locations': kMockV1Locations.map(_contractLocation).toList(),
      'ticks': kMockV1Ticks.map(_contractTick).toList(),
    };
  }

  Map<String, dynamic> tickV1World(String worldId) {
    final world = _findV1World(worldId);
    final tickCount = ((world['tick_cnt'] as num?)?.toInt() ?? 0) + 1;
    final now = DateTime.now().toUtc().toIso8601String();
    world['tick_cnt'] = tickCount;
    world['last_progress_at'] = now;
    world['last_progress_summary'] = 'Mock tick $tickCount completed.';
    world['updated_at'] = now;
    return {
      'world_id': world['wid'],
      'tick_cnt': tickCount,
      'last_tick': {
        'tick_index': tickCount,
        'created_at': now,
        'narrator': world['last_progress_summary'],
        'paragraphs': const <Map<String, dynamic>>[],
      },
    };
  }

  List<Map<String, dynamic>> v1Notifications() {
    return _v1Notifications.map(_deepCopyMap).toList();
  }

  Map<String, dynamic> v1UnreadSummary() {
    final systemUnread = _v1UnreadCount('system');
    final followerUnread = _v1UnreadCount('follower');
    final commentUnread = _v1UnreadCount('comment');
    const dmUnread = 0;
    return {
      'system_unread': systemUnread,
      'follower_unread': followerUnread,
      'comment_unread': commentUnread,
      'dm_unread': dmUnread,
      'total_unread': systemUnread + followerUnread + commentUnread + dmUnread,
    };
  }

  void markV1NotificationsRead({
    required String? category,
    required List<String> notificationIds,
  }) {
    for (final notification in _v1Notifications) {
      final matchesCategory =
          category == null ||
          category.isEmpty ||
          notification['category']?.toString() == category;
      final id = notification['id']?.toString();
      final matchesId = notificationIds.isEmpty || notificationIds.contains(id);
      if (matchesCategory && matchesId) {
        notification['is_read'] = true;
      }
    }
  }

  int _v1UnreadCount(String category) {
    return _v1Notifications.where((notification) {
      return notification['category']?.toString() == category &&
          notification['is_read'] != true;
    }).length;
  }

  List<Map<String, dynamic>> v1FollowerMessages() {
    return [
      {
        ..._deepCopyMap(_v1PeerUser),
        'created_at': kMockV1Now,
        'is_read': false,
        'relation': _deepCopyMap(kMockV1PeerRelation),
      },
    ];
  }

  Map<String, dynamic> v1UserList(
    Map<String, String> query, {
    required String type,
  }) {
    final users = type == 'following'
        ? _v1FollowingUsers()
        : _v1FollowerUsers();
    final pagedUsers = _v1PageItems(users, query);
    return {
      'total': users.length,
      'pn': int.tryParse(query['pn'] ?? '') ?? 1,
      'rn': int.tryParse(query['rn'] ?? '') ?? 10,
      'list': pagedUsers.map((item) {
        final user = _deepCopyMap(item);
        final relation = user.remove('relation');
        return {
          'user': user,
          'relation': relation is Map<String, dynamic>
              ? _deepCopyMap(relation)
              : _deepCopyMap(kMockV1PeerRelation),
        };
      }).toList(),
    };
  }

  List<Map<String, dynamic>> v1Relations() => v1FollowerMessages();

  List<Map<String, dynamic>> _v1FollowingUsers() {
    return _v1SearchUsers
        .skip(1)
        .take(36)
        .map((item) {
          final user = _deepCopyMap(item);
          user['is_followed'] = true;
          user['i_followed'] = true;
          user['followed_me'] = item['followed_me'] ?? false;
          user['is_friend'] = item['is_friend'] ?? false;
          user['follow_button_state'] = 'following';
          user['relation'] = _relationForFollowUser(user, followed: true);
          return user;
        })
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _v1FollowerUsers() {
    return _v1SearchUsers
        .skip(2)
        .take(42)
        .map((item) {
          final user = _deepCopyMap(item);
          final followed = item['i_followed'] == true;
          user['is_followed'] = followed;
          user['i_followed'] = followed;
          user['followed_me'] = true;
          user['is_friend'] = followed && item['is_friend'] == true;
          user['follow_button_state'] = followed ? 'following' : 'follow_back';
          user['relation'] = _relationForFollowUser(user, followed: followed);
          return user;
        })
        .toList(growable: false);
  }

  Map<String, dynamic> _relationForFollowUser(
    Map<String, dynamic> user, {
    required bool followed,
  }) {
    final followedMe = user['followed_me'] == true;
    final isFriend = followed && followedMe;
    return {
      'target_user_id': user['uid'],
      'is_self': user['uid'] == _v1User['uid'],
      'is_followed': followed,
      'i_followed': followed,
      'followed_me': followedMe,
      'is_friend': isFriend,
      'follow_button_state': followed
          ? 'following'
          : followedMe
          ? 'follow_back'
          : 'follow',
      'can_send_dm': true,
      'dm_permission': isFriend ? 'unlimited' : 'pingpong',
    };
  }

  Map<String, dynamic> _v1Paged(
    List<Map<String, dynamic>> items,
    Map<String, String> query,
  ) {
    return {
      'list': _v1PageItems(items, query),
      'total': items.length,
      'pn': int.tryParse(query['pn'] ?? '') ?? 1,
      'rn': int.tryParse(query['rn'] ?? '') ?? 10,
    };
  }

  List<Map<String, dynamic>> _v1PageItems(
    List<Map<String, dynamic>> items,
    Map<String, String> query,
  ) {
    final parsedPage = int.tryParse(query['pn'] ?? '') ?? 1;
    final parsedSize = int.tryParse(query['rn'] ?? '') ?? items.length;
    final page = parsedPage < 1 ? 1 : parsedPage;
    final size = parsedSize < 1 ? items.length : parsedSize;
    final rawStart = (page - 1) * size;
    final start = rawStart > items.length ? items.length : rawStart;
    final rawEnd = start + size;
    final end = rawEnd > items.length ? items.length : rawEnd;
    return items.sublist(start, end).map(_deepCopyMap).toList();
  }

  Map<String, dynamic> v1RelationStatus(List<Object?> uids) {
    return {
      for (final uid in uids)
        '$uid': {
          ..._deepCopyMap(kMockV1PeerRelation),
          'target_user_id': '$uid',
        },
    };
  }

  Map<String, dynamic> v1FollowResult({required bool followed}) {
    return {
      'followed': followed,
      'relation': {
        ..._deepCopyMap(kMockV1PeerRelation),
        'is_followed': followed,
        'i_followed': followed,
        'is_friend': followed,
        'follow_button_state': followed ? 'friends' : 'follow_back',
        'dm_permission': followed ? 'unlimited' : 'pingpong',
      },
      'follower_count': followed ? 13 : 12,
      'following_count': followed ? 9 : 8,
      'friend_count': followed ? 4 : 3,
    };
  }

  List<Map<String, dynamic>> v1DmChatList() {
    return [_deepCopyMap(kMockV1DmConversation)];
  }

  Map<String, dynamic> v1DmMessageList(String? conversationId) {
    return {
      'conversation_id': conversationId ?? 'dm_conv_001',
      'peer_name': _v1PeerUser['name'],
      'peer_uid': _v1PeerUser['uid'],
      'peer_avatar': _v1PeerUser['avatar'],
      'dm_permission': 'unlimited',
      'messages': _v1DmMessages.map(_deepCopyMap).toList(),
      'has_more': false,
    };
  }

  Map<String, dynamic> sendV1Dm(Map<String, dynamic> body) {
    final conversationId = '${body['conversation_id'] ?? 'dm_conv_001'}';
    final nextSeq = _v1DmMessages.isEmpty
        ? 1
        : (_v1DmMessages.last['seq'] as int? ?? 0) + 1;
    final message = {
      'message_id': 'dm_msg_${DateTime.now().millisecondsSinceEpoch}',
      'conversation_id': conversationId,
      'seq': nextSeq,
      'sender_uid': _v1User['uid'],
      'message_type': 'text',
      'content': '${body['content'] ?? ''}',
      'create_time': DateTime.now().toUtc().toIso8601String(),
    };
    _v1DmMessages.add(message);
    return {
      'message': _deepCopyMap(message),
      'permission': {
        'relation_type': 'friend',
        'dm_permission': 'unlimited',
        'can_send_now': true,
        'block_reason': '',
        'latest_sender_uid': _v1User['uid'],
        'conversation_id': conversationId,
      },
    };
  }

  Map<String, dynamic> v1InviteWorldCard(Map<String, dynamic> body) {
    return {
      'message': {
        'message_id': 'dm_invite_${DateTime.now().millisecondsSinceEpoch}',
        'conversation_id': '${body['conversation_id'] ?? 'dm_conv_001'}',
        'seq': (_v1DmMessages.length + 1),
        'sender_uid': _v1User['uid'],
        'message_type': 'invite',
        'invite_world_id': '${body['world_instance_id'] ?? _v1World['wid']}',
        'invite_origin_id': '${body['origin_id'] ?? _v1Origin['oid']}',
        'invite_world_name': _v1World['name'],
        'invite_origin_name': _v1Origin['name'],
        'inviter_user_name': _v1User['name'],
        'invite_status': 'pending',
        'create_time': DateTime.now().toUtc().toIso8601String(),
      },
    };
  }

  void _ensureV1DiscussCoverage() {
    for (final entry in _v1Origins.indexed) {
      final originIndex = entry.$1;
      final origin = entry.$2;
      final oid = '${origin['oid'] ?? ''}'.trim();
      if (oid.isEmpty) continue;

      final existingTopCount = _v1DiscussPosts
          .where((item) => item['biz_type'] == 1 && item['biz_id'] == oid)
          .length;
      for (var slot = existingTopCount; slot < 2; slot++) {
        final comment = _mockV1DiscussPost(
          origin: origin,
          originIndex: originIndex,
          slot: slot,
        );
        _v1DiscussPosts.add(comment);
        _v1DiscussReplies.add(
          _mockV1DiscussReply(
            origin: origin,
            comment: comment,
            originIndex: originIndex,
            slot: slot,
          ),
        );
      }
    }
  }

  Map<String, dynamic> _mockV1DiscussPost({
    required Map<String, dynamic> origin,
    required int originIndex,
    required int slot,
  }) {
    final oid = '${origin['oid']}';
    final title = '${origin['name']}';
    final idPart = _safeDiscussIdPart(oid);
    final author = (originIndex + slot).isEven ? _v1User : _v1PeerUser;
    return {
      'discuss_id': 'dis_mock_auto_${idPart}_$slot',
      'biz_type': 1,
      'biz_id': oid,
      'author': _deepCopyMap(author),
      'content': slot.isEven
          ? '$title 的最新分支很适合继续推进角色关系。'
          : '我在 $title 里补了一条 mock discuss，用来验证列表预览。',
      'images': <String>[],
      'root_discuss_id': '',
      'parent_discuss_id': '',
      'reply_to_uid': '',
      'level': 1,
      'reply_cnt': 1,
      'like_cnt': (originIndex + slot) % 9,
      'is_liked': (originIndex + slot) % 4 == 0,
      'created_at': _mockDiscussTimestamp(originIndex: originIndex, slot: slot),
    };
  }

  Map<String, dynamic> _mockV1DiscussReply({
    required Map<String, dynamic> origin,
    required Map<String, dynamic> comment,
    required int originIndex,
    required int slot,
  }) {
    final oid = '${origin['oid']}';
    final idPart = _safeDiscussIdPart(oid);
    final author = (originIndex + slot).isEven ? _v1PeerUser : _v1User;
    return {
      'discuss_id': 'dis_mock_auto_${idPart}_${slot}_reply',
      'biz_type': 1,
      'biz_id': oid,
      'author': _deepCopyMap(author),
      'content': '收到，这条讨论会出现在 ${origin['name']} 的最新回复里。',
      'images': <String>[],
      'root_discuss_id': comment['discuss_id'],
      'parent_discuss_id': comment['discuss_id'],
      'reply_to_uid':
          '${comment['author'] is Map ? comment['author']['uid'] : ''}',
      'level': 2,
      'reply_cnt': 0,
      'like_cnt': slot,
      'is_liked': false,
      'created_at': _mockDiscussTimestamp(
        originIndex: originIndex,
        slot: slot,
        minuteOffset: 2,
      ),
    };
  }

  Map<String, dynamic> v1DiscussList(Map<String, String> query) {
    final bizType = _positiveInt(query['biz_type'], fallback: 1);
    final bizId = query['biz_id'] ?? '${_v1Origin['oid']}';
    final page = _positiveInt(query['pn'], fallback: 1);
    final pageSize = _positiveInt(query['rn'], fallback: 10);
    final topComments =
        _v1DiscussPosts
            .where(
              (item) =>
                  item['biz_type'] == bizType &&
                  (bizId.isEmpty || item['biz_id'] == bizId),
            )
            .toList()
          ..sort(_compareDiscussCreatedDesc);
    final roots = topComments.map((item) => item['discuss_id']).toSet();
    final replies = _v1DiscussReplies
        .where(
          (item) =>
              item['biz_type'] == bizType &&
              (bizId.isEmpty || item['biz_id'] == bizId) &&
              roots.contains(item['root_discuss_id']),
        )
        .toList();
    final rawStart = (page - 1) * pageSize;
    final start = rawStart > topComments.length ? topComments.length : rawStart;
    final rawEnd = start + pageSize;
    final end = rawEnd > topComments.length ? topComments.length : rawEnd;
    final pageItems = topComments.sublist(start, end);
    return {
      'list': pageItems
          .map(
            (comment) => {
              'comment': _deepCopyMap(comment),
              'latest_replies': _latestV1DiscussReplies(
                '${comment['discuss_id']}',
              ),
            },
          )
          .toList(),
      'top_total': topComments.length,
      'total_all': topComments.length + replies.length,
      'pn': page,
      'rn': pageSize,
    };
  }

  Map<String, dynamic> addV1Discuss(Map<String, dynamic> body) {
    final rootDiscussId = '${body['root_discuss_id'] ?? ''}';
    final isReply = rootDiscussId.trim().isNotEmpty;
    final parentDiscussId = '${body['parent_discuss_id'] ?? ''}'.trim();
    final discussId = 'dis_mock_${DateTime.now().microsecondsSinceEpoch}';
    final parentId = isReply
        ? (parentDiscussId.isEmpty ? rootDiscussId : parentDiscussId)
        : '';
    final parent = _findV1Discuss(parentId);
    final item = {
      'discuss_id': discussId,
      'biz_type': _positiveInt('${body['biz_type'] ?? ''}', fallback: 1),
      'biz_id': '${body['biz_id'] ?? _v1Origin['oid']}',
      'author': _deepCopyMap(_v1User),
      'content': '${body['content'] ?? ''}',
      'images': body['images'] is List ? body['images'] : <String>[],
      'root_discuss_id': isReply ? rootDiscussId : '',
      'parent_discuss_id': parentId,
      'reply_to_uid':
          '${parent?['author'] is Map ? parent!['author']['uid'] : ''}',
      'level': isReply ? 2 : 1,
      'reply_cnt': 0,
      'like_cnt': 0,
      'is_liked': false,
      'created_at': _mockSqlTimestamp(),
    };
    if (isReply) {
      _v1DiscussReplies.insert(0, item);
      final root = _findV1Discuss(rootDiscussId);
      if (root != null) {
        root['reply_cnt'] = (root['reply_cnt'] as int? ?? 0) + 1;
      }
    } else {
      _v1DiscussPosts.insert(0, item);
      _adjustV1OriginDiscussCount('${item['biz_id']}', 1);
    }
    return {
      'discuss_id': discussId,
      'root_discuss_id': isReply ? rootDiscussId : '',
      'level': isReply ? 2 : 1,
    };
  }

  void likeV1Discuss(String discussId) {
    final item = _findV1Discuss(discussId);
    if (item == null || (item['is_liked'] as bool? ?? false)) return;
    item['is_liked'] = true;
    item['like_cnt'] = (item['like_cnt'] as int? ?? 0) + 1;
  }

  void unlikeV1Discuss(String discussId) {
    final item = _findV1Discuss(discussId);
    if (item == null || !(item['is_liked'] as bool? ?? false)) return;
    item['is_liked'] = false;
    final next = (item['like_cnt'] as int? ?? 0) - 1;
    item['like_cnt'] = next < 0 ? 0 : next;
  }

  void deleteV1Discuss(String discussId) {
    final removedReply = _v1DiscussReplies
        .where((item) => item['discuss_id'] == discussId)
        .toList();
    _v1DiscussReplies.removeWhere((item) => item['discuss_id'] == discussId);
    for (final reply in removedReply) {
      final root = _findV1Discuss('${reply['root_discuss_id']}');
      if (root != null) {
        final next = (root['reply_cnt'] as int? ?? 0) - 1;
        root['reply_cnt'] = next < 0 ? 0 : next;
      }
    }
    final removedTop = _v1DiscussPosts
        .where((item) => item['discuss_id'] == discussId)
        .toList();
    _v1DiscussPosts.removeWhere((item) => item['discuss_id'] == discussId);
    for (final comment in removedTop) {
      _adjustV1OriginDiscussCount('${comment['biz_id']}', -1);
    }
  }

  List<Map<String, dynamic>> _latestV1DiscussReplies(String rootDiscussId) {
    final replies =
        _v1DiscussReplies
            .where((item) => item['root_discuss_id'] == rootDiscussId)
            .toList()
          ..sort(_compareDiscussCreatedDesc);
    return replies.take(3).map(_deepCopyMap).toList();
  }

  Map<String, dynamic>? _findV1Discuss(String discussId) {
    for (final item in [..._v1DiscussPosts, ..._v1DiscussReplies]) {
      if (item['discuss_id'] == discussId) return item;
    }
    return null;
  }

  int _compareDiscussCreatedDesc(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    return '${b['created_at']}'.compareTo('${a['created_at']}');
  }

  String _mockSqlTimestamp() {
    final now = DateTime.now().toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)} '
        '${two(now.hour)}:${two(now.minute)}:${two(now.second)}';
  }

  String _mockDiscussTimestamp({
    required int originIndex,
    required int slot,
    int minuteOffset = 0,
  }) {
    final day = ((originIndex + slot) % 28) + 1;
    final hour = 8 + ((originIndex + slot) % 10);
    final minute = ((originIndex * 3) + (slot * 11) + minuteOffset) % 60;
    return '2026-05-${day.toString().padLeft(2, '0')} '
        '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}:00';
  }

  String _safeDiscussIdPart(String oid) {
    return oid.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_');
  }

  void _adjustV1OriginDiscussCount(String originId, int delta) {
    final origin = _v1Origins.firstWhere(
      (item) => item['oid'] == originId,
      orElse: () => <String, dynamic>{},
    );
    if (origin.isEmpty) return;
    final next = (origin['discuss_cnt'] as int? ?? 0) + delta;
    origin['discuss_cnt'] = next < 0 ? 0 : next;
  }

  Map<String, dynamic> v1Search(Map<String, String> query) {
    final raw = query['query'] ?? '';
    final normalized = raw.trim().toLowerCase();
    final requestedType = (query['type'] ?? 'all').trim().toLowerCase();
    final page = _positiveInt(query['pn'], fallback: 1);
    final pageSize = _positiveInt(query['rn'], fallback: 20);
    final originItems = v1OriginSummaries();
    final worldItems = v1WorldSummaries();
    bool matches(Object? value) =>
        normalized.isEmpty || '$value'.toLowerCase().contains(normalized);

    final originResults = originItems
        .where(
          (item) =>
              matches(item['oid']) ||
              matches(item['name']) ||
              matches(item['display_subtitle']) ||
              matches(item['created_user_name']) ||
              matches((item['tags'] as List?)?.join(' ')),
        )
        .map(
          (item) => {
            ..._searchItem(
              'origin',
              item['oid'],
              item['name'],
              _originSearchSubtitle(item),
            ),
            'cover_image': item['cover'] ?? '',
            'tags': item['tags'] is List ? item['tags'] : <String>[],
            'copy_cnt': item['copy_cnt'] ?? 0,
            'connect_cnt': item['connect_cnt'] ?? 0,
            'player_cnt': item['character_cnt'] ?? 0,
          },
        )
        .toList();

    final worldResults = worldItems
        .where(
          (item) =>
              matches(item['wid']) ||
              matches(item['name']) ||
              matches(item['display_subtitle']) ||
              matches(item['owner_name']) ||
              matches((item['tags'] as List?)?.join(' ')),
        )
        .map(
          (item) => {
            ..._searchItem(
              'world',
              item['wid'],
              item['name'],
              _worldSearchSubtitle(item),
            ),
            'cover_image': item['cover'] ?? '',
            'tags': item['tags'] is List ? item['tags'] : <String>[],
            'tick_cnt': item['tick_cnt'] ?? 0,
            'connect_cnt': item['connect_cnt'] ?? 0,
            'player_cnt': item['player_cnt'] ?? 0,
            'member_cnt': item['location_cnt'] ?? 0,
          },
        )
        .toList();

    final userResults = _v1SearchUsers
        .where(
          (item) =>
              matches(item['uid']) ||
              matches(item['name']) ||
              matches(item['bio']) ||
              matches(item['user_code']),
        )
        .map(
          (item) => {
            ..._searchItem('user', item['uid'], item['name'], item['bio']),
            'short_code': item['user_code'] ?? item['uid'],
            'cover_image': item['avatar'] ?? '',
            'relation': _relationForSearchUser(item),
          },
        )
        .toList();

    Map<String, dynamic> group(String type, List<Map<String, dynamic>> items) {
      final include =
          requestedType.isEmpty ||
          requestedType == 'all' ||
          requestedType == type;
      final visibleItems = include ? items : <Map<String, dynamic>>[];
      return {
        'type': type,
        'total': visibleItems.length,
        'list': _pageSearchResults(visibleItems, page, pageSize),
      };
    }

    return {
      'intent': {
        'raw_query': raw,
        'normalized_query': normalized,
        'strict_code_or_id':
            normalized.startsWith('u_') ||
            normalized.startsWith('o_') ||
            normalized.startsWith('w_'),
        'detected_type': requestedType == 'all' ? 'all' : requestedType,
        'detected_field': 'keyword',
      },
      'groups': [
        group('user', userResults),
        group('origin', originResults),
        group('world', worldResults),
      ],
      'pn': page,
      'rn': pageSize,
    };
  }

  int _positiveInt(String? value, {required int fallback}) {
    final parsed = int.tryParse(value ?? '') ?? fallback;
    return parsed < 1 ? fallback : parsed;
  }

  List<Map<String, dynamic>> _pageSearchResults(
    List<Map<String, dynamic>> items,
    int page,
    int pageSize,
  ) {
    final rawStart = (page - 1) * pageSize;
    final start = rawStart > items.length ? items.length : rawStart;
    final rawEnd = start + pageSize;
    final end = rawEnd > items.length ? items.length : rawEnd;
    return items.sublist(start, end).map(_deepCopyMap).toList();
  }

  String _originSearchSubtitle(Map<String, dynamic> item) {
    return [
      'OID: ${item['oid'] ?? ''}',
      'Originator: ${item['created_user_name'] ?? '-'}',
      'Latest Version: V${item['version_num'] ?? 1}',
    ].join(' · ');
  }

  String _worldSearchSubtitle(Map<String, dynamic> item) {
    return [
      'WID: ${item['wid'] ?? ''}',
      'Owner: ${item['owner_name'] ?? item['created_user_name'] ?? '-'}',
    ].join(' · ');
  }

  Map<String, dynamic> _relationForSearchUser(Map<String, dynamic> item) {
    if (item['uid'] == _v1User['uid']) return _deepCopyMap(kMockV1SelfRelation);
    return {
      ..._deepCopyMap(kMockV1PeerRelation),
      'target_user_id': item['uid'],
      'is_followed': item['is_followed'] ?? item['i_followed'] ?? false,
      'i_followed': item['i_followed'] ?? false,
      'followed_me': item['followed_me'] ?? false,
      'is_friend': item['is_friend'] ?? false,
      'follow_button_state': item['follow_button_state'] ?? 'follow',
    };
  }

  Map<String, dynamic> v1SearchSuggest(Map<String, String> query) {
    final result = v1Search(query);
    final groups = result['groups'] as List;
    return {
      'list': groups
          .expand((group) => ((group as Map)['list'] as List))
          .cast<Map<String, dynamic>>()
          .take(int.tryParse(query['limit'] ?? '') ?? 10)
          .map(_deepCopyMap)
          .toList(),
    };
  }

  Map<String, dynamic> v1Home() {
    return {
      'default_tab': 'my_world',
      'my_world': {'list': v1WorldSummaries()},
      'popular': {'list': v1OriginSummaries()},
      'following': {'list': v1FollowingFeed()},
    };
  }

  List<Map<String, dynamic>> v1FollowingFeed() {
    return [
      {
        'event_type': 'world_launch',
        'event_time': kMockV1Now,
        'actor': _deepCopyMap(_v1PeerUser),
        'target': {
          'oid': _v1Origin['oid'],
          'wid': _v1World['wid'],
          'name': _v1World['name'],
          'cover': _v1World['cover'],
          'tick_cnt': _v1World['tick_cnt'],
        },
        'summary': 'Penny launched a local mock world.',
      },
    ];
  }

  Map<String, dynamic> saveV1Draft(Map<String, dynamic> body) {
    final draftType = '${body['draft_type'] ?? 'origin_create'}';
    final draftId =
        '${body['draft_id'] ?? 'draft_${DateTime.now().millisecondsSinceEpoch}'}';
    final draft = {
      'draft_id': draftId,
      'draft_type': draftType,
      'draft_data': body['draft_data'] is Map ? body['draft_data'] : {},
      'update_time': DateTime.now().toUtc().toIso8601String(),
      'expire_time': DateTime.now()
          .toUtc()
          .add(const Duration(days: 7))
          .toIso8601String(),
    };
    _v1Drafts[draftType] = _deepCopyMap(draft);
    return _deepCopyMap(draft);
  }

  Map<String, dynamic>? readV1Draft(String? draftType) {
    return _deepCopyMap(
      _v1Drafts[draftType ?? 'origin_create'] ??
          {
            'draft_id': 'draft_mock_default',
            'draft_type': draftType ?? 'origin_create',
            'draft_data': {'name': 'Draft Steam Kingdom'},
            'update_time': kMockV1Now,
            'expire_time': '2026-05-27T10:00:00Z',
          },
    );
  }

  void deleteV1Draft(String draftId) {
    _v1Drafts.removeWhere((_, draft) => draft['draft_id'] == draftId);
  }

  Map<String, dynamic> _originDetailPayload(Map<String, dynamic> origin) {
    return {
      'origin': _deepCopyMap(origin),
      'character_list': kMockV1Characters.map(_deepCopyMap).toList(),
      'metric': _deepCopyMap(kMockV1Metric),
      'location_list': kMockV1Locations.map(_deepCopyMap).toList(),
      'event_list': kMockV1Events.map(_deepCopyMap).toList(),
    };
  }

  Map<String, dynamic> _v1OriginSummary(Map<String, dynamic> origin) {
    return {
      'oid': origin['oid'],
      'status': origin['status'],
      'version_num': origin['version_num'],
      'name': origin['name'],
      'cover': origin['cover'],
      'display_subtitle': origin['display_subtitle'],
      'world_view': origin['world_view'],
      'created_uid': origin['created_uid'],
      'created_user_name': origin['created_user_name'],
      'created_at': origin['created_at'],
      'updated_at': origin['updated_at'],
      'tags': origin['tags'],
      'copy_cnt': origin['copy_cnt'],
      'connect_cnt': origin['connect_cnt'],
      'discuss_cnt': origin['discuss_cnt'],
      'character_cnt': origin['character_cnt'],
      'location_cnt': origin['location_cnt'],
    };
  }

  Map<String, dynamic> _v1WorldSummary(Map<String, dynamic> world) {
    return {
      'oid': world['oid'],
      'origin_version_num': world['origin_version_num'],
      'origin_version_create_at': world['origin_version_create_at'],
      'wid': world['wid'],
      'status': world['status'],
      'name': world['name'],
      'cover': world['cover'],
      'display_subtitle': world['display_subtitle'],
      'created_uid': world['created_uid'],
      'created_user_name': world['created_user_name'],
      'owner_uid': world['owner_uid'],
      'owner_name': world['owner_name'],
      'created_at': world['created_at'],
      'updated_at': world['updated_at'],
      'last_progress_at': world['last_progress_at'],
      'last_progress_summary': world['last_progress_summary'],
      'tags': world['tags'],
      'tick_cnt': world['tick_cnt'],
      'connect_cnt': world['connect_cnt'],
      'ai_character_cnt': world['ai_character_cnt'],
      'player_cnt': world['player_cnt'],
      'location_cnt': world['location_cnt'],
    };
  }

  Map<String, dynamic> _v1OriginContractItem(Map<String, dynamic> origin) {
    return {
      'info': {
        'origin_id': origin['oid'],
        'origin_name': origin['name'],
        'origin_version': '${origin['version_num'] ?? 1}',
        'origin_version_time': origin['updated_at'],
        'brief': origin['display_subtitle'],
        'setting': origin['world_setting'],
        'events': kMockV1Events.map((event) => event['content']).toList(),
        'tags': origin['tags'],
        'created_at': origin['created_at'],
        'started_at': origin['start_time'],
        'tick_duration_days': origin['tick_duration_days'],
        'cover': origin['cover'],
        'map_url': origin['map_url'] ?? origin['cover'],
        'status': origin['status'],
      },
      'stats': {
        'copy_cnt': origin['copy_cnt'],
        'discuss_cnt': origin['discuss_cnt'],
        'character_cnt': origin['character_cnt'],
        'connect_cnt': origin['connect_cnt'],
        'location_cnt': origin['location_cnt'],
        'tick_cnt': origin['tick_cnt'] ?? 0,
      },
    };
  }

  Map<String, dynamic> _v1WorldContractItem(Map<String, dynamic> world) {
    return {
      'info': {
        'world_id': world['wid'],
        'world_name': world['name'],
        'origin_id': world['oid'],
        'origin_version': '${world['origin_version_num'] ?? 1}',
        'origin_version_time': world['origin_version_create_at'],
        'brief': world['display_subtitle'],
        'setting': world['world_setting'],
        'events': kMockV1Events.map((event) => event['content']).toList(),
        'tags': world['tags'],
        'created_at': world['created_at'],
        'created_uid': world['created_uid'],
        'created_user_name': world['created_user_name'],
        'owner_uid': world['owner_uid'],
        'owner_name': world['owner_name'],
        'updated_at': world['updated_at'],
        'last_progress_at': world['last_progress_at'],
        'last_progress_summary': world['last_progress_summary'],
        'preview_images': [world['cover'], world['cover']],
        'started_at': world['created_at'],
        'tick_duration_days': 30,
        'cover': world['cover'],
        'map_url': world['map_url'] ?? world['cover'],
        'status': world['status'],
      },
      'stats': {
        'character_cnt': world['ai_character_cnt'],
        'connect_cnt': world['connect_cnt'],
        'location_cnt': world['location_cnt'],
        'tick_cnt': world['tick_cnt'],
        'player_cnt': world['player_cnt'],
      },
    };
  }

  Map<String, dynamic> _contractCharacter(Map<String, dynamic> character) {
    return {
      'char_id': character['character_id'],
      'type': character['type'],
      'player_uid': character['player_uid'],
      'name': character['name'],
      'identity': character['identity'],
      'brief': character['tagline'],
      'description': character['description'],
      'goal': character['goal'],
      'avatar': character['avatar'],
      'initial_location_id': character['location_id'],
      'location_id': character['location_id'],
      'metric_value': 50,
    };
  }

  Map<String, dynamic> _contractLocation(Map<String, dynamic> location) {
    return {
      'location_id': location['location_id'],
      'location_pid': location['location_pid'] ?? '',
      'location_name': location['name'],
      'location_summary': location['description'],
      'image': location['image'],
      'x_percent': location['x_percent'],
      'y_percent': location['y_percent'],
      'map_url': location['map_url'] ?? location['image'],
      'initial_dialogue': const <Map<String, dynamic>>[],
    };
  }

  Map<String, dynamic> _contractTick(Map<String, dynamic> tick) {
    final paragraphs = tick['paragraphs'] is List
        ? (tick['paragraphs'] as List)
              .map((item) {
                final paragraph = item is Map
                    ? Map<String, dynamic>.from(item)
                    : const <String, dynamic>{};
                return {
                  'location_id': paragraph['location_id'] ?? 'loc_hub',
                  'timestamp':
                      paragraph['timestamp'] ??
                      tick['created_at'] ??
                      kMockV1Now,
                  'text': paragraph['text'] ?? tick['summary'] ?? '',
                  'character_deltas':
                      paragraph['character_deltas'] ??
                      const <Map<String, dynamic>>[],
                };
              })
              .toList(growable: false)
        : [
            {
              'location_id': 'loc_hub',
              'timestamp': tick['created_at'] ?? kMockV1Now,
              'text': tick['summary'] ?? '',
              'character_deltas': const <Map<String, dynamic>>[],
            },
          ];
    return {
      'tick_index': tick['tick_index'] ?? 1,
      'created_at': tick['created_at'] ?? kMockV1Now,
      'narrator': tick['summary'] ?? '',
      'paragraphs': paragraphs,
    };
  }

  Map<String, dynamic> _searchItem(
    String type,
    Object? id,
    Object? title,
    Object? subtitle,
  ) {
    return {
      'type': type,
      'entity_id': '$id',
      'short_code': '$id',
      'title': '$title',
      'subtitle': '$subtitle',
      'cover_image': '',
      'tags': type == 'origin' ? _v1Origin['tags'] : <String>[],
      'copy_cnt': type == 'origin' ? _v1Origin['copy_cnt'] : 0,
      'connect_cnt': type == 'origin' ? _v1Origin['connect_cnt'] : 0,
      'tick_cnt': type == 'world' ? _v1World['tick_cnt'] : 0,
      'player_cnt': type == 'world' ? _v1World['player_cnt'] : 0,
    };
  }

  Map<String, dynamic> _findV1Origin(String? oid) {
    if (oid == null || oid.isEmpty) return _v1Origin;
    return _v1Origins.firstWhere(
      (item) => item['oid'] == oid,
      orElse: () => {..._v1Origin, 'oid': oid},
    );
  }

  Map<String, dynamic> _findV1World(String? wid) {
    if (wid == null || wid.isEmpty) return _v1World;
    return _v1Worlds.firstWhere(
      (item) => item['wid'] == wid,
      orElse: () => {..._v1World, 'wid': wid},
    );
  }
}

Map<String, dynamic> _deepCopyMap(Map<String, dynamic> source) {
  final result = <String, dynamic>{};
  source.forEach((key, value) {
    result[key] = _deepCopyValue(value);
  });
  return result;
}

List<dynamic> _deepCopyList(List<dynamic> source) {
  return source.map(_deepCopyValue).toList(growable: true);
}

List<Map<String, dynamic>> _expandMockV1Origins() {
  const names = [
    '重生归来做首富',
    '重生 2005',
    'Steam Kingdom',
    'Neon Harbor',
    'Verdant Academy',
    'Dust Radio',
    'Moonlit Diner',
    'Glass Orchard',
    'Paper Armada',
    'Signal Monastery',
    'Copper Carnival',
    'Aurora Market',
  ];
  const subtitles = [
    '重生后从一间小公司开始逆袭都市商战，在资本围猎、旧友背叛和时代风口之间重新改写命运。',
    '老肖回到 2005 的创业线，带着未来记忆修正家庭遗憾、抢占产业窗口，并面对更早到来的竞争者。',
    kMockV1SteamSubtitle,
    kMockV1NeonSubtitle,
    kMockV1VerdantSubtitle,
    kMockV1DustSubtitle,
    kMockV1MoonlitSubtitle,
    'Transparent forest intrigue where every orchard branch shows a different possible betrayal before the morning council convenes.',
    'Fleet of folded cities sailing across paper seas while captains bargain with storms, cartographers, and runaway districts.',
    'Quiet mountain transmissions from a signal monastery where novice operators decode prophecies hidden inside static.',
    'Festival below old factories where performers, workers, and forgotten machines compete to control the final night parade.',
    'Polar bazaar of wishes where aurora merchants price every miracle against memory, warmth, and unfinished promises.',
  ];
  const tagPairs = [
    ['重生', '商战'],
    ['老肖', '年代'],
    ['steampunk', 'politics'],
    ['cyberpunk', 'mystery'],
    ['fantasy', 'academy'],
    ['survival', 'roadtrip'],
    ['slice-of-life', 'supernatural'],
    ['nature', 'intrigue'],
    ['naval', 'city'],
    ['monastery', 'signal'],
    ['festival', 'industrial'],
    ['aurora', 'market'],
  ];

  return List<Map<String, dynamic>>.generate(100, (index) {
    final base = kMockV1Origins[index % kMockV1Origins.length];
    final name = names[index % names.length];
    final subtitle = subtitles[index % subtitles.length];
    final seq = index + 1;
    return {
      ...base,
      'oid': 'o_mock_${seq.toString().padLeft(3, '0')}',
      'version_num': 1 + (index % 5),
      'name': '$name ${seq.toString().padLeft(2, '0')}',
      'display_subtitle': subtitle,
      'world_view': '$subtitle story seed #$seq, shaped by scene ${index % 7}.',
      'world_setting':
          'Players explore ${name.toLowerCase()} with conflict layer ${index % 9}.',
      'created_uid': index.isEven ? 'u_mock_001' : 'u_mock_peer',
      'created_user_name': index.isEven ? 'Mock User' : 'Penny Hardaway',
      'created_at':
          '2026-04-${((index % 28) + 1).toString().padLeft(2, '0')}T08:00:00Z',
      'updated_at':
          '2026-05-${((index % 20) + 1).toString().padLeft(2, '0')}T10:00:00Z',
      'tags': tagPairs[index % tagPairs.length],
      'copy_cnt': _mockStatCount(index, offset: 0),
      'connect_cnt': _mockStatCount(index, offset: 3),
      'discuss_cnt': _mockStatCount(index, offset: 1),
      'character_cnt': _mockStatCount(index, offset: 2),
      'location_cnt': _mockStatCount(index, offset: 4),
      'start_time': 'Day ${(index % 12) + 1} 08:00',
      'tick_duration_days': 7 + (index % 30),
    };
  });
}

List<Map<String, dynamic>> _expandMockV1Worlds() {
  final origins = _expandMockV1Origins();
  const suffixes = [
    'Live',
    'Night Shift',
    'Term One',
    'Caravan',
    'Regulars',
    'Expedition',
    'Council',
    'After Hours',
    'Crossroads',
    'Archive',
  ];

  return List<Map<String, dynamic>>.generate(100, (index) {
    final base = kMockV1Worlds[index % kMockV1Worlds.length];
    final origin = origins[index];
    final seq = index + 1;
    final suffix = suffixes[index % suffixes.length];
    return {
      ...base,
      'oid': origin['oid'],
      'origin_version_num': origin['version_num'],
      'origin_version_create_at': origin['created_at'],
      'wid': 'w_mock_${seq.toString().padLeft(3, '0')}',
      'status': 1,
      'is_join': index % 3 == 0 ? 0 : 1,
      'apply_status': index % 3 == 0 ? 'none' : 'success',
      'name': '${origin['name']} $suffix',
      'display_subtitle': origin['display_subtitle'],
      'world_view': origin['world_view'],
      'world_setting': origin['world_setting'],
      'created_uid': origin['created_uid'],
      'created_user_name': origin['created_user_name'],
      'owner_uid': origin['created_uid'],
      'owner_name': origin['created_user_name'],
      'created_at':
          '2026-05-${((index % 20) + 1).toString().padLeft(2, '0')}T09:00:00Z',
      'updated_at':
          '2026-05-${((index % 20) + 1).toString().padLeft(2, '0')}T18:00:00Z',
      'last_progress_at':
          '2026-05-${((index % 20) + 1).toString().padLeft(2, '0')}T18:00:00Z',
      'last_progress_summary':
          'Mock world #$seq progressed through ${origin['display_subtitle']}.',
      'tags': origin['tags'],
      'tick_cnt': _mockStatCount(index, offset: 0),
      'connect_cnt': _mockStatCount(index, offset: 3),
      'ai_character_cnt': _mockStatCount(index, offset: 2),
      'player_cnt': _mockStatCount(index, offset: 1),
      'location_cnt': _mockStatCount(index, offset: 4),
    };
  });
}

int _mockStatCount(int index, {required int offset}) {
  const samples = [
    2300,
    18500,
    240000,
    4400000,
    12300000,
    980000000,
    2500000000,
    7300000000000,
  ];
  return samples[(index + offset) % samples.length];
}

List<Map<String, dynamic>> _expandMockV1SearchUsers() {
  const names = [
    '老肖',
    '肖老板',
    'Penny Hardaway',
    'Mock User',
    'Iris Vale',
    'Marshal Crow',
    'Lena Gearwright',
    'Noah Signal',
    'Mira Glass',
    'Otto Fold',
    'Sage Greenhouse',
    'Vera Nightport',
    'Kai Copper',
    'June Aurora',
  ];
  const bios = [
    '重生故事线的核心玩家，擅长经营和决策。',
    '老肖账号，用于搜索页中文用户结果调试。',
    'Writes origin prompts for clockwork frontier stories.',
    'Builds cozy worlds and tests local search flows.',
    'Collects botanical mysteries and academy rumors.',
    'Runs survival scenes across long desert routes.',
    'Curates supernatural slice-of-life diners.',
    'Maps transparent forests and quiet signal towers.',
    'Launches paper cities into collaborative worlds.',
    'Tracks market wishes under polar lights.',
  ];

  return List<Map<String, dynamic>>.generate(72, (index) {
    final seq = index + 1;
    final isSelf = index == 0;
    final isPeer = index == 1;
    final uid = isSelf
        ? kMockV1User['uid'] as String
        : isPeer
        ? kMockV1PeerUser['uid'] as String
        : 'u_mock_search_${seq.toString().padLeft(3, '0')}';
    final name = isSelf
        ? kMockV1User['name'] as String
        : isPeer
        ? kMockV1PeerUser['name'] as String
        : '${names[index % names.length]} ${seq.toString().padLeft(2, '0')}';
    return {
      'uid': uid,
      'user_code': 'U_${seq.toString().padLeft(5, '0')}',
      'name': name,
      'avatar': '',
      'bio': '${bios[index % bios.length]} #$seq',
      'last_login_at':
          '2026-05-${((index % 20) + 1).toString().padLeft(2, '0')}T10:00:00Z',
      'create_at':
          '2026-04-${((index % 28) + 1).toString().padLeft(2, '0')}T08:00:00Z',
      'follower_cnt': 10 + index * 2,
      'following_cnt': 6 + index,
      'friend_cnt': index % 9,
      'create_origin_cnt': 1 + (index % 6),
      'launch_world_cnt': 1 + (index % 5),
      'join_world_cnt': 2 + (index % 8),
      'is_followed': index % 3 == 0,
      'i_followed': index % 3 == 0,
      'followed_me': index % 4 == 0,
      'is_friend': index % 9 == 0,
      'follow_button_state': index % 3 == 0 ? 'following' : 'follow',
    };
  });
}

dynamic _deepCopyValue(dynamic value) {
  if (value is Map<String, dynamic>) return _deepCopyMap(value);
  if (value is Map) {
    return value.map((key, v) => MapEntry('$key', _deepCopyValue(v)));
  }
  if (value is List) return _deepCopyList(value);
  return value;
}
