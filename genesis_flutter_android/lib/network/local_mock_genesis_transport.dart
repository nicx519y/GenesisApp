import 'dart:convert';

import 'http_transport.dart';
import 'mock_data/mock_message_data.dart';
import 'mock_data/mock_origin_data.dart';
import 'mock_data/mock_profile_data.dart';
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

    if (method == 'GET' && apiPath == 'auth/me/public-profile') {
      if (!_state.isAuthenticated) {
        return _error(401, 'unauthorized');
      }
      return _ok(_state.me);
    }

    if (method == 'POST' && apiPath == 'auth/google') {
      _state.markAuthenticated();
      return _ok({
        'token': 'mock-jwt-token',
        'user': _state.googleUserPayload(),
      });
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
      final q = '$raw'.trim();
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

  Map<String, dynamic> _decodeBody(List<int>? bytes) {
    if (bytes == null || bytes.isEmpty) return const <String, dynamic>{};
    final decoded = jsonDecode(utf8.decode(bytes));
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

  void markAuthenticated() {
    _authenticated = true;
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

dynamic _deepCopyValue(dynamic value) {
  if (value is Map<String, dynamic>) return _deepCopyMap(value);
  if (value is Map) {
    return value.map((key, v) => MapEntry('$key', _deepCopyValue(v)));
  }
  if (value is List) return _deepCopyList(value);
  return value;
}
