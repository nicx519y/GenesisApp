import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:genesis_flutter_android/app/bootstrap/app_services_scope.dart';
import 'package:genesis_flutter_android/app/bootstrap/service_registry.dart';
import 'package:genesis_flutter_android/app/config/app_config.dart';
import 'package:genesis_flutter_android/app/config/platform_config.dart';
import 'package:genesis_flutter_android/main.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/components/common/list_loading_skeleton.dart';
import 'package:genesis_flutter_android/components/common/copyable_id_label.dart';
import 'package:genesis_flutter_android/components/discuss/story_badge.dart';
import 'package:genesis_flutter_android/components/common/genesis_bottom_sheet_panel.dart';
import 'package:genesis_flutter_android/components/login_sheet.dart';
import 'package:genesis_flutter_android/components/me/user_profile_content.dart';
import 'package:genesis_flutter_android/components/me/signed_out_me_view.dart';
import 'package:genesis_flutter_android/components/world_map.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_client.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_message_storage.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_models.dart';
import 'package:genesis_flutter_android/network/chatroom/world_chatroom_service.dart';
import 'package:genesis_flutter_android/network/direct_message_conversation_store.dart';
import 'package:genesis_flutter_android/network/direct_message_message_store.dart';
import 'package:genesis_flutter_android/pages/create/create_basics_page.dart';
import 'package:genesis_flutter_android/pages/create/create_characters_page.dart';
import 'package:genesis_flutter_android/pages/create/create_locations_page.dart';
import 'package:genesis_flutter_android/pages/create/create_origin_draft_store.dart';
import 'package:genesis_flutter_android/pages/create/create_origin_id_utils.dart';
import 'package:genesis_flutter_android/pages/create/create_origin_page.dart';
import 'package:genesis_flutter_android/pages/create/create_story_events_page.dart';
import 'package:genesis_flutter_android/pages/edit/edit_locations_page.dart';
import 'package:genesis_flutter_android/pages/edit/edit_origin_page.dart';
import 'package:genesis_flutter_android/icons/my_flutter_app_icons.dart';
import 'package:genesis_flutter_android/network/genesis_api.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';
import 'package:genesis_flutter_android/network/mock_data/mock_v1_data.dart';
import 'package:genesis_flutter_android/network/models/user.dart';
import 'package:genesis_flutter_android/components/origin/stat_item.dart';
import 'package:genesis_flutter_android/components/search_bar.dart';
import 'package:genesis_flutter_android/components/world_map_stage.dart';
import 'package:genesis_flutter_android/pages/app_shell_page.dart';
import 'package:genesis_flutter_android/pages/chat/chat_page.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_page.dart';
import 'package:genesis_flutter_android/pages/home/home_page.dart';
import 'package:genesis_flutter_android/pages/me/follows_page.dart';
import 'package:genesis_flutter_android/pages/me/me_page.dart';
import 'package:genesis_flutter_android/pages/me/settings_page.dart';
import 'package:genesis_flutter_android/pages/me/user_info_page.dart';
import 'package:genesis_flutter_android/pages/messages/message_category_list_page.dart';
import 'package:genesis_flutter_android/pages/messages/messages_page.dart';
import 'package:genesis_flutter_android/pages/discuss/post_detail_page.dart';
import 'package:genesis_flutter_android/pages/origin/origin_page.dart';
import 'package:genesis_flutter_android/pages/origin/origin_world_page.dart';
import 'package:genesis_flutter_android/pages/origin_editor/origin_draft_repository.dart';
import 'package:genesis_flutter_android/pages/world/world_page.dart';
import 'package:genesis_flutter_android/platform/auth/auth_session.dart';
import 'package:genesis_flutter_android/platform/auth/backend_auth_coordinator.dart';
import 'package:genesis_flutter_android/platform/auth/identity_auth_service.dart';
import 'package:genesis_flutter_android/platform/channels/genesis_method_channels.dart';
import 'package:genesis_flutter_android/platform/device/device_id_service.dart';
import 'package:genesis_flutter_android/platform/session/memory_user_session_store.dart';
import 'package:genesis_flutter_android/routers/app_router.dart';
import 'package:genesis_flutter_android/ui/components/genesis_avatar.dart';
import 'package:genesis_flutter_android/utils/genesis_image_resource.dart';
import 'package:genesis_flutter_android/utils/genesis_timestamp_formatter.dart';

Finder _richTextWithPlainText(String text) {
  return find.byWidgetPredicate(
    (widget) => widget is RichText && widget.text.toPlainText() == text,
    description: 'RichText with plain text "$text"',
  );
}

SystemUiOverlayStyle _pageStatusBarStyle(WidgetTester tester) {
  return tester
      .widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      )
      .last
      .value;
}

List<Map<dynamic, dynamic>> _captureSystemUiOverlayStyleCalls() {
  final calls = <Map<dynamic, dynamic>>[];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'SystemChrome.setSystemUIOverlayStyle') {
          calls.add(Map<dynamic, dynamic>.from(call.arguments as Map));
        }
        return null;
      });
  return calls;
}

void _clearPlatformChannelHandler() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, null);
}

Future<AppServices> _testServices({
  bool backendAuthenticated = false,
  IdentityAuthService? identityAuth,
  BackendAuthCoordinator? backendAuth,
  ChatroomClient? chatroom,
  HttpTransport? transport,
  bool? useMock,
  String? initialUid = 'u_mock',
  String? initialAuthToken,
  Map<String, dynamic>? initialUserInfo,
  MemoryUserSessionStore? sessionStoreOverride,
  DirectMessageConversationStore? directMessageConversations,
  DirectMessageMessageStore? directMessageMessages,
  ChatroomMessageStorage? chatroomMessages,
}) async {
  const config = AppConfig(useMock: true);
  final platformConfig = DefaultPlatformConfig(appConfig: config);
  const deviceId = _FakeDeviceIdService();
  final sessionStore = sessionStoreOverride ?? MemoryUserSessionStore();
  if (initialUid != null) {
    await sessionStore.saveUid(initialUid);
  }
  if (initialAuthToken != null) {
    await sessionStore.saveAuthToken(initialAuthToken);
  }
  if (initialUserInfo != null) {
    await sessionStore.saveUserInfo(initialUserInfo);
  }
  final resolvedIdentityAuth = identityAuth ?? const _FakeIdentityAuthService();
  final api = GenesisApi(
    useMock: useMock ?? config.useMock,
    transport: transport,
    platformConfig: platformConfig,
    deviceIdService: deviceId,
    sessionStore: sessionStore,
    identityAuthService: resolvedIdentityAuth,
  );
  final resolvedBackendAuth =
      backendAuth ??
      _FakeBackendAuthCoordinator(
        authenticated: backendAuthenticated,
        sessionStore: sessionStore,
      );
  return AppServices(
    config: config,
    platformConfig: platformConfig,
    deviceId: deviceId,
    sessionStore: sessionStore,
    identityAuth: resolvedIdentityAuth,
    backendAuth: resolvedBackendAuth,
    api: api,
    chatroom:
        chatroom ??
        ChatroomClient(
          wsBaseUrl: config.chatroomWsBaseUrl,
          sessionStore: sessionStore,
        ),
    chatroomMessages: chatroomMessages ?? MemoryChatroomMessageStorage(),
    directMessageConversations:
        directMessageConversations ??
        DirectMessageConversationStore(
          api: api,
          sessionStore: sessionStore,
          storage: MemoryDirectMessageConversationStorage(),
        ),
    directMessageMessages:
        directMessageMessages ??
        DirectMessageMessageStore(
          api: api,
          sessionStore: sessionStore,
          storage: MemoryDirectMessageMessageStorage(),
        ),
  );
}

Future<void> _pumpGenesisApp(
  WidgetTester tester, {
  String? initialAuthToken,
}) async {
  await tester.pumpWidget(
    GenesisApp(
      services: await _testServices(initialAuthToken: initialAuthToken),
    ),
  );
}

class _FakeDeviceIdService implements DeviceIdService {
  const _FakeDeviceIdService();

  @override
  Future<String> getDeviceId() async => 'test-device-id';
}

class _FakeIdentityAuthService implements IdentityAuthService {
  const _FakeIdentityAuthService({
    this.hasLocalSession = false,
    this.signInSession,
  });

  final bool hasLocalSession;
  final AuthSession? signInSession;

  @override
  IdentityProfile? currentProfile() {
    if (!hasLocalSession) return null;
    return const IdentityProfile(
      uid: 'identity_uid',
      displayName: 'Identity User',
      email: 'identity@example.com',
      photoUrl: '',
    );
  }

  @override
  bool hasLocalIdentitySession() => hasLocalSession;

  @override
  Future<AuthSession?> refreshSilently() async => null;

  @override
  Future<AuthSession> signIn(IdentityProvider provider) async {
    final session = signInSession;
    if (session != null) {
      return AuthSession(
        provider: provider,
        providerIdToken: session.providerIdToken,
        firebaseIdToken: session.firebaseIdToken,
        identityUid: session.identityUid,
        email: session.email,
        displayName: session.displayName,
        photoUrl: session.photoUrl,
      );
    }
    throw UnimplementedError(
      'Widget tests should not launch identity sign-in.',
    );
  }

  @override
  Future<void> signOutIdentity() async {}
}

class _FakeBackendAuthCoordinator implements BackendAuthCoordinator {
  _FakeBackendAuthCoordinator({
    required bool authenticated,
    required MemoryUserSessionStore sessionStore,
    User? loginUser,
    Object? loginError,
  }) : _authenticated = authenticated,
       _sessionStore = sessionStore,
       _loginUser = loginUser,
       _loginError = loginError;

  bool _authenticated;
  final MemoryUserSessionStore _sessionStore;
  final User? _loginUser;
  final Object? _loginError;
  int loginCount = 0;
  int sessionCheckCount = 0;
  IdentityProvider? lastLoginProvider;

  @override
  Future<bool> hasAuthenticatedBackendSession({
    bool tryAutoRefresh = true,
  }) async {
    sessionCheckCount += 1;
    return _authenticated;
  }

  @override
  Future<User> loginWithIdentity(AuthSession session) async {
    loginCount += 1;
    lastLoginProvider = session.provider;
    final error = _loginError;
    if (error != null) throw error;
    final user =
        _loginUser ??
        User(
          id: 1,
          uid: session.identityUid,
          did: '',
          nickname: session.displayName,
          avatar: session.photoUrl,
          createdAt: null,
        );
    if (user.uid.trim().isNotEmpty) {
      await _sessionStore.saveUid(user.uid);
    }
    await _sessionStore.saveAuthToken('backend-token');
    _authenticated = true;
    return user;
  }

  @override
  Future<void> signOut() async {
    await _sessionStore.clearUid();
  }

  @override
  Future<void> deleteAccount() async {
    await _sessionStore.clearUid();
  }
}

class _RecordingV1ListTransport implements HttpTransport {
  static const total = 100;

  _RecordingV1ListTransport({
    this.worldRelationStatus = 'owner',
    this.originDiscussCount = 9,
    this.discussTotalAll = 25,
    this.originDetailCompleter,
    this.worldTickCompleter,
    this.worldDetailCompleter,
    this.userInfoCompleter,
    this.originListCompleter,
    this.worldListCompleter,
    this.setPlayerSceneCompleter,
    this.worldMetricDefault = 0,
    this.worldCharacterMetricValue = 50,
    this.originMapUrl = '',
    this.originCharacters,
    this.originLocations,
    this.originTicks,
    this.worldMapUrl = '',
    this.worldCharacters,
    this.worldLocations,
    this.worldSummaryLatestItems,
    this.worldDetailTicksByRequest,
    this.worldDetailTickCountsByRequest,
    this.hotTagsCompleter,
  });

  final requests = <TransportRequest>[];
  static const _defaultHotTags = ['Destroyed'];
  String worldRelationStatus;
  final int originDiscussCount;
  final int discussTotalAll;
  final Completer<TransportResponse>? originDetailCompleter;
  final Completer<TransportResponse>? worldTickCompleter;
  final Completer<TransportResponse>? worldDetailCompleter;
  final Completer<TransportResponse>? userInfoCompleter;
  final Completer<TransportResponse>? originListCompleter;
  final Completer<TransportResponse>? worldListCompleter;
  final Completer<TransportResponse>? setPlayerSceneCompleter;
  final Object? worldMetricDefault;
  final Object? worldCharacterMetricValue;
  final String originMapUrl;
  final List<Map<String, Object?>>? originCharacters;
  final List<Map<String, Object?>>? originLocations;
  final List<Map<String, Object?>>? originTicks;
  final String worldMapUrl;
  final List<Map<String, Object?>>? worldCharacters;
  final List<Map<String, Object?>>? worldLocations;
  final List<Map<String, Object?>>? worldSummaryLatestItems;
  final List<List<Map<String, Object?>>>? worldDetailTicksByRequest;
  final List<int>? worldDetailTickCountsByRequest;
  final Completer<TransportResponse>? hotTagsCompleter;
  int _worldDetailRequestIndex = 0;

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    requests.add(request);
    if (request.uri.path.endsWith('/origin/detail')) {
      final pendingResponse = originDetailCompleter;
      if (pendingResponse != null) return pendingResponse.future;
      final oid =
          request.uri.queryParameters['origin_id'] ??
          request.uri.queryParameters['oid'] ??
          '';
      return _jsonResponse({
        'err_no': 0,
        'err_str': 'success',
        'data': _originDetail(oid),
      });
    }
    if (request.uri.path.endsWith('/world/detail')) {
      final pendingResponse = worldDetailCompleter;
      if (pendingResponse != null) return pendingResponse.future;
      final wid =
          request.uri.queryParameters['world_id'] ??
          request.uri.queryParameters['wid'] ??
          '';
      final detail = _worldDetail(wid);
      final ticksByRequest = worldDetailTicksByRequest;
      if (ticksByRequest != null) {
        final index = _worldDetailRequestIndex.clamp(
          0,
          ticksByRequest.length - 1,
        );
        detail['ticks'] = ticksByRequest[index];
      }
      final tickCountsByRequest = worldDetailTickCountsByRequest;
      if (tickCountsByRequest != null) {
        final index = _worldDetailRequestIndex.clamp(
          0,
          tickCountsByRequest.length - 1,
        );
        final stats = Map<String, Object?>.from(detail['stats']! as Map);
        stats['tick_cnt'] = tickCountsByRequest[index];
        detail['stats'] = stats;
      }
      _worldDetailRequestIndex += 1;
      return _jsonResponse({'err_no': 0, 'err_str': 'success', 'data': detail});
    }
    if (request.uri.path.endsWith('/world/tick/list')) {
      final wid = request.uri.queryParameters['world_id'] ?? 'w_test_1';
      final pn = int.tryParse(request.uri.queryParameters['pn'] ?? '') ?? 1;
      final rn = int.tryParse(request.uri.queryParameters['rn'] ?? '') ?? 20;
      const totalTicks = 25;
      final start = ((pn - 1) * rn).clamp(0, totalTicks);
      final end = (start + rn).clamp(0, totalTicks);
      return _jsonResponse({
        'err_no': 0,
        'err_str': 'success',
        'data': {
          'list': [
            for (var index = start; index < end; index += 1)
              {
                'tick_id': 'tick_${wid}_${index + 1}',
                'tick_no': totalTicks - index,
                'status': 10,
                'created_at': 1777680000 + index,
                'tick_result': {
                  'narrator': index == 0
                      ? 'Paged event first page.'
                      : 'Paged event ${index + 1}.',
                  'paragraphs': [
                    {
                      'location_id': 'l_$wid',
                      'timestamp': 'tick-time-${index + 1}',
                      'text': 'Paged event paragraph ${index + 1}.',
                      'character_deltas': const <Object?>[],
                    },
                  ],
                  'location_groups': const <Object?>[],
                },
              },
          ],
          'total': totalTicks,
          'pn': pn,
          'rn': rn,
        },
      });
    }
    if (request.uri.path.endsWith('/world/summary/latest')) {
      return _jsonResponse({
        'err_no': 0,
        'err_str': 'success',
        'data': {
          'list':
              worldSummaryLatestItems ??
              _worldSummaryLatest(
                request.uri.queryParameters['origin_id'] ?? 'o_test_1',
              ),
        },
      });
    }
    if (request.method == 'POST' && request.uri.path.endsWith('/world/tick')) {
      if (worldTickCompleter != null) {
        return worldTickCompleter!.future;
      }
      final body = decodedBody(request);
      return _jsonResponse({
        'err_no': 0,
        'err_str': 'success',
        'data': {
          'world_id': body['world_id'],
          'tick_cnt': 4,
          'last_tick': <String, Object?>{},
        },
      });
    }
    if (request.method == 'POST' && request.uri.path.endsWith('/world/apply')) {
      final body = decodedBody(request);
      return _jsonResponse({
        'err_no': 0,
        'err_str': 'success',
        'data': {'apply_id': 'apl_${body['world_id']}', 'status': 10},
      });
    }
    if (request.method == 'POST' && request.uri.path.endsWith('/world/join')) {
      final body = decodedBody(request);
      return _jsonResponse({
        'err_no': 0,
        'err_str': 'success',
        'data': {'world_id': body['world_id'], 'char_id': 'char_1'},
      });
    }
    if (request.method == 'POST' &&
        request.uri.path.endsWith('/session/set-world')) {
      return _jsonResponse({
        'err_no': 0,
        'err_str': 'success',
        'data': {'ok': true},
      });
    }
    if (request.method == 'POST' &&
        request.uri.path.endsWith('/session/set-player-scene')) {
      if (setPlayerSceneCompleter != null) {
        return setPlayerSceneCompleter!.future;
      }
      return _jsonResponse({
        'err_no': 0,
        'err_str': 'success',
        'data': {'ok': true},
      });
    }
    if (request.method == 'POST' &&
        request.uri.path.endsWith('/origin/launch')) {
      return _jsonResponse({
        'err_no': 0,
        'err_msg': 'succ',
        'data': {'world_id': 'w_launched_from_origin'},
      });
    }
    if (request.method == 'GET' && request.uri.path.endsWith('/hot_tags')) {
      final pendingResponse = hotTagsCompleter;
      if (pendingResponse != null) return pendingResponse.future;
      return _jsonResponse({
        'err_no': 0,
        'err_msg': 'succ',
        'data': {'list': _defaultHotTags},
      });
    }
    if (request.method == 'POST' && request.uri.path.endsWith('/user/delete')) {
      return _jsonResponse({
        'err_no': 0,
        'err_msg': 'succ',
        'data': <String, Object?>{},
      });
    }
    if (request.method == 'POST' &&
        request.uri.path.endsWith('/discuss/post')) {
      return _jsonResponse({
        'err_no': 0,
        'err_str': 'success',
        'data': {'discuss_id': 'dis_new', 'root_discuss_id': '', 'level': 1},
      });
    }
    if (request.uri.path.endsWith('/user/info')) {
      if (userInfoCompleter != null) {
        return userInfoCompleter!.future;
      }
      final uid = request.uri.queryParameters['uid'] ?? 'u_cached';
      return _jsonResponse({
        'err_no': 0,
        'err_str': 'success',
        'data': {
          'user': {
            'uid': uid,
            'name': 'Remote User',
            'avatar': '',
            'following_cnt': 13,
            'follower_cnt': 17,
          },
          'relation': {
            'is_self': uid == 'u_cached',
            'is_followed': false,
            'i_followed': false,
          },
        },
      });
    }
    if (request.uri.path.endsWith('/discuss/list')) {
      final bizId = request.uri.queryParameters['biz_id'] ?? '';
      final pn = int.tryParse(request.uri.queryParameters['pn'] ?? '') ?? 1;
      final rn = int.tryParse(request.uri.queryParameters['rn'] ?? '') ?? 20;
      final totalAll = discussTotalAll;
      final start = ((pn - 1) * rn).clamp(0, totalAll);
      final end = (start + rn).clamp(0, totalAll);
      return _jsonResponse({
        'err_no': 0,
        'err_str': 'success',
        'data': {
          'list': [
            for (var index = start; index < end; index += 1)
              {
                'comment': {
                  'discuss_id': 'dis_${bizId}_${index + 1}',
                  'biz_type': 1,
                  'biz_id': bizId,
                  'author': {
                    'uid': 'u_discuss_${bizId}_${index + 1}',
                    'name': index == 0 ? 'Shawn' : 'User ${index + 1}',
                  },
                  'content': index == 0
                      ? 'Discuss preview for $bizId'
                      : 'Discuss preview ${index + 1} for $bizId',
                  'reply_cnt': 36 + index,
                  'created_at': '2026-02-09T00:00:00Z',
                },
                'latest_replies': const <Object?>[],
              },
          ],
          'top_total': totalAll,
          'total_all': totalAll,
          'pn': pn,
          'rn': rn,
        },
      });
    }

    final pn = int.tryParse(request.uri.queryParameters['pn'] ?? '') ?? 1;
    final rn = int.tryParse(request.uri.queryParameters['rn'] ?? '') ?? 20;
    if (request.uri.path.endsWith('/origin/list') &&
        originListCompleter != null) {
      return originListCompleter!.future;
    }
    if (request.uri.path.endsWith('/world/list') &&
        worldListCompleter != null) {
      return worldListCompleter!.future;
    }
    final start = ((pn - 1) * rn).clamp(0, total);
    final end = (start + rn).clamp(0, total);
    final list = [
      for (var index = start; index < end; index++)
        request.uri.path.endsWith('/world/list')
            ? _worldItem(index)
            : _originItem(index),
    ];
    return _jsonResponse({
      'err_no': 0,
      'err_str': 'success',
      'data': {'list': list, 'total': total},
    });
  }

  TransportResponse _jsonResponse(Map<String, Object?> body) {
    return TransportResponse(
      statusCode: 200,
      headers: const {'content-type': 'application/json'},
      body: jsonEncode(body),
    );
  }

  List<TransportRequest> requestsFor(String path) {
    return requests.where((request) => request.uri.path == path).toList();
  }

  Map<String, dynamic> decodedBody(TransportRequest request) {
    return jsonDecode(utf8.decode(request.bodyBytes ?? const <int>[]))
        as Map<String, dynamic>;
  }

  Map<String, Object?> _originItem(int index) {
    final seq = index + 1;
    return {
      'oid': 'o_test_$seq',
      'status': 2,
      'version_num': 1 + index % 3,
      'name': 'Origin $seq',
      'cover': '',
      'display_subtitle': 'Origin subtitle $seq',
      'world_view': 'Origin world view $seq',
      'created_uid': 'u_test',
      'created_user_name': 'Tester',
      'created_at': '2026-05-01T00:00:00Z',
      'updated_at': '2026-05-02T00:00:00Z',
      'tags': ['tag$seq', 'scene'],
      'copy_cnt': seq,
      'connect_cnt': seq + 1,
      'discuss_cnt': seq + 2,
      'character_cnt': 2,
      'location_cnt': 3,
    };
  }

  Map<String, Object?> _worldItem(int index) {
    final seq = index + 1;
    return {
      'oid': 'o_test_$seq',
      'origin_version_num': 1 + index % 3,
      'origin_version_create_at': '2026-05-01T00:00:00Z',
      'wid': 'w_test_$seq',
      'status': 1,
      'name': 'World $seq',
      'cover': '',
      'display_subtitle': 'World subtitle $seq',
      'created_uid': 'u_test',
      'created_user_name': 'Tester',
      'owner_uid': 'u_test',
      'owner_name': 'Tester',
      'created_at': '2026-05-01T00:00:00Z',
      'updated_at': '2026-05-02T00:00:00Z',
      'last_progress_at': '2026-05-02T00:00:00Z',
      'last_progress_summary': 'Legacy world progress summary $seq',
      'last_tick': {
        'tick_no': seq,
        'created_at': '2026-05-02T00:00:00Z',
        'narrator': 'World tick narrator $seq',
        'paragraphs': const <Map<String, Object?>>[],
      },
      'tags': ['world$seq', 'scene'],
      'tick_cnt': seq,
      'connect_cnt': seq + 1,
      'ai_character_cnt': 2,
      'player_cnt': 3,
      'location_cnt': 4,
    };
  }

  List<Map<String, Object?>> _worldSummaryLatest(String originId) {
    final resolvedOriginId = originId.isEmpty ? 'o_test_1' : originId;
    return [
      {
        'world_id': 'w_summary_1',
        'origin_id': resolvedOriginId,
        'tick_no': 4,
        'summary': 'First copied world progress summary for $resolvedOriginId.',
        'tick_time': 1780000000,
        'created_at': 1780000010,
      },
      {
        'world_id': 'w_summary_2',
        'origin_id': resolvedOriginId,
        'tick_no': 5,
        'summary':
            'Second copied world progress summary for $resolvedOriginId.',
        'tick_time': 1780000100,
        'created_at': 1780000110,
      },
    ];
  }

  Map<String, Object?> _originDetail(String oid) {
    final fallback = oid.isEmpty ? 'o_test_1' : oid;
    return {
      'info': {
        'origin_id': fallback,
        'origin_name': 'Origin detail $fallback',
        'origin_version': '1',
        'origin_version_time': 1777680000,
        'owner_uid': 'u_test',
        'owner_name': 'Tester',
        'brief': 'Origin detail subtitle',
        'setting': 'Origin detail setting',
        'events': const <String>[],
        'tags': ['detail'],
        'metric': <String, Object?>{},
        'created_at': 1777593600,
        'started_at': 'Day 1',
        'tick_duration_days': 30,
        'cover': '',
        'map_url': originMapUrl,
        'status': 10,
      },
      'stats': {
        'copy_cnt': 7,
        'discuss_cnt': originDiscussCount,
        'character_cnt': 1,
        'connect_cnt': 8,
        'location_cnt': 1,
        'max_tick_cnt': 0,
      },
      'characters':
          originCharacters ??
          [
            {
              'char_id': 'c_$fallback',
              'type': 'ai',
              'player_uid': '',
              'player_username': '',
              'name': 'Detail Character',
              'identity': 'Guide',
              'brief': 'Knows the path',
              'description': 'A character from detail.',
              'goal': '',
              'avatar': '',
              'initial_location_id': 'l_$fallback',
              'location_id': 'l_$fallback',
              'metric_value': 0,
              'delta': 0,
            },
          ],
      'locations':
          originLocations ??
          [
            {
              'location_id': 'l_$fallback',
              'level': 1,
              'location_pid': '',
              'location_name': 'Detail Location',
              'location_description': 'A location from detail.',
              'location_paragraph': 'Detail location launch paragraph.',
              'location_timestamp': '',
              'location_summary': '',
              'image': '',
              'x_percent': 30,
              'y_percent': 40,
              'map_url': '',
              'dialogue': const <Object?>[],
            },
          ],
      'ticks':
          originTicks ??
          const [
            {
              'tick_no': 1,
              'created_at': 1777680000,
              'tick_result': {
                'narrator': 'Origin launch tick narrator.',
                'paragraphs': [
                  {
                    'location_id': 'l_o_test_1',
                    'text': 'Detail location launch paragraph.',
                  },
                  {'location_id': 'l_o_test_1_empty', 'text': ''},
                ],
              },
            },
          ],
    };
  }

  Map<String, Object?> _worldDetail(String wid) {
    final fallback = wid.isEmpty ? 'w_test_1' : wid;
    return {
      'info': {
        'world_id': fallback,
        'world_name': 'World detail $fallback',
        'origin_id': 'o_for_$fallback',
        'origin_version': '1',
        'origin_version_time': '2026-05-01T00:00:00Z',
        'brief': 'World detail subtitle',
        'setting': 'World detail setting',
        'events': ['World detail loaded.'],
        'created_at': '2026-05-01T00:00:00Z',
        'owner_uid': 'u_test',
        'owner_name': 'Tester',
        'metric': {
          'mode': 'qualitative',
          'label': 'Goal Progress',
          'unit': '%',
          'range': [0, 100],
          'default': worldMetricDefault,
        },
        'started_at': '2026-05-01T00:00:00Z',
        'tick_duration_days': 30,
        'cover': '',
        'map_url': worldMapUrl,
        'status': 1,
      },
      'relation_status': worldRelationStatus,
      'stats': {
        'tick_cnt': 3,
        'connect_cnt': 4,
        'character_cnt': 1,
        'player_cnt': 1,
        'location_cnt': 1,
      },
      'characters':
          worldCharacters ??
          [
            {
              'type': 'ai',
              'player_uid': worldRelationStatus == 'approved' ? '' : 'u_mock',
              'player_username': 'Mock User',
              'char_id': 'c_$fallback',
              'name': 'World Character',
              'identity': 'Guide',
              'brief': 'Knows the world',
              'description': 'A world character.',
              'goal': 'Guide the player.',
              'avatar': '',
              'initial_location_id': 'l_$fallback',
              'location_id': 'l_$fallback',
              'metric_value': worldCharacterMetricValue,
            },
          ],
      'locations':
          worldLocations ??
          [
            {
              'location_id': 'l_$fallback',
              'location_name': 'World Location',
              'location_summary': 'A world location.',
              'image': '',
              'map_url': '',
              'x_percent': 35,
              'y_percent': 45,
            },
            {
              'location_id': 'l_${fallback}_child',
              'location_pid': 'l_$fallback',
              'location_name': 'Child Location',
              'location_summary': 'A child world location.',
              'image': '',
              'map_url': '',
              'x_percent': 55,
              'y_percent': 45,
            },
          ],
      'ticks': [
        {
          'tick_no': 1,
          'created_at': '2026-05-02T00:00:00Z',
          'tick_result': {
            'narrator': 'World detail loaded.',
            'paragraphs': [
              {
                'location_id': 'l_$fallback',
                'text': 'The first test tick wakes the location.',
                'character_deltas': [
                  {'name': 'World Character', 'delta': '+3 focus'},
                ],
              },
            ],
          },
        },
        {
          'tick_no': 2,
          'created_at': '2026-05-03T00:00:00Z',
          'tick_result': {
            'narrator': 'World detail changed again.',
            'paragraphs': [
              {
                'location_id': 'l_$fallback',
                'text': 'The second test tick moves the story forward.',
                'character_deltas': [
                  {'name': 'World Character', 'delta': '-1 stamina'},
                ],
              },
            ],
          },
        },
      ],
    };
  }
}

class _UserInfoRefreshTransport implements HttpTransport {
  final requests = <TransportRequest>[];
  final Completer<TransportResponse> _originRefreshCompleter =
      Completer<TransportResponse>();
  final Completer<TransportResponse> _worldRefreshCompleter =
      Completer<TransportResponse>();
  var originListRequests = 0;
  var worldListRequests = 0;

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    requests.add(request);
    final path = request.uri.path;
    if (path == '/api/v1/user/info') {
      return _v1Response({
        'user': {
          'uid': request.uri.queryParameters['uid'] ?? 'u_refresh_peer',
          'name': 'Refresh Peer',
          'avatar': '',
          'following_cnt': 2,
          'follower_cnt': 3,
        },
        'relation': {
          'is_self': false,
          'is_followed': false,
          'i_followed': false,
        },
      });
    }
    if (path == '/api/v1/origin/list') {
      originListRequests += 1;
      if (originListRequests == 1) {
        return _v1Response({
          'list': [_originListItem('o_old', 'Origin Old')],
          'total': 1,
        });
      }
      return _originRefreshCompleter.future;
    }
    if (path == '/api/v1/world/list') {
      worldListRequests += 1;
      if (worldListRequests == 1) {
        return _v1Response({
          'list': [_worldListItem('w_old', 'World Old')],
          'total': 1,
        });
      }
      return _worldRefreshCompleter.future;
    }
    return _v1Response(<String, Object?>{});
  }

  void completeOriginRefresh() {
    if (_originRefreshCompleter.isCompleted) return;
    _originRefreshCompleter.complete(
      _v1Response({
        'list': [_originListItem('o_new', 'Origin New')],
        'total': 1,
      }),
    );
  }

  void completeWorldRefresh() {
    if (_worldRefreshCompleter.isCompleted) return;
    _worldRefreshCompleter.complete(
      _v1Response({
        'list': [_worldListItem('w_new', 'World New')],
        'total': 1,
      }),
    );
  }

  Map<String, Object?> _originListItem(String oid, String name) {
    return {
      'info': {
        'oid': oid,
        'name': name,
        'cover': '',
        'created_user_name': 'Refresh Peer',
        'version_num': 1,
        'updated_at': '2026-06-05T00:00:00Z',
      },
      'stats': {'copy_cnt': 1, 'connect_cnt': 2, 'character_cnt': 3},
    };
  }

  Map<String, Object?> _worldListItem(String wid, String name) {
    return {
      'info': {
        'wid': wid,
        'name': name,
        'cover': '',
        'owner_name': 'Refresh Peer',
        'updated_at': '2026-06-05T00:00:00Z',
      },
      'stats': {
        'tick_cnt': 1,
        'connect_cnt': 2,
        'ai_character_cnt': 3,
        'player_cnt': 4,
      },
    };
  }
}

class _QueuedOriginRefreshTransport implements HttpTransport {
  _QueuedOriginRefreshTransport({required this.refreshResponse});

  final Future<TransportResponse> refreshResponse;
  final requests = <TransportRequest>[];
  final _delegate = _RecordingV1ListTransport();

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    requests.add(request);
    if (request.uri.path.endsWith('/origin/list')) {
      if (requestsFor('/api/v1/origin/list').length == 1) {
        return _originListResponse(0);
      }
      return refreshResponse;
    }
    return _delegate.send(request);
  }

  List<TransportRequest> requestsFor(String path) {
    return requests.where((request) => request.uri.path == path).toList();
  }

  TransportResponse _originListResponse(int startIndex) {
    return _delegate._jsonResponse({
      'err_no': 0,
      'err_str': 'success',
      'data': {
        'list': [_delegate._originItem(startIndex)],
        'total': 1,
      },
    });
  }
}

