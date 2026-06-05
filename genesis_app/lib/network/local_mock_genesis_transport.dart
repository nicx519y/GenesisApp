import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'http_transport.dart';
import 'json_utils.dart';
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
        : path.startsWith('/')
        ? path.substring(1)
        : path;

    if (apiPath.startsWith('aitown-chat/')) {
      return _handleChatroomHttp(method, apiPath, query, body);
    }

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

  Future<TransportResponse> _handleChatroomHttp(
    String method,
    String path,
    Map<String, String> query,
    Map<String, dynamic> body,
  ) async {
    if (method == 'GET' && path == 'aitown-chat/internal/world/messages') {
      return _v1Ok(_state.chatroomWorldMessages(query['world_id'] ?? ''));
    }

    if (method == 'GET' && path == 'aitown-chat/api/messages') {
      return _v1Ok(
        _state.chatroomHistoryMessages(
          worldId: query['world_instance_id'] ?? '',
          locationId: query['location_id'] ?? '',
          since: int.tryParse(query['since'] ?? ''),
          limit: int.tryParse(query['limit'] ?? ''),
        ),
      );
    }

    if (method == 'POST' && path == 'aitown-chat/internal/tick/lock') {
      final worldId = '${query['world_id'] ?? body['world_id'] ?? ''}';
      return _v1Ok(_state.lockChatroomWorld(worldId));
    }

    if (method == 'GET' && path == 'aitown-chat/internal/tick/progress') {
      return _v1Ok(_state.chatroomTickProgress(query['world_id'] ?? ''));
    }

    if (method == 'POST' && path == 'aitown-chat/internal/tick/unlock') {
      return _v1Ok(_state.unlockChatroomWorld('${body['world_id'] ?? ''}'));
    }

    if (method == 'POST' && path == 'aitown-chat/internal/narrator/write') {
      return _v1Ok(_state.writeChatroomNarrator(body));
    }

    return _v1Error(404, 'mock chatroom route not found: $method /$path');
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
      return _v1Ok({
        'world_id': _state.launchV1World(
          '${body['origin_id'] ?? body['oid'] ?? ''}',
        ),
      });
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

    if (method == 'GET' && path == 'world/tick/list') {
      return _v1Ok(
        _state.v1WorldTickList(worldId: query['world_id'] ?? '', query: query),
      );
    }

    if (method == 'GET' && path == 'world/origin_progress') {
      return _v1Ok(
        _state.v1WorldOriginProgress(
          uid: query['uid'] ?? '',
          originId: query['origin_id'] ?? '',
        ),
      );
    }

    if (method == 'POST' && path == 'world/apply') {
      return _v1Ok(
        _state.applyToV1World(
          worldId: '${body['world_id'] ?? ''}',
          message: body['message']?.toString(),
        ),
      );
    }

    if (method == 'GET' && path == 'world/apply/list') {
      return _v1Ok(_state.v1WorldApplyList(query));
    }

    if (method == 'POST' && path == 'world/apply/review') {
      return _v1Ok(
        _state.reviewV1WorldApply(
          applyId: '${body['apply_id'] ?? ''}',
          action: '${body['action'] ?? ''}',
          reviewMsg: body['review_msg']?.toString(),
        ),
      );
    }

    if (method == 'POST' && path == 'world/join') {
      return _v1Ok(
        _state.joinV1World(
          worldId: '${body['world_id'] ?? ''}',
          presetCharacterId: body['preset_character_id']?.toString(),
          customRole: body['custom_role'] is Map
              ? Map<String, dynamic>.from(body['custom_role'] as Map)
              : null,
        ),
      );
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

    if (method == 'GET' && path == 'message/unread') {
      return _v1Ok(_state.v1UnreadSummary());
    }

    if (method == 'GET' && path == 'message/notifications') {
      final block = query['block']?.trim();
      final items = _state.v1Notifications().where((item) {
        return block == null ||
            block.isEmpty ||
            item['notice_block']?.toString() == block;
      }).toList();
      return _v1Ok(_paged(items, query));
    }

    if (method == 'POST' && path == 'message/read') {
      _state.markV1NotificationsRead(
        block: body['block']?.toString(),
        notificationId: body['notification_id']?.toString(),
      );
      return _v1Ok(<String, dynamic>{});
    }

    if (method == 'GET' && path == 'messages/followers') {
      return _v1Ok(_paged(_state.v1FollowerMessages(), query));
    }

    if (method == 'GET' && path == 'direct_message/conversations') {
      final afterMessageId = query['after_message_id']?.trim();
      if (afterMessageId != null && afterMessageId.isNotEmpty) {
        return _v1Ok(_state.v1DmConversationDeltas(afterMessageId));
      }
      return _v1Ok(
        _paged(_state.v1DmConversations(), query, defaultSize: 20, maxSize: 100)
          ..['next_after_message_id'] = _state.v1DmConversationCursor(),
      );
    }

    if (method == 'GET' && path == 'direct_message/list') {
      return _v1Ok(
        _paged(
          _state.v1DmMessagesForPeer(query['peer_uid']),
          query,
          defaultSize: 20,
          maxSize: 100,
        ),
      );
    }

    if (method == 'POST' && path == 'direct_message/send') {
      return _v1Ok(_state.sendV1DirectMessage(body));
    }

    if (method == 'POST' && path == 'direct_message/read') {
      _state.markV1DirectMessagesRead(body['peer_uid']?.toString());
      return _v1Ok(<String, dynamic>{});
    }

    if (method == 'GET' && path == 'direct_message/unread') {
      return _v1Ok({'unread_cnt': _state.v1DirectMessageUnreadCount()});
    }

    if (method == 'POST' && path == 'direct_message/block') {
      _state.blockV1DirectMessagePeer(body['target_uid']?.toString());
      return _v1Ok(<String, dynamic>{});
    }

    if (method == 'POST' && path == 'direct_message/unblock') {
      _state.unblockV1DirectMessagePeer(body['target_uid']?.toString());
      return _v1Ok(<String, dynamic>{});
    }

    if (method == 'GET' && path == 'direct_message/blocks') {
      return _v1Ok(_paged(_state.v1DirectMessageBlocks(), query));
    }

    if (method == 'GET' && path == 'discuss/list') {
      return _v1Ok(_state.v1DiscussList(query));
    }

    if (method == 'GET' && path == 'discuss/replies') {
      return _v1Ok(_state.v1DiscussReplies(query));
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
    Map<String, String> query, {
    int? defaultSize,
    int? maxSize,
  }) {
    final parsedPage = int.tryParse(query['pn'] ?? '') ?? 1;
    final parsedSize =
        int.tryParse(query['rn'] ?? '') ?? defaultSize ?? items.length;
    final page = parsedPage < 1 ? 1 : parsedPage;
    final positiveSize = parsedSize < 1
        ? defaultSize ?? items.length
        : parsedSize;
    final size = maxSize == null || positiveSize <= maxSize
        ? positiveSize
        : maxSize;
    final rawStart = (page - 1) * size;
    final start = rawStart > items.length ? items.length : rawStart;
    final rawEnd = start + size;
    final end = rawEnd > items.length ? items.length : rawEnd;
    return {
      'list': items.sublist(start, end).map(_deepCopyMap).toList(),
      'total': items.length,
      'pn': page,
      'rn': size,
    };
  }

  Map<String, dynamic> _decodeBody(List<int>? bytes) {
    if (bytes == null || bytes.isEmpty) return const <String, dynamic>{};
    final decodedText = utf8.decode(bytes, allowMalformed: true);
    Object? decoded;
    try {
      decoded = jsonDecode(decodedText);
    } catch (_) {
      if (decodedText.contains('Content-Disposition: form-data')) {
        return _decodeMultipartFields(decodedText);
      }
      return const <String, dynamic>{};
    }
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return decoded.map((k, v) => MapEntry('$k', v));
    }
    return const <String, dynamic>{};
  }

  Map<String, dynamic> _decodeMultipartFields(String input) {
    final fields = <String, dynamic>{};
    final pattern = RegExp(
      r'name="([^"]+)"(?:\r?\n)+\r?\n([\s\S]*?)(?=\r?\n--)',
      multiLine: true,
    );
    for (final match in pattern.allMatches(input)) {
      final name = match.group(1)?.trim() ?? '';
      if (name.isEmpty) continue;
      fields[name] = match.group(2)?.trim() ?? '';
    }
    return fields;
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
  late final List<Map<String, dynamic>> _v1DirectMessagePeers =
      _mockDirectMessagePeers();
  final List<Map<String, dynamic>> _v1Origins = _expandMockV1Origins()
      .map((item) => _deepCopyMap(item))
      .toList(growable: true);
  final List<Map<String, dynamic>> _v1Worlds = _expandMockV1Worlds()
      .map((item) => _deepCopyMap(item))
      .toList(growable: true);
  final Map<String, List<Map<String, dynamic>>> _v1TicksByWorld =
      <String, List<Map<String, dynamic>>>{};
  final List<Map<String, dynamic>> _v1WorldApplies = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> _v1SearchUsers = _expandMockV1SearchUsers()
      .map((item) => _deepCopyMap(item))
      .toList(growable: true);
  late final Map<String, List<Map<String, dynamic>>> _v1DmMessagesByPeer =
      _mockDirectMessageMessagesByPeer();
  final Set<String> _v1BlockedDirectMessagePeers = <String>{};
  int _v1DirectMessageUnreadCount = 1;
  String _v1DmConversationCursor = 'dm_sync_1';
  bool _v1DmConversationDeltaSent = false;
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
  int _v1WorldApplySeq = 0;
  final List<Map<String, dynamic>> _chatroomMessages = <Map<String, dynamic>>[];
  final Map<String, bool> _chatroomWorldLocks = <String, bool>{};
  int _chatroomMessageSeq = 1000;
  int _chatroomRoundSeq = 100;

  _MockState() {
    _ensureV1DiscussCoverage();
    _ensureChatroomMessages();
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
    _chatroomMessages.add(
      _newChatroomMessage(
        worldId: wid,
        locationId: locationId,
        conversationRoundId: ++_chatroomRoundSeq,
        roundOrder: 1,
        senderType: 'user',
        senderId: 'player1',
        senderName: '${me['display_name']}',
        userId: userId,
        content: text,
      ),
    );
    return _deepCopyMap(msg);
  }

  Map<String, dynamic> chatroomWorldMessages(String worldId) {
    final messages = _chatroomMessagesForWorld(worldId);
    messages.sort((a, b) {
      final roundCompare = ((b['conversation_round_id'] as int?) ?? 0)
          .compareTo((a['conversation_round_id'] as int?) ?? 0);
      if (roundCompare != 0) return roundCompare;
      return ((a['round_order'] as int?) ?? 0).compareTo(
        (b['round_order'] as int?) ?? 0,
      );
    });
    final latest = messages.take(50).toList(growable: false);
    final byLocation = <String, List<Map<String, dynamic>>>{};
    for (final message in latest) {
      final locationId = '${message['location_id']}';
      byLocation
          .putIfAbsent(locationId, () => <Map<String, dynamic>>[])
          .add(_chatroomResponseMessage(message));
    }
    return {
      'locations': [
        for (final entry in byLocation.entries)
          {'location_id': entry.key, 'messages': entry.value},
      ],
    };
  }

  Map<String, dynamic> chatroomHistoryMessages({
    required String worldId,
    required String locationId,
    int? since,
    int? limit,
  }) {
    final size = limit == null || limit <= 0 ? 20 : limit;
    final messages =
        _chatroomMessagesForWorld(worldId)
            .where((message) {
              final sameLocation =
                  locationId.trim().isEmpty ||
                  message['location_id'] == locationId;
              final id = (message['message_id'] as int?) ?? 0;
              final beforeCursor = since == null || since <= 0 || id < since;
              return sameLocation && beforeCursor;
            })
            .toList(growable: false)
          ..sort((a, b) {
            return ((b['message_id'] as int?) ?? 0).compareTo(
              (a['message_id'] as int?) ?? 0,
            );
          });
    final page = messages.take(size).map(_chatroomResponseMessage).toList();
    final newestId = _chatroomMessagesForWorld(worldId).fold<int>(0, (
      maxId,
      message,
    ) {
      final id = (message['message_id'] as int?) ?? 0;
      return id > maxId ? id : maxId;
    });
    return {
      'messages': page,
      'has_more': messages.length > page.length,
      'newest_message_id': newestId,
    };
  }

  Map<String, dynamic> lockChatroomWorld(String worldId) {
    final resolved = _resolveChatroomWorldId(worldId);
    _chatroomWorldLocks[resolved] = true;
    return {'locked': true};
  }

  Map<String, dynamic> unlockChatroomWorld(String worldId) {
    final resolved = _resolveChatroomWorldId(worldId);
    _chatroomWorldLocks[resolved] = false;
    return {'unlocked': true};
  }

  Map<String, dynamic> chatroomTickProgress(String worldId) {
    final resolved = _resolveChatroomWorldId(worldId);
    final locked = _chatroomWorldLocks[resolved] ?? false;
    return {
      'progress': locked ? 0 : 1,
      'pending_messages': locked ? 1 : 0,
      'active_llm_calls': locked ? 1 : 0,
    };
  }

  Map<String, dynamic> writeChatroomNarrator(Map<String, dynamic> body) {
    final worldId = _resolveChatroomWorldId('${body['world_id'] ?? ''}');
    final groups = body['location_groups'] is List
        ? body['location_groups'] as List
        : const <Object?>[];
    var firstMessageId = 0;
    for (final rawGroup in groups) {
      if (rawGroup is! Map) continue;
      final group = asJsonMap(rawGroup);
      final locationId = asString(group['location_id'], fallback: 'loc_hub');
      final dialogues = group['initial_dialogue'] is List
          ? group['initial_dialogue'] as List
          : const <Object?>[];
      if (dialogues.isEmpty) {
        final message = _newChatroomMessage(
          worldId: worldId,
          locationId: locationId,
          conversationRoundId: ++_chatroomRoundSeq,
          roundOrder: 1,
          senderType: 'narrator',
          senderId: '',
          senderName: '旁白',
          userId: '',
          content: asString(group['location_summary']),
        );
        _chatroomMessages.add(message);
        firstMessageId = firstMessageId == 0
            ? message['message_id'] as int
            : firstMessageId;
        continue;
      }
      final roundId = ++_chatroomRoundSeq;
      var order = 1;
      for (final rawLine in dialogues) {
        if (rawLine is! Map) continue;
        final line = asJsonMap(rawLine);
        final message = _newChatroomMessage(
          worldId: worldId,
          locationId: locationId,
          conversationRoundId: roundId,
          roundOrder: order++,
          senderType: 'narrator',
          senderId: asString(line['char_id']),
          senderName: asString(line['char_name'], fallback: '旁白'),
          userId: '',
          content: asString(line['content']),
        );
        _chatroomMessages.add(message);
        firstMessageId = firstMessageId == 0
            ? message['message_id'] as int
            : firstMessageId;
      }
    }
    return {
      'message_id': firstMessageId == 0
          ? ++_chatroomMessageSeq
          : firstMessageId,
    };
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
    final normalizedUid = uid?.trim() ?? '';
    final isSelf = normalizedUid.isEmpty || normalizedUid == _v1User['uid'];
    final user = isSelf ? _v1User : _v1UserForUid(normalizedUid);
    return {
      'user': _deepCopyMap(user),
      'relation': _deepCopyMap(
        isSelf ? kMockV1SelfRelation : _relationForSearchUser(user),
      ),
    };
  }

  Map<String, dynamic> _v1UserForUid(String uid) {
    if (uid == _v1PeerUser['uid']) return _v1PeerUser;
    for (final user in [..._v1DirectMessagePeers, ..._v1SearchUsers]) {
      if (user['uid'] == uid) return user;
    }
    return {
      ..._deepCopyMap(_v1PeerUser),
      'uid': uid,
      'name': uid,
      'bio': 'Mock profile for $uid.',
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
    final now = DateTime.now().toUtc().toIso8601String();
    final oid = 'o_mock_${DateTime.now().millisecondsSinceEpoch}';
    final created = {
      ..._deepCopyMap(_v1Origin),
      'oid': oid,
      'name': '${body['origin_name'] ?? _v1Origin['name']}',
      'display_subtitle': '${body['brief'] ?? _v1Origin['display_subtitle']}',
      'world_view':
          '${body['setting'] ?? body['brief'] ?? _v1Origin['world_view']}',
      'world_setting': '${body['setting'] ?? _v1Origin['world_setting']}',
      'cover': '${body['cover'] ?? _v1Origin['cover']}',
      'map_url': '${body['map_url'] ?? body['cover'] ?? _v1Origin['map_url']}',
      'tags': body['tags'] is List ? body['tags'] : const <Object?>[],
      'start_time': '${body['started_at'] ?? _v1Origin['start_time']}',
      'tick_duration_days':
          (body['tick_duration_days'] as num?)?.toInt() ??
          _v1Origin['tick_duration_days'],
      'created_at': now,
      'updated_at': now,
      'character_cnt': body['characters'] is List
          ? (body['characters'] as List).length
          : _v1Origin['character_cnt'],
      'location_cnt': body['locations'] is List
          ? (body['locations'] as List).length
          : _v1Origin['location_cnt'],
    };
    _v1Origins.insert(0, created);
    return {
      ..._v1OriginContractItem(created),
      'characters': body['characters'] is List
          ? (body['characters'] as List)
                .map((item) => _contractCharacter(_mapFromObject(item)))
                .toList(growable: false)
          : kMockV1Characters.map(_contractCharacter).toList(),
      'locations': body['locations'] is List
          ? (body['locations'] as List)
                .map((item) => _contractLocation(_mapFromObject(item)))
                .toList(growable: false)
          : kMockV1Locations.map(_contractLocation).toList(),
      'ticks': const <Map<String, dynamic>>[],
    };
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
    final ownerUid = (query['owner_uid'] ?? '').trim();
    final worlds = ownerUid.isEmpty
        ? _v1Worlds
        : _v1Worlds
              .where(
                (world) =>
                    '${world['owner_uid'] ?? world['created_uid']}'.trim() ==
                    ownerUid,
              )
              .toList(growable: false);
    return _v1Paged(worlds.map(_v1WorldContractItem).toList(), query);
  }

  Map<String, dynamic> v1WorldOriginProgress({
    required String uid,
    required String originId,
  }) {
    final normalizedUid = uid.trim();
    final normalizedOriginId = originId.trim();
    if (normalizedUid.isEmpty || normalizedOriginId.isEmpty) {
      return {'world_id': '', 'tick_cnt': 0};
    }

    Map<String, dynamic>? bestWorld;
    for (final world in _v1Worlds) {
      if ('${world['oid'] ?? ''}'.trim() != normalizedOriginId) continue;
      if (!_v1WorldBelongsToUser(world, normalizedUid)) continue;
      final tickCnt = ((world['tick_cnt'] as num?)?.toInt() ?? 0);
      final bestTickCnt = ((bestWorld?['tick_cnt'] as num?)?.toInt() ?? -1);
      if (bestWorld == null || tickCnt > bestTickCnt) bestWorld = world;
    }

    if (bestWorld == null) return {'world_id': '', 'tick_cnt': 0};
    return {
      'world_id': '${bestWorld['wid'] ?? ''}',
      'tick_cnt': ((bestWorld['tick_cnt'] as num?)?.toInt() ?? 0),
    };
  }

  bool _v1WorldBelongsToUser(Map<String, dynamic> world, String uid) {
    final ownerUid = '${world['owner_uid'] ?? world['created_uid'] ?? ''}'
        .trim();
    if (ownerUid == uid) return true;
    final worldId = '${world['wid'] ?? ''}'.trim();
    if (worldId.isEmpty) return false;
    return _v1WorldApplies.any(
      (apply) =>
          '${apply['world_id'] ?? ''}'.trim() == worldId &&
          '${apply['applicant_uid'] ?? ''}'.trim() == uid &&
          apply['status'] == 40,
    );
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
      'relation_status': _v1WorldRelationStatus(world),
      'characters': kMockV1Characters.map(_contractCharacter).toList(),
      'locations': kMockV1Locations.map(_contractLocation).toList(),
      'ticks': _v1WorldTicks(world).map(_deepCopyMap).toList(),
    };
  }

  Map<String, dynamic> v1WorldTickList({
    required String worldId,
    required Map<String, String> query,
  }) {
    final world = _findV1World(worldId.trim());
    final ticks = _v1WorldTicks(world).map(_deepCopyMap).toList()
      ..sort((a, b) {
        final aTickNo = (a['tick_no'] as num?)?.toInt() ?? 0;
        final bTickNo = (b['tick_no'] as num?)?.toInt() ?? 0;
        final tickNoCompare = bTickNo.compareTo(aTickNo);
        if (tickNoCompare != 0) return tickNoCompare;
        return '${b['tick_id'] ?? ''}'.compareTo('${a['tick_id'] ?? ''}');
      });
    return _v1Paged(ticks, query);
  }

  Map<String, dynamic> applyToV1World({
    required String worldId,
    String? message,
  }) {
    final world = _findV1World(worldId.trim());
    final applicantUid = '${_v1User['uid']}';
    for (final apply in _v1WorldApplies) {
      if (apply['world_id'] == world['wid'] &&
          apply['applicant_uid'] == applicantUid &&
          (apply['status'] == 10 || apply['status'] == 20)) {
        return {'apply_id': apply['apply_id'], 'status': apply['status']};
      }
    }
    final apply = _newV1WorldApply(
      applyId: 'apl_mock_${(++_v1WorldApplySeq).toString().padLeft(3, '0')}',
      worldId: '${world['wid']}',
      message: message,
    );
    _v1WorldApplies.add(apply);
    return {'apply_id': apply['apply_id'], 'status': apply['status']};
  }

  Map<String, dynamic> v1WorldApplyList(Map<String, String> query) {
    final worldId = (query['world_id'] ?? '').trim();
    final status = int.tryParse((query['status'] ?? '').trim());
    final applies = _v1WorldApplies
        .where((apply) {
          final matchesWorld = worldId.isEmpty || apply['world_id'] == worldId;
          final matchesStatus = status == null || apply['status'] == status;
          return matchesWorld && matchesStatus;
        })
        .toList(growable: false);
    return _v1Paged(applies, query);
  }

  Map<String, dynamic> reviewV1WorldApply({
    required String applyId,
    required String action,
    String? reviewMsg,
  }) {
    final apply = _findV1WorldApply(applyId);
    final normalizedAction = action.trim().toLowerCase();
    final status = normalizedAction == 'reject' ? 30 : 20;
    apply['status'] = status;
    apply['reviewer_uid'] = _v1User['uid'];
    apply['review_msg'] = reviewMsg ?? '';
    apply['reviewed_at'] = _unixSeconds();
    return {'apply_id': apply['apply_id'], 'status': status};
  }

  Map<String, dynamic> joinV1World({
    required String worldId,
    String? presetCharacterId,
    Map<String, dynamic>? customRole,
  }) {
    final world = _findV1World(worldId.trim());
    final applicantUid = '${_v1User['uid']}';
    Map<String, dynamic>? apply;
    for (final item in _v1WorldApplies) {
      if (item['world_id'] == world['wid'] &&
          item['applicant_uid'] == applicantUid) {
        apply = item;
      }
    }
    if (apply == null) {
      apply = _newV1WorldApply(
        applyId: 'apl_mock_${(++_v1WorldApplySeq).toString().padLeft(3, '0')}',
        worldId: '${world['wid']}',
      );
      apply['status'] = 20;
      _v1WorldApplies.add(apply);
    }
    final wasJoined = apply['status'] == 40;
    apply['status'] = 40;
    apply['joined_at'] = _unixSeconds();

    final presetId = (presetCharacterId ?? '').trim();
    final customCharId = (customRole?['char_id'] ?? '').toString().trim();
    final charId = presetId.isNotEmpty
        ? presetId
        : customCharId.isNotEmpty
        ? customCharId
        : 'char_U_MOCK';
    if (!wasJoined) {
      world['player_cnt'] = ((world['player_cnt'] as num?)?.toInt() ?? 0) + 1;
      if (presetId.isEmpty) {
        world['ai_character_cnt'] =
            ((world['ai_character_cnt'] as num?)?.toInt() ?? 0) + 1;
      }
    }
    return {'world_id': world['wid'], 'char_id': charId};
  }

  String _v1WorldRelationStatus(Map<String, dynamic> world) {
    final applicantUid = '${_v1User['uid']}';
    if ('${world['owner_uid']}' == applicantUid) return 'owner';
    Map<String, dynamic>? currentApply;
    for (final apply in _v1WorldApplies) {
      if (apply['world_id'] == world['wid'] &&
          apply['applicant_uid'] == applicantUid) {
        currentApply = apply;
      }
    }
    switch (currentApply?['status']) {
      case 10:
        return 'pending';
      case 20:
        return 'approved';
      case 30:
        return 'rejected';
      case 40:
        return 'joined';
      default:
        return 'none';
    }
  }

  Map<String, dynamic> tickV1World(String worldId) {
    final world = _findV1World(worldId);
    final tickCount = ((world['tick_cnt'] as num?)?.toInt() ?? 0) + 1;
    final now = DateTime.now().toUtc();
    final nowIso = now.toIso8601String();
    final nowEpoch = _mockUnixTimestamp(now);
    world['tick_cnt'] = tickCount;
    world['last_progress_at'] = nowIso;
    world['last_progress_summary'] = 'Mock tick $tickCount completed.';
    world['updated_at'] = nowIso;
    final lastTick = {
      'tick_id': 'tick_${world['wid']}_$tickCount',
      'tick_no': tickCount,
      'status': 10,
      'created_at': nowEpoch,
      'tick_result': {
        'narrator': world['last_progress_summary'],
        'paragraphs': const <Map<String, dynamic>>[],
        'location_groups': const <Map<String, dynamic>>[],
      },
    };
    _v1WorldTicks(world).add(lastTick);
    return {
      'world_id': world['wid'],
      'tick_cnt': tickCount,
      'last_tick': _deepCopyMap(lastTick),
    };
  }

  List<Map<String, dynamic>> v1Notifications() {
    return _v1Notifications.map(_deepCopyMap).toList();
  }

  Map<String, dynamic> v1UnreadSummary() {
    final worldApplyUnread = _v1UnreadCount('world_apply');
    final followUnread = _v1UnreadCount('follow');
    final interactionUnread = _v1UnreadCount('interaction');
    final directMessageUnread = v1DirectMessageUnreadCount();
    return {
      'world_apply_unread': worldApplyUnread,
      'follow_unread': followUnread,
      'interaction_unread': interactionUnread,
      'direct_message_unread': directMessageUnread,
      'total_unread':
          worldApplyUnread +
          followUnread +
          interactionUnread +
          directMessageUnread,
    };
  }

  void markV1NotificationsRead({
    required String? block,
    required String? notificationId,
  }) {
    for (final notification in _v1Notifications) {
      final id = notification['notification_id']?.toString();
      final matchesId =
          notificationId != null &&
          notificationId.isNotEmpty &&
          id == notificationId;
      final matchesBlock =
          (block == null || block.isEmpty || block == 'all') ||
          notification['notice_block']?.toString() == block;
      if (matchesId ||
          (notificationId == null || notificationId.isEmpty) && matchesBlock) {
        notification['is_read'] = true;
      }
    }
  }

  int _v1UnreadCount(String block) {
    return _v1Notifications.where((notification) {
      return notification['notice_block']?.toString() == block &&
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

  List<Map<String, dynamic>> v1DmConversations() {
    return [
      _v1DirectMessageConversation(),
      for (var index = 1; index < _v1DirectMessagePeers.length; index += 1)
        _conversationForPeer('${_v1DirectMessagePeers[index]['uid']}'),
    ];
  }

  String v1DmConversationCursor() => _v1DmConversationCursor;

  Map<String, dynamic> v1DmConversationDeltas(String afterMessageId) {
    if (afterMessageId != _v1DmConversationCursor ||
        _v1DmConversationDeltaSent) {
      return {
        'list': <Map<String, dynamic>>[],
        'total': 0,
        'next_after_message_id': _v1DmConversationCursor,
      };
    }
    _v1DmConversationDeltaSent = true;
    _v1DmConversationCursor = 'dm_sync_2';
    final updatedPrimary = _v1DirectMessageConversation()
      ..['last_message_id'] = 'DM_MOCK_DELTA_001'
      ..['last_message'] = 'Incremental mock direct message update.'
      ..['last_message_at'] = _mockUnixTimestamp(DateTime.now())
      ..['last_sender_uid'] = _v1PeerUser['uid']
      ..['unread_cnt'] = 2;
    final newConversation = _mockDirectMessageConversation(1)
      ..['conv_id'] = 'DMC_MOCK_DELTA_001'
      ..['last_message_id'] = 'DM_MOCK_DELTA_002'
      ..['last_message'] = 'Brand new incremental conversation.'
      ..['last_message_at'] = _mockUnixTimestamp(
        DateTime.now().add(const Duration(seconds: 1)),
      )
      ..['unread_cnt'] = 1;
    return {
      'list': [updatedPrimary, newConversation],
      'total': 2,
      'next_after_message_id': _v1DmConversationCursor,
    };
  }

  List<Map<String, dynamic>> v1DmMessagesForPeer(String? peerUid) {
    final messages = _messagesForPeer(peerUid);
    return messages.reversed.map(_deepCopyMap).toList(growable: false);
  }

  Map<String, dynamic> sendV1DirectMessage(Map<String, dynamic> body) {
    final peerUid = '${body['peer_uid'] ?? _v1PeerUser['uid']}';
    final now = _mockUnixTimestamp(DateTime.now());
    final message = {
      'msg_id': 'DM_MOCK_${DateTime.now().millisecondsSinceEpoch}',
      'conv_id': _conversationIdForPeer(peerUid),
      'sender_uid': _v1User['uid'],
      'receiver_uid': peerUid,
      'content': '${body['content'] ?? ''}',
      'created_at': now,
    };
    _messagesForPeer(peerUid).add(message);
    return {
      'message': _deepCopyMap(message),
      'conversation': _conversationForPeer(peerUid),
    };
  }

  void markV1DirectMessagesRead(String? peerUid) {
    if (peerUid == null || peerUid.isEmpty || peerUid == _v1PeerUser['uid']) {
      _v1DirectMessageUnreadCount = 0;
    }
  }

  int v1DirectMessageUnreadCount() => _v1DirectMessageUnreadCount;

  void blockV1DirectMessagePeer(String? targetUid) {
    final uid = targetUid?.trim();
    if (uid == null || uid.isEmpty) return;
    _v1BlockedDirectMessagePeers.add(uid);
  }

  void unblockV1DirectMessagePeer(String? targetUid) {
    final uid = targetUid?.trim();
    if (uid == null || uid.isEmpty) return;
    _v1BlockedDirectMessagePeers.remove(uid);
  }

  List<Map<String, dynamic>> v1DirectMessageBlocks() {
    return [
      if (_v1BlockedDirectMessagePeers.contains(_v1PeerUser['uid']))
        _deepCopyMap(_v1PeerUser),
    ];
  }

  Map<String, dynamic> _v1DirectMessageConversation() {
    final conversation = _deepCopyMap(kMockV1DmConversation);
    final messages = _messagesForPeer('${_v1PeerUser['uid']}');
    final latest = messages.isEmpty ? null : messages.last;
    if (latest != null) {
      conversation['last_message'] = latest['content'];
      conversation['last_message_id'] = latest['msg_id'];
      conversation['last_message_at'] = latest['created_at'];
      conversation['last_sender_uid'] = latest['sender_uid'];
    }
    final iBlockedPeer = _v1BlockedDirectMessagePeers.contains(
      _v1PeerUser['uid'],
    );
    conversation['unread_cnt'] = _v1DirectMessageUnreadCount;
    conversation['i_blocked_peer'] = iBlockedPeer;
    conversation['peer_blocked_me'] = false;
    conversation['can_send_next_message'] = !iBlockedPeer;
    return conversation;
  }

  Map<String, dynamic> _conversationForPeer(String? peerUid) {
    final uid = (peerUid ?? '').trim();
    if (uid.isEmpty || uid == _v1PeerUser['uid']) {
      return _v1DirectMessageConversation();
    }
    final index = _v1DirectMessagePeers.indexWhere(
      (peer) => peer['uid'] == uid,
    );
    final conversation = index < 0
        ? _mockDirectMessageConversation(1)
        : _mockDirectMessageConversation(index);
    final messages = _messagesForPeer(uid);
    final latest = messages.isEmpty ? null : messages.last;
    if (latest != null) {
      conversation['last_message'] = latest['content'];
      conversation['last_message_id'] = latest['msg_id'];
      conversation['last_message_at'] = latest['created_at'];
      conversation['last_sender_uid'] = latest['sender_uid'];
    }
    return conversation;
  }

  String _conversationIdForPeer(String? peerUid) {
    final uid = (peerUid ?? '').trim();
    if (uid.isEmpty || uid == _v1PeerUser['uid']) return 'DMC_MOCK_001';
    final index = _v1DirectMessagePeers.indexWhere(
      (peer) => peer['uid'] == uid,
    );
    if (index < 0) return 'DMC_MOCK_UNKNOWN';
    return 'DMC_MOCK_${(index + 1).toString().padLeft(3, '0')}';
  }

  List<Map<String, dynamic>> _messagesForPeer(String? peerUid) {
    final uid = '${peerUid ?? _v1PeerUser['uid']}'.trim();
    final effectiveUid = uid.isEmpty ? '${_v1PeerUser['uid']}' : uid;
    return _v1DmMessagesByPeer.putIfAbsent(
      effectiveUid,
      () => <Map<String, dynamic>>[],
    );
  }

  Map<String, List<Map<String, dynamic>>> _mockDirectMessageMessagesByPeer() {
    final result = <String, List<Map<String, dynamic>>>{
      '${_v1PeerUser['uid']}': kMockV1DmMessages
          .map((item) => _deepCopyMap(item))
          .toList(growable: true),
    };
    for (var index = 1; index < _v1DirectMessagePeers.length; index += 1) {
      final peer = _v1DirectMessagePeers[index];
      final peerUid = '${peer['uid']}';
      final messageCount = _mockDirectMessageCountForPeerIndex(index);
      result[peerUid] = List<Map<String, dynamic>>.generate(messageCount, (
        messageIndex,
      ) {
        final senderIsPeer = messageIndex.isEven;
        final shortConversation = messageCount <= 2;
        return {
          'msg_id':
              'DM_${peerUid}_${(messageIndex + 1).toString().padLeft(3, '0')}',
          'conv_id': 'DMC_MOCK_${(index + 1).toString().padLeft(3, '0')}',
          'sender_uid': senderIsPeer ? peerUid : _v1User['uid'],
          'receiver_uid': senderIsPeer ? _v1User['uid'] : peerUid,
          'content': shortConversation
              ? _shortDirectMessageContent(index, messageIndex, peer['name'])
              : 'Mock message ${messageIndex + 1} with ${peer['name']}.',
          'created_at': _mockUnixTimestamp(
            DateTime.now().subtract(
              shortConversation
                  ? Duration(minutes: index * 7 + messageCount - messageIndex)
                  : Duration(minutes: (28 - messageIndex) * 11 + index),
            ),
          ),
        };
      }, growable: true);
    }
    return result;
  }

  int _mockDirectMessageCountForPeerIndex(int index) {
    return switch (index) {
      1 => 1,
      2 => 2,
      3 => 1,
      4 => 2,
      _ => 28,
    };
  }

  String _shortDirectMessageContent(
    int peerIndex,
    int messageIndex,
    Object? peerName,
  ) {
    final displayName = '$peerName'.trim().isEmpty
        ? 'this contact'
        : '$peerName';
    if (peerIndex == 1) {
      return 'One-message mock chat with $displayName.';
    }
    if (peerIndex == 2) {
      return messageIndex == 0
          ? 'First short mock message from $displayName.'
          : 'Second short mock reply.';
    }
    if (peerIndex == 3) {
      return 'Single short conversation for layout testing.';
    }
    return messageIndex == 0
        ? 'Tiny two-message thread starts here.'
        : 'And ends here.';
  }

  List<Map<String, dynamic>> _mockDirectMessagePeers() {
    return [
      _deepCopyMap(_v1PeerUser),
      for (var index = 2; index <= 25; index += 1)
        {
          'uid': 'u_mock_dm_${index.toString().padLeft(3, '0')}',
          'name': 'DM Contact $index',
          'avatar': '',
          'bio': 'Mock direct message contact $index.',
          'last_login_at': _mockUnixTimestamp(
            DateTime.utc(2026, 5, (index % 20) + 1, 10),
          ),
          'create_at': _mockUnixTimestamp(
            DateTime.utc(2026, 4, (index % 28) + 1, 8),
          ),
          'follower_cnt': 10 + index,
          'following_cnt': 6 + index,
          'friend_cnt': index % 7,
          'create_origin_cnt': index % 5,
          'launch_world_cnt': index % 4,
          'join_world_cnt': 2 + index,
        },
    ];
  }

  Map<String, dynamic> _mockDirectMessageConversation(int index) {
    final peer = _v1DirectMessagePeers[index];
    final timestamp = _mockUnixTimestamp(
      DateTime.now().subtract(Duration(minutes: index * 23)),
    );
    return {
      'conv_id': 'DMC_MOCK_${(index + 1).toString().padLeft(3, '0')}',
      'peer': _deepCopyMap(peer),
      'last_message_id':
          'DM_MOCK_CONV_${(index + 1).toString().padLeft(3, '0')}',
      'last_message': 'Mock conversation ${index + 1} preview message.',
      'last_message_at': timestamp,
      'last_sender_uid': index.isEven ? peer['uid'] : _v1User['uid'],
      'unread_cnt': index % 4 == 0 ? index % 9 + 1 : 0,
      'is_friend': index.isEven,
      'i_blocked_peer': false,
      'peer_blocked_me': false,
      'can_send_next_message': true,
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
      'world_id': _worldIdForOrigin(oid),
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
      'list': pageItems.map((comment) {
        final enrichedComment = _deepCopyMap(comment);
        enrichedComment.putIfAbsent(
          'world_id',
          () => _worldIdForOrigin('${comment['biz_id'] ?? ''}'),
        );
        return {
          'comment': enrichedComment,
          'latest_replies': _latestV1DiscussReplies('${comment['discuss_id']}'),
        };
      }).toList(),
      'top_total': topComments.length,
      'total_all': topComments.length + replies.length,
      'pn': page,
      'rn': pageSize,
    };
  }

  Map<String, dynamic> v1DiscussReplies(Map<String, String> query) {
    final rootDiscussId = (query['root_discuss_id'] ?? '').trim();
    final page = _positiveInt(query['pn'], fallback: 1);
    final pageSize = _positiveInt(query['rn'], fallback: 20);
    final replies =
        _v1DiscussReplies
            .where((item) => item['root_discuss_id'] == rootDiscussId)
            .toList()
          ..sort(_compareDiscussCreatedDesc);
    final rawStart = (page - 1) * pageSize;
    final start = rawStart > replies.length ? replies.length : rawStart;
    final rawEnd = start + pageSize;
    final end = rawEnd > replies.length ? replies.length : rawEnd;
    return {
      'list': replies.sublist(start, end).map(_deepCopyMap).toList(),
      'total': replies.length,
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
      'world_id': _worldIdForOrigin('${body['biz_id'] ?? _v1Origin['oid']}'),
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

  String _worldIdForOrigin(String oid) {
    final world = _v1Worlds.cast<Map<String, dynamic>?>().firstWhere(
      (item) => '${item?['oid'] ?? ''}' == oid,
      orElse: () => null,
    );
    return '${world?['wid'] ?? ''}'.trim();
  }

  int _compareDiscussCreatedDesc(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    return '${b['created_at']}'.compareTo('${a['created_at']}');
  }

  String _mockSqlTimestamp() {
    return _formatMockDateTime(DateTime.now());
  }

  int _mockUnixTimestamp(DateTime value) {
    return value.millisecondsSinceEpoch ~/ 1000;
  }

  int _mockEpoch(Object? value) {
    if (value is num) return value.toInt();
    final parsed = DateTime.tryParse('$value');
    if (parsed == null) return kMockV1NowEpoch;
    return parsed.toUtc().millisecondsSinceEpoch ~/ 1000;
  }

  String _formatMockDateTime(DateTime value) {
    final now = value.toLocal();
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
    final raw = query['keyword'] ?? query['query'] ?? '';
    final normalized = raw.trim().toLowerCase();
    final requestedType = (query['type'] ?? '').trim().toLowerCase();
    final page = _positiveInt(query['pn'], fallback: 1);
    final pageSize = _positiveInt(query['rn'], fallback: 20);
    bool matches(Object? value) =>
        normalized.isEmpty || '$value'.toLowerCase().contains(normalized);

    final originResults = _v1Origins
        .where(
          (origin) =>
              matches(origin['oid']) ||
              matches(origin['name']) ||
              matches(origin['display_subtitle']) ||
              matches(origin['created_user_name']) ||
              matches((origin['tags'] as List?)?.join(' ')),
        )
        .map(_v1OriginContractItem)
        .toList();

    final worldResults = _v1Worlds
        .where(
          (world) =>
              matches(world['wid']) ||
              matches(world['name']) ||
              matches(world['display_subtitle']) ||
              matches(world['owner_name']) ||
              matches((world['tags'] as List?)?.join(' ')),
        )
        .map(
          (world) => {
            ..._v1WorldContractItem(world),
            'last_tick': {
              'tick_no': world['tick_cnt'] ?? 0,
              'narrator': world['last_progress_summary'] ?? '',
              'created_at': world['last_progress_at'] ?? 0,
              'paragraphs': const <Map<String, dynamic>>[],
            },
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
            'user': {
              'uid': item['uid'] ?? '',
              'name': item['name'] ?? '',
              'avatar': item['avatar'] ?? '',
              'bio': item['bio'] ?? '',
              'last_login_at': item['last_login_at'] ?? kMockV1Now,
              'create_at': item['create_at'] ?? kMockV1Now,
              'follower_cnt': item['follower_cnt'] ?? 0,
              'following_cnt': item['following_cnt'] ?? 0,
              'friend_cnt': item['friend_cnt'] ?? 0,
              'create_origin_cnt': item['create_origin_cnt'] ?? 0,
              'launch_world_cnt': item['launch_world_cnt'] ?? 0,
              'join_world_cnt': item['join_world_cnt'] ?? 0,
            },
            'relation': _relationForSearchUser(item),
          },
        )
        .toList();

    Map<String, dynamic> section(
      String type,
      List<Map<String, dynamic>> items,
    ) {
      final include =
          requestedType.isEmpty ||
          requestedType == 'all' ||
          requestedType == type;
      final visibleItems = include ? items : <Map<String, dynamic>>[];
      return {
        'list': _pageSearchResults(visibleItems, page, pageSize),
        'total': visibleItems.length,
        'pn': page,
        'rn': pageSize,
      };
    }

    return {
      'keyword': raw,
      'type': requestedType == 'all' ? '' : requestedType,
      'origins': section('origin', originResults),
      'worlds': section('world', worldResults),
      'users': section('user', userResults),
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
    final sections = [result['origins'], result['worlds'], result['users']];
    return {
      'list': sections
          .expand((section) => ((section as Map)['list'] as List))
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
      'last_tick': {
        'tick_index': world['tick_cnt'],
        'created_at': world['last_progress_at'],
        'narrator': world['last_progress_summary'],
        'paragraphs': const <Map<String, dynamic>>[],
      },
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
        'origin_version_time': _mockEpoch(origin['updated_at']),
        'owner_uid': origin['owner_uid'] ?? origin['created_uid'],
        'owner_name': origin['owner_name'] ?? origin['created_user_name'],
        'brief': origin['display_subtitle'],
        'setting': origin['world_setting'],
        'events': kMockV1Events.map((event) => event['content']).toList(),
        'tags': origin['tags'],
        'metric': _deepCopyMap(kMockV1Metric),
        'created_at': _mockEpoch(origin['created_at']),
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
        'max_tick_cnt': origin['max_tick_cnt'] ?? origin['tick_cnt'] ?? 0,
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
        'owner_uid': world['owner_uid'],
        'owner_name': world['owner_name'],
        'brief': world['display_subtitle'],
        'setting': world['world_setting'],
        'events': kMockV1Events.map((event) => event['content']).toList(),
        'metric': _deepCopyMap(kMockV1Metric),
        'created_at': _mockEpoch(world['created_at']),
        'started_at': '${world['created_at']}',
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
      'char_id': character['character_id'] ?? character['char_id'],
      'type': character['type'] ?? 'ai',
      'player_uid': character['player_uid'] ?? '',
      'player_username': character['player_username'] ?? '',
      'name': character['name'],
      'identity': character['identity'],
      'brief': character['tagline'] ?? character['personality'],
      'description': character['description'] ?? character['bio'],
      'goal': character['goal'],
      'avatar': character['avatar'],
      'initial_location_id':
          character['initial_location_id'] ?? character['location_id'] ?? '',
      'location_id':
          character['location_id'] ?? character['initial_location_id'] ?? '',
      'metric_value': character['metric_value'] ?? 0,
      'delta': character['delta'] ?? 0,
    };
  }

  Map<String, dynamic> _contractLocation(Map<String, dynamic> location) {
    return {
      'location_id': location['location_id'],
      'level': location['level'] ?? 1,
      'location_pid': location['location_pid'] ?? '',
      'location_name': location['location_name'] ?? location['name'],
      'location_description':
          location['location_description'] ?? location['description'],
      'location_paragraph': location['location_paragraph'] ?? '',
      'location_timestamp': location['location_timestamp'] ?? '',
      'location_summary':
          location['location_summary'] ?? location['description'] ?? '',
      'image': location['image'],
      'x_percent': location['x_percent'],
      'y_percent': location['y_percent'],
      'map_url': location['map_url'] ?? location['image'],
      'dialogue': location['dialogue'] ?? const <Map<String, dynamic>>[],
    };
  }

  List<Map<String, dynamic>> _v1WorldTicks(Map<String, dynamic> world) {
    final worldId = '${world['wid'] ?? ''}'.trim();
    return _v1TicksByWorld.putIfAbsent(
      worldId,
      () => kMockV1Ticks.map(_contractTick).toList(growable: true),
    );
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
      'tick_id': 'tick_mock_${tick['tick_no'] ?? 1}',
      'tick_no': tick['tick_no'] ?? 1,
      'status': tick['status'] ?? 10,
      'created_at': _mockEpoch(tick['created_at']),
      'tick_result': {
        'narrator': tick['summary'] ?? '',
        'paragraphs': paragraphs,
        'location_groups': const <Map<String, dynamic>>[],
      },
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

  void _ensureChatroomMessages() {
    if (_chatroomMessages.isNotEmpty) return;
    final worldId = _resolveChatroomWorldId('');
    final seed = <Map<String, Object?>>[
      {
        'location_id': 'loc_hub',
        'conversation_round_id': 100,
        'round_order': 1,
        'sender_type': 'user',
        'sender_id': 'player1',
        'sender_name': 'Mock User',
        'user_id': 'u_mock_001',
        'content': '大家好',
        'created_at': '2026-05-29 10:00:00',
      },
      {
        'location_id': 'loc_hub',
        'conversation_round_id': 100,
        'round_order': 2,
        'sender_type': 'character',
        'sender_id': 'c_mock_iris',
        'sender_name': 'Iris Vale',
        'user_id': '',
        'content': '你好呀',
        'created_at': '2026-05-29 10:00:05',
      },
      {
        'location_id': 'loc_gate',
        'conversation_round_id': 101,
        'round_order': 1,
        'sender_type': 'narrator',
        'sender_id': '',
        'sender_name': '旁白',
        'user_id': '',
        'content': '夜幕降临...',
        'created_at': '2026-05-29 11:00:00',
      },
    ];
    for (final item in seed) {
      _chatroomMessages.add(
        _newChatroomMessage(
          worldId: worldId,
          locationId: '${item['location_id']}',
          conversationRoundId: item['conversation_round_id'] as int,
          roundOrder: item['round_order'] as int,
          senderType: '${item['sender_type']}',
          senderId: '${item['sender_id']}',
          senderName: '${item['sender_name']}',
          userId: '${item['user_id']}',
          content: '${item['content']}',
          createdAt: '${item['created_at']}',
        ),
      );
    }
  }

  String _resolveChatroomWorldId(String worldId) {
    final trimmed = worldId.trim();
    if (trimmed.isNotEmpty) return trimmed;
    return '${_v1World['wid']}';
  }

  List<Map<String, dynamic>> _chatroomMessagesForWorld(String worldId) {
    _ensureChatroomMessages();
    final resolved = _resolveChatroomWorldId(worldId);
    return _chatroomMessages
        .where((message) => message['world_id'] == resolved)
        .map(_deepCopyMap)
        .toList(growable: false);
  }

  Map<String, dynamic> _newChatroomMessage({
    required String worldId,
    required String locationId,
    required int conversationRoundId,
    required int roundOrder,
    required String senderType,
    required String senderId,
    required String senderName,
    required String userId,
    required String content,
    String? createdAt,
  }) {
    return {
      'message_id': ++_chatroomMessageSeq,
      'world_id': _resolveChatroomWorldId(worldId),
      'location_id': locationId,
      'conversation_round_id': conversationRoundId,
      'round_order': roundOrder,
      'sender_type': senderType,
      'sender_id': senderId,
      'sender_name': senderName,
      'user_id': userId,
      'content': content,
      'created_at': createdAt ?? DateTime.now().toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> _chatroomResponseMessage(Map<String, dynamic> message) {
    final copy = _deepCopyMap(message);
    copy.remove('world_id');
    return copy;
  }

  Map<String, dynamic> _findV1WorldApply(String? applyId) {
    final id = (applyId ?? '').trim();
    for (final apply in _v1WorldApplies) {
      if (id.isEmpty || apply['apply_id'] == id) return apply;
    }
    final apply = _newV1WorldApply(
      applyId: id.isEmpty
          ? 'apl_mock_${(++_v1WorldApplySeq).toString().padLeft(3, '0')}'
          : id,
      worldId: '${_v1World['wid']}',
    );
    _v1WorldApplies.add(apply);
    return apply;
  }

  Map<String, dynamic> _newV1WorldApply({
    required String applyId,
    required String worldId,
    String? message,
  }) {
    return {
      'apply_id': applyId,
      'world_id': worldId,
      'applicant_uid': _v1User['uid'],
      'message': message ?? '',
      'status': 10,
      'reviewer_uid': '',
      'review_msg': '',
      'reviewed_at': 0,
      'joined_at': 0,
      'created_at': _unixSeconds(),
    };
  }

  int _unixSeconds() => DateTime.now().millisecondsSinceEpoch ~/ 1000;
}

Map<String, dynamic> _deepCopyMap(Map<String, dynamic> source) {
  final result = <String, dynamic>{};
  source.forEach((key, value) {
    result[key] = _deepCopyValue(value);
  });
  return result;
}

Map<String, dynamic> _mapFromObject(Object? source) {
  if (source is Map<String, dynamic>) return source;
  if (source is Map) return source.map((key, value) => MapEntry('$key', value));
  return const <String, dynamic>{};
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