class _RecordingMessageCategoryTransport implements HttpTransport {
  _RecordingMessageCategoryTransport({
    this.readCompleter,
    this.notificationIsRead = true,
    this.notification,
    this.notifications,
  });

  final requests = <TransportRequest>[];
  final Completer<TransportResponse>? readCompleter;
  final bool notificationIsRead;
  final Map<String, Object?>? notification;
  final List<Map<String, Object?>>? notifications;
  var commentRead = false;
  final readBlocks = <String>{};

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    requests.add(request);
    final path = request.uri.path;
    Object? data = <String, Object?>{};
    if (request.method == 'POST' && path == '/api/v1/message/read') {
      final body = decodedBody(request);
      final block = body['block'];
      if (block is String && block.isNotEmpty) {
        readBlocks.add(block);
      }
      if (block == 'interaction') commentRead = true;
      final completer = readCompleter;
      if (completer != null) return completer.future;
    } else if (request.method == 'GET' && path == '/api/v1/message/unread') {
      data = {
        'world_apply_unread': 1,
        'follow_unread': 1,
        'interaction_unread': commentRead ? 0 : 1,
        'direct_message_unread': 0,
        'total_unread': commentRead ? 2 : 3,
      };
    } else if (request.method == 'GET' &&
        path == '/api/v1/message/notifications') {
      data = {
        'list':
            notifications ?? [notification ?? _defaultNotification(request)],
        'total': notifications?.length ?? 1,
      };
    } else if (request.method == 'POST' &&
        path == '/api/v1/world/apply/review') {
      data = {'apply_id': decodedBody(request)['apply_id'], 'status': 20};
    }
    return TransportResponse(
      statusCode: 200,
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({'err_no': 0, 'err_str': 'success', 'data': data}),
    );
  }

  Map<String, dynamic> decodedBody(TransportRequest request) {
    return jsonDecode(utf8.decode(request.bodyBytes ?? const <int>[]))
        as Map<String, dynamic>;
  }

  Map<String, Object?> _defaultNotification(TransportRequest request) {
    final block = request.uri.queryParameters['block'] ?? '';
    return {
      'id': 99,
      'notification_id': 'ntf_recorded_001',
      'notice_block': block,
      'notice_type': 'discuss_comment',
      'sender': const <String, Object?>{},
      'biz_type': 1,
      'biz_id': 'o_recorded_001',
      'obj_id': 'd_recorded_001',
      'content': 'Recorded block message',
      'is_read': readBlocks.contains(block) ? true : notificationIsRead,
      'created_at': '2026-05-20T10:00:00Z',
    };
  }
}

class _RecordingMessagesDataPollTransport implements HttpTransport {
  final requests = <TransportRequest>[];
  var unreadTotal = 4;

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    requests.add(request);
    final path = request.uri.path;
    Object? data = <String, Object?>{};
    if (request.method == 'GET' && path == '/api/v1/message/unread') {
      data = {
        'world_apply_unread': 1,
        'follow_unread': 1,
        'interaction_unread': 1,
        'direct_message_unread': 1,
        'total_unread': unreadTotal,
      };
    } else if (request.method == 'GET' &&
        path == '/api/v1/direct_message/conversations') {
      final isDelta = request.uri.queryParameters.containsKey(
        'after_message_id',
      );
      data = {
        'list': const <Object?>[],
        'total': 0,
        'pn': int.tryParse(request.uri.queryParameters['pn'] ?? '') ?? 1,
        'rn': int.tryParse(request.uri.queryParameters['rn'] ?? '') ?? 100,
        'next_after_message_id': isDelta ? 'dm_cursor_next' : 'dm_cursor_001',
      };
    } else if (request.method == 'GET' && path == '/api/v1/origin/list') {
      data = {'list': const <Object?>[], 'total': 0};
    }
    return _v1Response(data);
  }

  int count(String path) {
    return requests.where((request) => request.uri.path == path).length;
  }

  List<String> get messagesDataPaths {
    return requests
        .map((request) => request.uri.path)
        .where(
          (path) =>
              path == '/api/v1/message/unread' ||
              path == '/api/v1/direct_message/conversations',
        )
        .toList(growable: false);
  }
}

class _BlockingDmConversationsTransport implements HttpTransport {
  final requests = <TransportRequest>[];
  final _conversationsCompleter = Completer<TransportResponse>();

  @override
  Future<TransportResponse> send(TransportRequest request) {
    requests.add(request);
    if (request.method == 'GET' &&
        request.uri.path == '/api/v1/direct_message/conversations') {
      return _conversationsCompleter.future;
    }
    return Future.value(_v1Response(<String, Object?>{}));
  }

  void completeConversations() {
    if (_conversationsCompleter.isCompleted) return;
    _conversationsCompleter.complete(
      _v1Response({
        'list': const <Object?>[],
        'total': 0,
        'pn': 1,
        'rn': 100,
        'next_after_message_id': 'dm_cursor_empty',
      }),
    );
  }

  int count(String path) {
    return requests.where((request) => request.uri.path == path).length;
  }
}

class _RecordingDmConversationsTransport implements HttpTransport {
  final requests = <TransportRequest>[];
  var lastMessage = 'First direct message preview';
  final lastMessageAt = _unixTimestamp(
    DateTime.now().subtract(const Duration(hours: 2)),
  );

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    requests.add(request);
    final path = request.uri.path;
    Object? data = <String, Object?>{};
    if (request.method == 'GET' &&
        path == '/api/v1/direct_message/conversations') {
      final isDelta = request.uri.queryParameters.containsKey(
        'after_message_id',
      );
      data = {
        'list': [
          {
            'conv_id': 'dm_test_001',
            'peer': {
              'uid': 'u_peer_dm',
              'name': 'Penny Direct',
              'avatar': '',
              'last_login_at': _unixTimestamp(DateTime.utc(2026, 5, 20, 10)),
              'create_at': _unixTimestamp(DateTime.utc(2026, 5, 2, 8)),
            },
            'last_message_id': isDelta ? 'dm_msg_test_002' : 'dm_msg_test_001',
            'last_message': lastMessage,
            'last_message_at': lastMessageAt,
            'last_sender_uid': 'u_peer_dm',
            'unread_cnt': 2,
            'is_friend': true,
            'i_blocked_peer': false,
            'peer_blocked_me': false,
            'can_send_next_message': true,
          },
        ],
        'total': 1,
        'pn': int.tryParse(request.uri.queryParameters['pn'] ?? '') ?? 1,
        'rn': int.tryParse(request.uri.queryParameters['rn'] ?? '') ?? 20,
        'next_after_message_id': isDelta ? 'dm_cursor_002' : 'dm_cursor_001',
      };
    }
    return TransportResponse(
      statusCode: 200,
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({'err_no': 0, 'err_msg': 'succ', 'data': data}),
    );
  }
}

class _RecordingDmDeltaTransport implements HttpTransport {
  final requests = <TransportRequest>[];
  var deltaMessage = 'Old preview';

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    requests.add(request);
    final isDelta = request.uri.queryParameters.containsKey('after_message_id');
    final data = isDelta
        ? {
            'list': [
              _dmConversationJson(
                convId: 'dm_existing',
                peerName: 'Delta Peer',
                messageId: 'dm_delta_002',
                message: deltaMessage,
                minutesAgo: 1,
              ),
              _dmConversationJson(
                convId: 'dm_inserted',
                peerName: 'Inserted Peer',
                messageId: 'dm_delta_003',
                message: 'Inserted preview',
                minutesAgo: 2,
              ),
            ],
            'next_after_message_id': 'dm_cursor_002',
          }
        : {
            'list': [
              _dmConversationJson(
                convId: 'dm_existing',
                peerName: 'Delta Peer',
                messageId: 'dm_delta_001',
                message: 'Old preview',
                minutesAgo: 4,
              ),
            ],
            'total': 1,
            'pn': 1,
            'rn': 100,
            'next_after_message_id': 'dm_cursor_001',
          };
    return TransportResponse(
      statusCode: 200,
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({'err_no': 0, 'err_msg': 'succ', 'data': data}),
    );
  }
}

class _RecordingDmChatTransport implements HttpTransport {
  _RecordingDmChatTransport({
    this.failSend = false,
    List<Map<String, dynamic>>? messages,
  }) : messages =
           messages ??
           [
             {
               'msg_id': 'dm_synced_001',
               'conv_id': 'dm_conv',
               'sender_uid': 'u_peer_dm',
               'receiver_uid': 'u_mock',
               'content': 'Synced direct chat',
               'created_at': _unixTimestamp(DateTime.now()),
             },
           ];

  final bool failSend;
  final requests = <TransportRequest>[];
  final List<Map<String, dynamic>> messages;

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    requests.add(request);
    final path = request.uri.path;
    if (request.method == 'GET' && path == '/api/v1/direct_message/list') {
      return _v1Response({
        'list': messages.reversed.toList(growable: false),
        'total': messages.length,
        'pn': int.tryParse(request.uri.queryParameters['pn'] ?? '') ?? 1,
        'rn': int.tryParse(request.uri.queryParameters['rn'] ?? '') ?? 20,
      });
    }
    if (request.method == 'POST' && path == '/api/v1/direct_message/send') {
      if (failSend) {
        return TransportResponse(
          statusCode: 200,
          headers: const {'content-type': 'application/json'},
          body: jsonEncode({
            'err_no': 10001,
            'err_msg': 'send failed',
            'data': <String, Object?>{},
          }),
        );
      }
      final body = jsonDecode(utf8.decode(request.bodyBytes!)) as Map;
      final message = {
        'msg_id': 'dm_sent_${messages.length + 1}',
        'conv_id': 'dm_conv',
        'sender_uid': 'u_mock',
        'receiver_uid': body['peer_uid'],
        'content': body['content'],
        'created_at': _unixTimestamp(DateTime.now()),
      };
      messages.add(message);
      return _v1Response({
        'message': message,
        'conversation': _dmConversationJson(
          convId: 'dm_conv',
          peerName: 'Penny Direct',
          messageId: '${message['msg_id']}',
          message: '${message['content']}',
          minutesAgo: 0,
        ),
      });
    }
    if (request.method == 'POST' && path == '/api/v1/direct_message/read') {
      return _v1Response(<String, Object?>{});
    }
    return _v1Response(<String, Object?>{});
  }
}

Map<String, dynamic> _dmConversationJson({
  required String convId,
  required String peerName,
  required String messageId,
  required String message,
  required int minutesAgo,
}) {
  return {
    'conv_id': convId,
    'peer': {
      'uid': 'peer_$convId',
      'name': peerName,
      'avatar': '',
      'last_login_at': _unixTimestamp(DateTime.utc(2026, 5, 20, 10)),
      'create_at': _unixTimestamp(DateTime.utc(2026, 5, 2, 8)),
    },
    'last_message_id': messageId,
    'last_message': message,
    'last_message_at': _unixTimestamp(
      DateTime.now().subtract(Duration(minutes: minutesAgo)),
    ),
    'last_sender_uid': 'peer_$convId',
    'unread_cnt': 1,
    'is_friend': true,
    'i_blocked_peer': false,
    'peer_blocked_me': false,
    'can_send_next_message': true,
  };
}

int _unixTimestamp(DateTime value) {
  return value.millisecondsSinceEpoch ~/ 1000;
}

Future<AppServices> _messagesServicesWithCachedConversation({
  required DateTime lastMessageAt,
}) async {
  final sessionStore = MemoryUserSessionStore();
  await sessionStore.saveUid('u_mock');
  final storage = MemoryDirectMessageConversationStorage();
  final conversation = _dmConversationJson(
    convId: 'dm_cached_time',
    peerName: 'Penny Direct',
    messageId: 'dm_cached_time_msg',
    message: 'Cached direct message preview',
    minutesAgo: 0,
  )..['last_message_at'] = _unixTimestamp(lastMessageAt);
  await storage.mergeConversations(
    ownerUid: 'u_mock',
    conversations: [conversation],
    nextAfterMessageId: 'cached_cursor',
  );
  final api = GenesisApi(
    useMock: true,
    deviceIdService: const _FakeDeviceIdService(),
    sessionStore: sessionStore,
  );
  final store = DirectMessageConversationStore(
    api: api,
    sessionStore: sessionStore,
    storage: storage,
  );
  return _testServices(
    sessionStoreOverride: sessionStore,
    directMessageConversations: store,
  );
}

Future<void> _jumpChatListToBottom(WidgetTester tester) async {
  final scrollableFinder = find
      .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
      .first;
  final scrollable = tester.state<ScrollableState>(scrollableFinder);
  for (var index = 0; index < 4; index += 1) {
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

Future<void> _jumpChatListToTop(WidgetTester tester) async {
  final scrollableFinder = find
      .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
      .first;
  final scrollable = tester.state<ScrollableState>(scrollableFinder);
  scrollable.position.jumpTo(scrollable.position.minScrollExtent);
  await tester.pumpAndSettle();
}

TransportResponse _v1Response(Object? data) {
  return TransportResponse(
    statusCode: 200,
    headers: const {'content-type': 'application/json'},
    body: jsonEncode({'err_no': 0, 'err_msg': 'succ', 'data': data}),
  );
}

class _RecordingSearchTransport implements HttpTransport {
  final requests = <TransportRequest>[];

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    requests.add(request);
    final path = request.uri.path;
    Object? data = <String, Object?>{};
    if (path == '/api/v1/message/unread') {
      data = {
        'world_apply_unread': 0,
        'follow_unread': 0,
        'interaction_unread': 0,
        'direct_message_unread': 0,
        'total_unread': 0,
      };
    } else if (path == '/api/v1/origin/list') {
      data = {'list': const <Object?>[], 'total': 0};
    } else if (path == '/api/v1/search') {
      data = {
        'keyword': request.uri.queryParameters['keyword'] ?? '',
        'type': request.uri.queryParameters['type'] ?? '',
        'origins': {
          'total': 1,
          'pn': 1,
          'rn': 20,
          'list': [
            {
              'info': {
                'origin_id': 'o_search_1',
                'origin_name': 'Search Origin',
                'brief': 'Origin brief should not render',
                'owner_name': 'Origin Owner',
                'version_num': 3,
                'updated_at': '2020-01-01T00:00:00Z',
                'cover': '',
              },
              'stats': {'copy_cnt': 9, 'connect_cnt': 12, 'character_cnt': 8},
            },
          ],
        },
        'worlds': {
          'total': 1,
          'pn': 1,
          'rn': 20,
          'list': [
            {
              'info': {
                'world_id': 'w_search_1',
                'world_name': 'Search World',
                'brief': 'World brief should not render',
                'owner_name': 'World Owner',
                'cover': '',
              },
              'stats': {
                'tick_cnt': 6,
                'connect_cnt': 4,
                'player_cnt': 8,
                'location_cnt': 1,
              },
            },
          ],
        },
        'users': {
          'total': 1,
          'pn': 1,
          'rn': 20,
          'list': [
            {
              'user': {
                'uid': 'u_search_1',
                'name': 'Search User',
                'bio': 'Bio',
                'avatar': '',
              },
              'relation': {
                'is_self': false,
                'is_followed': false,
                'followed_me': false,
                'is_friend': false,
              },
            },
          ],
        },
      };
    }
    return TransportResponse(
      statusCode: 200,
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({'err_no': 0, 'err_str': 'success', 'data': data}),
    );
  }

  List<TransportRequest> requestsFor(String path) {
    return requests.where((request) => request.uri.path == path).toList();
  }
}

class _RecordingCreateOriginTransport implements HttpTransport {
  final requests = <TransportRequest>[];

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    requests.add(request);
    Object? data = <String, Object?>{};
    if (request.method == 'POST' &&
        request.uri.path == '/api/v1/origin/create') {
      final body = decodedBody(request);
      data = {
        'info': {
          'origin_id': 'o_created_1',
          'origin_name': body['origin_name'],
          'cover': body['cover'],
          'brief': body['brief'],
          'setting': body['setting'],
        },
        'stats': const <String, Object?>{},
        'characters': const <Object?>[],
        'locations': const <Object?>[],
        'ticks': const <Object?>[],
      };
    }
    if (request.method == 'GET' &&
        request.uri.path == '/api/v1/origin/foredit') {
      final oid = request.uri.queryParameters['origin_id'] ?? '';
      data = {
        'origin_id': oid,
        'origin_name': 'Editable Origin',
        'origin_version': '1',
        'brief': 'Editable public view.',
        'setting': 'Editable hidden rules.',
        'events': ['The archive opens.'],
        'tags': const <String>[],
        'metric': {
          'mode': 'qualitative',
          'label': 'Influence',
          'unit': '%',
          'range': [0, 100],
          'default': 0,
        },
        'started_at': 'Day 1',
        'tick_duration_days': 30,
        'cover': 'assets/images/mock_maps/steam_kingdom_isometric.png',
        'map_url': 'assets/images/mock_maps/steam_kingdom_isometric.png',
        'characters': [
          {
            'char_id': 'char_edit_1',
            'name': 'Mira',
            'identity': 'Archivist',
            'personality': 'Patient',
            'bio': 'Keeps the records.',
            'goal': 'Find the first page.',
            'avatar': '',
            'initial_location_id': 'location_edit_1',
          },
        ],
        'locations': [
          {
            'location_id': 'location_edit_1',
            'level': 1,
            'location_pid': '',
            'location_name': 'Archive',
            'location_description': 'A quiet tower.',
            'location_paragraph': '',
            'location_timestamp': '',
            'location_summary': '',
            'image': '',
            'x_percent': 0,
            'y_percent': 0,
            'map_url': '',
          },
        ],
      };
    }
    if (request.method == 'POST' &&
        request.uri.path == '/api/v1/origin/update') {
      final body = decodedBody(request);
      data = {
        'info': {
          'origin_id': body['origin_id'],
          'origin_name': body['origin_name'],
          'cover': body['cover'],
          'brief': body['brief'],
          'setting': body['setting'],
        },
        'stats': const <String, Object?>{},
        'characters': body['characters'] ?? const <Object?>[],
        'locations': body['locations'] ?? const <Object?>[],
        'ticks': const <Object?>[],
      };
    }
    return TransportResponse(
      statusCode: 200,
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({'err_no': 0, 'err_str': 'success', 'data': data}),
    );
  }

  Map<String, dynamic> decodedBody(TransportRequest request) {
    return jsonDecode(utf8.decode(request.bodyBytes ?? const <int>[]))
        as Map<String, dynamic>;
  }

  List<TransportRequest> requestsFor(String path) {
    return requests.where((request) => request.uri.path == path).toList();
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('Home is default tab', (WidgetTester tester) async {
    await _pumpGenesisApp(tester);

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('My World'), findsOneWidget);
    expect(find.text('Popular'), findsOneWidget);
    expect(find.text('Origin'), findsOneWidget);
    expect(find.text('Create'), findsOneWidget);
    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('Me'), findsOneWidget);
  });

  testWidgets('tap header search bar opens search page', (
    WidgetTester tester,
  ) async {
    await _pumpGenesisApp(tester);
    final homeSearchTop = tester
        .getTopLeft(find.byType(SearchBarPlaceholder).first)
        .dy;

    await tester.tap(find.text('Explore').first);
    await tester.pumpAndSettle();

    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);
    final searchPageSearchTop = tester
        .getTopLeft(find.byType(SearchBarPlaceholder).first)
        .dy;
    expect(searchPageSearchTop, homeSearchTop);
  });

  testWidgets('search bar placeholder stays single line with ellipsis', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 180, child: SearchBarPlaceholder()),
        ),
      ),
    );

    final placeholder = tester.widget<Text>(find.text('Explore'));
    expect(placeholder.maxLines, 1);
    expect(placeholder.overflow, TextOverflow.ellipsis);
    expect(placeholder.softWrap, isFalse);
  });

  testWidgets('search page shows tabs and no result state', (
    WidgetTester tester,
  ) async {
    await _pumpGenesisApp(tester);

    await tester.tap(find.text('Explore').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'zz');
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Origin'), findsOneWidget);
    expect(find.text('World'), findsOneWidget);
    expect(find.text('User'), findsOneWidget);
    expect(find.text('No results.'), findsOneWidget);

    await tester.tap(find.text('Origin'));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('No results.'), findsOneWidget);
    expect(find.text('Origins'), findsNothing);

    await tester.tap(find.text('World'));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('No results.'), findsOneWidget);
    expect(find.text('Worlds'), findsNothing);

    await tester.tap(find.text('User'));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('No results.'), findsOneWidget);
    expect(find.text('Users'), findsNothing);
  });

  testWidgets('search page debounces v1 search request and renders sections', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingSearchTransport();
    await tester.pumpWidget(
      GenesisApp(
        services: await _testServices(transport: transport, useMock: false),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Explore').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'reborn');
    await tester.pump(const Duration(milliseconds: 599));
    expect(transport.requestsFor('/api/v1/search'), isEmpty);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();

    final searchRequests = transport.requestsFor('/api/v1/search');
    expect(searchRequests, hasLength(1));
    expect(searchRequests.single.uri.queryParameters['keyword'], 'reborn');
    expect(
      searchRequests.single.uri.queryParameters.containsKey('type'),
      false,
    );
    expect(searchRequests.single.uri.queryParameters['pn'], '1');
    expect(searchRequests.single.uri.queryParameters['rn'], '20');
    expect(find.text('Origins'), findsOneWidget);
    expect(find.text('#Search Origin'), findsOneWidget);
    final title = tester.widget<Text>(find.text('#Search Origin'));
    expect(title.style?.fontSize, 14);
    expect(title.style?.fontWeight, FontWeight.w700);
    expect(find.text('Worlds'), findsOneWidget);
    expect(find.text('Search World'), findsOneWidget);
    expect(find.text('Users'), findsOneWidget);
    expect(find.text('Search User'), findsOneWidget);
    final searchUserUid = find.text('UID: u_search_1');
    expect(searchUserUid, findsOneWidget);
    expect(
      find.ancestor(of: searchUserUid, matching: find.byType(CopyableIdLabel)),
      findsOneWidget,
    );
    final searchUserUidLabel = find.ancestor(
      of: searchUserUid,
      matching: find.byType(CopyableIdLabel),
    );
    expect(
      find.descendant(
        of: searchUserUidLabel,
        matching: find.byIcon(Icons.copy_outlined),
      ),
      findsNothing,
    );
    expect(find.text('Origin brief should not render'), findsNothing);
    expect(find.text('World brief should not render'), findsNothing);
    final subtitle = tester.widget<Text>(
      find.textContaining('OID: o_search_1  Originator: Origin Owner'),
    );
    expect(subtitle.style?.fontSize, 12);
    expect(subtitle.style?.fontWeight, FontWeight.w400);
    expect(find.textContaining('Latest Version: V3 ·'), findsOneWidget);
    expect(find.text('WID: w_search_1  Owner: World Owner'), findsOneWidget);
    expect(find.byType(StatItem), findsNWidgets(7));
  });

  testWidgets('search page renders local mock Chinese user results', (
    WidgetTester tester,
  ) async {
    await _pumpGenesisApp(tester);

    await tester.tap(find.text('Explore').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '老肖');
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('Origins'), findsOneWidget);
    expect(find.textContaining('老肖'), findsWidgets);
  });

  testWidgets('search keeps previous results while debouncing next query', (
    WidgetTester tester,
  ) async {
    await _pumpGenesisApp(tester);

    await tester.tap(find.text('Explore').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '老肖');
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.textContaining('重生'), findsWidgets);

    await tester.enterText(find.byType(TextField), 'zz');
    await tester.pump(const Duration(milliseconds: 1999));
    expect(find.textContaining('重生'), findsWidgets);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('No results.'), findsOneWidget);
  });

  testWidgets('search debounce cancels previous query display', (
    WidgetTester tester,
  ) async {
    await _pumpGenesisApp(tester);

    await tester.tap(find.text('Explore').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'st');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(find.byType(TextField), 'zz');
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.textContaining('#Steam Kingdom'), findsNothing);
    expect(find.text('No results.'), findsOneWidget);
  });

  testWidgets('tap Messages while signed out shows login sheet', (
    WidgetTester tester,
  ) async {
    await _pumpGenesisApp(tester);

    await tester.tap(find.text('Messages'));
    await tester.pumpAndSettle();

    expect(find.text('登录后可使用该功能'), findsNothing);
    expect(find.text('Sign in to continue'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with Apple'), findsOneWidget);
    expect(find.text('Private chats'), findsNothing);
  });

  testWidgets('messages tab shows action buttons and section title', (
    WidgetTester tester,
  ) async {
    await _pumpGenesisApp(tester, initialAuthToken: 'backend-token');

    await tester.tap(find.text('Messages'));
    await tester.pumpAndSettle();

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('New followers'), findsOneWidget);
    expect(find.text('Comments'), findsOneWidget);
    expect(find.text('Private chats'), findsOneWidget);
    expect(
      find.image(const AssetImage('assets/custom-icons/png/notification.png')),
      findsOneWidget,
    );
    expect(
      find.image(const AssetImage('assets/custom-icons/png/following.png')),
      findsOneWidget,
    );
    expect(
      find.image(const AssetImage('assets/custom-icons/png/comment.png')),
      findsOneWidget,
    );
  });

  testWidgets('messages data polling is skipped while signed out', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingMessagesDataPollTransport();
    final services = await _testServices(transport: transport, useMock: false);
    await tester.pumpWidget(
      MaterialApp(
        home: AppServicesScope(
          services: services,
          child: const AppShellPage(initialIndex: 0),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(transport.count('/api/v1/message/unread'), 0);
    expect(transport.count('/api/v1/direct_message/conversations'), 0);

    await tester.pump(const Duration(seconds: 30));
    await tester.pump();
    expect(transport.count('/api/v1/message/unread'), 0);
    expect(transport.count('/api/v1/direct_message/conversations'), 0);

    await tester.tap(find.text('Messages'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in to continue'), findsOneWidget);
    expect(transport.count('/api/v1/message/unread'), 0);
    expect(transport.count('/api/v1/direct_message/conversations'), 0);
  });

  testWidgets('messages data polling shares one thirty second cadence', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingMessagesDataPollTransport();
    final services = await _testServices(
      transport: transport,
      useMock: false,
      initialAuthToken: 'backend-token',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AppServicesScope(
          services: services,
          child: const AppShellPage(initialIndex: 0),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(transport.count('/api/v1/message/unread'), 1);
    expect(transport.count('/api/v1/direct_message/conversations'), 1);
    expect(transport.messagesDataPaths.take(2), [
      '/api/v1/message/unread',
      '/api/v1/direct_message/conversations',
    ]);

    await tester.pump(const Duration(milliseconds: 29999));
    expect(transport.count('/api/v1/message/unread'), 1);
    expect(transport.count('/api/v1/direct_message/conversations'), 1);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(transport.count('/api/v1/message/unread'), 2);
    expect(transport.count('/api/v1/direct_message/conversations'), 2);

    await tester.tap(find.text('Messages'));
    await tester.pump();
    await tester.pump();
    expect(transport.count('/api/v1/message/unread'), 3);
    expect(transport.count('/api/v1/direct_message/conversations'), 3);

    await tester.pump(const Duration(milliseconds: 29999));
    expect(transport.count('/api/v1/message/unread'), 3);
    expect(transport.count('/api/v1/direct_message/conversations'), 3);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(transport.count('/api/v1/message/unread'), 4);
    expect(transport.count('/api/v1/direct_message/conversations'), 4);
  });

  testWidgets(
    'messages tab switch does not duplicate requests while polling is in flight',
    (WidgetTester tester) async {
      final transport = _BlockingDmConversationsTransport();
      final services = await _testServices(
        transport: transport,
        useMock: false,
        initialAuthToken: 'backend-token',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: AppServicesScope(
            services: services,
            child: const AppShellPage(initialIndex: 0),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(transport.count('/api/v1/message/unread'), 1);
      expect(transport.count('/api/v1/direct_message/conversations'), 1);

      await tester.tap(find.text('Messages'));
      await tester.pump();
      await tester.pump();

      expect(transport.count('/api/v1/message/unread'), 1);
      expect(transport.count('/api/v1/direct_message/conversations'), 1);

      transport.completeConversations();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('messages tab switch forces requests when polling is idle', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingMessagesDataPollTransport();
    final services = await _testServices(
      transport: transport,
      useMock: false,
      initialAuthToken: 'backend-token',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AppServicesScope(
          services: services,
          child: const AppShellPage(initialIndex: 0),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(transport.count('/api/v1/message/unread'), 1);
    expect(transport.count('/api/v1/direct_message/conversations'), 1);

    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text('Messages'));
    await tester.pump();
    await tester.pump();

    expect(transport.count('/api/v1/message/unread'), 2);
    expect(transport.count('/api/v1/direct_message/conversations'), 2);

    await tester.pump(const Duration(milliseconds: 29999));
    expect(transport.count('/api/v1/message/unread'), 2);
    expect(transport.count('/api/v1/direct_message/conversations'), 2);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(transport.count('/api/v1/message/unread'), 3);
    expect(transport.count('/api/v1/direct_message/conversations'), 3);
  });

  testWidgets('direct messages list uses conversations endpoint and polls', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingDmConversationsTransport();
    final services = await _testServices(transport: transport, useMock: false);
    await tester.pumpWidget(
      MaterialApp(
        home: AppServicesScope(services: services, child: const MessagesPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Penny Direct'), findsOneWidget);
    expect(find.text('First direct message preview'), findsOneWidget);
    expect(
      find.text(formatGenesisTimestamp(transport.lastMessageAt)),
      findsOneWidget,
    );
    final dmAvatar = find.byKey(const ValueKey('dm-avatar-dm_test_001'));
    final dmName = find.text('Penny Direct');
    expect(dmAvatar, findsOneWidget);
    expect(tester.getSize(dmAvatar), const Size(48, 48));
    expect(tester.widget<GenesisAvatar>(dmAvatar).borderRadius, 5);
    expect(tester.getTopLeft(dmAvatar).dy, tester.getTopLeft(dmName).dy);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('dm-avatar-dm_test_001-unread-badge')),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );

    final initialRequest = transport.requests.firstWhere(
      (request) => request.uri.path == '/api/v1/direct_message/conversations',
    );
    expect(initialRequest.uri.queryParameters['pn'], '1');
    expect(initialRequest.uri.queryParameters['rn'], '100');
    expect(
      initialRequest.uri.queryParameters.containsKey('after_message_id'),
      isFalse,
    );

    transport.lastMessage = 'Polled direct message preview';
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();

    expect(find.text('Polled direct message preview'), findsOneWidget);
    final deltaRequest = transport.requests.lastWhere(
      (request) =>
          request.uri.path == '/api/v1/direct_message/conversations' &&
          request.uri.queryParameters.containsKey('after_message_id'),
    );
    expect(
      deltaRequest.uri.queryParameters['after_message_id'],
      'dm_cursor_001',
    );
    expect(deltaRequest.uri.queryParameters.containsKey('pn'), isFalse);
    expect(deltaRequest.uri.queryParameters.containsKey('rn'), isFalse);
  });

  testWidgets('direct messages use shared absolute time labels', (
    WidgetTester tester,
  ) async {
    var now = DateTime(2026, 6, 5, 10);
    final lastMessageAt = now.subtract(const Duration(seconds: 30));
    final services = await _messagesServicesWithCachedConversation(
      lastMessageAt: lastMessageAt,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AppServicesScope(
          services: services,
          child: MessagesPage(
            onMessagesDataRefresh: () async {},
            nowProvider: () => now,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Penny Direct'), findsOneWidget);
    expect(
      find.text(formatGenesisDateTime(lastMessageAt, now: now)),
      findsOneWidget,
    );

    now = now.add(const Duration(minutes: 1));
    await tester.pump(const Duration(minutes: 1));

    expect(
      find.text(formatGenesisDateTime(lastMessageAt, now: now)),
      findsOneWidget,
    );
  });

  testWidgets('direct messages time labels refresh when tab becomes active', (
    WidgetTester tester,
  ) async {
    final isActive = ValueNotifier<bool>(false);
    var now = DateTime(2026, 6, 5, 23, 59, 30);
    final lastMessageAt = now.subtract(const Duration(seconds: 30));
    final services = await _messagesServicesWithCachedConversation(
      lastMessageAt: lastMessageAt,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AppServicesScope(
          services: services,
          child: MessagesPage(
            onMessagesDataRefresh: () async {},
            isActiveListenable: isActive,
            nowProvider: () => now,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Penny Direct'), findsOneWidget);
    expect(
      find.text(formatGenesisDateTime(lastMessageAt, now: now)),
      findsOneWidget,
    );

    now = now.add(const Duration(seconds: 75));
    await tester.pump(const Duration(seconds: 75));

    expect(find.text('23:59'), findsOneWidget);
    expect(find.text('6-5 23:59'), findsNothing);

    isActive.value = true;
    await tester.pump();

    expect(find.text('23:59'), findsNothing);
    expect(find.text('6-5 23:59'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    isActive.dispose();
  });

  testWidgets('direct messages list avoids spinner during conversation sync', (
    WidgetTester tester,
  ) async {
    void expectEmptyTextCentered() {
      final emptyState = find.byKey(
        const ValueKey('direct-messages-empty-state'),
      );
      final emptyText = find.text('no private messages yet.');
      final emptyCenter = tester.getCenter(emptyState);
      final textCenter = tester.getCenter(emptyText);
      expect(textCenter.dx, closeTo(emptyCenter.dx, 0.1));
      expect(textCenter.dy, closeTo(emptyCenter.dy, 0.1));
    }

    final transport = _BlockingDmConversationsTransport();
    final services = await _testServices(transport: transport, useMock: false);
    await tester.pumpWidget(
      MaterialApp(
        home: AppServicesScope(services: services, child: const MessagesPage()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      transport.requests
          .where(
            (request) =>
                request.uri.path == '/api/v1/direct_message/conversations',
          )
          .length,
      1,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('no private messages yet.'), findsOneWidget);
    expectEmptyTextCentered();

    transport.completeConversations();
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('no private messages yet.'), findsOneWidget);
    expectEmptyTextCentered();
  });

  testWidgets(
    'direct messages pull refresh keeps old rows until callback returns',
    (WidgetTester tester) async {
      final services = await _messagesServicesWithCachedConversation(
        lastMessageAt: DateTime.utc(2026, 6, 5, 10),
      );
      final refreshCompleter = Completer<void>();

      await tester.pumpWidget(
        MaterialApp(
          home: AppServicesScope(
            services: services,
            child: MessagesPage(
              onMessagesDataRefresh: () async {
                await refreshCompleter.future;
                await services.directMessageConversations.mergeConversationJson(
                  _dmConversationJson(
                    convId: 'dm_cached_time',
                    peerName: 'Penny Direct',
                    messageId: 'dm_cached_time_msg_2',
                    message: 'Refreshed direct message preview',
                    minutesAgo: 1,
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cached direct message preview'), findsOneWidget);
      expect(find.text('Refreshed direct message preview'), findsNothing);

      final refreshFuture = tester
          .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
          .show();
      await tester.pump();

      expect(find.text('Cached direct message preview'), findsOneWidget);
      expect(find.text('Refreshed direct message preview'), findsNothing);

      refreshCompleter.complete();
      await tester.pumpAndSettle();
      await refreshFuture;

      expect(find.text('Cached direct message preview'), findsNothing);
      expect(find.text('Refreshed direct message preview'), findsOneWidget);
    },
  );

  testWidgets('direct messages tap opens chat page with peer uid', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingDmConversationsTransport();
    final services = await _testServices(transport: transport, useMock: false);
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: AppRouter.onGenerateRoute,
        builder: (context, child) {
          return AppServicesScope(
            services: services,
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: const MessagesPage(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Penny Direct').first);
    await tester.pumpAndSettle();

    final listRequest = transport.requests.firstWhere(
      (request) => request.uri.path == '/api/v1/direct_message/list',
    );
    expect(listRequest.uri.queryParameters['peer_uid'], 'u_peer_dm');
  });

  testWidgets('direct messages render cached db data before delta sync', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingDmDeltaTransport();
    final sessionStore = MemoryUserSessionStore();
    await sessionStore.saveUid('u_mock');
    final api = GenesisApi(
      useMock: false,
      transport: transport,
      platformConfig: const DefaultPlatformConfig(),
      deviceIdService: const _FakeDeviceIdService(),
      sessionStore: sessionStore,
      identityAuthService: const _FakeIdentityAuthService(),
    );
    final storage = MemoryDirectMessageConversationStorage();
    await storage.mergeConversations(
      ownerUid: 'u_mock',
      conversations: [
        _dmConversationJson(
          convId: 'cached_conv',
          peerName: 'Cached Peer',
          messageId: 'cached_msg',
          message: 'Cached preview',
          minutesAgo: 5,
        ),
      ],
      nextAfterMessageId: 'cached_cursor',
    );
    final store = DirectMessageConversationStore(
      api: api,
      sessionStore: sessionStore,
      storage: storage,
    );
    final services = await _testServices(
      transport: transport,
      useMock: false,
      directMessageConversations: store,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AppServicesScope(services: services, child: const MessagesPage()),
      ),
    );
    await tester.pump();

    expect(find.text('Cached Peer'), findsOneWidget);
    expect(find.text('Cached preview'), findsOneWidget);
    final deltaRequest = transport.requests.singleWhere(
      (request) => request.uri.queryParameters.containsKey('after_message_id'),
    );
    expect(
      deltaRequest.uri.queryParameters['after_message_id'],
      'cached_cursor',
    );
  });

  testWidgets('direct messages merge delta rows without clearing the list', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingDmDeltaTransport();
    final services = await _testServices(transport: transport, useMock: false);
    await tester.pumpWidget(
      MaterialApp(
        home: AppServicesScope(services: services, child: const MessagesPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Old preview'), findsOneWidget);
    transport.deltaMessage = 'Updated preview';
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();

    expect(find.text('Old preview'), findsNothing);
    expect(find.text('Updated preview'), findsOneWidget);
    expect(find.text('Inserted preview'), findsOneWidget);
    expect(find.text('Delta Peer'), findsOneWidget);
  });

  testWidgets('unread summary renders messages badges', (
    WidgetTester tester,
  ) async {
    await _pumpGenesisApp(tester, initialAuthToken: 'backend-token');
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('bottom-nav-Messages-unread-badge')),
        matching: find.text('4'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Messages'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(
          const ValueKey('message-menu-/message/notifications-unread-badge'),
        ),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(
          const ValueKey('message-menu-/messages/new_followers-unread-badge'),
        ),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(
          const ValueKey('message-menu-/messages/comments-unread-badge'),
        ),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('direct-messages-unread-badge')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('logout clears messages badge and signed-in tab caches', (
    WidgetTester tester,
  ) async {
    final sessionStore = MemoryUserSessionStore();
    final backendAuth = _FakeBackendAuthCoordinator(
      authenticated: true,
      sessionStore: sessionStore,
    );
    final transport = _RecordingMessagesDataPollTransport();
    final services = await _testServices(
      transport: transport,
      useMock: false,
      sessionStoreOverride: sessionStore,
      backendAuth: backendAuth,
      initialUid: 'u_cached',
      initialAuthToken: 'backend-token',
      initialUserInfo: const {'uid': 'u_cached', 'name': 'Cached User'},
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AppServicesScope(
          services: services,
          child: const AppShellPage(initialIndex: 0),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('bottom-nav-Messages-unread-badge')),
        matching: find.text('4'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Me'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out').last);
    await tester.pumpAndSettle();

    expect(await sessionStore.readUid(), isNull);
    expect(
      find.byKey(const ValueKey('bottom-nav-Messages-unread-badge')),
      findsNothing,
    );

    await tester.tap(find.text('Messages'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in to continue'), findsOneWidget);
    expect(find.text('Private chats'), findsNothing);
  });

  testWidgets('messages action button navigates to list page', (
    WidgetTester tester,
  ) async {
    await _pumpGenesisApp(tester, initialAuthToken: 'backend-token');

    await tester.tap(find.text('Messages'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Notifications').first);
    await tester.pumpAndSettle();

    expect(find.text('Notifications'), findsWidgets);
    expect(find.text('Join request'), findsOneWidget);
    expect(
      _richTextWithPlainText(
        'Penny Hardaway request to join Steam Kingdom Live(w_mock_001)',
      ),
      findsOneWidget,
    );
  });

  testWidgets('message category pages request matching notification block', (
    WidgetTester tester,
  ) async {
    await _pumpGenesisApp(tester, initialAuthToken: 'backend-token');

    await tester.tap(find.text('Messages'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('New followers').first);
    await tester.pumpAndSettle();

    expect(find.text('New followers'), findsWidgets);
    expect(find.text('Penny Hardaway'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('message-follow-action-u_mock_peer')),
      findsOneWidget,
    );
    expect(
      tester
          .getTopRight(
            find.byKey(const ValueKey('message-follow-action-u_mock_peer')),
          )
          .dx,
      closeTo(
        tester
            .getTopRight(
              find.byKey(const ValueKey('message-follow-row-u_mock_peer')),
            )
            .dx,
        0.1,
      ),
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('message-follow-row-u_mock_peer')))
          .height,
      66,
    );

    await tester.tap(find.text('Penny Hardaway'));
    await tester.pumpAndSettle();

    expect(find.byType(UserInfoPage), findsOneWidget);
    expect(find.text('Penny Hardaway'), findsWidgets);

    Navigator.of(tester.element(find.byType(UserInfoPage))).pop();
    await tester.pumpAndSettle();

    Navigator.of(tester.element(find.byType(MessageCategoryListPage))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Comments').first);
    await tester.pumpAndSettle();

    expect(find.text('Comments'), findsWidgets);
    expect(
      find.text('Penny Hardaway commented on your origin'),
      findsOneWidget,
    );
    expect(find.text('Love this world setting!'), findsOneWidget);
    await tester.tap(find.text('Penny Hardaway commented on your origin'));
    await tester.pumpAndSettle();

    expect(find.byType(PostDetailPage), findsOneWidget);
  });

  testWidgets(
    'message category page loads list without waiting for mark read',
    (WidgetTester tester) async {
      final readCompleter = Completer<TransportResponse>();
      final transport = _RecordingMessageCategoryTransport(
        readCompleter: readCompleter,
        notificationIsRead: false,
      );
      final services = await _testServices(
        transport: transport,
        useMock: false,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: AppServicesScope(
            services: services,
            child: MessageCategoryListPage(
              title: 'Comments',
              block: 'interaction',
              emptyText: 'No comments yet.',
              onNotificationsRead: () async {
                await services.api.v1.messages.unreadSummary();
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Recorded block message'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('message-category-unread-dot')),
        findsOneWidget,
      );

      final readRequest = transport.requests.firstWhere(
        (request) => request.uri.path == '/api/v1/message/read',
      );
      final listRequest = transport.requests.firstWhere(
        (request) => request.uri.path == '/api/v1/message/notifications',
      );
      expect(
        transport.requests.where(
          (request) => request.uri.path == '/api/v1/message/unread',
        ),
        isEmpty,
      );

      readCompleter.complete(
        TransportResponse(
          statusCode: 200,
          headers: const {'content-type': 'application/json'},
          body: jsonEncode({
            'err_no': 0,
            'err_str': 'success',
            'data': <String, Object?>{},
          }),
        ),
      );
      await tester.pumpAndSettle();

      final unreadRequest = transport.requests.firstWhere(
        (request) => request.uri.path == '/api/v1/message/unread',
      );

      expect(readRequest.method, 'POST');
      expect(transport.decodedBody(readRequest)['block'], 'interaction');
      expect(unreadRequest.method, 'GET');
      expect(listRequest.method, 'GET');
      expect(listRequest.uri.queryParameters['block'], 'interaction');
      expect(listRequest.uri.queryParameters['pn'], '1');
      expect(listRequest.uri.queryParameters['rn'], '20');
      expect(
        transport.requests.indexOf(listRequest),
        lessThan(transport.requests.indexOf(readRequest)),
      );
      expect(
        transport.requests.indexOf(readRequest),
        lessThan(transport.requests.indexOf(unreadRequest)),
      );
      expect(find.text('Recorded block message'), findsOneWidget);
    },
  );

  testWidgets('new followers action button aligns with row trailing edge', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingMessageCategoryTransport(
      notificationIsRead: false,
      notification: const {
        'notification_id': 'ntf_follow_align',
        'notice_block': 'follow',
        'notice_type': 'follow',
        'sender': {
          'uid': 'u_follow_align',
          'name': 'Aligned User',
          'avatar': '',
        },
        'relation': {'i_followed': false},
        'content': 'Aligned User started following you.',
        'is_read': false,
        'created_at': '2026-05-20T10:00:00Z',
      },
    );
    final services = await _testServices(transport: transport, useMock: false);

    await tester.pumpWidget(
      MaterialApp(
        home: AppServicesScope(
          services: services,
          child: const MessageCategoryListPage(
            title: 'New followers',
            block: 'follow',
            emptyText: 'No new followers yet.',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    final action = find.byKey(
      const ValueKey('message-follow-action-u_follow_align'),
    );
    final row = find.byKey(const ValueKey('message-follow-row-u_follow_align'));
    final unreadDot = find.byKey(const ValueKey('message-category-unread-dot'));

    expect(action, findsOneWidget);
    expect(row, findsOneWidget);
    expect(unreadDot, findsOneWidget);

    final rowRight = tester.getTopRight(row).dx;
    expect(tester.getTopRight(action).dx, closeTo(rowRight, 0.1));
    expect(tester.getTopLeft(unreadDot).dx, greaterThan(rowRight));
  });

  testWidgets('message category unread dots clear after reopening lists', (
    WidgetTester tester,
  ) async {
    const cases = [
      (title: 'Notifications', block: 'world_apply'),
      (title: 'New followers', block: 'follow'),
      (title: 'Comments', block: 'interaction'),
    ];

    for (final testCase in cases) {
      final transport = _RecordingMessageCategoryTransport(
        notificationIsRead: false,
      );
      final services = await _testServices(
        transport: transport,
        useMock: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AppServicesScope(
            services: services,
            child: MessageCategoryListPage(
              title: testCase.title,
              block: testCase.block,
              emptyText: 'No messages yet.',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('message-category-unread-dot')),
        findsOneWidget,
        reason: testCase.block,
      );
      expect(transport.readBlocks, contains(testCase.block));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        MaterialApp(
          home: AppServicesScope(
            services: services,
            child: MessageCategoryListPage(
              title: testCase.title,
              block: testCase.block,
              emptyText: 'No messages yet.',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('message-category-unread-dot')),
        findsNothing,
        reason: testCase.block,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });

  testWidgets('join request notification approves world apply', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingMessageCategoryTransport(
      notificationIsRead: false,
      notification: const {
        'notification_id': 'ntf_apply_001',
        'notice_block': 'world_apply',
        'notice_type': 'world_apply',
        'sender': {'uid': 'U_Z7Y8S', 'name': 'Hushie'},
        'biz_type': 2,
        'biz_id': 'W_G9B5TK',
        'obj_id': 'apl_apply_001',
        'world_name': '重生 2005 测试时间设置',
        'content': 'Hushie request to join 重生 2005 测试时间设置.',
        'is_read': false,
        'created_at': '2026-05-20T10:00:00Z',
      },
    );
    final services = await _testServices(transport: transport, useMock: false);
    await tester.pumpWidget(
      MaterialApp(
        home: AppServicesScope(
          services: services,
          child: const MessageCategoryListPage(
            title: 'Notifications',
            block: 'world_apply',
            emptyText: 'No notifications yet.',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Join request'), findsOneWidget);
    expect(
      _richTextWithPlainText('Hushie request to join 重生 2005 测试时间设置(W_G9B5TK)'),
      findsOneWidget,
    );

    await tester.tap(find.text('Join request').last);
    await tester.pumpAndSettle();
    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);

    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();

    final reviewRequest = transport.requests.firstWhere(
      (request) => request.uri.path == '/api/v1/world/apply/review',
    );
    final body = transport.decodedBody(reviewRequest);
    expect(reviewRequest.method, 'POST');
    expect(body['apply_id'], 'apl_apply_001');
    expect(body['action'], 'approve');
    expect(find.text('Approved'), findsWidgets);
    await tester.pump(const Duration(seconds: 3));

    await tester.tap(find.text('Join request').last);
    await tester.pumpAndSettle();
    expect(find.text('Approve'), findsNothing);
    expect(find.text('Reject'), findsNothing);
    expect(find.text('Approved'), findsWidgets);
  });

  testWidgets('world apply review notification opens world', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingMessageCategoryTransport(
      notification: const {
        'notification_id': 'ntf_apply_review_001',
        'notice_block': 'world_apply',
        'notice_type': 'world_apply_review',
        'sender': {'uid': 'U_REVIEWER', 'name': 'Reviewer'},
        'biz_type': 2,
        'biz_id': 'W_REVIEW',
        'obj_id': 'apl_review_001',
        'world_name': 'Review World',
        'status': 30,
        'content': 'request to Review World',
        'is_read': false,
        'created_at': '2026-05-20T10:00:00Z',
      },
    );
    final services = await _testServices(transport: transport, useMock: false);
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (settings) {
          if (settings.name == RouteNames.world) {
            final args = settings.arguments as Map;
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => Text('World route ${args['wid']}'),
            );
          }
          return null;
        },
        home: AppServicesScope(
          services: services,
          child: const MessageCategoryListPage(
            title: 'Notifications',
            block: 'world_apply',
            emptyText: 'No notifications yet.',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      _richTextWithPlainText('request to Review World(W_REVIEW)'),
      findsOneWidget,
    );
    expect(find.text('Rejected'), findsOneWidget);

    await tester.tap(
      _richTextWithPlainText('request to Review World(W_REVIEW)'),
    );
    await tester.pumpAndSettle();

    expect(find.text('World route W_REVIEW'), findsOneWidget);
  });

  testWidgets('comment notifications render interaction categories', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingMessageCategoryTransport(
      notifications: const [
        {
          'notification_id': 'ntf_comment_001',
          'notice_block': 'interaction',
          'notice_type': 'discuss_comment',
          'sender': {'uid': 'U_ALEX', 'name': 'Alex'},
          'biz_type': 1,
          'biz_id': 'O_COMMENT',
          'obj_id': 'D_COMMENT',
          'origin_name': 'Comment Origin',
          'content': 'Alex commented: "Comment text"',
          'is_read': false,
          'created_at': '2026-05-20T10:00:00Z',
        },
        {
          'notification_id': 'ntf_reply_001',
          'notice_block': 'interaction',
          'notice_type': 'discuss_reply',
          'sender': {'uid': 'U_BLAIR', 'name': 'Blair'},
          'biz_type': 1,
          'biz_id': 'O_REPLY',
          'obj_id': 'D_REPLY',
          'origin_name': 'Reply Origin',
          'comment_text': 'Reply text',
          'content': 'Reply text',
          'is_read': false,
          'created_at': '2026-05-20T10:00:00Z',
        },
        {
          'notification_id': 'ntf_like_001',
          'notice_block': 'interaction',
          'notice_type': 'discuss_like',
          'sender': {'uid': 'U_CASEY', 'name': 'Casey'},
          'biz_type': 1,
          'biz_id': 'O_LIKE',
          'obj_id': 'D_LIKE',
          'origin_name': 'Like Origin',
          'comment_text': 'Liked comment',
          'content': 'Liked comment',
          'is_read': false,
          'created_at': '2026-05-20T10:00:00Z',
        },
      ],
    );
    final services = await _testServices(transport: transport, useMock: false);
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (settings) {
          if (settings.name == RouteNames.postDetail) {
            final args = settings.arguments as Map;
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => AppServicesScope(
                services: services,
                child: PostDetailPage(item: args['item'] as dynamic),
              ),
            );
          }
          return null;
        },
        home: AppServicesScope(
          services: services,
          child: const MessageCategoryListPage(
            title: 'Comments',
            block: 'interaction',
            emptyText: 'No comments yet.',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Alex comment your origin'), findsOneWidget);
    expect(find.text('Blair reply to you'), findsOneWidget);
    expect(find.text('Casey like your comment'), findsOneWidget);
    expect(find.textContaining('#Comment Origin'), findsOneWidget);
    expect(find.textContaining('#Reply Origin'), findsOneWidget);
    expect(find.textContaining('#Like Origin'), findsOneWidget);
    expect(find.textContaining('#O_COMMENT'), findsNothing);
    expect(find.textContaining('#O_REPLY'), findsNothing);
    expect(find.textContaining('#O_LIKE'), findsNothing);

    final title = tester.widget<Text>(find.text('Alex comment your origin'));
    expect(title.style?.fontSize, 14);
    expect(title.style?.fontWeight, FontWeight.w700);
    expect(title.style?.color, const Color(0xFF111111));

    final body = tester.widget<Text>(find.text('Comment text'));
    expect(body.style?.fontSize, 12);
    expect(body.style?.fontWeight, FontWeight.w400);
    expect(body.style?.color, const Color(0xFF111111));

    final meta = tester.widget<Text>(find.textContaining('#Comment Origin'));
    expect(meta.style?.fontSize, 12);
    expect(meta.style?.fontWeight, FontWeight.w400);
    expect(meta.style?.color, const Color(0xFF8A8D93));

    final itemRect = tester.getRect(
      find.byKey(const ValueKey('ntf_comment_001')),
    );
    final titleRect = tester.getRect(find.text('Alex comment your origin'));
    final bodyRect = tester.getRect(find.text('Comment text'));
    final metaRect = tester.getRect(find.textContaining('#Comment Origin'));
    expect(itemRect.left, 20);
    expect(titleRect.left, itemRect.left);
    expect(bodyRect.left, itemRect.left);
    expect(metaRect.left, itemRect.left);
    expect((bodyRect.top - titleRect.bottom).round(), 8);
    expect((metaRect.top - bodyRect.bottom).round(), 8);

    for (final title in [
      'Alex comment your origin',
      'Blair reply to you',
      'Casey like your comment',
    ]) {
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
      expect(find.byType(PostDetailPage), findsOneWidget);
      Navigator.of(tester.element(find.byType(PostDetailPage))).pop();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('tap Origin switches to Origin page', (
    WidgetTester tester,
  ) async {
    await _pumpGenesisApp(tester);

    expect(find.text('My World'), findsOneWidget);
    expect(find.text('Popular'), findsOneWidget);

    await tester.tap(find.text('Origin'));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Origin'), findsNWidgets(2));
    expect(find.text('For you'), findsOneWidget);
  });

  testWidgets('main tabs keep page state after switching away and back', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingV1ListTransport();
    await tester.pumpWidget(
      MaterialApp(
        home: AppServicesScope(
          services: await _testServices(transport: transport, useMock: false),
          child: const AppShellPage(initialIndex: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    var originRequests = transport.requestsFor('/api/v1/origin/list');
    expect(originRequests, hasLength(1));
    expect(find.text('#Origin 1'), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(transport.requestsFor('/api/v1/world/list'), hasLength(1));

    await tester.tap(find.text('Origin'));
    await tester.pumpAndSettle();

    originRequests = transport.requestsFor('/api/v1/origin/list');
    expect(originRequests, hasLength(1));
    expect(find.text('#Origin 1'), findsOneWidget);
  });

  testWidgets('Origin tab requests v1 origin list scene on enter', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingV1ListTransport(
      worldRelationStatus: 'approved',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AppServicesScope(
          services: await _testServices(transport: transport, useMock: false),
          child: const OriginPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    var originRequests = transport.requestsFor('/api/v1/origin/list');
    expect(originRequests, hasLength(1));
    expect(originRequests.single.uri.queryParameters['scene'], 'foryou');
    expect(originRequests.single.uri.queryParameters['pn'], '1');
    expect(originRequests.single.uri.queryParameters['rn'], '20');
    expect(originRequests.single.uri.queryParameters.containsKey('tag'), false);

    await tester.tap(find.text('Destroyed'));
    await tester.pumpAndSettle();

    originRequests = transport.requestsFor('/api/v1/origin/list');
    expect(originRequests, hasLength(2));
    expect(originRequests.last.uri.queryParameters['scene'], 'tag');
    expect(originRequests.last.uri.queryParameters['tag'], 'Destroyed');
  });

  testWidgets('Origin requests For you list before hot tags return', (
    WidgetTester tester,
  ) async {
    final hotTagsCompleter = Completer<TransportResponse>();
    final transport = _RecordingV1ListTransport(
      hotTagsCompleter: hotTagsCompleter,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AppServicesScope(
          services: await _testServices(transport: transport, useMock: false),
          child: const OriginPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final originRequests = transport.requestsFor('/api/v1/origin/list');
    expect(originRequests, hasLength(1));
    expect(originRequests.single.uri.queryParameters['scene'], 'foryou');
    expect(transport.requestsFor('/api/v1/origin/hot_tags'), hasLength(1));
    expect(find.text('For you'), findsOneWidget);
    expect(find.text('Destroyed'), findsNothing);

    hotTagsCompleter.complete(
      transport._jsonResponse({
        'err_no': 0,
        'err_msg': 'succ',
        'data': {
          'list': ['Destroyed'],
        },
      }),
    );
    await tester.pumpAndSettle();

    expect(find.text('Destroyed'), findsOneWidget);
  });

  testWidgets('Origin renders cached hot tags then syncs latest tags', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'origin_hot_tags_v1': <String>['Cached', 'For you', 'Cached'],
    });
    final hotTagsCompleter = Completer<TransportResponse>();
    final transport = _RecordingV1ListTransport(
      hotTagsCompleter: hotTagsCompleter,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AppServicesScope(
          services: await _testServices(transport: transport, useMock: false),
          child: const OriginPage(),
        ),
      ),
    );
    for (var i = 0; i < 3 && find.text('Cached').evaluate().isEmpty; i += 1) {
      await tester.pump();
    }

    expect(find.text('For you'), findsOneWidget);
    expect(find.text('Cached'), findsOneWidget);
    expect(find.text('Remote'), findsNothing);
    expect(transport.requestsFor('/api/v1/origin/list'), hasLength(1));
    expect(transport.requestsFor('/api/v1/origin/hot_tags'), hasLength(1));

    hotTagsCompleter.complete(
      transport._jsonResponse({
        'err_no': 0,
        'err_msg': 'succ',
        'data': {
          'list': ['Remote'],
        },
      }),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cached'), findsNothing);
    expect(find.text('Remote'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('origin_hot_tags_v1'), <String>['Remote']);
  });

  testWidgets(
    'Home My World tab requests v1 world list with mine scene on enter',
    (WidgetTester tester) async {
      final transport = _RecordingV1ListTransport();
      await tester.pumpWidget(
        MaterialApp(
          home: AppServicesScope(
            services: await _testServices(
              transport: transport,
              useMock: false,
              initialAuthToken: 'backend-token',
            ),
            child: const HomePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      var worldRequests = transport.requestsFor('/api/v1/world/list');
      expect(worldRequests, hasLength(1));
      expect(
        worldRequests.single.uri.queryParameters.containsKey('owner_uid'),
        false,
      );
      expect(
        worldRequests.single.uri.queryParameters.containsKey('uid'),
        false,
      );
      expect(worldRequests.single.uri.queryParameters['pn'], '1');
      expect(worldRequests.single.uri.queryParameters['rn'], '20');
      expect(worldRequests.single.uri.queryParameters['scene'], 'mine');
      expect(find.text('World tick narrator 1'), findsOneWidget);
      expect(find.text('Legacy world progress summary 1'), findsNothing);

      await tester.tap(find.text('Popular'));
      await tester.pumpAndSettle();

      final originRequests = transport.requestsFor('/api/v1/origin/list');
      expect(originRequests, hasLength(1));
      expect(originRequests.single.uri.queryParameters['scene'], 'popular');
      expect(originRequests.single.uri.queryParameters['pn'], '1');
      expect(originRequests.single.uri.queryParameters['rn'], '20');
      expect(find.text('#Origin 1'), findsWidgets);

      final discussRequests = transport.requestsFor('/api/v1/discuss/list');
      expect(discussRequests, isNotEmpty);
      expect(discussRequests.first.uri.queryParameters['biz_type'], '1');
      expect(discussRequests.first.uri.queryParameters['biz_id'], 'o_test_1');
      expect(discussRequests.first.uri.queryParameters['pn'], '1');
      expect(discussRequests.first.uri.queryParameters['rn'], '20');
      expect(find.text('Discuss preview for o_test_1'), findsOneWidget);
    },
  );

  testWidgets('Home defaults to Popular tab while signed out', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingV1ListTransport();
    await tester.pumpWidget(
      MaterialApp(
        home: AppServicesScope(
          services: await _testServices(
            transport: transport,
            useMock: false,
            initialUid: null,
          ),
          child: const HomePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(transport.requestsFor('/api/v1/world/list'), isEmpty);
    final originRequests = transport.requestsFor('/api/v1/origin/list');
    expect(originRequests, hasLength(1));
    expect(originRequests.single.uri.queryParameters['pn'], '1');
    expect(originRequests.single.uri.queryParameters['rn'], '20');
    expect(find.text('#Origin 1'), findsWidgets);
  });

  testWidgets('Home My Worlds signed-out tap asks login and stays Popular', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingV1ListTransport();
    await tester.pumpWidget(
      MaterialApp(
        home: AppServicesScope(
          services: await _testServices(
            transport: transport,
            useMock: false,
            initialUid: null,
          ),
          child: const HomePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final originRequestCount = transport
        .requestsFor('/api/v1/origin/list')
        .length;

    await tester.tap(find.text('My Worlds'));
    await tester.pump();

    expect(
      transport.requestsFor('/api/v1/origin/list'),
      hasLength(originRequestCount),
    );
    expect(transport.requestsFor('/api/v1/world/list'), isEmpty);
    expect(find.byType(GenesisListLoadingSkeleton), findsNothing);
    expect(find.text('#Origin 1'), findsWidgets);

    await tester.pumpAndSettle();

    expect(find.text('Sign in to continue'), findsOneWidget);
    expect(transport.requestsFor('/api/v1/world/list'), isEmpty);
    expect(find.text('#Origin 1'), findsWidgets);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('Sign in to continue'), findsNothing);
    expect(transport.requestsFor('/api/v1/world/list'), isEmpty);
    expect(find.text('#Origin 1'), findsWidgets);
  });

  testWidgets('Home My Worlds login success selects tab and loads worlds', (
    WidgetTester tester,
  ) async {
    final sessionStore = MemoryUserSessionStore();
    final transport = _RecordingV1ListTransport();
    final backendAuth = _FakeBackendAuthCoordinator(
      authenticated: false,
      sessionStore: sessionStore,
      loginUser: const User(
        id: 42,
        uid: 'backend_uid',
        did: '',
        nickname: 'Backend User',
        avatar: '',
        createdAt: null,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AppServicesScope(
          services: await _testServices(
            transport: transport,
            useMock: false,
            initialUid: null,
            sessionStoreOverride: sessionStore,
            identityAuth: const _FakeIdentityAuthService(
              signInSession: AuthSession(
                provider: IdentityProvider.google,
                providerIdToken: 'google-token',
                firebaseIdToken: 'firebase-token',
                identityUid: 'identity_uid',
                email: 'identity@example.com',
                displayName: 'Identity User',
                photoUrl: '',
              ),
            ),
            backendAuth: backendAuth,
          ),
          child: const HomePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('My Worlds'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in to continue'), findsOneWidget);

    await tester.tap(find.text('Continue with Google').last);
    await tester.pumpAndSettle();

    expect(backendAuth.loginCount, 1);
    expect(transport.requestsFor('/api/v1/world/list'), hasLength(1));
    expect(find.text('World tick narrator 1'), findsOneWidget);
    expect(find.text('Sign in to continue'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('genesis-world-list-skeleton')),
      findsNothing,
    );
  });

  testWidgets('Origin list item opens origin detail with current oid', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingV1ListTransport();
    await tester.pumpWidget(
      AppServicesScope(
        services: await _testServices(
          transport: transport,
          useMock: false,
          initialAuthToken: 'token',
        ),
        child: MaterialApp(
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: const OriginPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('#Origin 1'));
    await tester.pumpAndSettle();

    final detailRequests = transport.requestsFor('/api/v1/origin/detail');
    expect(detailRequests, hasLength(1));
    expect(detailRequests.single.uri.queryParameters['origin_id'], 'o_test_1');
    expect(find.text('#Origin detail o_test_1'), findsOneWidget);

    final discussRequestsAfterDetail = transport.requestsFor(
      '/api/v1/discuss/list',
    );
    final detailDiscussRequest = discussRequestsAfterDetail.last;
    expect(detailDiscussRequest.uri.queryParameters['biz_type'], '1');
    expect(detailDiscussRequest.uri.queryParameters['biz_id'], 'o_test_1');
    expect(detailDiscussRequest.uri.queryParameters['pn'], '1');
    expect(detailDiscussRequest.uri.queryParameters['rn'], '20');
    final previousDiscussRequestCount = discussRequestsAfterDetail.length;

    await tester.dragFrom(const Offset(400, 510), const Offset(0, -420));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('View More >'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    final discussRequests = transport.requestsFor('/api/v1/discuss/list');
    expect(discussRequests.length, previousDiscussRequestCount);
    expect(find.widgetWithText(TextField, 'Write a post'), findsNothing);
    expect(find.text('Discuss preview for o_test_1'), findsOneWidget);
    expect(find.text('View More >'), findsOneWidget);
  });

  testWidgets('Origin detail discuss area opens discuss page when populated', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingV1ListTransport();
    await tester.pumpWidget(
      AppServicesScope(
        services: await _testServices(
          transport: transport,
          useMock: false,
          initialAuthToken: 'token',
        ),
        child: MaterialApp(
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: const OriginWorldPage(oid: 'o_test_1', originId: 0),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final discussArea = find.byKey(
      const ValueKey('origin-discuss-summary-area'),
    );
    await _dragOriginPanelUntilVisible(tester, discussArea);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('origin-discuss-like-dis_o_test_1_1')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('origin-discuss-reply-dis_o_test_1_1')),
      findsNothing,
    );
    await tester.tap(discussArea);
    await tester.pumpAndSettle();

    expect(find.text('Discuss'), findsOneWidget);
    final discussRequests = transport.requestsFor('/api/v1/discuss/list');
    expect(discussRequests.last.uri.queryParameters['biz_id'], 'o_test_1');
  });

  testWidgets('Origin detail status bar switches after map scrolls out', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingV1ListTransport();
    final systemUiOverlayStyleCalls = _captureSystemUiOverlayStyleCalls();
    addTearDown(_clearPlatformChannelHandler);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    await tester.pump();
    systemUiOverlayStyleCalls.clear();

    await tester.pumpWidget(
      AppServicesScope(
        services: await _testServices(transport: transport, useMock: false),
        child: MaterialApp(
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: const OriginWorldPage(oid: 'o_test_1', originId: 0),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      _pageStatusBarStyle(tester).statusBarIconBrightness,
      Brightness.light,
    );

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -720));
    await tester.pumpAndSettle();

    expect(
      _pageStatusBarStyle(tester).statusBarIconBrightness,
      Brightness.dark,
    );

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 720));
    await tester.pumpAndSettle();

    expect(
      _pageStatusBarStyle(tester).statusBarIconBrightness,
      Brightness.light,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(
      systemUiOverlayStyleCalls.last['statusBarIconBrightness'],
      Brightness.dark.toString(),
    );
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('Origin detail empty discuss area opens post composer', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingV1ListTransport(
      originDiscussCount: 0,
      discussTotalAll: 0,
    );
    await tester.pumpWidget(
      AppServicesScope(
        services: await _testServices(
          transport: transport,
          useMock: false,
          initialAuthToken: 'test-token',
        ),
        child: MaterialApp(
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: const OriginWorldPage(oid: 'o_test_1', originId: 0),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final discussArea = find.byKey(
      const ValueKey('origin-discuss-summary-area'),
    );
    await _dragOriginPanelUntilVisible(tester, discussArea);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Write a post'), findsOneWidget);
    await tester.tap(discussArea);
    await tester.pumpAndSettle();

    expect(find.text('New post'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Write a post').last,
      'First empty discuss post',
    );
    await tester.pump();
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    final postRequests = transport.requestsFor('/api/v1/discuss/post');
    expect(postRequests, hasLength(1));
    final postBody = transport.decodedBody(postRequests.single);
    expect(postBody['biz_type'], 1);
    expect(postBody['biz_id'], 'o_test_1');
    expect(postBody['content'], 'First empty discuss post');
  });

  testWidgets('Origin detail loading map does not show fallback background', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingV1ListTransport(
      originDetailCompleter: Completer<TransportResponse>(),
    );
    await tester.pumpWidget(
      AppServicesScope(
        services: await _testServices(transport: transport, useMock: false),
        child: MaterialApp(
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: const OriginWorldPage(oid: 'o_test_1', originId: 0),
        ),
      ),
    );
    await tester.pump();

    expect(_assetImageFinder(kWorldMapFallbackBackgroundAsset), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Origin detail map starts with root location map url', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingV1ListTransport(
      originMapUrl: kMockV1SteamMapImage,
      originLocations: const [
        {
          'location_id': 'l_o_test_1',
          'level': 1,
          'location_pid': '',
          'location_name': 'Origin Root',
          'location_description': 'The root location.',
          'image': '',
          'x_percent': 30,
          'y_percent': 40,
          'map_url': kMockV1LocationCentralHubMap,
          'dialogue': <Object?>[],
        },
        {
          'location_id': 'l_o_test_1_child',
          'level': 2,
          'location_pid': 'l_o_test_1',
          'location_name': 'Origin Child',
          'location_description': 'The child location.',
          'image': '',
          'x_percent': 55,
          'y_percent': 45,
          'map_url': kMockV1LocationRailGateMap,
          'dialogue': <Object?>[],
        },
      ],
    );
    await tester.pumpWidget(
      AppServicesScope(
        services: await _testServices(transport: transport, useMock: false),
        child: MaterialApp(
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: const OriginWorldPage(oid: 'o_test_1', originId: 0),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final mapStage = find.byType(WorldMapStage);
    expect(
      find.descendant(
        of: mapStage,
        matching: _assetImageFinder(kMockV1LocationCentralHubMap),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: mapStage,
        matching: _assetImageFinder(kMockV1SteamMapImage),
      ),
      findsNothing,
    );
  });

  testWidgets('Origin detail worldview image opens image viewer', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingV1ListTransport(
      originMapUrl: kMockV1SteamMapImage,
    );
    await tester.pumpWidget(
      AppServicesScope(
        services: await _testServices(transport: transport, useMock: false),
        child: MaterialApp(
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: const OriginWorldPage(oid: 'o_test_1', originId: 0),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final worldviewImage = _assetImageFinder(kMockV1SteamMapImage);
    await _dragOriginPanelUntilVisible(tester, worldviewImage);
    await tester.tap(worldviewImage);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('genesis-image-viewer-page-view')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('genesis-image-viewer-close')));
    await tester.pumpAndSettle();
  });

  testWidgets('Origin detail character portrait opens character image viewer', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingV1ListTransport(
      originCharacters: const [
        {
          'char_id': 'c_iris',
          'name': 'Iris',
          'identity': 'Guide',
          'brief': 'Keeps the path',
          'description': 'First character.',
          'avatar': 'assets/images/mock_avatars/avatar_iris.png',
          'initial_location_id': 'l_o_test_1',
          'location_id': 'l_o_test_1',
        },
        {
          'char_id': 'c_nia',
          'name': 'Nia',
          'identity': 'Scout',
          'brief': 'Finds the signal',
          'description': 'Second character.',
          'avatar': 'assets/images/mock_avatars/avatar_nia.png',
          'initial_location_id': 'l_o_test_1',
          'location_id': 'l_o_test_1',
        },
      ],
    );
    await tester.pumpWidget(
      AppServicesScope(
        services: await _testServices(transport: transport, useMock: false),
        child: MaterialApp(
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: const OriginWorldPage(oid: 'o_test_1', originId: 0),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final firstPortrait = find.byKey(
      const ValueKey('origin-character-portrait-c_iris'),
    );
    await _dragOriginPanelUntilVisible(tester, firstPortrait);
    tester.widget<GestureDetector>(firstPortrait).onTap?.call();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('genesis-image-viewer-page-view')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('genesis-image-viewer-page-dots')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('genesis-image-viewer-dot-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('genesis-image-viewer-dot-1')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('genesis-image-viewer-close')));
    await tester.pumpAndSettle();
  });

  testWidgets('Origin detail launch bar launches a world', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingV1ListTransport(
      worldRelationStatus: 'approved',
    );
    await tester.pumpWidget(
      AppServicesScope(
        services: await _testServices(
          transport: transport,
          useMock: false,
          initialAuthToken: 'token',
        ),
        child: MaterialApp(
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: const OriginWorldPage(oid: 'o_test_1', originId: 0),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Launch'), findsOneWidget);
    final launchButtonFinder = find.widgetWithText(FilledButton, 'Launch');
    expect(tester.getSize(launchButtonFinder), const Size(140, 35));
    final launchButton = tester.widget<FilledButton>(launchButtonFinder);
    expect(
      launchButton.style?.textStyle?.resolve(<WidgetState>{})?.fontSize,
      16,
    );
    await tester.tap(find.text('Launch'));
    await tester.pumpAndSettle();
    expect(find.text('Setup Your Role'), findsOneWidget);
    expect(find.byType(GenesisBottomSheetPanel), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('origin-role-sheet')),
        matching: find.byType(AnimatedSwitcher),
      ),
      findsNothing,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('origin-role-cancel'))).height,
      35,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('origin-role-launch'))).height,
      35,
    );

    await tester.tap(find.byKey(const ValueKey('origin-role-launch')));
    await tester.pump();

    expect(find.text('Please select a preset role'), findsOneWidget);
    expect(transport.requestsFor('/api/v1/origin/launch'), isEmpty);

    await tester.tap(
      find.byKey(const ValueKey('origin-role-preset-c_o_test_1')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('origin-role-launch')));
    await tester.pumpAndSettle();

    final launchRequests = transport.requestsFor('/api/v1/origin/launch');
    expect(launchRequests, hasLength(1));
    final launchBody = transport.decodedBody(launchRequests.single);
    expect(launchBody['origin_id'], 'o_test_1');
    expect(launchBody.containsKey('oid'), isFalse);
    expect(launchBody['preset_character_id'], 'c_o_test_1');
    final worldRequests = transport.requestsFor('/api/v1/world/detail');
    expect(worldRequests, isNotEmpty);
    expect(
      worldRequests.last.uri.queryParameters['world_id'],
      'w_launched_from_origin',
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });

  testWidgets('Origin launch navigates to world and waits for first tick', (
    WidgetTester tester,
  ) async {
    final generatedTick = <String, Object?>{
      'tick_no': 1,
      'created_at': '2026-05-02T00:00:00Z',
      'tick_result': {
        'narrator': 'Generated launch tick.',
        'paragraphs': const <Object?>[
          {
            'location_id': 'l_w_launched_from_origin',
            'text': 'The generated world wakes up.',
            'character_deltas': <Object?>[],
          },
        ],
      },
    };
    final transport = _RecordingV1ListTransport(
      worldDetailTicksByRequest: [
        const <Map<String, Object?>>[],
        [generatedTick],
      ],
      worldDetailTickCountsByRequest: const [0, 0, 1],
    );
    await tester.pumpWidget(
      AppServicesScope(
        services: await _testServices(transport: transport, useMock: false),
        child: MaterialApp(
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: const OriginWorldPage(oid: 'o_test_1', originId: 0),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Launch'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('origin-role-preset-c_o_test_1')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('origin-role-launch')));
    await tester.pumpAndSettle();

    expect(find.text('World detail w_launched_from_origin'), findsWidgets);
    expect(
      find.byKey(const ValueKey('world-tick1-wait-dialog')),
      findsOneWidget,
    );
    final waitTitle = tester.widget<Text>(find.text('Generating first tick'));
    expect(waitTitle.style?.fontSize, 16);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('world-tick1-wait-dialog')),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsNothing,
    );
    final waitBodyFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          (widget.data ?? '').startsWith(
            'LLM is generating your first tick. This may take a moment',
          ),
    );
    expect(waitBodyFinder, findsOneWidget);
    final waitBody = tester.widget<Text>(waitBodyFinder);
    expect(waitBody.style?.fontSize, 14);
    expect(waitBody.data, endsWith('.'));
    final initialWaitBodyText = waitBody.data;
    await tester.pump(const Duration(milliseconds: 400));
    final animatedWaitBody = tester.widget<Text>(waitBodyFinder);
    expect(animatedWaitBody.data, isNot(initialWaitBodyText));
    var worldRequests = transport.requestsFor('/api/v1/world/detail');
    expect(worldRequests.length, greaterThanOrEqualTo(2));
    expect(
      worldRequests.last.uri.queryParameters['world_id'],
      'w_launched_from_origin',
    );

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('world-tick1-wait-dialog')), findsNothing);
    worldRequests = transport.requestsFor('/api/v1/world/detail');
    expect(worldRequests.length, greaterThanOrEqualTo(3));
  });

  testWidgets('Origin detail location opens launch-only chat panel', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingV1ListTransport();
    final chatroom = _FakeChatroomClient();
    await tester.pumpWidget(
      AppServicesScope(
        services: await _testServices(
          transport: transport,
          useMock: false,
          chatroom: chatroom,
        ),
        child: MaterialApp(
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: const OriginWorldPage(oid: 'o_test_1', originId: 0),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Detail Location'), warnIfMissed: false);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(chatroom.connectCount, 0);
    expect(_visibleText('Detail Location (1)'), findsOneWidget);
    final chatPanel = find.byType(LocationChatPanel);
    expect(chatPanel, findsOneWidget);
    expect(
      find.descendant(of: chatPanel, matching: find.byType(TextField)),
      findsNothing,
    );
    final chatLaunch = find.descendant(
      of: chatPanel,
      matching: find.text('Launch to send'),
    );
    expect(chatLaunch, findsOneWidget);

    await tester.tap(chatLaunch);
    await tester.pumpAndSettle();

    expect(find.text('Setup Your Role'), findsOneWidget);
    expect(transport.requestsFor('/api/v1/origin/launch'), isEmpty);
  });

  testWidgets('Origin detail launch preview uses detail tick and locations', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingV1ListTransport();
    await tester.pumpWidget(
      AppServicesScope(
        services: await _testServices(transport: transport, useMock: false),
        child: MaterialApp(
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: const OriginWorldPage(oid: 'o_test_1', originId: 0),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.dragFrom(const Offset(400, 500), const Offset(0, -420));
    await tester.pumpAndSettle();
    for (var i = 0; i < 5; i++) {
      if (find.text('Launch Preview').evaluate().isNotEmpty) break;
      await tester.dragFrom(const Offset(400, 500), const Offset(0, -500));
      await tester.pumpAndSettle();
    }

    expect(find.text('Launch Preview'), findsOneWidget);
    expect(find.text('Global'), findsOneWidget);
    expect(find.text('Origin launch tick narrator.'), findsOneWidget);
    expect(find.text('Detail Location'), findsWidgets);
    expect(find.text('Detail location launch paragraph.'), findsOneWidget);
  });

  testWidgets('Origin detail hides launch preview without tick1 data', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingV1ListTransport(
      originTicks: const <Map<String, Object?>>[],
    );
    await tester.pumpWidget(
      AppServicesScope(
        services: await _testServices(transport: transport, useMock: false),
        child: MaterialApp(
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: const OriginWorldPage(oid: 'o_test_1', originId: 0),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Launch Preview'), findsNothing);
    expect(find.text('Origin launch tick narrator.'), findsNothing);
    expect(find.text('Detail location launch paragraph.'), findsNothing);
  });

  testWidgets(
    'Origin detail copy world progress rotates summary latest items',
    (WidgetTester tester) async {
      final transport = _RecordingV1ListTransport();
      await tester.pumpWidget(
        AppServicesScope(
          services: await _testServices(transport: transport, useMock: false),
          child: MaterialApp(
            onGenerateRoute: (settings) {
              if (settings.name == RouteNames.world) {
                final args = settings.arguments as Map;
                return MaterialPageRoute<void>(
                  settings: settings,
                  builder: (_) => Text('World route ${args['wid']}'),
                );
              }
              return null;
            },
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(12),
                child: const CopyWorldProgressSection(originId: 'o_test_1'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final summaryRequests = transport.requestsFor(
        '/api/v1/world/summary/latest',
      );
      expect(summaryRequests, hasLength(1));
      expect(
        summaryRequests.single.uri.queryParameters['origin_id'],
        'o_test_1',
      );
      expect(
        summaryRequests.single.uri.queryParameters.containsKey('world_id'),
        isFalse,
      );
      expect(
        find.text('First copied world progress summary for o_test_1.'),
        findsOneWidget,
      );
      expect(find.text('WID: w_summary_1'), findsOneWidget);
      expect(find.text('4'), findsWidgets);
      expect(find.byType(DiscussStoryBadge), findsOneWidget);
      final widRight = tester.getTopRight(find.text('WID: w_summary_1')).dx;
      final chipLeft = tester.getTopLeft(find.byType(DiscussStoryBadge)).dx;
      expect(chipLeft - widRight, closeTo(8, 0.1));
      expect(
        tester
            .getSize(find.byKey(const ValueKey('copy-world-progress-body')))
            .height,
        closeTo(12 * 1.45 * 5 + 6, 0.1),
      );
      await tester.tap(
        find.text('First copied world progress summary for o_test_1.'),
      );
      await tester.pumpAndSettle();
      expect(find.text('World route w_summary_1'), findsOneWidget);
      Navigator.of(tester.element(find.text('World route w_summary_1'))).pop();
      await tester.pumpAndSettle();

      await tester.pump(const Duration(seconds: 8));
      await tester.pump(const Duration(milliseconds: 600));

      expect(
        find.text('Second copied world progress summary for o_test_1.'),
        findsOneWidget,
      );
      expect(find.text('WID: w_summary_2'), findsOneWidget);
      await tester.tap(
        find.text('Second copied world progress summary for o_test_1.'),
      );
      await tester.pumpAndSettle();
      expect(find.text('World route w_summary_2'), findsOneWidget);
    },
  );

  testWidgets(
    'Origin detail copy world progress gives Chinese five-line text room',
    (WidgetTester tester) async {
      final transport = _RecordingV1ListTransport(
        worldSummaryLatestItems: const <Map<String, Object?>>[
          {
            'world_id': 'w_summary_cn',
            'summary': '第一行中文进展会占满一整行，第二行继续描述角色行动，第三行写地点变化，第四行补充冲突，第五行保留结尾。',
            'tick_no': 5,
            'tick_time': '2026-05-20T12:00:00Z',
            'created_at': '2026-05-20T12:00:00Z',
          },
        ],
      );
      await tester.pumpWidget(
        AppServicesScope(
          services: await _testServices(transport: transport, useMock: false),
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 180,
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CopyWorldProgressSection(originId: 'o_test_1'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final bodySize = tester.getSize(
        find.byKey(const ValueKey('copy-world-progress-body')),
      );
      expect(bodySize.height, greaterThan(12 * 1.45 * 5));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Origin detail copy world progress empty list uses natural height',
    (WidgetTester tester) async {
      final transport = _RecordingV1ListTransport(
        worldSummaryLatestItems: const <Map<String, Object?>>[],
      );
      await tester.pumpWidget(
        AppServicesScope(
          services: await _testServices(transport: transport, useMock: false),
          child: const MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: EdgeInsets.all(12),
                child: CopyWorldProgressSection(originId: 'o_test_1'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No launched world'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('copy-world-progress-body')),
        findsNothing,
      );
      expect(
        tester
            .getSize(find.byKey(const ValueKey('copy-world-progress-empty')))
            .height,
        lessThan(14 * 1.45 * 5),
      );
    },
  );

  testWidgets('Origin detail originator opens user info', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingV1ListTransport();
    await tester.pumpWidget(
      AppServicesScope(
        services: await _testServices(transport: transport, useMock: false),
        child: MaterialApp(
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: const OriginWorldPage(oid: 'o_test_1', originId: 0),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Originator: Tester'));
    await tester.pumpAndSettle();

    final userInfoRequests = transport.requestsFor('/api/v1/user/info');
    expect(userInfoRequests, hasLength(1));
    expect(userInfoRequests.single.uri.queryParameters['uid'], 'u_test');
    expect(find.text('User Info'), findsOneWidget);
  });

  testWidgets('Origin detail shows edit button to owner', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingV1ListTransport();
    await tester.pumpWidget(
      AppServicesScope(
        services: await _testServices(
          transport: transport,
          useMock: false,
          initialUid: 'u_test',
        ),
        child: MaterialApp(
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: const OriginWorldPage(oid: 'o_test_1', originId: 0),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Edit Origin'), findsOneWidget);
  });

  testWidgets('Origin detail hides edit button from non-owner', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingV1ListTransport();
    await tester.pumpWidget(
      AppServicesScope(
        services: await _testServices(
          transport: transport,
          useMock: false,
          initialUid: 'u_other',
        ),
        child: MaterialApp(
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: const OriginWorldPage(oid: 'o_test_1', originId: 0),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Edit Origin'), findsNothing);
  });

  testWidgets('Origin detail launch sheet sends custom role payload', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingV1ListTransport();
    await tester.pumpWidget(
      AppServicesScope(
        services: await _testServices(transport: transport, useMock: false),
        child: MaterialApp(
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: const OriginWorldPage(oid: 'o_test_1', originId: 0),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Launch'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Custom Hero');
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('origin-role-launch')));
    await tester.pump();

    expect(find.text('Please enter identity'), findsOneWidget);
    expect(transport.requestsFor('/api/v1/origin/launch'), isEmpty);

    await tester.enterText(find.byType(TextField).at(1), 'Time traveler');
    await tester.enterText(find.byType(TextField).at(2), 'Knows too much.');
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('origin-role-launch')));
    await tester.pumpAndSettle();

    final launchRequests = transport.requestsFor('/api/v1/origin/launch');
    expect(launchRequests, hasLength(1));
    final launchBody = transport.decodedBody(launchRequests.single);
    expect(launchBody['origin_id'], 'o_test_1');
    expect(launchBody.containsKey('oid'), isFalse);
    expect(launchBody.containsKey('preset_character_id'), isFalse);
    expect(launchBody['custom_role'], containsPair('name', 'Custom Hero'));
    expect(
      launchBody['custom_role'],
      containsPair('identity', 'Time traveler'),
    );
    expect(launchBody['custom_role'], containsPair('bio', 'Knows too much.'));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });

  testWidgets('Origin detail custom role fills avatar from profile', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingV1ListTransport(
      worldRelationStatus: 'approved',
    );
    await tester.pumpWidget(
      AppServicesScope(
        services: await _testServices(
          transport: transport,
          useMock: false,
          initialAuthToken: 'token',
          initialUserInfo: {
            'name': 'Profile Hero',
            'identity': 'Saved explorer',
            'avatar': {
              'sm_url':
                  'https://lh3.googleusercontent.com/a/profile-avatar=s96-c',
              'xl_url':
                  'https://lh3.googleusercontent.com/a/profile-avatar=s96-c',
              'object_key': '',
            },
            'bio': 'Profile biography',
          },
        ),
        child: MaterialApp(
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: const OriginWorldPage(oid: 'o_test_1', originId: 0),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Launch'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Fill from my profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fill from my profile'));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('origin-role-launch')));
    await tester.pumpAndSettle();

    final launchRequests = transport.requestsFor('/api/v1/origin/launch');
    expect(launchRequests, hasLength(1));
    final launchBody = transport.decodedBody(launchRequests.single);
    expect(
      launchBody['custom_role'],
      containsPair(
        'avatar',
        'https://lh3.googleusercontent.com/a/profile-avatar=s96-c',
      ),
    );
    expect(launchBody['custom_role'], containsPair('name', 'Profile Hero'));
    expect(
      launchBody['custom_role'],
      containsPair('identity', 'Saved explorer'),
    );
    expect(launchBody['custom_role'], containsPair('bio', 'Profile biography'));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });

  testWidgets('Origin detail profile fill asks for login when signed out', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingV1ListTransport();
    await tester.pumpWidget(
      AppServicesScope(
        services: await _testServices(
          transport: transport,
          useMock: false,
          initialUid: null,
          initialUserInfo: {
            'name': 'Profile Hero',
            'identity': 'Saved explorer',
          },
        ),
        child: MaterialApp(
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: const OriginWorldPage(oid: 'o_test_1', originId: 0),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Launch'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in to continue'), findsOneWidget);
    expect(transport.requestsFor('/api/v1/origin/launch'), isEmpty);
  });

  testWidgets(
    'Origin detail custom role keeps avatar empty when profile has no avatar',
    (WidgetTester tester) async {
      final transport = _RecordingV1ListTransport(
        worldRelationStatus: 'approved',
      );
      await tester.pumpWidget(
        AppServicesScope(
          services: await _testServices(
            transport: transport,
            useMock: false,
            initialAuthToken: 'token',
            initialUserInfo: {
              'name': 'Profile Hero',
              'identity': 'Saved explorer',
              'bio': 'Profile biography',
            },
          ),
          child: MaterialApp(
            onGenerateRoute: AppRouter.onGenerateRoute,
            home: const OriginWorldPage(oid: 'o_test_1', originId: 0),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Launch'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Fill from my profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fill from my profile'));
      await tester.pump();

      expect(find.text('AVATAR\n(Optional)'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('origin-role-launch')));
      await tester.pumpAndSettle();

      final launchRequests = transport.requestsFor('/api/v1/origin/launch');
      expect(launchRequests, hasLength(1));
      final launchBody = transport.decodedBody(launchRequests.single);
      expect(launchBody['custom_role'], isNot(contains('avatar')));
      expect(launchBody['custom_role'], containsPair('name', 'Profile Hero'));
      expect(
        launchBody['custom_role'],
        containsPair('identity', 'Saved explorer'),
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('World list item opens world detail with current wid', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingV1ListTransport();
    await tester.pumpWidget(
      AppServicesScope(
        services: await _testServices(transport: transport, useMock: false),
        child: MaterialApp(
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: const HomePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('World 1'));
    await tester.pumpAndSettle();

    final detailRequests = transport.requestsFor('/api/v1/world/detail');
    expect(detailRequests, hasLength(1));
    expect(detailRequests.single.uri.queryParameters['world_id'], 'w_test_1');
    expect(find.text('World detail w_test_1'), findsWidgets);
    final sheet = tester.widget<DraggableScrollableSheet>(
      find.byType(DraggableScrollableSheet),
    );
    final height =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    final collapsedSize = 0.31 - 15 / height;
    expect(sheet.minChildSize, closeTo(collapsedSize, 0.001));
    expect(sheet.initialChildSize, closeTo(collapsedSize, 0.001));

    await tester.tap(find.text('Owner: Tester'));
    await tester.pumpAndSettle();

    final userInfoRequests = transport.requestsFor('/api/v1/user/info');
    expect(userInfoRequests, hasLength(1));
    expect(userInfoRequests.single.uri.queryParameters['uid'], 'u_test');
    expect(find.text('User Info'), findsOneWidget);
  });

  testWidgets('World top navigation uses safe area plus eight', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingV1ListTransport();
    await tester.pumpWidget(
      AppServicesScope(
        services: await _testServices(transport: transport, useMock: false),
        child: MaterialApp(
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: const HomePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('World 1'));
    await tester.pumpAndSettle();

    final stage = tester.widget<WorldMapStage>(find.byType(WorldMapStage));
    final safeTop = MediaQuery.paddingOf(
      tester.element(find.byType(WorldMapStage)),
    ).top;
    expect(stage.top, safeTop + 8);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });

  testWidgets('World status uses metric default when character value is zero', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingV1ListTransport(
      worldMetricDefault: 42,
      worldCharacterMetricValue: 0,
    );
    await tester.pumpWidget(
      AppServicesScope(
        services: await _testServices(transport: transport, useMock: false),
        child: MaterialApp(
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: const HomePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('World 1'));
    await tester.pumpAndSettle();
    await tester.dragFrom(const Offset(400, 570), const Offset(0, -360));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Status'));
    await tester.pumpAndSettle();

    expect(find.text('Goal Progress: 42%'), findsOneWidget);
  });

  testWidgets('World status and character lists prioritize users and self', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingV1ListTransport(
      worldRelationStatus: 'none',
      worldCharacters: [
        {
          'type': 'player',
          'player_uid': '',
          'player_username': '',
          'char_id': 'c_ai',
          'name': 'AI Guide',
          'identity': 'Guide',
          'brief': 'AI row',
          'description': 'An AI character.',
          'goal': '',
          'avatar': '',
          'initial_location_id': 'l_w_test_1',
          'location_id': 'l_w_test_1',
          'metric_value': 12,
        },
        {
          'type': 'ai',
          'player_uid': 'u_other',
          'player_username': 'Other User',
          'char_id': 'c_other',
          'name': 'Other Hero',
          'identity': 'Visitor',
          'brief': 'Other row',
          'description': 'Another user character.',
          'goal': '',
          'avatar': '',
          'initial_location_id': 'l_w_test_1',
          'location_id': 'l_w_test_1',
          'metric_value': 34,
        },
        {
          'type': 'ai',
          'player_uid': 'u_mock',
          'player_username': 'Mock User',
          'char_id': 'c_self',
          'name': 'Self Hero',
          'identity': 'Self',
          'brief': 'Self row',
          'description': 'Current user character.',
          'goal': '',
          'avatar': '',
          'initial_location_id': 'l_w_test_1',
          'location_id': 'l_w_test_1',
          'metric_value': 56,
        },
      ],
    );
    await tester.pumpWidget(
      AppServicesScope(
        services: await _testServices(transport: transport, useMock: false),
        child: MaterialApp(
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: const HomePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('World 1'));
    await tester.pumpAndSettle();
    await tester.dragFrom(const Offset(400, 570), const Offset(0, -360));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Status'));
    await tester.pumpAndSettle();
    _expectCharacterNameOrder(tester);
    expect(find.text('Player'), findsNWidgets(2));
    expect(find.text('Character'), findsOneWidget);

    await tester.tap(find.text('Characters'));
    await tester.pumpAndSettle();
    _expectCharacterNameOrder(tester);
    expect(find.text('Player'), findsNWidgets(2));
    expect(find.text('Character'), findsOneWidget);
    expect(find.text('Guide'), findsOneWidget);
    expect(find.text('Visitor'), findsOneWidget);
    expect(find.text('Self'), findsOneWidget);
    expect(find.text('AI row'), findsNothing);
    expect(find.text('Other row'), findsNothing);
    expect(find.text('Self row'), findsNothing);

    final otherName = tester.widget<Text>(
      _richTextFinder('Other Hero (Other User)'),
    );
    final otherSpan = otherName.textSpan! as TextSpan;
    final suffixSpan = otherSpan.children!.single as TextSpan;
    expect(suffixSpan.style?.color, const Color(0xFF888888));
  });

  testWidgets('World character row marks current player as Me', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingV1ListTransport(worldRelationStatus: 'none');
    await tester.pumpWidget(
      AppServicesScope(
        services: await _testServices(transport: transport, useMock: false),
        child: MaterialApp(
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: const HomePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('World 1'));
    await tester.pumpAndSettle();
    await tester.dragFrom(const Offset(400, 570), const Offset(0, -360));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Characters'));
    await tester.pumpAndSettle();

    expect(_richTextFinder('World Character (Me)'), findsOneWidget);
  });

  testWidgets('World map drills into non-leaf locations', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingV1ListTransport();
    await tester.pumpWidget(
      AppServicesScope(
        services: await _testServices(transport: transport, useMock: false),
        child: MaterialApp(
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: const HomePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('World 1'));
    await tester.pumpAndSettle();

    expect(find.text('World Location'), findsWidgets);
    expect(find.text('Child Location'), findsNothing);

    await tester.tap(find.text('Location (2)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('World Location').last);
    await tester.pumpAndSettle();

    expect(find.text('World detail w_test_1'), findsWidgets);
    expect(find.text('Child Location'), findsWidgets);
    expect(find.text('Location (2)'), findsOneWidget);
    expect(find.byIcon(Icons.subdirectory_arrow_left), findsOneWidget);
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.byIcon(Icons.subdirectory_arrow_left),
          matching: find.byType(InkWell),
        ),
        matching: find.text('World Location'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Location (2)'));
    await tester.pumpAndSettle();
    expect(find.text('World Location'), findsWidgets);
    expect(find.text('Child Location'), findsWidgets);

    await tester.tap(find.text('Map'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.subdirectory_arrow_left));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.subdirectory_arrow_left), findsNothing);
    expect(find.text('World Location'), findsWidgets);
    expect(find.text('Child Location'), findsNothing);

    await tester.tap(find.text('Location (2)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('World Location').last);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.subdirectory_arrow_left), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pumpAndSettle();

    expect(find.text('World detail w_test_1'), findsNothing);
    expect(find.text('World 1'), findsOneWidget);
  });

  testWidgets('World map starts with root location map url', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingV1ListTransport(
      worldRelationStatus: 'none',
      worldMapUrl: kMockV1SteamMapImage,
      worldLocations: const [
        {
          'location_id': 'l_w_test_1',
          'location_name': 'World Root',
          'location_summary': 'The root location.',
          'image': '',
          'map_url': kMockV1LocationCentralHubMap,
          'x_percent': 35,
          'y_percent': 45,
        },
        {
          'location_id': 'l_w_test_1_child',
          'location_pid': 'l_w_test_1',
          'location_name': 'Child Location',
          'location_summary': 'A child world location.',
          'image': '',
          'map_url': kMockV1LocationRailGateMap,
          'x_percent': 55,
          'y_percent': 45,
        },
      ],
    );
    await tester.pumpWidget(
      AppServicesScope(
        services: await _testServices(transport: transport, useMock: false),
        child: MaterialApp(
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: const HomePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('World 1'));
    await tester.pumpAndSettle();

    expect(_assetImageFinder(kMockV1LocationCentralHubMap), findsOneWidget);
    expect(_assetImageFinder(kMockV1SteamMapImage), findsNothing);
  });

  testWidgets('World Request button confirms before v1 apply', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingV1ListTransport(worldRelationStatus: 'none');
    await tester.pumpWidget(
      AppServicesScope(
        services: await _testServices(transport: transport, useMock: false),
        child: MaterialApp(
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: const HomePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('World 1'));
    await tester.pumpAndSettle();

    final buttonFinder = find.widgetWithText(FilledButton, 'Request');
    await tester.ensureVisible(buttonFinder);
    await tester.pumpAndSettle();
    await tester.tap(buttonFinder);
    await tester.pumpAndSettle();

    expect(find.text('Request to join this World?'), findsOneWidget);
    expect(transport.requestsFor('/api/v1/world/apply'), isEmpty);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(transport.requestsFor('/api/v1/world/apply'), isEmpty);

    await tester.tap(buttonFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Request').last);
    await tester.pumpAndSettle();

    final applyRequests = transport.requestsFor('/api/v1/world/apply');
    expect(applyRequests, hasLength(1));
    expect(transport.decodedBody(applyRequests.single)['world_id'], 'w_test_1');
  });

  testWidgets('World pending button is disabled', (WidgetTester tester) async {
    final transport = _RecordingV1ListTransport(worldRelationStatus: 'pending');
    await tester.pumpWidget(
      AppServicesScope(
        services: await _testServices(transport: transport, useMock: false),
        child: MaterialApp(
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: const HomePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('World 1'));
    await tester.pumpAndSettle();

    final buttonFinder = find.widgetWithText(FilledButton, 'Requested');
    await tester.ensureVisible(buttonFinder);
    await tester.pumpAndSettle();
    expect(buttonFinder, findsOneWidget);
    expect(tester.widget<FilledButton>(buttonFinder).onPressed, isNull);

    await tester.tap(buttonFinder);
    await tester.pump();
    expect(transport.requestsFor('/api/v1/world/apply'), isEmpty);
    expect(transport.requestsFor('/api/v1/world/join'), isEmpty);
    expect(transport.requestsFor('/api/v1/world/tick'), isEmpty);
  });

  testWidgets('World Launch button shows role sheet before v1 join', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingV1ListTransport(
      worldRelationStatus: 'approved',
    );
    await tester.pumpWidget(
      AppServicesScope(
        services: await _testServices(transport: transport, useMock: false),
        child: MaterialApp(
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: const HomePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('World 1'));
    await tester.pumpAndSettle();

    final buttonFinder = find.widgetWithText(FilledButton, 'Launch');
    await tester.ensureVisible(buttonFinder);
    await tester.pumpAndSettle();
    await tester.tap(buttonFinder);
    await tester.pumpAndSettle();

    expect(find.text('Setup Your Role'), findsOneWidget);
    expect(find.byType(GenesisBottomSheetPanel), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('origin-role-launch')));
    await tester.pump();

    expect(find.text('Please select a preset role'), findsOneWidget);
    expect(transport.requestsFor('/api/v1/world/join'), isEmpty);

    await tester.tap(
      find.byKey(const ValueKey('origin-role-preset-c_w_test_1')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('origin-role-launch')));
    await tester.pumpAndSettle();

    final joinRequests = transport.requestsFor('/api/v1/world/join');
    expect(joinRequests, hasLength(1));
    final body = transport.decodedBody(joinRequests.single);
    expect(body['world_id'], 'w_test_1');
    expect(body['preset_character_id'], 'c_w_test_1');
    expect(body.containsKey('apply_id'), isFalse);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'World progress button calls v1 tick and disables while pending',
    (WidgetTester tester) async {
      final tickCompleter = Completer<TransportResponse>();
      final transport = _RecordingV1ListTransport(
        worldTickCompleter: tickCompleter,
      );
      await tester.pumpWidget(
        AppServicesScope(
          services: await _testServices(transport: transport, useMock: false),
          child: MaterialApp(
            onGenerateRoute: AppRouter.onGenerateRoute,
            home: const HomePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('World 1'));
      await tester.pumpAndSettle();

      final buttonFinder = find.widgetWithText(FilledButton, 'Progress');
      await tester.ensureVisible(buttonFinder);
      await tester.pumpAndSettle();
      await tester.tap(buttonFinder);
      await tester.pump();

      var tickRequests = transport.requestsFor('/api/v1/world/tick');
      expect(tickRequests, hasLength(1));
      expect(
        transport.decodedBody(tickRequests.single)['world_id'],
        'w_test_1',
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );

      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      tickRequests = transport.requestsFor('/api/v1/world/tick');
      expect(tickRequests, hasLength(1));

      tickCompleter.complete(
        transport._jsonResponse({
          'err_no': 0,
          'err_str': 'success',
          'data': {
            'world_id': 'w_test_1',
            'tick_cnt': 4,
            'last_tick': <String, Object?>{},
          },
        }),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));

      expect(find.widgetWithText(FilledButton, 'Progress'), findsOneWidget);
    },
  );

  testWidgets('Home world list loads next page near bottom', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingV1ListTransport();
    await tester.pumpWidget(
      MaterialApp(
        home: AppServicesScope(
          services: await _testServices(
            transport: transport,
            useMock: false,
            initialAuthToken: 'backend-token',
          ),
          child: const HomePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (var i = 0; i < 4; i++) {
      await tester.drag(find.byType(ListView), const Offset(0, -900));
      await tester.pump(const Duration(milliseconds: 200));
      if (transport.requestsFor('/api/v1/world/list').length > 1) break;
    }

    final worldRequests = transport.requestsFor('/api/v1/world/list');
    expect(worldRequests.length, greaterThanOrEqualTo(2));
    expect(
      worldRequests[1].uri.queryParameters.containsKey('owner_uid'),
      false,
    );
    expect(worldRequests[1].uri.queryParameters.containsKey('uid'), false);
    expect(worldRequests[1].uri.queryParameters['scene'], 'mine');
    expect(worldRequests[1].uri.queryParameters['pn'], '2');
    expect(worldRequests[1].uri.queryParameters['rn'], '20');
  });

  testWidgets('Origin pull refresh reloads first page', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingV1ListTransport();
    await tester.pumpWidget(
      MaterialApp(
        home: AppServicesScope(
          services: await _testServices(transport: transport, useMock: false),
          child: const OriginPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    tester.state<RefreshIndicatorState>(find.byType(RefreshIndicator)).show();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final originRequests = transport.requestsFor('/api/v1/origin/list');
    expect(originRequests, hasLength(2));
    expect(originRequests.last.uri.queryParameters['pn'], '1');
    expect(originRequests.last.uri.queryParameters['rn'], '20');
  });

  testWidgets('Origin pull refresh keeps current list until response returns', (
    WidgetTester tester,
  ) async {
    final refreshCompleter = Completer<TransportResponse>();
    final transport = _QueuedOriginRefreshTransport(
      refreshResponse: refreshCompleter.future,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AppServicesScope(
          services: await _testServices(transport: transport, useMock: false),
          child: const OriginPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('#Origin 1'), findsOneWidget);

    final refreshFuture = tester
        .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
        .show();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(transport.requestsFor('/api/v1/origin/list'), hasLength(2));
    expect(find.text('#Origin 1'), findsOneWidget);
    expect(find.byType(RefreshProgressIndicator), findsOneWidget);

    refreshCompleter.complete(transport._originListResponse(100));
    await refreshFuture;
    await tester.pumpAndSettle();

    expect(find.text('#Origin 1'), findsNothing);
    expect(find.text('#Origin 101'), findsOneWidget);
  });

  testWidgets('Origin tab keeps loaded list when switching away and back', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingV1ListTransport();
    await tester.pumpWidget(
      MaterialApp(
        home: AppServicesScope(
          services: await _testServices(transport: transport, useMock: false),
          child: const OriginPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    var originRequests = transport.requestsFor('/api/v1/origin/list');
    expect(originRequests, hasLength(1));
    expect(find.text('#Origin 1'), findsOneWidget);

    await tester.tap(find.text('Destroyed'));
    await tester.pumpAndSettle();
    originRequests = transport.requestsFor('/api/v1/origin/list');
    expect(originRequests, hasLength(2));

    await tester.tap(find.text('For you'));
    await tester.pumpAndSettle();

    originRequests = transport.requestsFor('/api/v1/origin/list');
    expect(originRequests, hasLength(2));
    expect(find.text('#Origin 1'), findsOneWidget);
  });

  testWidgets('tap Me shows signed-out Me view when not logged in', (
    WidgetTester tester,
  ) async {
    await _pumpGenesisApp(tester);

    await tester.tap(find.text('Me'));
    await tester.pumpAndSettle();

    expect(find.text('LIVE YOUR WORLD'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with Apple'), findsOneWidget);
  });

  testWidgets('tap EULA opens EULA legal document', (
    WidgetTester tester,
  ) async {
    await _pumpGenesisApp(tester);

    await tester.tap(find.text('Me'));
    await tester.pumpAndSettle();

    final eulaRecognizer = _recognizerForText(
      tester.widget<Text>(_loginLegalTextFinder()).textSpan!,
      'EULA',
    );
    eulaRecognizer.onTap?.call();
    await tester.pumpAndSettle();

    expect(find.text('EULA'), findsOneWidget);
    expect(find.text('End User License Agreement ("EULA")'), findsOneWidget);
    expect(find.text('Last updated: 2026-06-14'), findsOneWidget);
  });

  testWidgets('signed-out Me view uses the current Genesis logo', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SignedOutMeView(loggingInProvider: null, onLogin: (_) {}),
        ),
      ),
    );

    final logo = find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName ==
              'assets/images/genesis_home_logo.png',
    );
    expect(logo, findsOneWidget);
    expect(find.text('LIVE YOUR WORLD'), findsOneWidget);
  });

  testWidgets(
    'tap Me shows signed-out view without local backend login state',
    (WidgetTester tester) async {
      final backendAuth = _FakeBackendAuthCoordinator(
        authenticated: true,
        sessionStore: MemoryUserSessionStore(),
      );
      await tester.pumpWidget(
        GenesisApp(
          services: await _testServices(
            identityAuth: const _FakeIdentityAuthService(hasLocalSession: true),
            backendAuth: backendAuth,
          ),
        ),
      );

      await tester.tap(find.text('Me'));
      await tester.pumpAndSettle();

      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Continue with Apple'), findsOneWidget);
      expect(backendAuth.sessionCheckCount, 0);
    },
  );

  testWidgets('login sheet shows both provider options', (
    WidgetTester tester,
  ) async {
    IdentityProvider? tappedProvider;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoginSheet(
            onLogin: (provider) async {
              tappedProvider = provider;
              return false;
            },
          ),
        ),
      ),
    );

    expect(find.byType(GenesisBottomSheetPanel), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with Apple'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.text('Cancel'), findsNothing);
    expect(_loginLegalTextFinder(), findsOneWidget);
    expect(
      find.text('Create origin, launch worlds and invite friends'),
      findsOneWidget,
    );
    final title = tester.widget<Text>(find.text('Sign in to continue'));
    final subtitle = tester.widget<Text>(
      find.text('Create origin, launch worlds and invite friends'),
    );
    final googleLabel = tester.widget<Text>(find.text('Continue with Google'));
    expect(title.style?.fontSize, 22);
    expect(title.style?.fontWeight, FontWeight.w400);
    expect(subtitle.style?.fontSize, 14);
    expect(subtitle.style?.color, const Color(0xFF666666));
    expect(googleLabel.style?.fontSize, 14);
    expect(googleLabel.style?.fontWeight, FontWeight.w400);
    final googleIcon = find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName ==
              'assets/custom-icons/png/google_oauth.png',
    );
    final iconRight = tester.getTopRight(googleIcon).dx;
    final labelLeft = tester.getTopLeft(find.text('Continue with Google')).dx;
    expect(labelLeft - iconRight, closeTo(10, 1));

    await tester.tap(find.text('Continue with Apple'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(tappedProvider, IdentityProvider.apple);
    expect(find.text('Continue with Apple'), findsOneWidget);
    expect(_loginLegalTextFinder(), findsOneWidget);
  });

  testWidgets('tap Me renders cached profile then refreshes user info', (
    WidgetTester tester,
  ) async {
    final userInfoCompleter = Completer<TransportResponse>();
    final transport = _RecordingV1ListTransport(
      userInfoCompleter: userInfoCompleter,
    );
    final backendAuth = _FakeBackendAuthCoordinator(
      authenticated: false,
      sessionStore: MemoryUserSessionStore(),
    );
    final services = await _testServices(
      backendAuth: backendAuth,
      transport: transport,
      useMock: false,
      initialUid: 'u_cached',
      initialAuthToken: 'backend-token',
      initialUserInfo: {
        'uid': 'u_cached',
        'name': 'Cached User',
        'avatar': '',
        'following_cnt': 7,
        'follower_cnt': 11,
      },
    );
    await tester.pumpWidget(GenesisApp(services: services));

    await tester.tap(find.text('Me'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in to continue'), findsNothing);
    expect(find.text('Cached User'), findsOneWidget);
    expect(find.text('11'), findsOneWidget);
    expect(backendAuth.sessionCheckCount, 0);
    expect(transport.requestsFor('/api/v1/user/info'), hasLength(1));

    userInfoCompleter.complete(
      transport._jsonResponse({
        'err_no': 0,
        'err_str': 'success',
        'data': {
          'user': {
            'uid': 'u_cached',
            'name': 'Remote User',
            'avatar': '',
            'following_cnt': 13,
            'follower_cnt': 17,
          },
          'relation': {
            'is_self': true,
            'is_followed': false,
            'i_followed': false,
          },
        },
      }),
    );
    await tester.pumpAndSettle();

    expect(find.text('Remote User'), findsOneWidget);
    expect(find.text('17'), findsOneWidget);
    final cachedUser = await services.sessionStore.readUserInfo();
    expect(cachedUser?['following_cnt'], 13);
    expect(cachedUser?['follower_cnt'], 17);
  });

  testWidgets('switching back to signed-in Me refreshes user info only', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingV1ListTransport();
    await tester.pumpWidget(
      GenesisApp(
        services: await _testServices(
          transport: transport,
          useMock: false,
          initialUid: 'u_cached',
          initialAuthToken: 'backend-token',
          initialUserInfo: {
            'uid': 'u_cached',
            'name': 'Cached User',
            'avatar': '',
            'following_cnt': 7,
            'follower_cnt': 11,
          },
        ),
      ),
    );

    await tester.tap(find.text('Me'));
    await tester.pumpAndSettle();

    final userInfoCount = transport.requestsFor('/api/v1/user/info').length;
    final originListCount = transport.requestsFor('/api/v1/origin/list').length;
    final worldListCount = transport.requestsFor('/api/v1/world/list').length;
    expect(userInfoCount, 1);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Me'));
    await tester.pumpAndSettle();

    expect(
      transport.requestsFor('/api/v1/user/info'),
      hasLength(userInfoCount + 1),
    );
    expect(
      transport.requestsFor('/api/v1/origin/list'),
      hasLength(originListCount),
    );
    expect(
      transport.requestsFor('/api/v1/world/list'),
      hasLength(worldListCount),
    );
  });

  testWidgets('switching back to signed-out Me does not request user info', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingV1ListTransport();
    await tester.pumpWidget(
      GenesisApp(
        services: await _testServices(
          transport: transport,
          useMock: false,
          initialUid: null,
        ),
      ),
    );

    await tester.tap(find.text('Me'));
    await tester.pumpAndSettle();

    expect(find.text('Continue with Google'), findsOneWidget);
    expect(transport.requestsFor('/api/v1/user/info'), isEmpty);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Me'));
    await tester.pumpAndSettle();

    expect(find.text('Continue with Google'), findsOneWidget);
    expect(transport.requestsFor('/api/v1/user/info'), isEmpty);
  });

  testWidgets('Me origin and world refresh preserve old list until response', (
    WidgetTester tester,
  ) async {
    final transport = _UserInfoRefreshTransport();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppServicesScope(
            services: await _testServices(
              transport: transport,
              useMock: false,
              initialUid: 'u_me_refresh',
              initialAuthToken: 'backend-token',
            ),
            child: const MePage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('#Origin Old'), findsOneWidget);
    expect(find.text('#Origin New'), findsNothing);

    var refreshFuture = tester
        .widget<RefreshIndicator>(
          find.byKey(const ValueKey('profile-origin-list-refresh')),
        )
        .onRefresh();
    await tester.pump();

    expect(transport.originListRequests, 2);
    expect(find.text('#Origin Old'), findsOneWidget);
    expect(find.text('#Origin New'), findsNothing);

    transport.completeOriginRefresh();
    await tester.pumpAndSettle();
    await refreshFuture;

    expect(find.text('#Origin Old'), findsNothing);
    expect(find.text('#Origin New'), findsOneWidget);

    await tester.tap(find.text('World'));
    await tester.pumpAndSettle();

    expect(find.text('World Old'), findsOneWidget);
    expect(find.text('World New'), findsNothing);

    refreshFuture = tester
        .widget<RefreshIndicator>(
          find.byKey(const ValueKey('profile-world-list-refresh')),
        )
        .onRefresh();
    await tester.pump();

    expect(transport.worldListRequests, 2);
    expect(find.text('World Old'), findsOneWidget);
    expect(find.text('World New'), findsNothing);

    transport.completeWorldRefresh();
    await tester.pumpAndSettle();
    await refreshFuture;

    expect(find.text('World Old'), findsNothing);
    expect(find.text('World New'), findsOneWidget);
  });

  test('remote user info with same rendered fields is ignored', () {
    const current = UserProfileData(
      avatarUrl: '',
      displayName: 'Cached User',
      uid: 'u_cached',
      followingCount: 7,
      followerCount: 11,
      origins: <UserProfileOriginItem>[],
      worlds: <UserProfileWorldItem>[],
    );

    final next = mergeRemoteUserInfoForRenderForTest(current, {
      'uid': 'u_cached',
      'name': 'Cached User',
      'avatar': '',
      'following_cnt': 7,
      'follower_cnt': 11,
    });

    expect(sameRenderedUserInfoForTest(current, next), isTrue);
  });

  test('remote user info with changed rendered fields is applied', () {
    const current = UserProfileData(
      avatarUrl: '',
      displayName: 'Cached User',
      uid: 'u_cached',
      followingCount: 7,
      followerCount: 11,
      origins: <UserProfileOriginItem>[],
      worlds: <UserProfileWorldItem>[],
    );

    final next = mergeRemoteUserInfoForRenderForTest(current, {
      'uid': 'u_cached',
      'name': 'Remote User',
      'avatar': '',
      'following_cnt': 13,
      'follower_cnt': 17,
    });

    expect(sameRenderedUserInfoForTest(current, next), isFalse);
    expect(next.displayName, 'Remote User');
    expect(next.followingCount, 13);
    expect(next.followerCount, 17);
  });

  test('remote user info image object avatar keeps responsive resource', () {
    const current = UserProfileData(
      avatarUrl: '',
      displayName: 'Cached User',
      uid: 'u_cached',
      followingCount: 7,
      followerCount: 11,
      origins: <UserProfileOriginItem>[],
      worlds: <UserProfileWorldItem>[],
    );

    final next = mergeRemoteUserInfoForRenderForTest(current, {
      'uid': 'u_cached',
      'name': 'Cached User',
      'avatar': {
        'sm_url': 'https://cdn.example.com/me_avatar_400_300.webp',
        'xl_url': 'https://cdn.example.com/me_avatar_800_600.webp',
        'object_key': 'uploads/user_avatar/20260608/me_avatar_800_600.webp',
      },
      'following_cnt': 7,
      'follower_cnt': 11,
    });

    expect(next.avatarUrl, 'https://cdn.example.com/me_avatar_800_600.webp');
    expect(
      selectGenesisImageUrl(
        next.avatarUrl,
        logicalWidth: 120,
        logicalHeight: 90,
        devicePixelRatio: 2,
      ),
      'https://cdn.example.com/me_avatar_400_300.webp',
    );
  });

  testWidgets('Me page enters before origin and world lists finish', (
    WidgetTester tester,
  ) async {
    final userInfoCompleter = Completer<TransportResponse>();
    final originListCompleter = Completer<TransportResponse>();
    final worldListCompleter = Completer<TransportResponse>();
    final transport = _RecordingV1ListTransport(
      userInfoCompleter: userInfoCompleter,
      originListCompleter: originListCompleter,
      worldListCompleter: worldListCompleter,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AppServicesScope(
          services: await _testServices(
            transport: transport,
            useMock: false,
            initialUid: 'u_cached',
            initialAuthToken: 'backend-token',
            initialUserInfo: {
              'uid': 'u_cached',
              'name': 'Cached User',
              'avatar': '',
              'following_cnt': 7,
              'follower_cnt': 11,
            },
          ),
          child: const MePage(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.text('Cached User'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('profile-origin-list-loading')),
      findsOneWidget,
    );
    expect(transport.requestsFor('/api/v1/origin/list'), hasLength(1));
    expect(transport.requestsFor('/api/v1/world/list'), hasLength(1));

    await tester.tap(find.text('World'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const ValueKey('profile-world-list-loading')),
      findsOneWidget,
    );

    userInfoCompleter.complete(
      transport._jsonResponse({
        'err_no': 0,
        'err_str': 'success',
        'data': {
          'user': {
            'uid': 'u_cached',
            'name': 'Remote User',
            'avatar': '',
            'following_cnt': 13,
            'follower_cnt': 17,
          },
        },
      }),
    );
    originListCompleter.complete(
      transport._jsonResponse({
        'err_no': 0,
        'err_str': 'success',
        'data': {'list': const <Object?>[], 'total': 0},
      }),
    );
    worldListCompleter.complete(
      transport._jsonResponse({
        'err_no': 0,
        'err_str': 'success',
        'data': {'list': const <Object?>[], 'total': 0},
      }),
    );
    await tester.pump();
  });

  testWidgets('profile list notifier update does not rebuild profile shell', (
    WidgetTester tester,
  ) async {
    final origins =
        ValueNotifier<UserProfileCollectionState<UserProfileOriginItem>>(
          const UserProfileCollectionState<UserProfileOriginItem>(
            items: <UserProfileOriginItem>[],
            isLoading: true,
          ),
        );
    final worlds =
        ValueNotifier<UserProfileCollectionState<UserProfileWorldItem>>(
          const UserProfileCollectionState<UserProfileWorldItem>(
            items: <UserProfileWorldItem>[],
            isLoading: true,
          ),
        );
    addTearDown(origins.dispose);
    addTearDown(worlds.dispose);
    var shellBuilds = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              shellBuilds += 1;
              return UserProfileContent(
                data: const UserProfileData(
                  avatarUrl: '',
                  displayName: 'Cached User',
                  uid: 'u_cached',
                  followingCount: 7,
                  followerCount: 11,
                  origins: <UserProfileOriginItem>[],
                  worlds: <UserProfileWorldItem>[],
                ),
                originsListenable: origins,
                worldsListenable: worlds,
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    expect(shellBuilds, 1);
    expect(
      find.byKey(const ValueKey('profile-origin-list-loading')),
      findsOneWidget,
    );

    origins.value = const UserProfileCollectionState<UserProfileOriginItem>(
      items: <UserProfileOriginItem>[
        UserProfileOriginItem(
          originId: 1,
          oid: 'o_loaded',
          title: 'Origin loaded',
          subtitle: 'OID: o_loaded',
          imageUrl: '',
          copyCount: 1,
          interactCount: 2,
          characterCount: 3,
        ),
      ],
      isLoading: false,
    );
    await tester.pump();

    expect(shellBuilds, 1);
    expect(find.text('#Origin loaded'), findsOneWidget);
  });

  testWidgets('profile avatar notifier update does not rebuild profile shell', (
    WidgetTester tester,
  ) async {
    final avatarUrl = ValueNotifier<String>('https://cdn.example.com/old.png');
    addTearDown(avatarUrl.dispose);
    var shellBuilds = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              shellBuilds += 1;
              return UserProfileContent(
                data: const UserProfileData(
                  avatarUrl: 'https://cdn.example.com/old.png',
                  displayName: 'Cached User',
                  uid: 'u_cached',
                  followingCount: 7,
                  followerCount: 11,
                  origins: <UserProfileOriginItem>[],
                  worlds: <UserProfileWorldItem>[],
                ),
                avatarUrlListenable: avatarUrl,
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(shellBuilds, 1);
    expect(
      tester
          .widget<CachedNetworkImage>(
            find.byKey(const ValueKey('user-profile-avatar-image')),
          )
          .imageUrl,
      'https://cdn.example.com/old.png',
    );

    avatarUrl.value = 'https://cdn.example.com/new.png';
    await tester.pump();

    expect(shellBuilds, 1);
    expect(find.text('Cached User'), findsOneWidget);
    expect(
      tester
          .widget<CachedNetworkImage>(
            find.byKey(const ValueKey('user-profile-avatar-image')),
          )
          .imageUrl,
      'https://cdn.example.com/new.png',
    );
  });

  testWidgets(
    'profile display name notifier update does not rebuild profile shell',
    (WidgetTester tester) async {
      final displayName = ValueNotifier<String>('');
      addTearDown(displayName.dispose);
      var shellBuilds = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                shellBuilds += 1;
                return UserProfileContent(
                  data: const UserProfileData(
                    avatarUrl: '',
                    displayName: 'Cached User',
                    uid: 'u_cached',
                    followingCount: 7,
                    followerCount: 11,
                    origins: <UserProfileOriginItem>[],
                    worlds: <UserProfileWorldItem>[],
                  ),
                  displayNameListenable: displayName,
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();

      expect(shellBuilds, 1);
      expect(find.text('Cached User'), findsOneWidget);

      displayName.value = 'Updated Nick';
      await tester.pump();

      expect(shellBuilds, 1);
      expect(find.text('Updated Nick'), findsOneWidget);
      expect(find.text('Cached User'), findsNothing);
    },
  );

  testWidgets('profile display name edit icon stays next to text', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UserProfileContent(
            data: const UserProfileData(
              avatarUrl: '',
              displayName: 'Short',
              uid: 'u_cached',
              followingCount: 7,
              followerCount: 11,
              origins: <UserProfileOriginItem>[],
              worlds: <UserProfileWorldItem>[],
            ),
            onEditDisplayName: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    final textRight = tester.getTopRight(find.text('Short')).dx;
    final iconLeft = tester.getTopLeft(find.byIcon(Icons.edit)).dx;
    expect(iconLeft - textRight, lessThan(16));
  });

  testWidgets('profile avatar edit button uses image edit icon', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UserProfileContent(
            data: const UserProfileData(
              avatarUrl: '',
              displayName: 'Short',
              uid: 'u_cached',
              followingCount: 7,
              followerCount: 11,
              origins: <UserProfileOriginItem>[],
              worlds: <UserProfileWorldItem>[],
            ),
            onEditAvatar: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byIcon(MyFlutterApp.editImage), findsOneWidget);
    expect(find.byIcon(Icons.image_outlined), findsNothing);
    expect(find.byIcon(Icons.photo_camera_outlined), findsNothing);
    expect(find.byIcon(Icons.add_photo_alternate_outlined), findsNothing);
    expect(find.byIcon(Icons.edit_document), findsNothing);
  });

  testWidgets('profile content scrolls header away and pins tabs', (
    WidgetTester tester,
  ) async {
    var collapsed = false;
    final origins = List<UserProfileOriginItem>.generate(
      12,
      (index) => UserProfileOriginItem(
        originId: index + 1,
        oid: 'o_scroll_$index',
        title: 'Origin scroll $index',
        subtitle: 'OID: o_scroll_$index',
        imageUrl: '',
        copyCount: index,
        interactCount: index + 1,
        characterCount: index + 2,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 360,
            child: UserProfileContent(
              data: UserProfileData(
                avatarUrl: '',
                displayName: 'Scrollable User',
                uid: 'u_scroll',
                followingCount: 7,
                followerCount: 11,
                origins: origins,
                worlds: const <UserProfileWorldItem>[],
              ),
              onCollapsedChanged: (value) => collapsed = value,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final initialTabTop = tester.getTopLeft(find.text('Origin')).dy;
    expect(initialTabTop, greaterThan(80));

    await tester.drag(find.byType(NestedScrollView), const Offset(0, -260));
    await tester.pumpAndSettle();

    expect(collapsed, isTrue);
    expect(tester.getTopLeft(find.text('Origin')).dy, lessThanOrEqualTo(10));
    expect(find.text('Scrollable User'), findsNothing);
  });

  testWidgets('signed-out Me view enters Me after Google login succeeds', (
    WidgetTester tester,
  ) async {
    final sessionStore = MemoryUserSessionStore();
    final backendAuth = _FakeBackendAuthCoordinator(
      authenticated: false,
      sessionStore: sessionStore,
      loginUser: const User(
        id: 42,
        uid: 'backend_uid',
        did: '',
        nickname: 'Backend User',
        avatar: '',
        createdAt: null,
      ),
    );

    await tester.pumpWidget(
      GenesisApp(
        services: await _testServices(
          sessionStoreOverride: sessionStore,
          identityAuth: const _FakeIdentityAuthService(
            signInSession: AuthSession(
              provider: IdentityProvider.google,
              providerIdToken: 'google-token',
              firebaseIdToken: 'firebase-token',
              identityUid: 'identity_uid',
              email: 'identity@example.com',
              displayName: 'Identity User',
              photoUrl: '',
            ),
          ),
          backendAuth: backendAuth,
        ),
      ),
    );

    await tester.tap(find.text('Me'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue with Google'));
    await tester.tap(find.text('Continue with Google').last);
    await tester.pumpAndSettle();

    expect(backendAuth.loginCount, 1);
    expect(backendAuth.lastLoginProvider, IdentityProvider.google);
    expect(find.text('Continue with Google'), findsNothing);
  });

  testWidgets('Messages login refreshes cached Me session state', (
    WidgetTester tester,
  ) async {
    final sessionStore = MemoryUserSessionStore();
    final backendAuth = _FakeBackendAuthCoordinator(
      authenticated: false,
      sessionStore: sessionStore,
      loginUser: const User(
        id: 42,
        uid: 'backend_uid',
        did: '',
        nickname: 'Backend User',
        avatar: '',
        createdAt: null,
      ),
    );

    await tester.pumpWidget(
      GenesisApp(
        services: await _testServices(
          initialUid: null,
          sessionStoreOverride: sessionStore,
          identityAuth: const _FakeIdentityAuthService(
            signInSession: AuthSession(
              provider: IdentityProvider.google,
              providerIdToken: 'google-token',
              firebaseIdToken: 'firebase-token',
              identityUid: 'identity_uid',
              email: 'identity@example.com',
              displayName: 'Identity User',
              photoUrl: '',
            ),
          ),
          backendAuth: backendAuth,
        ),
      ),
    );

    await tester.tap(find.text('Me'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue with Google'));
    expect(find.text('Continue with Google'), findsOneWidget);

    await tester.tap(find.text('Messages'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in to continue'), findsOneWidget);

    await tester.tap(find.text('Continue with Google').last);
    await tester.pumpAndSettle();
    expect(backendAuth.loginCount, 1);
    expect(await sessionStore.readUid(), 'backend_uid');

    await tester.tap(find.text('Me'));
    await tester.pumpAndSettle();

    expect(find.text('Continue with Google'), findsNothing);
    expect(find.byType(UserProfileContent), findsOneWidget);
  });

  testWidgets('signed-out Me view can start Apple login', (
    WidgetTester tester,
  ) async {
    final sessionStore = MemoryUserSessionStore();
    final backendAuth = _FakeBackendAuthCoordinator(
      authenticated: false,
      sessionStore: sessionStore,
      loginUser: const User(
        id: 42,
        uid: 'backend_uid',
        did: '',
        nickname: 'Backend User',
        avatar: '',
        createdAt: null,
      ),
    );

    await tester.pumpWidget(
      GenesisApp(
        services: await _testServices(
          sessionStoreOverride: sessionStore,
          identityAuth: const _FakeIdentityAuthService(
            signInSession: AuthSession(
              provider: IdentityProvider.apple,
              providerIdToken: 'apple-token',
              firebaseIdToken: 'firebase-token',
              identityUid: 'identity_uid',
              email: 'identity@example.com',
              displayName: 'Identity User',
              photoUrl: '',
            ),
          ),
          backendAuth: backendAuth,
        ),
      ),
    );

    await tester.tap(find.text('Me'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue with Apple'));
    await tester.tap(find.text('Continue with Apple'));
    await tester.pumpAndSettle();

    expect(backendAuth.loginCount, 1);
    expect(backendAuth.lastLoginProvider, IdentityProvider.apple);
    expect(find.text('Continue with Apple'), findsNothing);
  });

  testWidgets('signed-out Me view stays open when backend HTTP login fails', (
    WidgetTester tester,
  ) async {
    final sessionStore = MemoryUserSessionStore();
    final backendAuth = _FakeBackendAuthCoordinator(
      authenticated: false,
      sessionStore: sessionStore,
      loginError: Exception('backend login failed'),
    );

    await tester.pumpWidget(
      GenesisApp(
        services: await _testServices(
          sessionStoreOverride: sessionStore,
          identityAuth: const _FakeIdentityAuthService(
            signInSession: AuthSession(
              provider: IdentityProvider.google,
              providerIdToken: 'google-token',
              firebaseIdToken: 'firebase-token',
              identityUid: 'identity_uid',
              email: 'identity@example.com',
              displayName: 'Identity User',
              photoUrl: '',
            ),
          ),
          backendAuth: backendAuth,
        ),
      ),
    );

    await tester.tap(find.text('Me'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue with Google'));
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(backendAuth.loginCount, 1);
    expect(find.text('Continue with Google'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });

  testWidgets('tap Create while signed out shows login sheet', (
    WidgetTester tester,
  ) async {
    await _pumpGenesisApp(tester);
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in to continue'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with Apple'), findsOneWidget);
    expect(find.text('Create Origin'), findsNothing);
    expect(find.text('Basics'), findsNothing);
  });

  testWidgets('tap Create while signed in opens create origin page directly', (
    WidgetTester tester,
  ) async {
    await _pumpGenesisApp(tester, initialAuthToken: 'backend-token');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('Create Origin'), findsOneWidget);
    expect(find.text('Basics'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Create'), findsOneWidget);
  });

  testWidgets('create route opens create origin page', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: RouteNames.create,
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Create Origin'), findsOneWidget);
    expect(find.text('Basics'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Create'), findsOneWidget);
  });

  testWidgets('create origin entries navigate to detail pages', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        initialRoute: RouteNames.create,
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Basics'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Basics'), findsWidgets);
    Navigator.of(tester.element(find.byType(Scaffold).first)).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Characters'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Characters'), findsWidgets);
    Navigator.of(tester.element(find.byType(Scaffold).first)).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Locations'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Locations'), findsWidgets);
    Navigator.of(tester.element(find.byType(Scaffold).first)).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Story Events (Optional)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Story Events'), findsWidgets);
  });

  testWidgets('create origin page renders final draft summaries', (
    WidgetTester tester,
  ) async {
    await CreateOriginDraftStore.saveFinal(
      const CreateOriginDraft(
        basics: BasicsDraft(
          originName: '#Cff',
          worldView: 'Xkkdd',
          worldLogic: 'Nfhnnfjdkd dndiengmcksowbdjcxjnsked rules',
          coverImageUrl: 'https://example.com/cover.png',
        ),
        characters: <CharacterDraft>[
          CharacterDraft(
            charId: 'char_tff',
            name: 'Tff',
            identity: 'Guide',
            personality: 'Calm',
          ),
        ],
        locations: <LocationDraft>[
          LocationDraft(locationId: 'location_1', name: 'Jenrn ff'),
        ],
        storyEvents: <StoryEventDraft>[
          StoryEventDraft(event: 'First event'),
          StoryEventDraft(event: 'Second event'),
        ],
        basicsSaved: true,
        charactersSaved: true,
        locationsSaved: true,
        storyEventsSaved: true,
      ),
    );

    await tester.pumpWidget(const MaterialApp(home: CreateOriginPage()));
    await tester.pumpAndSettle();

    expect(find.textContaining('World Name: #Cff'), findsOneWidget);
    expect(find.textContaining('World View: Xkkdd'), findsOneWidget);
    expect(find.textContaining('World Logic:'), findsNothing);
    expect(find.textContaining('Cover Image: Uploaded'), findsOneWidget);
    expect(find.text('Tff: Guide / Calm'), findsOneWidget);
    expect(find.text('Jenrn ff'), findsOneWidget);
    expect(find.text('2 Events'), findsOneWidget);
  });

  testWidgets('create origin back action can discard the local draft', (
    WidgetTester tester,
  ) async {
    await CreateOriginDraftStore.saveFinal(
      const CreateOriginDraft(
        basics: BasicsDraft(originName: 'Draft Origin'),
        characters: <CharacterDraft>[CharacterDraft()],
        locations: <LocationDraft>[LocationDraft()],
        storyEvents: <StoryEventDraft>[StoryEventDraft()],
        basicsSaved: true,
        charactersSaved: false,
        locationsSaved: false,
        storyEventsSaved: false,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: FilledButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CreateOriginPage(),
                    ),
                  );
                },
                child: const Text('Open create'),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open create'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pumpAndSettle();

    expect(find.text('Save the draft before leaving?'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('genesis-action-box-detached-cancel')),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Create Origin'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(find.text('Open create'), findsOneWidget);
    expect(find.text('Create Origin'), findsNothing);
    expect((await CreateOriginDraftStore.load()).basics.originName, isEmpty);
  });

  testWidgets('characters add button appends empty form', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CreateCharactersPage()));
    await tester.pumpAndSettle();

    expect(find.text('Character 1'), findsOneWidget);
    expect(find.text('Character 2'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('+ Add Character'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('+ Add Character'));
    await tester.pumpAndSettle();

    expect(find.text('Character 2'), findsOneWidget);
  });

  testWidgets('characters delete confirms before clearing edited form', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CreateCharactersPage()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Ari');
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text('Delete Character 1?'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    TextField nameField = tester.widget<TextField>(
      find.byType(TextField).first,
    );
    expect(nameField.controller?.text, 'Ari');

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Character 1'), findsOneWidget);
    nameField = tester.widget<TextField>(find.byType(TextField).first);
    expect(nameField.controller?.text, isEmpty);
  });

  testWidgets(
    'characters save ignores empty cards but validates partial cards',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return FilledButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const CreateCharactersPage(),
                      ),
                    );
                  },
                  child: const Text('Open characters'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open characters'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      var draft = await CreateOriginDraftStore.loadFinal();
      expect(draft.charactersSaved, isTrue);
      expect(
        draft.characters.where((item) => item.name.trim().isNotEmpty),
        isEmpty,
      );

      await tester.tap(find.text('Open characters'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Ari');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Character 1: Identity is required.'), findsOneWidget);
      draft = await CreateOriginDraftStore.loadFinal();
      expect(
        draft.characters.where((item) => item.name.trim().isNotEmpty),
        isEmpty,
      );
      await tester.pump(const Duration(seconds: 2));
    },
  );

  testWidgets('locations add button appends empty form', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CreateLocationsPage()));
    await tester.pumpAndSettle();

    expect(find.text('Location 1'), findsOneWidget);
    expect(find.text('Location 2'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('+ Add Location'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('+ Add Location'));
    await tester.pumpAndSettle();

    expect(find.text('Location 2'), findsOneWidget);
  });

  testWidgets(
    'locations save ignores empty cards but validates partial cards',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return FilledButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const CreateLocationsPage(),
                      ),
                    );
                  },
                  child: const Text('Open locations'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open locations'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      var draft = await CreateOriginDraftStore.loadFinal();
      expect(draft.locationsSaved, isTrue);
      expect(
        draft.locations.where((item) => item.name.trim().isNotEmpty),
        isEmpty,
      );

      await tester.tap(find.text('Open locations'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), 'Hidden door');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(
        find.text('Location 1: Location Name is required.'),
        findsOneWidget,
      );
      draft = await CreateOriginDraftStore.loadFinal();
      expect(
        draft.locations.where((item) => item.name.trim().isNotEmpty),
        isEmpty,
      );
      await tester.pump(const Duration(seconds: 2));
    },
  );

  testWidgets('locations character picker reports empty final characters', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CreateLocationsPage()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('location-character-picker')).first,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(
      find.byKey(const ValueKey('location-character-picker')).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('There are no characters yet.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('locations editor does not show parent location picker', (
    WidgetTester tester,
  ) async {
    await CreateOriginDraftStore.saveFinal(
      const CreateOriginDraft(
        basics: BasicsDraft(),
        characters: <CharacterDraft>[CharacterDraft()],
        locations: <LocationDraft>[
          LocationDraft(locationId: 'loc_gate', name: 'Gate'),
          LocationDraft(locationId: 'loc_tower', name: 'Tower'),
        ],
        storyEvents: <StoryEventDraft>[StoryEventDraft()],
        basicsSaved: false,
        charactersSaved: false,
        locationsSaved: true,
        storyEventsSaved: false,
      ),
    );

    await tester.pumpWidget(const MaterialApp(home: CreateLocationsPage()));
    await tester.pumpAndSettle();

    expect(find.text('Parent Location'), findsNothing);
    expect(find.byKey(const ValueKey('location-parent-picker')), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final draft = await CreateOriginDraftStore.load();
    expect(draft.locations, hasLength(2));
    expect(draft.locations.first.toJson().containsKey('location_pid'), isFalse);
    expect(draft.locations.last.toJson().containsKey('location_pid'), isFalse);
  });

  testWidgets('edit locations editor does not show parent location picker', (
    WidgetTester tester,
  ) async {
    final repository = MemoryOriginDraftRepository(
      initialDraft: const CreateOriginDraft(
        basics: BasicsDraft(),
        characters: <CharacterDraft>[CharacterDraft()],
        locations: <LocationDraft>[
          LocationDraft(locationId: 'loc_gate', name: 'Gate'),
        ],
        storyEvents: <StoryEventDraft>[StoryEventDraft()],
        basicsSaved: false,
        charactersSaved: false,
        locationsSaved: true,
        storyEventsSaved: false,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: EditLocationsPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Parent Location'), findsNothing);
    expect(find.byKey(const ValueKey('location-parent-picker')), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final draft = await repository.loadDraft();
    expect(draft.locations.single.toJson().containsKey('location_pid'), false);
  });

  testWidgets('locations character picker binds available character ids', (
    WidgetTester tester,
  ) async {
    await CreateOriginDraftStore.saveFinal(
      const CreateOriginDraft(
        basics: BasicsDraft(),
        characters: <CharacterDraft>[
          CharacterDraft(
            charId: 'char_ari',
            name: 'Ari',
            identity: 'Guide',
            personality: 'Calm',
          ),
          CharacterDraft(
            charId: 'char_bex',
            name: 'Bex',
            identity: 'Scout',
            personality: 'Bold',
          ),
        ],
        locations: <LocationDraft>[LocationDraft()],
        storyEvents: <StoryEventDraft>[StoryEventDraft()],
        basicsSaved: false,
        charactersSaved: true,
        locationsSaved: false,
        storyEventsSaved: false,
      ),
    );

    await tester.pumpWidget(const MaterialApp(home: CreateLocationsPage()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('location-character-picker')).first,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(
      find.byKey(const ValueKey('location-character-picker')).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Select Characters'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('character-picker-tile-char_ari')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Select'));
    await tester.pumpAndSettle();

    expect(find.text('Ari'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Gate');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final draft = await CreateOriginDraftStore.load();
    expect(draft.locations.single.initialCharacterIds, <String>['char_ari']);
  });

  testWidgets('story events add button appends empty form', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CreateStoryEventsPage()));
    await tester.pumpAndSettle();

    expect(find.text('Event 1'), findsOneWidget);
    expect(find.text('Event 2'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('+ Add Event'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('+ Add Event'));
    await tester.pumpAndSettle();

    expect(find.text('Event 2'), findsOneWidget);
  });

  testWidgets('basics save validates required starred fields', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CreateBasicsPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Origin Name is required.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('basics back without save does not persist section draft', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CreateBasicsPage()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Unsaved Origin');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pumpAndSettle();

    final draft = await CreateOriginDraftStore.load();
    final finalDraft = await CreateOriginDraftStore.loadFinal();
    expect(draft.basics.originName, isEmpty);
    expect(finalDraft.basics.originName, isEmpty);
  });

  test('create id helper hashes uid and timestamp deterministically', () {
    final id = createUidTimestampHashId(
      uid: 'u_mock',
      timestamp: DateTime.fromMicrosecondsSinceEpoch(42, isUtc: true),
      prefix: 'origin',
    );

    expect(
      id,
      createUidTimestampHashId(
        uid: 'u_mock',
        timestamp: DateTime.fromMicrosecondsSinceEpoch(42, isUtc: true),
        prefix: 'origin',
      ),
    );
    expect(id, startsWith('origin_'));
    expect(id.length, 'origin_'.length + 24);
  });

  testWidgets('create save reports missing local draft sections', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CreateOriginPage()));
    await tester.pumpAndSettle();

    final createButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Create'),
    );
    expect(createButton.onPressed, isNotNull);
    expect(
      createButton.style?.backgroundColor?.resolve(<WidgetState>{}),
      const Color(0xFF198B64),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    expect(
      find.text('Please save Basics, Characters, Locations before creating.'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('create save posts v1 origin and clears local draft', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingCreateOriginTransport();
    await CreateOriginDraftStore.saveFinal(
      const CreateOriginDraft(
        basics: BasicsDraft(
          originId: 'origin_local_1',
          originName: 'Crystal City',
          worldView: 'A public world view.',
          worldLogic: 'Hidden rules.',
          coverImageUrl: 'https://example.com/cover.png',
        ),
        characters: <CharacterDraft>[
          CharacterDraft(
            charId: 'char_local_1',
            name: 'Ari',
            identity: 'Guide',
            personality: 'Calm',
          ),
        ],
        locations: <LocationDraft>[
          LocationDraft(locationId: 'location_local_1', name: 'Gate'),
        ],
        storyEvents: <StoryEventDraft>[StoryEventDraft()],
        basicsSaved: true,
        charactersSaved: true,
        locationsSaved: true,
        storyEventsSaved: true,
      ),
    );

    await tester.pumpWidget(
      AppServicesScope(
        services: await _testServices(transport: transport, useMock: false),
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CreateOriginPage(),
                    ),
                  );
                },
                child: const Text('Open create'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open create'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    final requests = transport.requestsFor('/api/v1/origin/create');
    expect(requests, hasLength(1));
    final body = transport.decodedBody(requests.single);
    expect(body.containsKey('origin_id'), isFalse);
    expect(body.containsKey('name'), isFalse);
    expect(body.containsKey('world_view'), isFalse);
    expect(body.containsKey('world_setting'), isFalse);
    expect(body.containsKey('origin_version'), isFalse);
    expect(body.containsKey('character_list'), isFalse);
    expect(body.containsKey('location_list'), isFalse);
    expect(body['origin_name'], 'Crystal City');
    expect(body['brief'], 'A public world view.');
    expect(body['setting'], 'Hidden rules.');
    expect(body['cover'], 'https://example.com/cover.png');
    expect(body['characters'], isA<List>());
    final characters = body['characters'] as List;
    expect(characters.single['char_id'], 'char_local_1');
    expect(characters.single['personality'], 'Calm');
    expect(body['locations'], isA<List>());
    final locationList = body['locations'] as List;
    expect(locationList, hasLength(1));
    expect(locationList.single['location_id'], 'location_local_1');
    expect(locationList.single.containsKey('location_pid'), isFalse);
    expect(locationList.single['location_name'], 'Gate');

    final draft = await CreateOriginDraftStore.load();
    expect(draft.hasAllSectionsSaved, isFalse);
    expect(find.text('Open create'), findsOneWidget);
    expect(find.text('Create Origin'), findsNothing);
    expect(
      find.text('Origin created successfully: o_created_1'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });

  testWidgets('edit flow loads origin detail and posts update after changes', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingCreateOriginTransport();
    await tester.pumpWidget(
      AppServicesScope(
        services: await _testServices(transport: transport, useMock: false),
        child: const MaterialApp(home: EditOriginPage(originId: 'o_edit_1')),
      ),
    );
    await tester.pumpAndSettle();

    final detailRequests = transport.requestsFor('/api/v1/origin/foredit');
    expect(detailRequests, hasLength(1));
    expect(detailRequests.single.uri.queryParameters['origin_id'], 'o_edit_1');
    expect(find.textContaining('World Name: Editable Origin'), findsOneWidget);

    var rootPublish = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Publish'),
    );
    expect(rootPublish.onPressed, isNotNull);
    expect(
      rootPublish.style?.backgroundColor?.resolve(<WidgetState>{}),
      const Color(0xFF198B64),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Publish'));
    await tester.pumpAndSettle();
    expect(find.text('No changes to publish.'), findsOneWidget);
    expect(transport.requestsFor('/api/v1/origin/update'), isEmpty);
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.text('Basics'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Origin'), findsNothing);
    expect(find.text('🌐 Basics'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Edited Origin');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.textContaining('World Name: Edited Origin'), findsOneWidget);
    rootPublish = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Publish'),
    );
    expect(rootPublish.onPressed, isNotNull);

    await tester.tap(find.widgetWithText(FilledButton, 'Publish'));
    await tester.pumpAndSettle();

    final updateRequests = transport.requestsFor('/api/v1/origin/update');
    expect(updateRequests, hasLength(1));
    final body = transport.decodedBody(updateRequests.single);
    expect(body.containsKey('oid'), isFalse);
    expect(body.containsKey('name'), isFalse);
    expect(body.containsKey('world_view'), isFalse);
    expect(body.containsKey('world_setting'), isFalse);
    expect(body.containsKey('character_list'), isFalse);
    expect(body.containsKey('location_list'), isFalse);
    expect(body.containsKey('event_list'), isFalse);
    expect(body['origin_id'], 'o_edit_1');
    expect(body['origin_name'], 'Edited Origin');
    expect(body['brief'], 'Editable public view.');
    expect(body['setting'], 'Editable hidden rules.');
    expect(body['started_at'], 'Day 1');
    expect(body['tick_duration_days'], 30);
    expect(body['metric'], {
      'mode': 'qualitative',
      'label': 'Influence',
      'unit': '%',
      'range': [0, 100],
      'default': 0,
    });
    final metric = body['metric'] as Map;
    expect(metric.containsKey('progress_metric'), isFalse);
    expect(metric.containsKey('starting_value'), isFalse);
    expect(metric.containsKey('start_time'), isFalse);
    expect(metric.containsKey('time_per_progress'), isFalse);
    expect(
      body['cover'],
      'assets/images/mock_maps/steam_kingdom_isometric.png',
    );
    final editedCharacters = body['characters'] as List;
    expect(editedCharacters.single['char_id'], 'char_edit_1');
    expect(editedCharacters.single['initial_location_id'], 'location_edit_1');
    expect(body['deleted_char_ids'], isEmpty);
    expect(body['deleted_location_ids'], isEmpty);
    final editedLocations = body['locations'] as List;
    expect(
      editedLocations
          .where(
            (item) => item is Map && item['location_id'] == 'location_edit_1',
          )
          .single['location_name'],
      'Archive',
    );
    expect(editedLocations.single.containsKey('location_pid'), isFalse);

    final draft = await CreateOriginDraftStore.load();
    expect(draft.hasAllSectionsSaved, isFalse);
    expect(
      find.text('Origin published successfully: o_edit_1'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'edit flow exits without draft dialog and reloads original detail',
    (WidgetTester tester) async {
      final transport = _RecordingCreateOriginTransport();
      await tester.pumpWidget(
        AppServicesScope(
          services: await _testServices(transport: transport, useMock: false),
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: Center(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                const EditOriginPage(originId: 'o_edit_1'),
                          ),
                        );
                      },
                      child: const Text('Open edit'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open edit'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('World Name: Editable Origin'),
        findsOneWidget,
      );

      await tester.tap(find.text('Basics'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Edited Origin');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.textContaining('World Name: Edited Origin'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
      await tester.pumpAndSettle();
      expect(find.text('Publish changes before leaving?'), findsNothing);
      expect(find.text('Open edit'), findsOneWidget);
      expect(transport.requestsFor('/api/v1/origin/update'), isEmpty);

      await tester.tap(find.text('Open edit'));
      await tester.pumpAndSettle();
      expect(transport.requestsFor('/api/v1/origin/foredit'), hasLength(2));
      expect(
        find.textContaining('World Name: Editable Origin'),
        findsOneWidget,
      );
      expect(find.textContaining('World Name: Edited Origin'), findsNothing);
    },
  );

  testWidgets('settings opens about us page', (WidgetTester tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      GenesisMethodChannels.device,
      (call) async {
        if (call.method == GenesisMethodChannels.getAppName) {
          return 'worldo';
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        GenesisMethodChannels.device,
        null,
      );
    });
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') return null;
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: SettingsPage(),
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Delete account'), findsOneWidget);
    expect(find.text('Developer page'), findsNothing);
    expect(find.text('Location chat test'), findsNothing);
    expect(find.text('WebSocket test'), findsNothing);
    expect(find.text('Clear direct message cache'), findsNothing);

    await tester.tap(find.text('About us'));
    await tester.pumpAndSettle();

    expect(find.text('About'), findsOneWidget);
    expect(
      find.byKey(const Key('about_genesis_launch_logo'), skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('Genesis'), findsNothing);
    expect(find.text('v1.0.0'), findsOneWidget);
    expect(
      _richTextFinder(
        'Worldo lets you create, discover, and enter AI-powered worlds filled '
        'with characters, stories, and evolving events. Chat with AI '
        'characters, play with friends, and progress each world through '
        'immersive scenes and choices.\n\n'
        'Our app offers a new way to experience interactive stories — not just '
        'as a reader, but as someone inside the world. If you have any '
        'questions, please contact us at worldodeveloper@gmail.com.',
      ),
      findsOneWidget,
    );
    final emailRecognizer = _recognizerForText(
      tester
          .widget<Text>(
            _richTextFinder(
              'Worldo lets you create, discover, and enter AI-powered worlds '
              'filled with characters, stories, and evolving events. Chat with '
              'AI characters, play with friends, and progress each world '
              'through immersive scenes and choices.\n\n'
              'Our app offers a new way to experience interactive stories — '
              'not just as a reader, but as someone inside the world. If you '
              'have any questions, please contact us at '
              'worldodeveloper@gmail.com.',
            ),
          )
          .textSpan!,
      'worldodeveloper@gmail.com',
    );
    emailRecognizer.onTap?.call();
    await tester.pumpAndSettle();
    expect(find.text('Email copied'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    final legalLinksFinder = _richTextFinder(
      'Privacy Policy , Terms of Use and End User License Agreement',
    );
    expect(legalLinksFinder, findsOneWidget);

    final eulaRecognizer = _recognizerForText(
      tester.widget<Text>(legalLinksFinder).textSpan!,
      'End User License Agreement',
    );
    eulaRecognizer.onTap?.call();
    await tester.pumpAndSettle();

    expect(find.text('End User License Agreement ("EULA")'), findsOneWidget);
  });

  testWidgets('settings reveals developer page after ten blank taps', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsPage()));
    await tester.pumpAndSettle();

    final unlockArea = find.byKey(
      const ValueKey<String>('settings-developer-unlock-area'),
    );
    expect(find.text('Developer page'), findsNothing);

    for (var i = 0; i < 9; i += 1) {
      await tester.tap(unlockArea);
      await tester.pump();
    }
    expect(find.text('Developer page'), findsNothing);

    await tester.tap(unlockArea);
    await tester.pumpAndSettle();

    expect(find.text('Developer page'), findsOneWidget);
  });

  testWidgets(
    'developer page shows device id and clears local direct message cache',
    (WidgetTester tester) async {
      final sessionStore = MemoryUserSessionStore();
      await sessionStore.saveUid('u_mock');
      final api = GenesisApi(
        useMock: true,
        platformConfig: const DefaultPlatformConfig(),
        deviceIdService: const _FakeDeviceIdService(),
        sessionStore: sessionStore,
        identityAuthService: const _FakeIdentityAuthService(),
      );
      final conversationStorage = MemoryDirectMessageConversationStorage();
      await conversationStorage.mergeConversations(
        ownerUid: 'u_mock',
        conversations: [
          _dmConversationJson(
            convId: 'dm_cached',
            peerName: 'Cached Peer',
            messageId: 'dm_cached_msg',
            message: 'Cached preview',
            minutesAgo: 1,
          ),
        ],
        nextAfterMessageId: 'dm_cached_cursor',
      );
      final messageStorage = MemoryDirectMessageMessageStorage();
      await messageStorage.mergeMessages(
        ownerUid: 'u_mock',
        peerUid: 'peer_dm_cached',
        messages: [
          {
            'msg_id': 'dm_cached_msg',
            'conv_id': 'dm_cached',
            'sender_uid': 'peer_dm_cached',
            'receiver_uid': 'u_mock',
            'content': 'Cached message',
            'created_at': _unixTimestamp(DateTime.now()),
          },
        ],
      );
      final conversationStore = DirectMessageConversationStore(
        api: api,
        sessionStore: sessionStore,
        storage: conversationStorage,
      );
      final messageStore = DirectMessageMessageStore(
        api: api,
        sessionStore: sessionStore,
        storage: messageStorage,
      );
      await conversationStore.loadFromDb();
      await messageStore.loadFromDb('peer_dm_cached');

      await tester.pumpWidget(
        MaterialApp(
          home: AppServicesScope(
            services: await _testServices(
              directMessageConversations: conversationStore,
              directMessageMessages: messageStore,
            ),
            child: const SettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final unlockArea = find.byKey(
        const ValueKey<String>('settings-developer-unlock-area'),
      );
      for (var i = 0; i < 10; i += 1) {
        await tester.tap(unlockArea);
        await tester.pump();
      }

      await tester.tap(find.text('Developer page'));
      await tester.pumpAndSettle();

      expect(find.text('Developer page'), findsWidgets);
      expect(find.text('Device ID'), findsOneWidget);
      expect(find.text('test-device-id'), findsOneWidget);

      await tester.tap(find.text('Clear direct message cache'));
      await tester.pumpAndSettle();

      expect(find.text('Direct message cache cleared'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(conversationStore.orderedConversationIds.value, isEmpty);
      expect(messageStore.orderedMessageIds.value, isEmpty);
      expect(await conversationStorage.loadConversations('u_mock'), isEmpty);
      expect(
        await messageStorage.loadMessages(
          ownerUid: 'u_mock',
          peerUid: 'peer_dm_cached',
        ),
        isEmpty,
      );
    },
  );

  testWidgets(
    'settings delete account clears session posts delete and opens origin',
    (WidgetTester tester) async {
      final sessionStore = MemoryUserSessionStore();
      await sessionStore.saveUid('u_cached');
      await sessionStore.saveAuthToken('backend-token');
      await sessionStore.saveUserInfo({
        'uid': 'u_cached',
        'name': 'Cached User',
      });
      final transport = _RecordingV1ListTransport();
      final api = GenesisApi(
        transport: transport,
        useMock: false,
        platformConfig: const DefaultPlatformConfig(),
        deviceIdService: const _FakeDeviceIdService(),
        sessionStore: sessionStore,
        identityAuthService: const _FakeIdentityAuthService(),
      );
      final backendAuth = GenesisBackendAuthCoordinator(
        api: api,
        identityAuth: const _FakeIdentityAuthService(),
        sessionStore: sessionStore,
      );
      final services = await _testServices(
        transport: transport,
        useMock: false,
        sessionStoreOverride: sessionStore,
        backendAuth: backendAuth,
        initialUid: null,
      );

      await tester.pumpWidget(
        AppServicesScope(
          services: services,
          child: MaterialApp(
            onGenerateRoute: AppRouter.onGenerateRoute,
            home: const SettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete account'));
      await tester.pumpAndSettle();

      expect(find.text('Delete your account?'), findsOneWidget);
      expect(await sessionStore.readUid(), 'u_cached');

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(await sessionStore.readUid(), 'u_cached');
      expect(transport.requestsFor('/api/v1/user/delete'), isEmpty);

      await tester.tap(find.text('Delete account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete account').last);
      await tester.pumpAndSettle();

      expect(await sessionStore.readUid(), isNull);
      expect(await sessionStore.readAuthToken(), isNull);
      expect(await sessionStore.readUserInfo(), isNull);
      final deleteRequests = transport.requestsFor('/api/v1/user/delete');
      expect(deleteRequests, hasLength(1));
      expect(deleteRequests.single.method, 'POST');
      expect(
        deleteRequests.single.headers['authorization'],
        'Bearer backend-token',
      );
      expect(find.text('For you'), findsOneWidget);
      expect(transport.requestsFor('/api/v1/origin/list'), hasLength(1));
    },
  );

  testWidgets('settings logout clears local login session cache', (
    WidgetTester tester,
  ) async {
    final sessionStore = MemoryUserSessionStore();
    await sessionStore.saveUid('u_cached');
    await sessionStore.saveAuthToken('backend-token');
    await sessionStore.saveUserInfo({'uid': 'u_cached', 'name': 'Cached User'});
    final backendAuth = _FakeBackendAuthCoordinator(
      authenticated: true,
      sessionStore: sessionStore,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AppServicesScope(
          services: await _testServices(
            sessionStoreOverride: sessionStore,
            backendAuth: backendAuth,
            initialUid: null,
          ),
          child: const SettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    expect(find.text('Log out of your account?'), findsOneWidget);
    expect(await sessionStore.readUid(), 'u_cached');

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(await sessionStore.readUid(), 'u_cached');

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out').last);
    await tester.pumpAndSettle();

    expect(await sessionStore.readUid(), isNull);
    expect(await sessionStore.readAuthToken(), isNull);
    expect(await sessionStore.readUserInfo(), isNull);
  });

  testWidgets(
    'me page edits nickname without disposing dialog controller early',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AppServicesScope(
            services: await _testServices(),
            child: const MePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('8'), findsOneWidget);
      expect(find.text('Following'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('Followers'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.edit).last);
      await tester.pumpAndSettle();

      expect(find.text('Edit Nick Name'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Updated Nick');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.text('Updated Nick'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('user info page renders requested uid profile from v1 info', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingV1ListTransport();
    await tester.pumpWidget(
      MaterialApp(
        home: AppServicesScope(
          services: await _testServices(transport: transport, useMock: false),
          child: const UserInfoPage(uid: 'u_mock_peer'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Remote User'), findsOneWidget);
    expect(find.text('13'), findsOneWidget);
    expect(find.text('Following'), findsOneWidget);
    expect(find.text('17'), findsOneWidget);
    expect(find.text('Followers'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    final originRequests = transport.requestsFor('/api/v1/origin/list');
    expect(originRequests, hasLength(1));
    expect(originRequests.single.uri.queryParameters['scene'], 'uid');
    expect(originRequests.single.uri.queryParameters['uid'], 'u_mock_peer');
    expect(
      originRequests.single.uri.queryParameters.containsKey('owner_uid'),
      false,
    );

    await tester.tap(find.text('World'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.chevron_right), findsNothing);
    final worldRequests = transport.requestsFor('/api/v1/world/list');
    expect(worldRequests, hasLength(1));
    expect(worldRequests.single.uri.queryParameters['scene'], 'uid');
    expect(worldRequests.single.uri.queryParameters['uid'], 'u_mock_peer');
    expect(
      worldRequests.single.uri.queryParameters.containsKey('owner_uid'),
      false,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('user info page shows skeleton while loading', (
    WidgetTester tester,
  ) async {
    final userInfoCompleter = Completer<TransportResponse>();
    final transport = _RecordingV1ListTransport(
      userInfoCompleter: userInfoCompleter,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AppServicesScope(
          services: await _testServices(transport: transport, useMock: false),
          child: const UserInfoPage(uid: 'u_mock_peer'),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('user-info-loading-skeleton')),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);

    userInfoCompleter.complete(
      transport._jsonResponse({
        'err_no': 0,
        'err_str': 'success',
        'data': {
          'user': {
            'uid': 'u_mock_peer',
            'name': 'Penny Hardaway',
            'avatar': '',
            'following_cnt': 16,
            'follower_cnt': 20,
          },
          'relation': {
            'is_self': false,
            'is_followed': false,
            'i_followed': false,
          },
        },
      }),
    );
    await tester.pumpAndSettle();

    expect(find.text('Penny Hardaway'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'user info origin and world refresh preserve old list until response',
    (WidgetTester tester) async {
      final transport = _UserInfoRefreshTransport();

      await tester.pumpWidget(
        MaterialApp(
          home: AppServicesScope(
            services: await _testServices(transport: transport, useMock: false),
            child: const UserInfoPage(uid: 'u_refresh_peer'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('#Origin Old'), findsOneWidget);
      expect(find.text('#Origin New'), findsNothing);

      var refreshFuture = tester
          .widget<RefreshIndicator>(
            find.byKey(const ValueKey('profile-origin-list-refresh')),
          )
          .onRefresh();
      await tester.pump();

      expect(transport.originListRequests, 2);
      expect(find.text('#Origin Old'), findsOneWidget);
      expect(find.text('#Origin New'), findsNothing);

      transport.completeOriginRefresh();
      await tester.pumpAndSettle();
      await refreshFuture;

      expect(find.text('#Origin Old'), findsNothing);
      expect(find.text('#Origin New'), findsOneWidget);

      await tester.tap(find.text('World'));
      await tester.pumpAndSettle();

      expect(find.text('World Old'), findsOneWidget);
      expect(find.text('World New'), findsNothing);

      refreshFuture = tester
          .widget<RefreshIndicator>(
            find.byKey(const ValueKey('profile-world-list-refresh')),
          )
          .onRefresh();
      await tester.pump();

      expect(transport.worldListRequests, 2);
      expect(find.text('World Old'), findsOneWidget);
      expect(find.text('World New'), findsNothing);

      transport.completeWorldRefresh();
      await tester.pumpAndSettle();
      await refreshFuture;

      expect(find.text('World Old'), findsNothing);
      expect(find.text('World New'), findsOneWidget);
    },
  );

  testWidgets('peer profile follows and opens direct chat', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingProfileActionTransport();
    await tester.pumpWidget(
      AppServicesScope(
        services: await _testServices(transport: transport, useMock: false),
        child: MaterialApp(
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: const UserInfoPage(uid: 'u_peer'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Peer User'), findsOneWidget);
    expect(find.text('Follow'), findsOneWidget);
    expect(find.text('Message'), findsOneWidget);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('user-profile-follow-button')))
          .height,
      42,
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('user-profile-message-button')))
          .height,
      42,
    );

    await tester.tap(find.byKey(const ValueKey('user-profile-follow-button')));
    await tester.pump();

    final followButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('user-profile-follow-button')),
    );
    expect(followButton.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(transport.followRequests, hasLength(1));
    expect(transport.decodedBody(transport.followRequests.single), {
      'target_uid': 'u_peer',
    });

    transport.completeFollow();
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('user-profile-follow-button')),
        matching: find.text('Following'),
      ),
      findsOneWidget,
    );
    expect(find.text('22'), findsOneWidget);
    final unfollowButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('user-profile-follow-button')),
    );
    expect(
      unfollowButton.style?.backgroundColor?.resolve(<WidgetState>{}),
      const Color(0xFFE5E5E5),
    );
    expect(
      unfollowButton.style?.foregroundColor?.resolve(<WidgetState>{}),
      Colors.black,
    );

    await tester.tap(find.byKey(const ValueKey('user-profile-message-button')));
    await tester.pumpAndSettle();

    expect(find.byType(ChatPage), findsOneWidget);
    final chatPage = tester.widget<ChatPage>(find.byType(ChatPage));
    expect(chatPage.peerUid, 'u_peer');
    expect(chatPage.peerName, 'Peer User');
  });

  testWidgets('follows page loads following and followers lists', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingFollowsTransport();
    await tester.pumpWidget(
      AppServicesScope(
        services: await _testServices(transport: transport, useMock: false),
        child: const MaterialApp(
          home: FollowsPage(uid: 'u_peer', initialTitle: 'Peer User'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      transport
          .requestsFor('/api/v1/user/following')
          .single
          .uri
          .queryParameters['uid'],
      'u_peer',
    );
    expect(
      transport
          .requestsFor('/api/v1/user/followers')
          .single
          .uri
          .queryParameters['uid'],
      'u_peer',
    );
    expect(find.text('Peer User'), findsOneWidget);
    expect(find.text('24 Following'), findsOneWidget);
    expect(find.text('24 Followers'), findsOneWidget);
    expect(find.text('Following Friend 01'), findsOneWidget);
    expect(find.text('Following Friend 24'), findsNothing);
    expect(find.text('Following'), findsWidgets);
    final followingName = tester.widget<Text>(find.text('Following Friend 01'));
    expect(followingName.style?.fontWeight, FontWeight.w500);
    final followingAvatar = find.byKey(
      const ValueKey('follows-avatar-u_following_01'),
    );
    final followingAction = find.byKey(
      const ValueKey('follows-action-u_following_01'),
    );
    final followingGenesisAvatar = find.descendant(
      of: followingAvatar,
      matching: find.byType(GenesisAvatar),
    );
    expect(followingAvatar, findsOneWidget);
    expect(tester.getSize(followingAvatar), const Size(48, 48));
    expect(
      tester.getTopLeft(followingAvatar).dy,
      tester.getTopLeft(find.text('Following Friend 01')).dy,
    );
    expect(followingGenesisAvatar, findsOneWidget);
    expect(
      tester.widget<GenesisAvatar>(followingGenesisAvatar).borderRadius,
      5,
    );
    expect(
      tester.widget<GenesisAvatar>(followingGenesisAvatar).url,
      'https://cdn.example.com/u_following_01-xl.png',
    );
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey('follows-name-uid-gap-u_following_01')),
          )
          .height,
      4,
    );
    final followingUid = find.text('UID: u_following_01');
    expect(followingUid, findsOneWidget);
    expect(
      find.ancestor(of: followingUid, matching: find.byType(CopyableIdLabel)),
      findsNothing,
    );
    final unfollowButtonSize = tester.getSize(followingAction);
    expect(unfollowButtonSize, const Size(86, 28));
    expect(
      tester.getCenter(followingAction).dy,
      tester.getCenter(followingAvatar).dy,
    );

    await tester.tap(find.text('24 Followers'));
    await tester.pumpAndSettle();

    expect(find.text('Follower Friend 01'), findsOneWidget);
    expect(find.text('Follower Friend 24'), findsNothing);
    expect(find.text('Follow'), findsWidgets);
    expect(
      tester.getSize(
        find.byKey(const ValueKey('follows-action-u_follower_01')),
      ),
      unfollowButtonSize,
    );

    await tester.tap(
      find.byKey(const ValueKey('follows-action-u_follower_01')),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.getSize(
        find.byKey(const ValueKey('follows-action-u_follower_01')),
      ),
      unfollowButtonSize,
    );

    transport.completeFollow();
    await tester.pumpAndSettle();

    expect(transport.followRequests, hasLength(1));
    expect(transport.decodedBody(transport.followRequests.single), {
      'target_uid': 'u_follower_01',
    });
    expect(find.text('Following'), findsOneWidget);
  });

  testWidgets('follows page renders cached totals before list totals', (
    WidgetTester tester,
  ) async {
    final followingCompleter = Completer<TransportResponse>();
    final followersCompleter = Completer<TransportResponse>();
    final transport = _RecordingFollowsTransport(
      followingCompleter: followingCompleter,
      followersCompleter: followersCompleter,
    );
    await tester.pumpWidget(
      AppServicesScope(
        services: await _testServices(
          transport: transport,
          useMock: false,
          initialUid: 'u_cached',
          initialUserInfo: {
            'uid': 'u_cached',
            'following_cnt': 7,
            'follower_cnt': 11,
          },
        ),
        child: const MaterialApp(
          home: FollowsPage(uid: 'u_cached', initialTitle: 'Cached User'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('7 Following'), findsOneWidget);
    expect(find.text('11 Followers'), findsOneWidget);
    expect(transport.requestsFor('/api/v1/user/following'), hasLength(1));
    expect(transport.requestsFor('/api/v1/user/followers'), hasLength(1));

    followingCompleter.complete(
      transport._v1Response({
        'total': 24,
        'pn': 1,
        'rn': 50,
        'list': transport._followUsers(
          prefix: 'u_following',
          name: 'Following Friend',
        ),
      }),
    );
    followersCompleter.complete(
      transport._v1Response({
        'total': 24,
        'pn': 1,
        'rn': 50,
        'list': transport._followUsers(
          prefix: 'u_follower',
          name: 'Follower Friend',
          followed: false,
        ),
      }),
    );
    await tester.pumpAndSettle();

    expect(find.text('24 Following'), findsOneWidget);
    expect(find.text('24 Followers'), findsOneWidget);
  });

  testWidgets('chat page renders cached direct messages then syncs', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingDmChatTransport();
    final sessionStore = MemoryUserSessionStore();
    await sessionStore.saveUid('u_mock');
    final api = GenesisApi(
      useMock: false,
      transport: transport,
      platformConfig: const DefaultPlatformConfig(),
      deviceIdService: const _FakeDeviceIdService(),
      sessionStore: sessionStore,
      identityAuthService: const _FakeIdentityAuthService(),
    );
    final storage = MemoryDirectMessageMessageStorage();
    await storage.mergeMessages(
      ownerUid: 'u_mock',
      peerUid: 'u_peer_dm',
      messages: [
        {
          'msg_id': 'dm_cached_001',
          'conv_id': 'dm_conv',
          'sender_uid': 'u_peer_dm',
          'receiver_uid': 'u_mock',
          'content': 'Cached direct chat',
          'created_at': _unixTimestamp(DateTime.now()),
        },
      ],
    );
    final store = DirectMessageMessageStore(
      api: api,
      sessionStore: sessionStore,
      storage: storage,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AppServicesScope(
          services: await _testServices(
            transport: transport,
            useMock: false,
            directMessageMessages: store,
          ),
          child: const ChatPage(
            peerUid: 'u_peer_dm',
            peerName: 'Penny Direct',
            peerAvatar: 'assets/images/mock_avatars/avatar_iris.png',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Cached direct chat'), findsOneWidget);
    expect(find.text('Direct message'), findsNothing);
    expect(find.byIcon(Icons.location_on), findsNothing);
    expect(find.byIcon(Icons.more_horiz), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/images/mock_avatars/avatar_iris.png',
      ),
      findsWidgets,
    );
    await tester.pumpAndSettle();

    expect(find.text('Synced direct chat'), findsOneWidget);
    expect(tester.widget<ListView>(find.byType(ListView)).reverse, isFalse);
    expect(
      transport.requests
          .where((request) => request.uri.path == '/api/v1/direct_message/list')
          .single
          .uri
          .queryParameters,
      containsPair('peer_uid', 'u_peer_dm'),
    );
    expect(
      transport.requests.where(
        (request) => request.uri.path == '/api/v1/direct_message/read',
      ),
      hasLength(1),
    );

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(
      transport.requests.where(
        (request) => request.uri.path == '/api/v1/direct_message/read',
      ),
      hasLength(1),
    );
  });

  testWidgets('chat page renders current user avatar for self messages', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingDmChatTransport(messages: const []);
    final sessionStore = MemoryUserSessionStore();
    await sessionStore.saveUid('u_mock');
    final api = GenesisApi(
      useMock: false,
      transport: transport,
      platformConfig: const DefaultPlatformConfig(),
      deviceIdService: const _FakeDeviceIdService(),
      sessionStore: sessionStore,
      identityAuthService: const _FakeIdentityAuthService(),
    );
    final storage = MemoryDirectMessageMessageStorage();
    await storage.mergeMessages(
      ownerUid: 'u_mock',
      peerUid: 'u_peer_dm',
      messages: [
        {
          'msg_id': 'dm_self_001',
          'conv_id': 'dm_conv',
          'sender_uid': 'u_mock',
          'receiver_uid': 'u_peer_dm',
          'content': 'Self direct chat',
          'created_at': _unixTimestamp(DateTime.now()),
        },
      ],
    );
    final store = DirectMessageMessageStore(
      api: api,
      sessionStore: sessionStore,
      storage: storage,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AppServicesScope(
          services: await _testServices(
            transport: transport,
            useMock: false,
            initialUserInfo: const {
              'uid': 'u_mock',
              'avatar_url': 'assets/images/mock_avatars/avatar_nia.png',
            },
            directMessageMessages: store,
          ),
          child: const ChatPage(peerUid: 'u_peer_dm', peerName: 'Penny Direct'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Self direct chat'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/images/mock_avatars/avatar_nia.png',
      ),
      findsOneWidget,
    );
  });

  testWidgets('chat page restores an unsent draft for the peer conversation', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingDmChatTransport();
    final sessionStore = MemoryUserSessionStore();
    await sessionStore.saveUid('u_mock');
    final api = GenesisApi(
      useMock: false,
      transport: transport,
      platformConfig: const DefaultPlatformConfig(),
      deviceIdService: const _FakeDeviceIdService(),
      sessionStore: sessionStore,
      identityAuthService: const _FakeIdentityAuthService(),
    );
    final storage = MemoryDirectMessageMessageStorage();

    DirectMessageMessageStore newStore() {
      return DirectMessageMessageStore(
        api: api,
        sessionStore: sessionStore,
        storage: storage,
      );
    }

    Future<void> pumpChat(DirectMessageMessageStore store) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AppServicesScope(
            services: await _testServices(
              transport: transport,
              useMock: false,
              directMessageMessages: store,
            ),
            child: const ChatPage(
              peerUid: 'u_peer_dm',
              peerName: 'Penny Direct',
            ),
          ),
        ),
      );
    }

    await pumpChat(newStore());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'unsent local draft');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    expect(
      await storage.loadDraft(ownerUid: 'u_mock', peerUid: 'u_peer_dm'),
      'unsent local draft',
    );

    await pumpChat(newStore());
    await tester.pumpAndSettle();

    expect(find.text('unsent local draft'), findsOneWidget);
  });

  testWidgets('chat page clears the peer draft when sending a message', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingDmChatTransport();
    final sessionStore = MemoryUserSessionStore();
    await sessionStore.saveUid('u_mock');
    final api = GenesisApi(
      useMock: false,
      transport: transport,
      platformConfig: const DefaultPlatformConfig(),
      deviceIdService: const _FakeDeviceIdService(),
      sessionStore: sessionStore,
      identityAuthService: const _FakeIdentityAuthService(),
    );
    final storage = MemoryDirectMessageMessageStorage();
    await storage.saveDraft(
      ownerUid: 'u_mock',
      peerUid: 'u_peer_dm',
      content: 'send this draft',
    );
    final store = DirectMessageMessageStore(
      api: api,
      sessionStore: sessionStore,
      storage: storage,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AppServicesScope(
          services: await _testServices(
            transport: transport,
            useMock: false,
            directMessageMessages: store,
          ),
          child: const ChatPage(peerUid: 'u_peer_dm', peerName: 'Penny Direct'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('send this draft'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      await storage.loadDraft(ownerUid: 'u_mock', peerUid: 'u_peer_dm'),
      '',
    );
  });

  testWidgets('chat page keeps short message lists anchored above composer', (
    WidgetTester tester,
  ) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;

    final transport = _RecordingDmChatTransport(
      messages: [
        {
          'msg_id': 'dm_short_001',
          'conv_id': 'dm_conv',
          'sender_uid': 'u_peer_dm',
          'receiver_uid': 'u_mock',
          'content': 'Short list message',
          'created_at': _unixTimestamp(DateTime.now()),
        },
      ],
    );
    final sessionStore = MemoryUserSessionStore();
    await sessionStore.saveUid('u_mock');
    final api = GenesisApi(
      useMock: false,
      transport: transport,
      platformConfig: const DefaultPlatformConfig(),
      deviceIdService: const _FakeDeviceIdService(),
      sessionStore: sessionStore,
      identityAuthService: const _FakeIdentityAuthService(),
    );
    final store = DirectMessageMessageStore(
      api: api,
      sessionStore: sessionStore,
      storage: MemoryDirectMessageMessageStorage(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AppServicesScope(
          services: await _testServices(
            transport: transport,
            useMock: false,
            directMessageMessages: store,
          ),
          child: const ChatPage(peerUid: 'u_peer_dm', peerName: 'Penny Direct'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final headerBottom = tester.getBottomLeft(find.byType(ChatHeader)).dy;
    final composerTop = tester.getTopLeft(find.byType(ChatComposer)).dy;
    final messageTop = tester.getTopLeft(find.text('Short list message')).dy;
    final beforeDragTop = tester.getTopLeft(find.text('Short list message')).dy;
    final listView = tester.widget<ListView>(find.byType(ListView));

    expect(messageTop, greaterThan(headerBottom));
    expect(
      messageTop,
      lessThan(headerBottom + (composerTop - headerBottom) / 2),
    );
    expect(listView.physics, isA<NeverScrollableScrollPhysics>());

    await tester.drag(find.byType(ListView), const Offset(0, -80));
    await tester.pump();

    expect(
      tester.getTopLeft(find.text('Short list message')).dy,
      beforeDragTop,
    );
  });

  testWidgets(
    'chat page keeps latest message above keyboard as composer grows',
    (WidgetTester tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetViewInsets();
      });
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;

      final baseTime = DateTime.now().subtract(const Duration(minutes: 40));
      final messages = List<Map<String, dynamic>>.generate(28, (index) {
        return <String, dynamic>{
          'msg_id': 'dm_scroll_${index.toString().padLeft(2, '0')}',
          'conv_id': 'dm_conv',
          'sender_uid': index.isEven ? 'u_peer_dm' : 'u_mock',
          'receiver_uid': index.isEven ? 'u_mock' : 'u_peer_dm',
          'content': 'Scrollable message $index',
          'created_at': _unixTimestamp(baseTime.add(Duration(minutes: index))),
        };
      });
      final transport = _RecordingDmChatTransport(messages: messages);
      final sessionStore = MemoryUserSessionStore();
      await sessionStore.saveUid('u_mock');
      final api = GenesisApi(
        useMock: false,
        transport: transport,
        platformConfig: const DefaultPlatformConfig(),
        deviceIdService: const _FakeDeviceIdService(),
        sessionStore: sessionStore,
        identityAuthService: const _FakeIdentityAuthService(),
      );
      final store = DirectMessageMessageStore(
        api: api,
        sessionStore: sessionStore,
        storage: MemoryDirectMessageMessageStorage(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AppServicesScope(
            services: await _testServices(
              transport: transport,
              useMock: false,
              directMessageMessages: store,
            ),
            child: const ChatPage(
              peerUid: 'u_peer_dm',
              peerName: 'Penny Direct',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _jumpChatListToBottom(tester);

      await tester.tap(find.byType(TextField));
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump();
      await tester.enterText(
        find.byType(TextField),
        List.filled(8, 'expanded composer line').join('\n'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      final latestMessage = find.text('Scrollable message 27');
      expect(latestMessage, findsOneWidget);
      expect(
        tester.getBottomLeft(latestMessage).dy,
        lessThanOrEqualTo(tester.getTopLeft(find.byType(ChatComposer)).dy),
      );
    },
  );

  testWidgets(
    'chat page keeps position and shows notice for incoming messages away from bottom',
    (WidgetTester tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;

      final baseTime = DateTime.now().subtract(const Duration(hours: 2));
      final messages = List<Map<String, dynamic>>.generate(60, (index) {
        return <String, dynamic>{
          'msg_id': 'dm_notice_${index.toString().padLeft(2, '0')}',
          'conv_id': 'dm_conv',
          'sender_uid': index.isEven ? 'u_peer_dm' : 'u_mock',
          'receiver_uid': index.isEven ? 'u_mock' : 'u_peer_dm',
          'content':
              'Notice base message $index with enough text to keep the '
              'loaded window scrollable after paging is capped',
          'created_at': _unixTimestamp(baseTime.add(Duration(minutes: index))),
        };
      });
      final transport = _RecordingDmChatTransport(messages: messages);
      final sessionStore = MemoryUserSessionStore();
      await sessionStore.saveUid('u_mock');
      final api = GenesisApi(
        useMock: false,
        transport: transport,
        platformConfig: const DefaultPlatformConfig(),
        deviceIdService: const _FakeDeviceIdService(),
        sessionStore: sessionStore,
        identityAuthService: const _FakeIdentityAuthService(),
      );
      final store = DirectMessageMessageStore(
        api: api,
        sessionStore: sessionStore,
        storage: MemoryDirectMessageMessageStorage(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AppServicesScope(
            services: await _testServices(
              transport: transport,
              useMock: false,
              directMessageMessages: store,
            ),
            child: const ChatPage(
              peerUid: 'u_peer_dm',
              peerName: 'Penny Direct',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _jumpChatListToTop(tester);
      final scrollable = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(
        scrollable.position.maxScrollExtent - scrollable.position.pixels,
        greaterThan(80),
      );

      final visibleMessage = find.textContaining('Notice base message').first;
      expect(visibleMessage, findsOneWidget);
      final visibleMessageTop = tester.getTopLeft(visibleMessage).dy;

      transport.messages.add(<String, dynamic>{
        'msg_id': 'dm_notice_new_001',
        'conv_id': 'dm_conv',
        'sender_uid': 'u_peer_dm',
        'receiver_uid': 'u_mock',
        'content': 'Fresh incoming while reading',
        'created_at': _unixTimestamp(baseTime.add(const Duration(hours: 1))),
      });

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      expect(find.text('1 条新消息'), findsOneWidget);
      expect(tester.getTopLeft(visibleMessage).dy, visibleMessageTop);
    },
  );

  testWidgets('chat page follows incoming messages while already at bottom', (
    WidgetTester tester,
  ) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;

    final baseTime = DateTime.now().subtract(const Duration(hours: 2));
    final messages = List<Map<String, dynamic>>.generate(60, (index) {
      return <String, dynamic>{
        'msg_id': 'dm_follow_${index.toString().padLeft(2, '0')}',
        'conv_id': 'dm_conv',
        'sender_uid': index.isEven ? 'u_peer_dm' : 'u_mock',
        'receiver_uid': index.isEven ? 'u_mock' : 'u_peer_dm',
        'content': 'Follow base message $index',
        'created_at': _unixTimestamp(baseTime.add(Duration(minutes: index))),
      };
    });
    final transport = _RecordingDmChatTransport(messages: messages);
    final sessionStore = MemoryUserSessionStore();
    await sessionStore.saveUid('u_mock');
    final api = GenesisApi(
      useMock: false,
      transport: transport,
      platformConfig: const DefaultPlatformConfig(),
      deviceIdService: const _FakeDeviceIdService(),
      sessionStore: sessionStore,
      identityAuthService: const _FakeIdentityAuthService(),
    );
    final store = DirectMessageMessageStore(
      api: api,
      sessionStore: sessionStore,
      storage: MemoryDirectMessageMessageStorage(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AppServicesScope(
          services: await _testServices(
            transport: transport,
            useMock: false,
            directMessageMessages: store,
          ),
          child: const ChatPage(peerUid: 'u_peer_dm', peerName: 'Penny Direct'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _jumpChatListToBottom(tester);

    transport.messages.add(<String, dynamic>{
      'msg_id': 'dm_follow_new_001',
      'conv_id': 'dm_conv',
      'sender_uid': 'u_peer_dm',
      'receiver_uid': 'u_mock',
      'content': 'Fresh incoming at bottom',
      'created_at': _unixTimestamp(baseTime.add(const Duration(hours: 1))),
    });

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(find.text('Fresh incoming at bottom'), findsOneWidget);
    expect(find.text('1 条新消息'), findsNothing);
    expect(
      tester.getBottomLeft(find.text('Fresh incoming at bottom')).dy,
      lessThanOrEqualTo(tester.getTopLeft(find.byType(ChatComposer)).dy),
    );
  });

  testWidgets('chat page inserts optimistic message and marks send failure', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingDmChatTransport(failSend: true);
    final sessionStore = MemoryUserSessionStore();
    await sessionStore.saveUid('u_mock');
    final api = GenesisApi(
      useMock: false,
      transport: transport,
      platformConfig: const DefaultPlatformConfig(),
      deviceIdService: const _FakeDeviceIdService(),
      sessionStore: sessionStore,
      identityAuthService: const _FakeIdentityAuthService(),
    );
    final storage = MemoryDirectMessageMessageStorage();
    final store = DirectMessageMessageStore(
      api: api,
      sessionStore: sessionStore,
      storage: storage,
    );
    final services = await _testServices(
      transport: transport,
      useMock: false,
      directMessageMessages: store,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AppServicesScope(
          services: services,
          child: const ChatPage(peerUid: 'u_peer_dm', peerName: 'Penny Direct'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'optimistic hello');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(find.text('optimistic hello'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('optimistic hello')).dy,
      greaterThan(tester.getTopLeft(find.text('Synced direct chat')).dy),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.priority_high), findsOneWidget);
    final persisted = await storage.loadMessages(
      ownerUid: 'u_mock',
      peerUid: 'u_peer_dm',
    );
    expect(
      persisted.where((record) => record.content == 'optimistic hello'),
      isEmpty,
    );
  });

  testWidgets('chat page opens peer user info from message avatar', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingDmChatTransport();
    final sessionStore = MemoryUserSessionStore();
    await sessionStore.saveUid('u_mock');
    final api = GenesisApi(
      useMock: false,
      transport: transport,
      platformConfig: const DefaultPlatformConfig(),
      deviceIdService: const _FakeDeviceIdService(),
      sessionStore: sessionStore,
      identityAuthService: const _FakeIdentityAuthService(),
    );
    final storage = MemoryDirectMessageMessageStorage();
    await storage.mergeMessages(
      ownerUid: 'u_mock',
      peerUid: 'u_peer_dm',
      messages: [
        {
          'msg_id': 'dm_cached_avatar',
          'conv_id': 'dm_conv',
          'sender_uid': 'u_peer_dm',
          'receiver_uid': 'u_mock',
          'content': 'Tap my avatar',
          'created_at': _unixTimestamp(DateTime.now()),
        },
      ],
    );
    final store = DirectMessageMessageStore(
      api: api,
      sessionStore: sessionStore,
      storage: storage,
    );
    final services = await _testServices(
      transport: transport,
      useMock: false,
      directMessageMessages: store,
    );
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: AppRouter.onGenerateRoute,
        builder: (context, child) {
          return AppServicesScope(
            services: services,
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: const ChatPage(peerUid: 'u_peer_dm', peerName: 'Penny Direct'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ChatAvatar).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(find.byType(UserInfoPage), findsOneWidget);
    final userInfoRequest = transport.requests.lastWhere(
      (request) => request.uri.path == '/api/v1/user/info',
    );
    expect(userInfoRequest.uri.queryParameters['uid'], 'u_peer_dm');
  });

  testWidgets(
    'world page connects chatroom when relation allows and disconnects on dispose',
    (WidgetTester tester) async {
      final transport = _RecordingV1ListTransport(worldRelationStatus: 'owner');
      final chatroom = _FakeChatroomClient();
      final services = await _testServices(
        transport: transport,
        useMock: false,
        chatroom: chatroom,
      );

      await tester.pumpWidget(
        AppServicesScope(
          services: services,
          child: const MaterialApp(home: WorldPage(wid: 'w_test_1')),
        ),
      );
      await tester.pumpAndSettle();

      expect(chatroom.worldId, 'w_test_1');
      expect(chatroom.senderId, 'u_mock');

      await tester.pump();
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(chatroom.session.disconnectCount, greaterThan(0));
    },
  );

  testWidgets('world page loading map does not show fallback background', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingV1ListTransport(
      worldDetailCompleter: Completer<TransportResponse>(),
    );
    final services = await _testServices(transport: transport, useMock: false);

    await tester.pumpWidget(
      AppServicesScope(
        services: services,
        child: const MaterialApp(home: WorldPage(wid: 'w_test_1')),
      ),
    );
    await tester.pump();

    expect(_assetImageFinder(kWorldMapFallbackBackgroundAsset), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('world detail status bar switches after map scrolls out', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingV1ListTransport();
    final systemUiOverlayStyleCalls = _captureSystemUiOverlayStyleCalls();
    addTearDown(_clearPlatformChannelHandler);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    await tester.pump();
    systemUiOverlayStyleCalls.clear();

    await tester.pumpWidget(
      AppServicesScope(
        services: await _testServices(transport: transport, useMock: false),
        child: const MaterialApp(home: WorldPage(wid: 'w_test_1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      _pageStatusBarStyle(tester).statusBarIconBrightness,
      Brightness.light,
    );

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -720));
    await tester.pumpAndSettle();

    expect(
      _pageStatusBarStyle(tester).statusBarIconBrightness,
      Brightness.dark,
    );

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 720));
    await tester.pumpAndSettle();

    expect(
      _pageStatusBarStyle(tester).statusBarIconBrightness,
      Brightness.light,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(
      systemUiOverlayStyleCalls.last['statusBarIconBrightness'],
      Brightness.dark.toString(),
    );
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets(
    'world page events load from paged tick list and request next page near edge',
    (WidgetTester tester) async {
      final transport = _RecordingV1ListTransport();
      final services = await _testServices(
        transport: transport,
        useMock: false,
      );

      await tester.pumpWidget(
        AppServicesScope(
          services: services,
          child: const MaterialApp(home: WorldPage(wid: 'w_test_1')),
        ),
      );
      await tester.pumpAndSettle();

      final initialRequests = transport.requestsFor('/api/v1/world/tick/list');
      expect(initialRequests, hasLength(1));
      expect(
        initialRequests.single.uri.queryParameters['world_id'],
        'w_test_1',
      );
      expect(initialRequests.single.uri.queryParameters['pn'], '1');
      expect(initialRequests.single.uri.queryParameters['rn'], '20');
      expect(
        find.text('Paged event first page.', skipOffstage: false),
        findsWidgets,
      );
      expect(
        find.text('Tick 25 · tick-time-1', skipOffstage: false),
        findsWidgets,
      );

      await tester.dragUntilVisible(
        find.text('Paged event 20.', skipOffstage: false).first,
        find.byType(CustomScrollView).last,
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();

      final tickRequests = transport.requestsFor('/api/v1/world/tick/list');
      expect(tickRequests.length, greaterThanOrEqualTo(2));
      expect(tickRequests[1].uri.queryParameters['world_id'], 'w_test_1');
      expect(tickRequests[1].uri.queryParameters['pn'], '2');
      expect(tickRequests[1].uri.queryParameters['rn'], '20');
      expect(find.text('Paged event 25.', skipOffstage: false), findsWidgets);
      expect(
        find.text('Tick 1 · tick-time-25', skipOffstage: false),
        findsWidgets,
      );
    },
  );

  testWidgets('world page does not poll world detail after entry', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingV1ListTransport(
      worldRelationStatus: 'approved',
    );
    final chatroom = _FakeChatroomClient();
    final services = await _testServices(
      transport: transport,
      useMock: false,
      chatroom: chatroom,
    );

    await tester.pumpWidget(
      AppServicesScope(
        services: services,
        child: const MaterialApp(home: WorldPage(wid: 'w_test_1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(chatroom.connectCount, 0);
    expect(chatroom.worldId, isNull);
    final initialWorldDetailRequests = transport
        .requestsFor('/api/v1/world/detail')
        .length;
    expect(initialWorldDetailRequests, greaterThan(0));

    transport.worldRelationStatus = 'joined';
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(chatroom.connectCount, 0);
    expect(chatroom.worldId, isNull);
    expect(
      transport.requestsFor('/api/v1/world/detail'),
      hasLength(initialWorldDetailRequests),
    );
  });

  testWidgets('world location chat does not prebuild hidden panels on entry', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingV1ListTransport(worldRelationStatus: 'joined');
    final chatroom = _FakeChatroomClient();
    final services = await _testServices(
      transport: transport,
      useMock: false,
      chatroom: chatroom,
    );

    await tester.pumpWidget(
      AppServicesScope(
        services: services,
        child: const MaterialApp(home: WorldPage(wid: 'w_test_1')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump();
    await tester.pump();

    expect(chatroom.connectCount, 1);
    expect(chatroom.session.joinCount, 0);
    expect(chatroom.session.joinLocationId, isNull);
    expect(find.text('World Location (1)', skipOffstage: false), findsNothing);
    expect(find.text('Child Location (1)', skipOffstage: false), findsNothing);
    expect(_visibleText('World Location (1)'), findsNothing);
    expect(_visibleText('Child Location (1)'), findsNothing);
  });

  testWidgets(
    'world location chat opens inline and reuses cached panel state',
    (WidgetTester tester) async {
      final transport = _RecordingV1ListTransport(
        worldRelationStatus: 'joined',
      );
      final chatroom = _FakeChatroomClient();
      final observer = _RecordingNavigatorObserver();
      final services = await _testServices(
        transport: transport,
        useMock: false,
        chatroom: chatroom,
      );

      await tester.pumpWidget(
        AppServicesScope(
          services: services,
          child: MaterialApp(
            navigatorObservers: [observer],
            home: const WorldPage(wid: 'w_test_1'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final initialPushCount = observer.pushCount;
      Future<void> tapLocationListItem(String label) async {
        final row = find.ancestor(
          of: find.text(label).last,
          matching: find.byType(InkWell),
        );
        await tester.tap(row.last);
      }

      await tester.tap(find.text('Location (2)'));
      await tester.pumpAndSettle();
      await tapLocationListItem('Child Location');
      await tester.pump();
      await tester.pumpAndSettle();

      expect(observer.pushCount, initialPushCount);
      expect(find.byType(LocationChatPage), findsNothing);
      expect(_visibleText('Child Location (1)'), findsOneWidget);
      expect(chatroom.session.joinLocationId, 'l_w_test_1_child');
      expect(chatroom.session.joinCount, 1);

      final activeInput = find.byWidgetPredicate(
        (widget) => widget is TextField && widget.enabled == true,
      );
      await tester.tap(activeInput);
      await tester.enterText(activeInput, 'cached draft');
      await tester.pump();
      expect(find.text('cached draft'), findsOneWidget);

      final chatBack = find.descendant(
        of: find.byType(ChatHeader).last,
        matching: find.byType(IconButton),
      );
      tester.widget<IconButton>(chatBack.first).onPressed!();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(chatroom.session.leaveCount, 1);
      expect(_visibleText('Child Location (1)'), findsNothing);

      await tester.tap(find.text('Location (2)'));
      await tester.pumpAndSettle();
      await tapLocationListItem('Child Location');
      await tester.pump();
      await tester.pumpAndSettle();

      expect(chatroom.session.joinLocationId, 'l_w_test_1_child');
      expect(chatroom.session.joinCount, 2);
      expect(_visibleText('Child Location (1)'), findsOneWidget);
      expect(find.text('cached draft'), findsOneWidget);
    },
  );

  testWidgets('world location chat shows skeleton before first panel frame', (
    WidgetTester tester,
  ) async {
    final connectCompleter = Completer<void>();
    final transport = _RecordingV1ListTransport(worldRelationStatus: 'joined');
    final chatroom = _FakeChatroomClient(connectCompleter: connectCompleter);
    final services = await _testServices(
      transport: transport,
      useMock: false,
      chatroom: chatroom,
    );

    await tester.pumpWidget(
      AppServicesScope(
        services: services,
        child: const MaterialApp(home: WorldPage(wid: 'w_test_1')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Location (2)'));
    await tester.pumpAndSettle();
    final childRow = find.ancestor(
      of: find.text('Child Location').last,
      matching: find.byType(InkWell),
    );
    await tester.tap(childRow.last);
    await tester.pump();

    expect(_visibleText('Child Location (1)'), findsOneWidget);
    expect(_visibleText('Loading'), findsOneWidget);
    expect(chatroom.session.joinCount, 0);

    connectCompleter.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('world location chat opens before position update completes', (
    WidgetTester tester,
  ) async {
    final setPlayerSceneCompleter = Completer<TransportResponse>();
    final transport = _RecordingV1ListTransport(
      worldRelationStatus: 'joined',
      setPlayerSceneCompleter: setPlayerSceneCompleter,
    );
    final chatroom = _FakeChatroomClient();
    final services = await _testServices(
      transport: transport,
      useMock: false,
      chatroom: chatroom,
    );

    await tester.pumpWidget(
      AppServicesScope(
        services: services,
        child: const MaterialApp(home: WorldPage(wid: 'w_test_1')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Location (2)'));
    await tester.pumpAndSettle();
    final childRow = find.ancestor(
      of: find.text('Child Location').last,
      matching: find.byType(InkWell),
    );
    await tester.tap(childRow.last);
    await tester.pump();
    await tester.pump();

    expect(
      transport.requestsFor('/api/session/set-player-scene'),
      hasLength(1),
    );
    expect(setPlayerSceneCompleter.isCompleted, false);
    expect(_visibleText('Child Location (1)'), findsOneWidget);
    expect(chatroom.session.joinLocationId, 'l_w_test_1_child');

    setPlayerSceneCompleter.complete(
      TransportResponse(
        statusCode: 200,
        headers: const {'content-type': 'application/json'},
        body: jsonEncode({
          'err_no': 0,
          'err_str': 'success',
          'data': {'ok': true},
        }),
      ),
    );
    await tester.pump();
  });

  testWidgets(
    'world location chat opens while websocket connects in background',
    (WidgetTester tester) async {
      final connectCompleter = Completer<void>();
      final transport = _RecordingV1ListTransport(
        worldRelationStatus: 'joined',
      );
      final chatroom = _FakeChatroomClient(connectCompleter: connectCompleter);
      final messageStorage = MemoryChatroomMessageStorage();
      await messageStorage.mergeMessages(
        ownerUid: 'u_mock',
        worldId: 'w_test_1',
        locationId: 'l_w_test_1_child',
        messages: const [
          {
            'msg_id': 7,
            'location_id': 'l_w_test_1_child',
            'conversation_round_id': 7,
            'round_order': 1,
            'sender_type': 'user',
            'sender_id': 'u_cached_peer',
            'sender_name': 'Cached Peer',
            'user_id': 'u_cached_peer',
            'content': 'cached local location message',
            'ts': 1717300000007,
          },
        ],
      );
      final services = await _testServices(
        transport: transport,
        useMock: false,
        chatroom: chatroom,
        chatroomMessages: messageStorage,
      );

      await tester.pumpWidget(
        AppServicesScope(
          services: services,
          child: const MaterialApp(home: WorldPage(wid: 'w_test_1')),
        ),
      );
      await tester.pumpAndSettle();

      expect(chatroom.connectCount, 1);
      expect(connectCompleter.isCompleted, false);

      await tester.tap(find.text('Location (2)'));
      await tester.pumpAndSettle();
      final childRow = find.ancestor(
        of: find.text('Child Location').last,
        matching: find.byType(InkWell),
      );
      await tester.tap(childRow.last);
      await tester.pump();
      await tester.pump();

      expect(_visibleText('Child Location (1)'), findsOneWidget);
      expect(find.text('cached local location message'), findsOneWidget);
      expect(chatroom.session.joinCount, 0);

      connectCompleter.complete();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(chatroom.session.joinLocationId, 'l_w_test_1_child');
      expect(chatroom.session.joinCount, 1);
    },
  );

  testWidgets(
    'world location chat renders cached point-id messages before join',
    (WidgetTester tester) async {
      final connectCompleter = Completer<void>();
      final transport = _RecordingV1ListTransport(
        worldRelationStatus: 'joined',
        worldLocations: const [
          {
            'location_id': 'scene_root',
            'point_id': 'point_root',
            'location_name': 'World Location',
            'location_summary': 'A world location.',
            'image': '',
            'map_url': '',
            'x_percent': 35,
            'y_percent': 45,
          },
          {
            'location_id': 'scene_child',
            'point_id': 'point_child',
            'location_pid': 'scene_root',
            'location_name': 'Child Location',
            'location_summary': 'A child world location.',
            'image': '',
            'map_url': '',
            'x_percent': 55,
            'y_percent': 45,
          },
        ],
      );
      final chatroom = _FakeChatroomClient(connectCompleter: connectCompleter);
      final messageStorage = MemoryChatroomMessageStorage();
      await messageStorage.mergeMessages(
        ownerUid: 'u_mock',
        worldId: 'w_test_1',
        locationId: 'point_child',
        messages: const [
          {
            'msg_id': 8,
            'location_id': 'point_child',
            'conversation_round_id': 8,
            'round_order': 1,
            'sender_type': 'user',
            'sender_id': 'u_cached_peer',
            'sender_name': 'Cached Peer',
            'user_id': 'u_cached_peer',
            'content': 'cached point-id location message',
            'ts': 1717300000008,
          },
        ],
      );
      final services = await _testServices(
        transport: transport,
        useMock: false,
        chatroom: chatroom,
        chatroomMessages: messageStorage,
      );

      await tester.pumpWidget(
        AppServicesScope(
          services: services,
          child: const MaterialApp(home: WorldPage(wid: 'w_test_1')),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Location (2)'));
      await tester.pumpAndSettle();
      final childRow = find.ancestor(
        of: find.text('Child Location').last,
        matching: find.byType(InkWell),
      );
      await tester.tap(childRow.last);
      await tester.pump();
      await tester.pump();

      expect(_visibleText('Child Location (1)'), findsOneWidget);
      expect(find.text('cached point-id location message'), findsOneWidget);
      expect(chatroom.session.joinCount, 0);

      connectCompleter.complete();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(chatroom.session.joinLocationId, 'scene_child');
      expect(chatroom.session.joinCount, 1);
    },
  );

  testWidgets(
    'world location chat loads cached messages only for the opened location',
    (WidgetTester tester) async {
      final connectCompleter = Completer<void>();
      final transport = _RecordingV1ListTransport(
        worldRelationStatus: 'joined',
        worldLocations: const [
          {
            'location_id': 'scene_root',
            'point_id': 'point_root',
            'location_name': 'World Location',
            'location_summary': 'A world location.',
            'image': '',
            'map_url': '',
            'x_percent': 35,
            'y_percent': 45,
          },
          {
            'location_id': 'scene_child',
            'point_id': 'point_child',
            'location_pid': 'scene_root',
            'location_name': 'Child Location',
            'location_summary': 'A child world location.',
            'image': '',
            'map_url': '',
            'x_percent': 55,
            'y_percent': 45,
          },
        ],
      );
      final chatroom = _FakeChatroomClient(connectCompleter: connectCompleter);
      final messageStorage = _RecordingChatroomMessageStorage();
      await messageStorage.mergeMessages(
        ownerUid: 'u_mock',
        worldId: 'w_test_1',
        locationId: 'point_child',
        messages: const [
          {
            'msg_id': 9,
            'location_id': 'point_child',
            'conversation_round_id': 9,
            'round_order': 1,
            'sender_type': 'user',
            'sender_id': 'u_cached_peer',
            'sender_name': 'Cached Peer',
            'user_id': 'u_cached_peer',
            'content': 'preloaded local message',
            'ts': 1717300000009,
          },
        ],
      );
      final services = await _testServices(
        transport: transport,
        useMock: false,
        chatroom: chatroom,
        chatroomMessages: messageStorage,
      );

      await tester.pumpWidget(
        AppServicesScope(
          services: services,
          child: const MaterialApp(home: WorldPage(wid: 'w_test_1')),
        ),
      );
      await tester.pumpAndSettle();

      expect(connectCompleter.isCompleted, false);
      expect(chatroom.session.joinCount, 0);
      expect(messageStorage.latestLocationIds, isNot(contains('point_child')));
      expect(_visibleText('preloaded local message'), findsNothing);

      await tester.tap(find.text('Location (2)'));
      await tester.pumpAndSettle();
      final childRow = find.ancestor(
        of: find.text('Child Location').last,
        matching: find.byType(InkWell),
      );
      await tester.tap(childRow.last);
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(messageStorage.latestLocationIds, contains('point_child'));
      expect(_visibleText('preloaded local message'), findsOneWidget);
      expect(chatroom.session.joinCount, 0);
    },
  );

  testWidgets('system back hides inline world location chat', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingV1ListTransport(worldRelationStatus: 'joined');
    final chatroom = _FakeChatroomClient();
    final observer = _RecordingNavigatorObserver();
    final services = await _testServices(
      transport: transport,
      useMock: false,
      chatroom: chatroom,
    );

    await tester.pumpWidget(
      AppServicesScope(
        services: services,
        child: MaterialApp(
          navigatorObservers: [observer],
          home: const WorldPage(wid: 'w_test_1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Location (2)'));
    await tester.pumpAndSettle();
    final childRow = find.ancestor(
      of: find.text('Child Location').last,
      matching: find.byType(InkWell),
    );
    await tester.tap(childRow.last);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(_visibleText('Child Location (1)'), findsOneWidget);
    expect(chatroom.session.joinCount, 1);

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(observer.popCount, 0);
    expect(find.byType(WorldPage), findsOneWidget);
    expect(_visibleText('Child Location (1)'), findsNothing);
    expect(chatroom.session.leaveCount, 1);
  });

  testWidgets(
    'location chat route connects and sends through chatroom client',
    (WidgetTester tester) async {
      final chatroom = _FakeChatroomClient();
      final services = await _testServices(
        chatroom: chatroom,
        initialUserInfo: const {
          'uid': 'u_mock',
          'avatar_url': 'assets/images/mock_avatars/avatar_jules.png',
        },
      );
      await tester.pumpWidget(GenesisApp(services: services));
      await tester.pumpAndSettle();

      Navigator.of(tester.element(find.byType(Scaffold).first)).pushNamed(
        RouteNames.locationChat,
        arguments: {
          'world_id': 'world-1',
          'world_name': 'World One',
          'location_id': 'castle',
          'location_name': 'Castle',
        },
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(chatroom.worldId, 'world-1');
      expect(chatroom.locationId, '');
      expect(chatroom.session.joinLocationId, 'castle');
      expect(chatroom.senderId, 'u_mock');
      expect(chatroom.senderName, 'u_mock');
      expect(find.text('Castle (1)'), findsOneWidget);
      expect(find.text('World One'), findsNothing);
      expect(find.text('Joined'), findsOneWidget);
      await tester.showKeyboard(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'hello castle');
      await tester.pump();
      final sendButton = find.descendant(
        of: find.byKey(const ValueKey('chat-composer-send-button')),
        matching: find.byType(TextButton),
      );
      for (var i = 0; i < 10; i++) {
        if (tester.widget<TextButton>(sendButton).onPressed != null) break;
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(tester.widget<TextButton>(sendButton).onPressed, isNotNull);
      chatroom.session.holdSendAcks = true;
      await tester.tap(sendButton);
      await tester.pump();

      expect(chatroom.session.sentMessages, ['hello castle']);
      final clientMsgId = chatroom.session.sentClientMsgIds.single;
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        '',
      );
      expect(tester.testTextInput.isVisible, isTrue);

      expect(find.text('hello castle'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName ==
                  'assets/images/mock_avatars/avatar_jules.png',
        ),
        findsOneWidget,
      );

      chatroom.session.emit(
        ChatroomUserMessage(
          sessionId: 'sess-1',
          worldId: 'world-1',
          locationId: 'castle',
          userId: 'U_J57GT5',
          code: 0,
          codeMsg: 'ok',
          ts: null,
          messageId: 42,
          conversationRoundId: 'round-1',
          roundOrder: 0,
          senderType: 'user',
          senderId: 'U_J57GT5',
          senderName: '号称句句',
          content: 'hello castle',
          broadcast: true,
          clientMsgId: clientMsgId,
          createdAt: null,
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('hello castle'), findsOneWidget);
    },
  );

  testWidgets('location chat merges pending send with matching user message', (
    WidgetTester tester,
  ) async {
    final chatroom = _FakeChatroomClient();
    final services = await _testServices(chatroom: chatroom);
    await tester.pumpWidget(GenesisApp(services: services));
    await tester.pumpAndSettle();

    Navigator.of(tester.element(find.byType(Scaffold).first)).pushNamed(
      RouteNames.locationChat,
      arguments: {
        'world_id': 'world-1',
        'world_name': 'World One',
        'location_id': 'castle',
        'location_name': 'Castle',
      },
    );
    await tester.pumpAndSettle();
    chatroom.session.holdSendAcks = true;

    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), '吃饭了吗');
    await tester.pump();
    final sendButton = find.descendant(
      of: find.byKey(const ValueKey('chat-composer-send-button')),
      matching: find.byType(TextButton),
    );
    expect(tester.widget<TextButton>(sendButton).onPressed, isNotNull);
    await tester.tap(sendButton);
    await tester.pump();

    final clientMsgId = chatroom.session.sentClientMsgIds.single;
    expect(find.text('吃饭了吗'), findsOneWidget);

    chatroom.session.emit(
      ChatroomUserMessage(
        sessionId: 'sess-1',
        worldId: 'world-1',
        locationId: 'castle',
        userId: 'U_J57GT5',
        code: 0,
        codeMsg: 'ok',
        ts: null,
        messageId: 126,
        conversationRoundId: '1317',
        roundOrder: 0,
        senderType: 'user',
        senderId: 'U_J57GT5',
        senderName: '号称句句',
        content: '吃饭了吗',
        broadcast: true,
        clientMsgId: clientMsgId,
        createdAt: null,
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('吃饭了吗'), findsOneWidget);
  });

  testWidgets(
    'location chat renders non-nar narrator push as character bubble',
    (WidgetTester tester) async {
      final chatroom = _FakeChatroomClient();
      final services = await _testServices(chatroom: chatroom);
      await tester.pumpWidget(GenesisApp(services: services));
      await tester.pumpAndSettle();

      Navigator.of(tester.element(find.byType(Scaffold).first)).pushNamed(
        RouteNames.locationChat,
        arguments: {
          'world_id': 'world-1',
          'world_name': 'World One',
          'location_id': 'castle',
          'location_name': 'Castle',
        },
      );
      await tester.pumpAndSettle();

      chatroom.session.emit(
        ChatroomNarratorMessage(
          sessionId: 'sess-1',
          worldId: 'world-1',
          locationId: 'castle',
          userId: '',
          code: 0,
          codeMsg: 'ok',
          ts: null,
          messageId: 155,
          conversationRoundId: '1349',
          roundOrder: 0,
          senderType: 'narrator',
          senderId: 'char-1',
          senderName: 'Alice',
          content: '角色旁白式发言',
          broadcast: true,
          createdAt: null,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('角色旁白式发言'), findsOneWidget);
      expect(find.byType(ChatAiBadge), findsNothing);
    },
  );

  test('location chat visible messages keep only latest consecutive tick', () {
    WorldChatroomMessage message(int id, String senderType) {
      return WorldChatroomMessage(
        messageId: id,
        conversationRoundId: '$id',
        roundOrder: 0,
        tickNo: senderType == 'tick' ? id : 0,
        locationId: 'loc-1',
        senderType: senderType,
        senderId: senderType == 'tick' ? 'tick' : 'u_peer',
        senderName: senderType == 'tick' ? 'Time' : 'Peer',
        content: 'message $id',
        createdAt: null,
      );
    }

    final visible = visibleLocationChatMessagesForTesting([
      message(1, 'user'),
      message(2, 'tick'),
      message(3, 'tick'),
      message(4, 'user'),
      message(5, 'tick'),
    ]);

    expect(visible.map((message) => message.messageId), [1, 3, 4, 5]);
  });

  testWidgets('location chat shows new message notice when not at bottom', (
    WidgetTester tester,
  ) async {
    final chatroom = _FakeChatroomClient();
    final services = await _testServices(chatroom: chatroom);
    await tester.pumpWidget(GenesisApp(services: services));
    await tester.pumpAndSettle();

    Navigator.of(tester.element(find.byType(Scaffold).first)).pushNamed(
      RouteNames.locationChat,
      arguments: {
        'world_id': 'world-1',
        'world_name': 'World One',
        'location_id': 'castle',
        'location_name': 'Castle',
      },
    );
    await tester.pumpAndSettle();

    for (var i = 1; i <= 60; i += 1) {
      chatroom.session.emit(
        ChatroomUserMessage(
          sessionId: 'sess-1',
          worldId: 'world-1',
          locationId: 'castle',
          userId: 'u_peer',
          code: 0,
          codeMsg: 'ok',
          ts: null,
          messageId: i,
          conversationRoundId: '$i',
          roundOrder: 0,
          senderType: 'user',
          senderId: 'u_peer',
          senderName: 'Peer',
          content: 'history message $i',
          broadcast: true,
          clientMsgId: '',
          createdAt: null,
        ),
      );
    }
    await tester.pumpAndSettle();

    final scrollable = find.descendant(
      of: find.byType(ListView),
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(scrollable).position;
    expect(position.pixels, 0);
    expect(position.maxScrollExtent, greaterThan(240));

    position.jumpTo(240);
    await tester.pump();
    final offsetBeforeNewMessage = position.pixels;

    chatroom.session.emit(
      ChatroomUserMessage(
        sessionId: 'sess-1',
        worldId: 'world-1',
        locationId: 'castle',
        userId: 'u_peer',
        code: 0,
        codeMsg: 'ok',
        ts: null,
        messageId: 61,
        conversationRoundId: '61',
        roundOrder: 0,
        senderType: 'user',
        senderId: 'u_peer',
        senderName: 'Peer',
        content: 'new while reading',
        broadcast: true,
        clientMsgId: '',
        createdAt: null,
      ),
    );
    await tester.pumpAndSettle();

    expect(position.pixels, offsetBeforeNewMessage);
    expect(find.text('1 条新消息'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('location-chat-new-message-notice')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('location-chat-new-message-notice')),
    );
    await tester.pump();

    expect(position.pixels, 0);
    expect(find.text('1 条新消息'), findsNothing);
  });

  testWidgets('location chat shows role name instead of pushed username', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingV1ListTransport(
      worldCharacters: const [
        {
          'type': 'player',
          'player_uid': 'u_other',
          'player_username': 'Actual Username',
          'char_id': 'c_other',
          'name': 'Role Persona',
          'identity': 'Visitor',
          'brief': 'Visits the world',
          'description': 'A player role.',
          'goal': 'Talk',
          'avatar': '',
          'location_id': 'l_world-1',
        },
      ],
    );
    final chatroom = _FakeChatroomClient();
    final services = await _testServices(
      transport: transport,
      useMock: false,
      chatroom: chatroom,
    );
    await tester.pumpWidget(GenesisApp(services: services));
    await tester.pumpAndSettle();

    Navigator.of(tester.element(find.byType(Scaffold).first)).pushNamed(
      RouteNames.locationChat,
      arguments: {
        'world_id': 'world-1',
        'location_id': 'l_world-1',
        'location_name': 'World Location',
      },
    );
    await tester.pump();
    await tester.pumpAndSettle();

    chatroom.session.emit(
      ChatroomUserMessage(
        sessionId: 'sess-1',
        worldId: 'world-1',
        locationId: 'l_world-1',
        userId: 'u_other',
        code: 0,
        codeMsg: 'ok',
        ts: null,
        messageId: 127,
        conversationRoundId: '1318',
        roundOrder: 0,
        senderType: 'user',
        senderId: 'u_other',
        senderName: 'Actual Username',
        content: 'role name check',
        broadcast: true,
        clientMsgId: '',
        createdAt: null,
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Role Persona'), findsOneWidget);
    expect(find.text('Actual Username'), findsNothing);
    expect(find.text('role name check'), findsOneWidget);
  });

  testWidgets('location chat does not join non-leaf locations', (
    WidgetTester tester,
  ) async {
    final chatroom = _FakeChatroomClient();
    final services = await _testServices(chatroom: chatroom);
    await tester.pumpWidget(GenesisApp(services: services));
    await tester.pumpAndSettle();

    Navigator.of(tester.element(find.byType(Scaffold).first)).pushNamed(
      RouteNames.locationChat,
      arguments: {
        'world_id': 'world-1',
        'world_name': 'World One',
        'location_id': 'district',
        'location_name': 'District',
        'is_leaf_location': false,
      },
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(chatroom.worldId, 'world-1');
    expect(chatroom.session.joinLocationId, isNull);
    final sendButton = find.descendant(
      of: find.byKey(const ValueKey('chat-composer-send-button')),
      matching: find.byType(TextButton),
    );
    expect(tester.widget<TextButton>(sendButton).onPressed, isNull);
  });

  testWidgets('location chat disables send during tick progress', (
    WidgetTester tester,
  ) async {
    final chatroom = _FakeChatroomClient();
    final services = await _testServices(chatroom: chatroom);
    await tester.pumpWidget(GenesisApp(services: services));
    await tester.pumpAndSettle();

    Navigator.of(tester.element(find.byType(Scaffold).first)).pushNamed(
      RouteNames.locationChat,
      arguments: {
        'world_id': 'world-1',
        'world_name': 'World One',
        'location_id': 'castle',
        'location_name': 'Castle',
      },
    );
    await tester.pump();
    await tester.pumpAndSettle();

    final sendButton = find.descendant(
      of: find.byKey(const ValueKey('chat-composer-send-button')),
      matching: find.byType(TextButton),
    );
    expect(tester.widget<TextButton>(sendButton).onPressed, isNotNull);

    chatroom.session.emit(
      ChatroomWorldNotification(
        worldId: 'world-1',
        locationId: 'castle',
        eventType: 'tick_start',
        title: '',
        summary: '',
        detailUrl: '',
        ts: null,
        broadcast: false,
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(tester.widget<TextButton>(sendButton).onPressed, isNull);

    chatroom.session.emit(
      ChatroomWorldNotification(
        worldId: 'world-1',
        locationId: 'castle',
        eventType: 'tick_done',
        title: '',
        summary: '',
        detailUrl: '',
        ts: null,
        broadcast: false,
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(tester.widget<TextButton>(sendButton).onPressed, isNotNull);
  });

  testWidgets('location chat input stays editable before connection', (
    WidgetTester tester,
  ) async {
    final services = await _testServices(chatroom: _FailingChatroomClient());
    await tester.pumpWidget(GenesisApp(services: services));
    await tester.pumpAndSettle();

    Navigator.of(tester.element(find.byType(Scaffold).first)).pushNamed(
      RouteNames.locationChat,
      arguments: {
        'world_id': 'world-1',
        'location_id': 'castle',
        'location_name': 'Castle',
      },
    );
    await tester.pump();
    await tester.pumpAndSettle();

    final input = find.byType(TextField);
    expect(tester.widget<TextField>(input).enabled, isTrue);
    await tester.enterText(input, 'draft before connect');
    await tester.pump();

    expect(find.text('draft before connect'), findsOneWidget);
    final sendButton = find.descendant(
      of: find.byKey(const ValueKey('chat-composer-send-button')),
      matching: find.byType(TextButton),
    );
    expect(tester.widget<TextButton>(sendButton).onPressed, isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });
}

Future<void> _dragOriginPanelUntilVisible(
  WidgetTester tester,
  Finder finder,
) async {
  for (var attempt = 0; attempt < 12; attempt += 1) {
    if (finder.evaluate().isNotEmpty) {
      final top = tester.getTopLeft(finder).dy;
      final bottom = tester.getBottomRight(finder).dy;
      if (top >= 100 && bottom <= 600) return;
      if (top < 100) {
        await tester.dragFrom(const Offset(400, 220), const Offset(0, 240));
        await tester.pumpAndSettle();
        continue;
      }
    }
    await tester.dragFrom(const Offset(400, 500), const Offset(0, -500));
    await tester.pumpAndSettle();
  }
  expect(finder, findsOneWidget);
}

Finder _richTextFinder(String text) {
  return find.byWidgetPredicate((widget) {
    return widget is Text && widget.textSpan?.toPlainText() == text;
  });
}

Finder _assetImageFinder(String path, {bool skipOffstage = true}) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is Image &&
        widget.image is AssetImage &&
        (widget.image as AssetImage).assetName == path,
    skipOffstage: skipOffstage,
  );
}

Finder _loginLegalTextFinder() {
  return _richTextFinder(
    'By continuing, you agree to our Terms, Privacy Policy, and EULA',
  );
}

TapGestureRecognizer _recognizerForText(InlineSpan span, String text) {
  TapGestureRecognizer? findRecognizer(InlineSpan child) {
    if (child is! TextSpan) return null;
    if (child.text == text) {
      return child.recognizer as TapGestureRecognizer?;
    }
    for (final nested in child.children ?? const <InlineSpan>[]) {
      final recognizer = findRecognizer(nested);
      if (recognizer != null) return recognizer;
    }
    return null;
  }

  final result = findRecognizer(span);
  if (result == null) {
    throw StateError('No tap recognizer found for "$text".');
  }
  return result;
}

Finder _visibleText(String text) {
  return find.byElementPredicate((element) {
    final widget = element.widget;
    final matchesText =
        widget is Text &&
        (widget.data == text || widget.textSpan?.toPlainText() == text);
    if (!matchesText) return false;

    var visible = true;
    element.visitAncestorElements((ancestor) {
      final ancestorWidget = ancestor.widget;
      if (ancestorWidget is Opacity && ancestorWidget.opacity == 0) {
        visible = false;
        return false;
      }
      return true;
    });
    return visible;
  });
}

class _RecordingNavigatorObserver extends NavigatorObserver {
  int pushCount = 0;
  int popCount = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushCount += 1;
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    popCount += 1;
    super.didPop(route, previousRoute);
  }
}

void _expectCharacterNameOrder(WidgetTester tester) {
  final self = _richTextFinder('Self Hero (Me)');
  final other = _richTextFinder('Other Hero (Other User)');
  final ai = _richTextFinder('AI Guide');
  expect(self, findsOneWidget);
  expect(other, findsOneWidget);
  expect(ai, findsOneWidget);
  expect(tester.getTopLeft(self).dy, lessThan(tester.getTopLeft(other).dy));
  expect(tester.getTopLeft(other).dy, lessThan(tester.getTopLeft(ai).dy));
}

class _RecordingProfileActionTransport implements HttpTransport {
  final requests = <TransportRequest>[];
  final Completer<TransportResponse> _followCompleter =
      Completer<TransportResponse>();

  List<TransportRequest> get followRequests {
    return requests
        .where(
          (request) =>
              request.method == 'POST' &&
              request.uri.path == '/api/v1/user/follow',
        )
        .toList(growable: false);
  }

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    requests.add(request);
    final path = request.uri.path;
    if (path == '/api/v1/user/info') {
      return _v1Response({
        'user': {
          'uid': 'u_peer',
          'name': 'Peer User',
          'avatar': '',
          'follower_cnt': 21,
          'following_cnt': 8,
        },
        'relation': {
          'is_self': false,
          'is_followed': false,
          'i_followed': false,
        },
      });
    }
    if (path == '/api/v1/origin/list' || path == '/api/v1/world/list') {
      return _v1Response({'list': const <Object?>[], 'total': 0});
    }
    if (path == '/api/v1/message/unread') {
      return _v1Response({
        'world_apply_unread': 0,
        'follow_unread': 0,
        'interaction_unread': 0,
        'direct_message_unread': 0,
        'total_unread': 0,
      });
    }
    if (request.method == 'POST' && path == '/api/v1/user/follow') {
      return _followCompleter.future;
    }
    return _v1Response(<String, Object?>{});
  }

  void completeFollow() {
    _followCompleter.complete(_v1Response(<String, Object?>{}));
  }

  Map<String, dynamic> decodedBody(TransportRequest request) {
    return jsonDecode(utf8.decode(request.bodyBytes ?? const <int>[]))
        as Map<String, dynamic>;
  }

  TransportResponse _v1Response(Object? data) {
    return TransportResponse(
      statusCode: 200,
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({'err_no': 0, 'err_msg': 'succ', 'data': data}),
    );
  }
}

class _RecordingFollowsTransport implements HttpTransport {
  _RecordingFollowsTransport({
    this.followingCompleter,
    this.followersCompleter,
  });

  final requests = <TransportRequest>[];
  final Completer<TransportResponse>? followingCompleter;
  final Completer<TransportResponse>? followersCompleter;
  final Completer<TransportResponse> _followCompleter =
      Completer<TransportResponse>();

  List<TransportRequest> requestsFor(String path) {
    return requests
        .where((request) => request.uri.path == path)
        .toList(growable: false);
  }

  List<TransportRequest> get followRequests {
    return requestsFor(
      '/api/v1/user/follow',
    ).where((request) => request.method == 'POST').toList(growable: false);
  }

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    requests.add(request);
    final path = request.uri.path;
    if (path == '/api/v1/user/following') {
      if (followingCompleter != null) return followingCompleter!.future;
      return _v1Response({
        'total': 24,
        'pn': 1,
        'rn': 50,
        'list': _followUsers(prefix: 'u_following', name: 'Following Friend'),
      });
    }
    if (path == '/api/v1/user/followers') {
      if (followersCompleter != null) return followersCompleter!.future;
      return _v1Response({
        'total': 24,
        'pn': 1,
        'rn': 50,
        'list': _followUsers(
          prefix: 'u_follower',
          name: 'Follower Friend',
          followed: false,
        ),
      });
    }
    if (request.method == 'POST' && path == '/api/v1/user/follow') {
      return _followCompleter.future;
    }
    if (request.method == 'POST' && path == '/api/v1/user/unfollow') {
      return _v1Response(<String, Object?>{});
    }
    return _v1Response(<String, Object?>{});
  }

  void completeFollow() {
    _followCompleter.complete(_v1Response(<String, Object?>{}));
  }

  List<Map<String, Object?>> _followUsers({
    required String prefix,
    required String name,
    bool followed = true,
  }) {
    return List<Map<String, Object?>>.generate(24, (index) {
      final seq = (index + 1).toString().padLeft(2, '0');
      final uid = '${prefix}_$seq';
      return {
        'user': {
          'uid': uid,
          'name': '$name $seq',
          'avatar': {
            'sm_url': 'https://cdn.example.com/$uid-sm.png',
            'xl_url': 'https://cdn.example.com/$uid-xl.png',
            'object_key': 'avatars/$uid.png',
          },
        },
        'relation': {'target_user_id': uid, 'i_followed': followed},
      };
    });
  }

  Map<String, dynamic> decodedBody(TransportRequest request) {
    return jsonDecode(utf8.decode(request.bodyBytes ?? const <int>[]))
        as Map<String, dynamic>;
  }

  TransportResponse _v1Response(Object? data) {
    return TransportResponse(
      statusCode: 200,
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({'err_no': 0, 'err_msg': 'succ', 'data': data}),
    );
  }
}

class _FailingChatroomClient implements ChatroomClient {
  @override
  Future<ChatroomSession> connect({
    required String worldId,
    String? locationId,
    String? userId,
    String? senderId,
    String? senderName,
    bool? autoHeartbeat,
  }) async {
    throw StateError('test connection failed');
  }

  @override
  Future<ChatroomSession> connectAndJoin({
    required String worldId,
    String? locationId,
    String? userId,
    String? senderId,
    String? senderName,
    bool? autoHeartbeat,
  }) async {
    throw StateError('test connection failed');
  }
}

class _RecordingChatroomMessageStorage extends MemoryChatroomMessageStorage {
  final latestLocationIds = <String>[];

  @override
  Future<List<Map<String, dynamic>>> loadLatestMessages({
    required String ownerUid,
    required String worldId,
    required String locationId,
    required int limit,
  }) async {
    latestLocationIds.add(locationId);
    return super.loadLatestMessages(
      ownerUid: ownerUid,
      worldId: worldId,
      locationId: locationId,
      limit: limit,
    );
  }
}

class _FakeChatroomClient implements ChatroomClient {
  _FakeChatroomClient({this.connectCompleter});

  final Completer<void>? connectCompleter;
  late final _FakeChatroomSession session;
  int connectCount = 0;
  String? worldId;
  String? locationId;
  String? userId;
  String? senderId;
  String? senderName;

  @override
  Future<ChatroomSession> connect({
    required String worldId,
    String? locationId,
    String? userId,
    String? senderId,
    String? senderName,
    bool? autoHeartbeat,
  }) async {
    connectCount += 1;
    final resolvedWorldId = worldId;
    this.worldId = resolvedWorldId;
    this.locationId = locationId ?? '';
    this.userId = userId;
    this.senderId = senderId;
    this.senderName = senderName;
    session = _FakeChatroomSession(
      worldId: resolvedWorldId,
      locationId: locationId ?? '',
      userId: userId ?? '',
      senderId: senderId ?? '',
      senderName: senderName ?? '',
    );
    if (connectCompleter != null) {
      await connectCompleter!.future;
    }
    return session;
  }

  @override
  Future<ChatroomSession> connectAndJoin({
    required String worldId,
    String? locationId,
    String? userId,
    String? senderId,
    String? senderName,
    bool? autoHeartbeat,
  }) async {
    final session = await connect(
      worldId: worldId,
      locationId: locationId,
      userId: userId,
      senderId: senderId,
      senderName: senderName,
      autoHeartbeat: autoHeartbeat,
    );
    await session.join();
    return session;
  }
}

class _FakeChatroomSession implements ChatroomSession {
  _FakeChatroomSession({
    required this.worldId,
    required this.locationId,
    required this.userId,
    required this.senderId,
    required this.senderName,
  });

  @override
  final String worldId;

  @override
  final String locationId;

  @override
  final String userId;

  @override
  final String senderId;

  @override
  final String senderName;

  final sentMessages = <String>[];
  final sentClientMsgIds = <String>[];
  final pendingSendAcks = <String, Completer<ChatroomAck>>{};
  String? joinLocationId;
  int joinCount = 0;
  int leaveCount = 0;
  int disconnectCount = 0;
  bool holdSendAcks = false;
  final _events = StreamController<ChatroomEvent>.broadcast();
  final _errors = StreamController<ChatroomErrorEvent>.broadcast();
  final _failures = StreamController<ChatroomFailureEvent>.broadcast();
  final _streams = StreamController<ChatroomAiMessageStream>.broadcast();

  @override
  ChatroomJoined? get joined => ChatroomJoined(
    sessionId: 'sess-1',
    worldId: worldId,
    locationId: joinLocationId ?? locationId,
    userId: 'u_mock',
    code: 0,
    codeMsg: 'ok',
    ts: null,
    onlineUsers: const [
      ChatroomOnlineUser(
        userId: 'u_mock',
        senderId: 'u_mock',
        senderName: 'Me',
      ),
    ],
  );

  @override
  Stream<ChatroomEvent> get events => _events.stream;

  @override
  Stream<ChatroomErrorEvent> get errors => _errors.stream;

  @override
  Stream<ChatroomFailureEvent> get failures => _failures.stream;

  @override
  Stream<ChatroomAiMessageStream> get streams => _streams.stream;

  void emit(ChatroomEvent event) {
    if (event is ChatroomUserMessage && event.clientMsgId.isNotEmpty) {
      pendingSendAcks
          .remove(event.clientMsgId)
          ?.complete(
            ChatroomAck(
              sessionId: event.sessionId,
              worldId: event.worldId,
              locationId: event.locationId,
              userId: event.userId,
              code: event.code,
              codeMsg: event.codeMsg,
              ts: event.ts,
              messageId: event.messageId,
              conversationRoundId: event.conversationRoundId,
              clientMsgId: event.clientMsgId,
            ),
          );
    }
    _events.add(event);
  }

  @override
  StreamSubscription<ChatroomEvent> listenMessages(
    ChatroomMessageHandlers handlers, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return events.listen(
      handlers.handle,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  Future<ChatroomJoined> join({String? locationId}) async {
    joinCount += 1;
    joinLocationId = locationId;
    final event = joined!;
    _events.add(event);
    return event;
  }

  @override
  Future<void> heartbeat() async {}

  @override
  Future<ChatroomAck> sendMessage(String text, {String? clientMsgId}) async {
    sentMessages.add(text);
    final resolvedClientMsgId = clientMsgId ?? 'client-1';
    sentClientMsgIds.add(resolvedClientMsgId);
    final ack = ChatroomAck(
      sessionId: 'sess-1',
      worldId: worldId,
      locationId: locationId,
      userId: 'u_mock',
      code: 0,
      codeMsg: 'ok',
      ts: null,
      messageId: 42,
      conversationRoundId: 'round-1',
      clientMsgId: resolvedClientMsgId,
    );
    if (holdSendAcks) {
      final completer = Completer<ChatroomAck>();
      pendingSendAcks[resolvedClientMsgId] = completer;
      return completer.future;
    }
    return ack;
  }

  @override
  ChatroomAiMessageStream? streamForMessage(int messageId) => null;

  @override
  Future<void> leave() async {
    leaveCount += 1;
  }

  @override
  Future<void> disconnect() async {
    disconnectCount += 1;
    await close();
  }

  @override
  Future<void> close() async {
    await _events.close();
    await _errors.close();
    await _failures.close();
    await _streams.close();
  }
}
