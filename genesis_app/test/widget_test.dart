import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:genesis_flutter_android/app/bootstrap/app_services_scope.dart';
import 'package:genesis_flutter_android/app/bootstrap/service_registry.dart';
import 'package:genesis_flutter_android/app/config/app_config.dart';
import 'package:genesis_flutter_android/app/config/platform_config.dart';
import 'package:genesis_flutter_android/icons/my_flutter_app_icons.dart';
import 'package:genesis_flutter_android/main.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_client.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_models.dart';
import 'package:genesis_flutter_android/pages/create/create_basics_page.dart';
import 'package:genesis_flutter_android/pages/create/create_characters_page.dart';
import 'package:genesis_flutter_android/pages/create/create_locations_page.dart';
import 'package:genesis_flutter_android/pages/create/create_origin_draft_store.dart';
import 'package:genesis_flutter_android/pages/create/create_origin_page.dart';
import 'package:genesis_flutter_android/pages/create/create_story_events_page.dart';
import 'package:genesis_flutter_android/network/genesis_api.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';
import 'package:genesis_flutter_android/components/search_bar.dart';
import 'package:genesis_flutter_android/pages/app_shell_page.dart';
import 'package:genesis_flutter_android/pages/chat/chat_page.dart';
import 'package:genesis_flutter_android/pages/home/home_page.dart';
import 'package:genesis_flutter_android/pages/me/follows_page.dart';
import 'package:genesis_flutter_android/pages/me/me_page.dart';
import 'package:genesis_flutter_android/pages/me/settings_page.dart';
import 'package:genesis_flutter_android/pages/me/user_info_page.dart';
import 'package:genesis_flutter_android/pages/messages/message_category_list_page.dart';
import 'package:genesis_flutter_android/pages/origin/origin_page.dart';
import 'package:genesis_flutter_android/pages/origin/origin_world_page.dart';
import 'package:genesis_flutter_android/platform/auth/auth_session.dart';
import 'package:genesis_flutter_android/platform/auth/backend_auth_coordinator.dart';
import 'package:genesis_flutter_android/platform/auth/identity_auth_service.dart';
import 'package:genesis_flutter_android/platform/device/device_id_service.dart';
import 'package:genesis_flutter_android/platform/session/memory_user_session_store.dart';
import 'package:genesis_flutter_android/routers/app_router.dart';

Future<AppServices> _testServices({
  bool backendAuthenticated = false,
  ChatroomClient? chatroom,
  HttpTransport? transport,
  bool? useMock,
  String? initialUid = 'u_mock',
}) async {
  const config = AppConfig(useMock: true);
  final platformConfig = DefaultPlatformConfig(appConfig: config);
  const deviceId = _FakeDeviceIdService();
  final sessionStore = MemoryUserSessionStore();
  if (initialUid != null) {
    await sessionStore.saveUid(initialUid);
  }
  const identityAuth = _FakeIdentityAuthService();
  final api = GenesisApi(
    useMock: useMock ?? config.useMock,
    transport: transport,
    platformConfig: platformConfig,
    deviceIdService: deviceId,
    sessionStore: sessionStore,
    identityAuthService: identityAuth,
  );
  final backendAuth = _FakeBackendAuthCoordinator(
    authenticated: backendAuthenticated,
    sessionStore: sessionStore,
  );
  return AppServices(
    config: config,
    platformConfig: platformConfig,
    deviceId: deviceId,
    sessionStore: sessionStore,
    identityAuth: identityAuth,
    backendAuth: backendAuth,
    api: api,
    chatroom:
        chatroom ??
        ChatroomClient(
          wsBaseUrl: config.chatroomWsBaseUrl,
          sessionStore: sessionStore,
        ),
  );
}

Future<void> _pumpGenesisApp(WidgetTester tester) async {
  await tester.pumpWidget(GenesisApp(services: await _testServices()));
}

class _FakeDeviceIdService implements DeviceIdService {
  const _FakeDeviceIdService();

  @override
  Future<String> getDeviceId() async => 'test-device-id';
}

class _FakeIdentityAuthService implements IdentityAuthService {
  const _FakeIdentityAuthService();

  @override
  IdentityProfile? currentProfile() => null;

  @override
  bool hasLocalIdentitySession() => false;

  @override
  Future<AuthSession?> refreshSilently() async => null;

  @override
  Future<AuthSession> signIn() {
    throw UnimplementedError(
      'Widget tests should not launch identity sign-in.',
    );
  }

  @override
  Future<void> signOutIdentity() async {}
}

class _FakeBackendAuthCoordinator implements BackendAuthCoordinator {
  const _FakeBackendAuthCoordinator({
    required bool authenticated,
    required MemoryUserSessionStore sessionStore,
  }) : _authenticated = authenticated,
       _sessionStore = sessionStore;

  final bool _authenticated;
  final MemoryUserSessionStore _sessionStore;

  @override
  Future<bool> hasAuthenticatedBackendSession({
    bool tryAutoRefresh = true,
  }) async {
    return _authenticated;
  }

  @override
  Future<Never> loginWithIdentity(AuthSession session) {
    throw UnimplementedError('Widget tests should not perform backend login.');
  }

  @override
  Future<void> signOut() async {
    await _sessionStore.clearUid();
  }
}

class _RecordingV1ListTransport implements HttpTransport {
  static const total = 100;

  _RecordingV1ListTransport({this.worldTickCompleter});

  final requests = <TransportRequest>[];
  final Completer<TransportResponse>? worldTickCompleter;

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    requests.add(request);
    if (request.uri.path.endsWith('/origin/detail')) {
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
      final wid =
          request.uri.queryParameters['world_id'] ??
          request.uri.queryParameters['wid'] ??
          '';
      return _jsonResponse({
        'err_no': 0,
        'err_str': 'success',
        'data': _worldDetail(wid),
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
    if (request.method == 'POST' &&
        request.uri.path.endsWith('/origin/launch')) {
      return _jsonResponse({
        'err_no': 0,
        'err_str': 'success',
        'data': {'wid': 'w_launched_from_origin'},
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
    if (request.uri.path.endsWith('/discuss/list')) {
      final bizId = request.uri.queryParameters['biz_id'] ?? '';
      return _jsonResponse({
        'err_no': 0,
        'err_str': 'success',
        'data': {
          'list': [
            {
              'comment': {
                'discuss_id': 'dis_$bizId',
                'biz_type': 1,
                'biz_id': bizId,
                'author': {'uid': 'u_discuss_$bizId', 'name': 'Shawn'},
                'content': 'Discuss preview for $bizId',
                'reply_cnt': 36,
                'created_at': '2026-02-09T00:00:00Z',
              },
              'latest_replies': const <Object?>[],
            },
          ],
          'top_total': 1,
          'total_all': 1,
          'pn': 1,
          'rn': 2,
        },
      });
    }

    final pn = int.tryParse(request.uri.queryParameters['pn'] ?? '') ?? 1;
    final rn = int.tryParse(request.uri.queryParameters['rn'] ?? '') ?? 20;
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
      'last_progress_summary': 'World progress summary $seq',
      'tags': ['world$seq', 'scene'],
      'tick_cnt': seq,
      'connect_cnt': seq + 1,
      'ai_character_cnt': 2,
      'player_cnt': 3,
      'location_cnt': 4,
    };
  }

  Map<String, Object?> _originDetail(String oid) {
    final fallback = oid.isEmpty ? 'o_test_1' : oid;
    return {
      'origin': {
        'oid': fallback,
        'status': 2,
        'version_num': 1,
        'name': 'Origin detail $fallback',
        'cover': '',
        'display_subtitle': 'Origin detail subtitle',
        'world_view': 'Origin detail world view',
        'world_setting': 'Origin detail setting',
        'created_uid': 'u_test',
        'created_user_name': 'Tester',
        'created_at': '2026-05-01T00:00:00Z',
        'updated_at': '2026-05-02T00:00:00Z',
        'tags': ['detail'],
        'copy_cnt': 7,
        'connect_cnt': 8,
        'discuss_cnt': 9,
        'character_cnt': 1,
        'location_cnt': 1,
      },
      'character_list': [
        {
          'character_id': 'c_$fallback',
          'name': 'Detail Character',
          'identity': 'Guide',
          'tagline': 'Knows the path',
          'description': 'A character from detail.',
          'avatar': '',
          'location_id': 'l_$fallback',
        },
      ],
      'metric': <String, Object?>{},
      'location_list': [
        {
          'location_id': 'l_$fallback',
          'name': 'Detail Location',
          'description': 'A location from detail.',
          'image': '',
          'x_percent': 30,
          'y_percent': 40,
        },
      ],
      'event_list': const [],
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
        'tags': ['world-detail'],
        'created_at': '2026-05-01T00:00:00Z',
        'created_uid': 'u_test',
        'created_user_name': 'Tester',
        'owner_uid': 'u_test',
        'owner_name': 'Tester',
        'updated_at': '2026-05-02T00:00:00Z',
        'last_progress_at': '2026-05-02T00:00:00Z',
        'last_progress_summary': 'World detail loaded.',
        'preview_images': <String>[],
        'started_at': '2026-05-01T00:00:00Z',
        'tick_duration_days': 30,
        'cover': '',
        'map_url': '',
        'status': 1,
      },
      'stats': {
        'tick_cnt': 3,
        'connect_cnt': 4,
        'character_cnt': 1,
        'player_cnt': 1,
        'location_cnt': 1,
      },
      'characters': [
        {
          'type': 'ai',
          'player_uid': '',
          'char_id': 'c_$fallback',
          'name': 'World Character',
          'identity': 'Guide',
          'brief': 'Knows the world',
          'description': 'A world character.',
          'goal': 'Guide the player.',
          'avatar': '',
          'initial_location_id': 'l_$fallback',
          'location_id': 'l_$fallback',
          'metric_value': 50,
        },
      ],
      'locations': [
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
          'tick_index': 1,
          'narrator': 'World detail loaded.',
          'created_at': '2026-05-02T00:00:00Z',
          'paragraphs': [
            {
              'location_id': 'l_$fallback',
              'timestamp': '2026-05-02T00:00:00Z',
              'text': 'The first test tick wakes the location.',
              'character_deltas': const <Map<String, Object?>>[],
            },
          ],
        },
        {
          'tick_index': 2,
          'narrator': 'World detail changed again.',
          'created_at': '2026-05-03T00:00:00Z',
          'paragraphs': [
            {
              'location_id': 'l_$fallback',
              'timestamp': '2026-05-03T00:00:00Z',
              'text': 'The second test tick moves the story forward.',
              'character_deltas': const <Map<String, Object?>>[],
            },
          ],
        },
      ],
    };
  }
}

class _RecordingMessageCategoryTransport implements HttpTransport {
  final requests = <TransportRequest>[];
  var commentRead = false;

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    requests.add(request);
    final path = request.uri.path;
    Object? data = <String, Object?>{};
    if (request.method == 'POST' &&
        path == '/api/v1/messages/notifications/read') {
      final body = decodedBody(request);
      if (body['category'] == 'comment') commentRead = true;
    } else if (request.method == 'GET' &&
        path == '/api/v1/messages/unread-summary') {
      data = {
        'system_unread': 1,
        'follower_unread': 1,
        'comment_unread': commentRead ? 0 : 1,
        'dm_unread': 0,
        'total_unread': commentRead ? 2 : 3,
      };
    } else if (request.method == 'GET' &&
        path == '/api/v1/messages/notifications') {
      data = {
        'list': [
          {
            'id': 99,
            'category': request.uri.queryParameters['category'],
            'message': 'Recorded category message',
            'is_read': true,
            'created_at': '2026-05-20T10:00:00Z',
          },
        ],
        'total': 1,
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
}

class _RecordingSearchTransport implements HttpTransport {
  final requests = <TransportRequest>[];

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    requests.add(request);
    final path = request.uri.path;
    Object? data = <String, Object?>{};
    if (path == '/api/v1/messages/unread-summary') {
      data = {
        'system_unread': 0,
        'follower_unread': 0,
        'comment_unread': 0,
        'dm_unread': 0,
        'total_unread': 0,
      };
    } else if (path == '/api/v1/origin/list') {
      data = {'list': const <Object?>[], 'total': 0};
    } else if (path == '/api/v1/search') {
      data = {
        'groups': [
          {
            'type': 'origin',
            'total': 1,
            'list': [
              {
                'type': 'origin',
                'entity_id': 'o_search_1',
                'short_code': 'O_SEARCH_1',
                'title': 'Search Origin',
                'subtitle': 'OID: O_SEARCH_1',
                'cover_image': '',
                'copy_cnt': 9,
                'connect_cnt': 12,
                'player_cnt': 8,
              },
            ],
          },
          {
            'type': 'world',
            'total': 1,
            'list': [
              {
                'type': 'world',
                'entity_id': 'w_search_1',
                'short_code': 'W_SEARCH_1',
                'title': 'Search World',
                'subtitle': 'WID: W_SEARCH_1',
                'cover_image': '',
                'tick_cnt': 6,
                'connect_cnt': 4,
                'player_cnt': 8,
                'member_cnt': 1,
              },
            ],
          },
          {
            'type': 'user',
            'total': 1,
            'list': [
              {
                'type': 'user',
                'entity_id': 'u_search_1',
                'short_code': 'U_SEARCH_1',
                'title': 'Search User',
                'subtitle': 'Bio',
                'cover_image': '',
              },
            ],
          },
        ],
        'pn': 1,
        'rn': 20,
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
        'origin': {
          'oid': 'o_created_1',
          'name': body['name'],
          'cover': body['cover'],
          'world_view': body['world_view'],
          'world_setting': body['world_setting'],
        },
        'character_list': const <Object?>[],
        'location_list': const <Object?>[],
        'event_list': const <Object?>[],
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

  testWidgets('Origin is default tab', (WidgetTester tester) async {
    await _pumpGenesisApp(tester);

    expect(find.text('Origin'), findsWidgets);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Create'), findsOneWidget);
    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('Me'), findsOneWidget);
  });

  testWidgets('tap header search bar opens search page', (
    WidgetTester tester,
  ) async {
    await _pumpGenesisApp(tester);

    await tester.tap(find.text('Search origins, worlds, users...').first);
    await tester.pumpAndSettle();

    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('No search history yet.'), findsOneWidget);
  });

  testWidgets('search bar placeholder stays single line with ellipsis', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 180,
            child: SearchBarPlaceholder(
              hintText: 'Search origins, worlds, users...',
            ),
          ),
        ),
      ),
    );

    final placeholder = tester.widget<Text>(
      find.text('Search origins, worlds, users...'),
    );
    expect(placeholder.maxLines, 1);
    expect(placeholder.overflow, TextOverflow.ellipsis);
    expect(placeholder.softWrap, isFalse);
  });

  testWidgets('search page shows tabs and no result state', (
    WidgetTester tester,
  ) async {
    await _pumpGenesisApp(tester);

    await tester.tap(find.text('Search origins, worlds, users...').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'zz');
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Origin'), findsOneWidget);
    expect(find.text('World'), findsOneWidget);
    expect(find.text('User'), findsOneWidget);
    expect(find.text('No results.'), findsOneWidget);
  });

  testWidgets('search page debounces v1 search request and renders groups', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingSearchTransport();
    await tester.pumpWidget(
      GenesisApp(
        services: await _testServices(transport: transport, useMock: false),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Search origins, worlds, users...').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'reborn');
    await tester.pump(const Duration(milliseconds: 1999));
    expect(transport.requestsFor('/api/v1/search'), isEmpty);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();

    final searchRequests = transport.requestsFor('/api/v1/search');
    expect(searchRequests, hasLength(1));
    expect(searchRequests.single.uri.queryParameters['query'], 'reborn');
    expect(searchRequests.single.uri.queryParameters['type'], 'all');
    expect(searchRequests.single.uri.queryParameters['pn'], '1');
    expect(searchRequests.single.uri.queryParameters['rn'], '20');
    expect(find.text('Origins'), findsOneWidget);
    expect(find.text('#Search Origin'), findsOneWidget);
    expect(find.text('Worlds'), findsOneWidget);
    expect(find.text('Search World'), findsOneWidget);
    expect(find.text('Users'), findsOneWidget);
    expect(find.text('Search User'), findsOneWidget);
  });

  testWidgets('search page renders local mock Chinese user results', (
    WidgetTester tester,
  ) async {
    await _pumpGenesisApp(tester);

    await tester.tap(find.text('Search origins, worlds, users...').first);
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

    await tester.tap(find.text('Search origins, worlds, users...').first);
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

    await tester.tap(find.text('Search origins, worlds, users...').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'st');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(find.byType(TextField), 'zz');
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.textContaining('#Steam Kingdom'), findsNothing);
    expect(find.text('No results.'), findsOneWidget);
  });

  testWidgets('tap Messages does not show login sheet', (
    WidgetTester tester,
  ) async {
    await _pumpGenesisApp(tester);

    await tester.tap(find.text('Messages'));
    await tester.pumpAndSettle();

    expect(find.text('登录后可使用该功能'), findsNothing);
    expect(find.text('Sign In With Google'), findsNothing);
  });

  testWidgets('messages tab shows action buttons and section title', (
    WidgetTester tester,
  ) async {
    await _pumpGenesisApp(tester);

    await tester.tap(find.text('Messages'));
    await tester.pumpAndSettle();

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('New followers'), findsOneWidget);
    expect(find.text('Comments'), findsOneWidget);
    expect(find.text('Direct messages'), findsOneWidget);
  });

  testWidgets('unread summary renders messages badges', (
    WidgetTester tester,
  ) async {
    await _pumpGenesisApp(tester);
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('bottom-nav-Messages-unread-badge')),
        matching: find.text('3'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Messages'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(
          const ValueKey('message-menu-/messages/notifications-unread-badge'),
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
        matching: find.text('0'),
      ),
      findsNothing,
    );
  });

  testWidgets('messages action button navigates to list page', (
    WidgetTester tester,
  ) async {
    await _pumpGenesisApp(tester);

    await tester.tap(find.text('Messages'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Notifications').first);
    await tester.pumpAndSettle();

    expect(find.text('Notifications'), findsWidgets);
    expect(
      find.text('Penny wants to join Steam Kingdom Live.'),
      findsOneWidget,
    );
  });

  testWidgets('message category pages request matching notification category', (
    WidgetTester tester,
  ) async {
    await _pumpGenesisApp(tester);

    await tester.tap(find.text('Messages'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('New followers').first);
    await tester.pumpAndSettle();

    expect(find.text('New followers'), findsWidgets);
    expect(find.text('Penny Hardaway started following you.'), findsOneWidget);

    Navigator.of(tester.element(find.byType(MessageCategoryListPage))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Comments').first);
    await tester.pumpAndSettle();

    expect(find.text('Comments'), findsWidgets);
    expect(
      find.text('Penny commented: "Love this world setting!"'),
      findsOneWidget,
    );
  });

  testWidgets('message category page marks category read before loading list', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingMessageCategoryTransport();
    final services = await _testServices(transport: transport, useMock: false);
    await tester.pumpWidget(
      MaterialApp(
        home: AppServicesScope(
          services: services,
          child: MessageCategoryListPage(
            title: 'Comments',
            category: 'comment',
            emptyText: 'No comments yet.',
            onNotificationsRead: () async {
              await services.api.v1.messages.unreadSummary();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final readRequest = transport.requests.firstWhere(
      (request) => request.uri.path == '/api/v1/messages/notifications/read',
    );
    final listRequest = transport.requests.firstWhere(
      (request) => request.uri.path == '/api/v1/messages/notifications',
    );
    final unreadRequest = transport.requests.firstWhere(
      (request) => request.uri.path == '/api/v1/messages/unread-summary',
    );

    expect(readRequest.method, 'POST');
    expect(transport.decodedBody(readRequest)['category'], 'comment');
    expect(unreadRequest.method, 'GET');
    expect(listRequest.method, 'GET');
    expect(listRequest.uri.queryParameters['category'], 'comment');
    expect(listRequest.uri.queryParameters['pn'], '1');
    expect(listRequest.uri.queryParameters['rn'], '20');
    expect(
      transport.requests.indexOf(readRequest),
      lessThan(transport.requests.indexOf(unreadRequest)),
    );
    expect(
      transport.requests.indexOf(unreadRequest),
      lessThan(transport.requests.indexOf(listRequest)),
    );
    expect(find.text('Recorded category message'), findsOneWidget);
  });

  testWidgets('tap Home switches to Home page', (WidgetTester tester) async {
    await _pumpGenesisApp(tester);

    expect(find.text('Origin'), findsNWidgets(2));

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('My World'), findsOneWidget);
    expect(find.text('Popular'), findsOneWidget);
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
    expect(originRequests.single.uri.queryParameters['scene'], 'foryou');
    expect(originRequests.single.uri.queryParameters['pn'], '1');
    expect(originRequests.single.uri.queryParameters['rn'], '20');
    expect(originRequests.single.uri.queryParameters.containsKey('tag'), false);

    await tester.tap(find.text('Destroyed'));
    await tester.pumpAndSettle();

    originRequests = transport.requestsFor('/api/v1/origin/list');
    expect(originRequests, hasLength(2));
    expect(originRequests.last.uri.queryParameters['scene'], 'destroyed');
    expect(originRequests.last.uri.queryParameters.containsKey('tag'), false);
  });

  testWidgets('Home My World tab requests v1 world list with uid on enter', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingV1ListTransport();
    await tester.pumpWidget(
      MaterialApp(
        home: AppServicesScope(
          services: await _testServices(transport: transport, useMock: false),
          child: const HomePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    var worldRequests = transport.requestsFor('/api/v1/world/list');
    expect(worldRequests, hasLength(1));
    expect(worldRequests.single.uri.queryParameters['uid'], 'u_mock');
    expect(worldRequests.single.uri.queryParameters['pn'], '1');
    expect(worldRequests.single.uri.queryParameters['rn'], '20');
    expect(
      worldRequests.single.uri.queryParameters.containsKey('scene'),
      false,
    );

    await tester.tap(find.text('Popular'));
    await tester.pumpAndSettle();

    final originRequests = transport.requestsFor('/api/v1/origin/list');
    expect(originRequests, hasLength(1));
    expect(originRequests.single.uri.queryParameters['pn'], '1');
    expect(originRequests.single.uri.queryParameters['rn'], '20');
    expect(find.text('#Origin 1'), findsWidgets);

    final discussRequests = transport.requestsFor('/api/v1/discuss/list');
    expect(discussRequests, isNotEmpty);
    expect(discussRequests.first.uri.queryParameters['biz_type'], '1');
    expect(discussRequests.first.uri.queryParameters['biz_id'], 'o_test_1');
    expect(discussRequests.first.uri.queryParameters['pn'], '1');
    expect(discussRequests.first.uri.queryParameters['rn'], '2');
    expect(find.text('Discuss preview for o_test_1'), findsOneWidget);
  });

  testWidgets('Home My World tab is empty without local uid', (
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
    expect(find.text('No data'), findsOneWidget);
  });

  testWidgets('Origin list item opens origin detail with current oid', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingV1ListTransport();
    await tester.pumpWidget(
      AppServicesScope(
        services: await _testServices(transport: transport, useMock: false),
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

    final previousDiscussRequestCount = transport
        .requestsFor('/api/v1/discuss/list')
        .length;
    await tester.dragFrom(const Offset(400, 510), const Offset(0, -420));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('View More >'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    final discussRequests = transport.requestsFor('/api/v1/discuss/list');
    expect(discussRequests.length, greaterThan(previousDiscussRequestCount));
    final detailDiscussRequest = discussRequests.last;
    expect(detailDiscussRequest.uri.queryParameters['biz_type'], '1');
    expect(detailDiscussRequest.uri.queryParameters['biz_id'], 'o_test_1');
    expect(detailDiscussRequest.uri.queryParameters['pn'], '1');
    expect(detailDiscussRequest.uri.queryParameters['rn'], '2');
    expect(find.widgetWithText(TextField, 'Write a post'), findsOneWidget);
    expect(find.text('Discuss preview for o_test_1'), findsOneWidget);
    expect(find.text('View More >'), findsOneWidget);

    final discussListCountBeforePost = discussRequests.length;
    await tester.tap(find.widgetWithText(TextField, 'Write a post'));
    await tester.pumpAndSettle();

    expect(find.text('New post'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Write a post').last,
      'A new discuss post',
    );
    await tester.pump();
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    final postRequests = transport.requestsFor('/api/v1/discuss/post');
    expect(postRequests, hasLength(1));
    final postBody = transport.decodedBody(postRequests.single);
    expect(postBody['biz_type'], 1);
    expect(postBody['biz_id'], 'o_test_1');
    expect(postBody['content'], 'A new discuss post');
    expect(postBody['images'], isEmpty);
    expect(find.text('New post'), findsNothing);
    expect(
      transport.requestsFor('/api/v1/discuss/list').length,
      greaterThan(discussListCountBeforePost),
    );
  });

  testWidgets('Origin detail launch bar launches a world', (
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

    expect(find.text('Launch'), findsOneWidget);
    await tester.tap(find.text('Launch'));
    await tester.pumpAndSettle();

    final launchRequests = transport.requestsFor('/api/v1/origin/launch');
    expect(launchRequests, hasLength(1));
    expect(transport.decodedBody(launchRequests.single)['oid'], 'o_test_1');
    final worldRequests = transport.requestsFor('/api/v1/world/detail');
    expect(worldRequests, isNotEmpty);
    expect(
      worldRequests.last.uri.queryParameters['world_id'],
      'w_launched_from_origin',
    );
  });

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

    await tester.tap(find.text('#World 1'));
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
    final collapsedSize = 0.2 - 10 / height;
    expect(sheet.minChildSize, closeTo(collapsedSize, 0.001));
    expect(sheet.initialChildSize, closeTo(collapsedSize, 0.001));

    await tester.tap(find.text('Owner: Tester'));
    await tester.pumpAndSettle();

    final userInfoRequests = transport.requestsFor('/api/v1/user/info');
    expect(userInfoRequests, hasLength(1));
    expect(userInfoRequests.single.uri.queryParameters['uid'], 'u_test');
    expect(find.text('User Info'), findsOneWidget);
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

    await tester.tap(find.text('#World 1'));
    await tester.pumpAndSettle();

    expect(find.text('World Location'), findsWidgets);
    expect(find.text('Child Location'), findsNothing);

    await tester.tap(find.text('Point (2)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('World Location').last);
    await tester.pumpAndSettle();

    expect(find.text('World detail w_test_1'), findsWidgets);
    expect(find.text('Child Location'), findsWidgets);
    expect(find.text('Point (2)'), findsOneWidget);
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

    await tester.tap(find.text('Point (2)'));
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

    await tester.tap(find.text('Point (2)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('World Location').last);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.subdirectory_arrow_left), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pumpAndSettle();

    expect(find.text('World detail w_test_1'), findsNothing);
    expect(find.text('#World 1'), findsOneWidget);
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

      await tester.tap(find.text('#World 1'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Progress'));
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
          services: await _testServices(transport: transport, useMock: false),
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

  testWidgets('tap Me shows login sheet when not logged in', (
    WidgetTester tester,
  ) async {
    await _pumpGenesisApp(tester);

    await tester.tap(find.text('Me'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in to continue'), findsOneWidget);
    expect(find.text('Sign In With Google'), findsOneWidget);
  });

  testWidgets('tap Create opens create origin page directly', (
    WidgetTester tester,
  ) async {
    await _pumpGenesisApp(tester);
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('Create Origin'), findsOneWidget);
    expect(find.text('Basics'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);
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
    expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);
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

    await tester.tap(find.text('Locations (Optional)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Locations'), findsWidgets);
    Navigator.of(tester.element(find.byType(Scaffold).first)).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Story Events (Optional)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Story Events'), findsWidgets);
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
  });

  testWidgets('create save reports missing local draft sections', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CreateOriginPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Please save Basics, Characters, Locations, Story Events before creating.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('create save posts v1 origin and clears local draft', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingCreateOriginTransport();
    await CreateOriginDraftStore.save(
      const CreateOriginDraft(
        basics: BasicsDraft(
          originName: 'Crystal City',
          worldView: 'A public world view.',
          worldLogic: 'Hidden rules.',
          coverImageUrl: 'https://example.com/cover.png',
        ),
        characters: <CharacterDraft>[
          CharacterDraft(name: 'Ari', identity: 'Guide', personality: 'Calm'),
        ],
        locations: <LocationDraft>[LocationDraft(name: 'Gate')],
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
        child: const MaterialApp(home: CreateOriginPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final requests = transport.requestsFor('/api/v1/origin/create');
    expect(requests, hasLength(1));
    final body = transport.decodedBody(requests.single);
    expect(body['name'], 'Crystal City');
    expect(body['cover'], 'https://example.com/cover.png');
    expect(body['character_list'], isA<List>());
    expect(body['location_list'], isA<List>());

    final draft = await CreateOriginDraftStore.load();
    expect(draft.hasAllSectionsSaved, isFalse);
    expect(
      find.text('Origin created successfully: o_created_1'),
      findsOneWidget,
    );
  });

  testWidgets('settings opens about us page', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsPage()));
    await tester.pumpAndSettle();

    expect(find.text('Location chat test'), findsOneWidget);
    expect(find.text('WebSocket test'), findsOneWidget);

    await tester.tap(find.text('About us'));
    await tester.pumpAndSettle();

    expect(find.text('About us'), findsWidgets);
    expect(
      find.text(
        'Thanks for using Genesis Beta. More about us will appear here.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('settings opens websocket test page', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('WebSocket test'));
    await tester.pumpAndSettle();

    expect(find.text('WebSocket test'), findsWidgets);
    expect(find.text('Status: Disconnected'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Send message'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Send message'), findsOneWidget);
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
    await tester.pumpWidget(
      MaterialApp(
        home: AppServicesScope(
          services: await _testServices(),
          child: const UserInfoPage(uid: 'u_mock_peer'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Penny Hardaway'), findsOneWidget);
    expect(find.text('16'), findsOneWidget);
    expect(find.text('Following'), findsOneWidget);
    expect(find.text('20'), findsOneWidget);
    expect(find.text('Followers'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('peer profile follows and opens messages', (
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

    expect(find.text('Unfollow'), findsOneWidget);
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

    expect(find.text('Messages'), findsWidgets);
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
    expect(find.text('Unfollow'), findsWidgets);
    final unfollowButtonSize = tester.getSize(
      find.byKey(const ValueKey('follows-action-u_following_01')),
    );
    expect(unfollowButtonSize, const Size(86, 28));

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
    expect(find.text('Unfollow'), findsOneWidget);
  });

  testWidgets('chat page reloads content when location changes in same slot', (
    WidgetTester tester,
  ) async {
    final transport = _RecordingChatTransport();
    await tester.pumpWidget(
      MaterialApp(
        home: AppServicesScope(
          services: await _testServices(transport: transport, useMock: false),
          child: const _ChatPageHost(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Castle message'), findsOneWidget);
    expect(find.text('Garden message'), findsNothing);

    tester.state<_ChatPageHostState>(find.byType(_ChatPageHost)).showGarden();
    await tester.pump();
    await tester.pump();

    expect(find.text('Castle message'), findsNothing);
    expect(find.text('Garden message'), findsOneWidget);
    expect(
      transport.messageRequests.map(
        (request) => request.uri.queryParameters['location_id'],
      ),
      containsAllInOrder(['castle', 'garden']),
    );
  });

  testWidgets(
    'location chat route connects and sends through chatroom client',
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
      await tester.pump();
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(chatroom.worldInstanceId, 'world-1');
      expect(chatroom.locationId, 'castle');
      expect(chatroom.senderId, 'u_mock');
      expect(chatroom.senderName, 'u_mock');
      expect(find.text('Castle (1)'), findsOneWidget);
      expect(find.text('World One'), findsOneWidget);
      expect(find.text('Me'), findsOneWidget);
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'hello castle');
      await tester.pump();
      final sendButton = find.ancestor(
        of: find.byIcon(MyFlutterApp.add2),
        matching: find.byType(IconButton),
      );
      for (var i = 0; i < 10; i++) {
        if (tester.widget<IconButton>(sendButton).onPressed != null) break;
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(tester.widget<IconButton>(sendButton).onPressed, isNotNull);
      await tester.tap(sendButton);
      await tester.pump();

      expect(chatroom.session.sentMessages, ['hello castle']);
      await tester.pumpAndSettle();

      expect(find.text('hello castle'), findsOneWidget);
    },
  );

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
    final sendButton = find.ancestor(
      of: find.byIcon(MyFlutterApp.add2),
      matching: find.byType(IconButton),
    );
    expect(tester.widget<IconButton>(sendButton).onPressed, isNull);
  });
}

class _ChatPageHost extends StatefulWidget {
  const _ChatPageHost();

  @override
  State<_ChatPageHost> createState() => _ChatPageHostState();
}

class _ChatPageHostState extends State<_ChatPageHost> {
  String _locationId = 'castle';

  void showGarden() {
    setState(() => _locationId = 'garden');
  }

  @override
  Widget build(BuildContext context) {
    return ChatPage(
      wid: 'world-1',
      pointId: 'point-1',
      sceneId: _locationId,
      locationName: _locationId,
    );
  }
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
    if (path == '/api/v1/messages/unread-summary') {
      return _v1Response({
        'system_unread': 0,
        'follower_unread': 0,
        'comment_unread': 0,
        'dm_unread': 0,
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
  final requests = <TransportRequest>[];
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
      return _v1Response({
        'total': 24,
        'pn': 1,
        'rn': 50,
        'list': _followUsers(prefix: 'u_following', name: 'Following Friend'),
      });
    }
    if (path == '/api/v1/user/followers') {
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
        'user': {'uid': uid, 'name': '$name $seq', 'avatar': ''},
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

class _RecordingChatTransport implements HttpTransport {
  final requests = <TransportRequest>[];

  List<TransportRequest> get messageRequests {
    return requests
        .where((request) => request.uri.path == '/api/points/point-1/messages')
        .toList(growable: false);
  }

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    requests.add(request);
    final locationId = request.uri.queryParameters['location_id'] ?? '';
    final text = locationId == 'garden' ? 'Garden message' : 'Castle message';
    return TransportResponse(
      statusCode: 200,
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({
        'messages': [
          {
            'id': 'msg-$locationId',
            'api_user_id': 'peer',
            'content': text,
            'created_at': '2026-05-26T00:00:00Z',
          },
        ],
      }),
    );
  }
}

class _FailingChatroomClient implements ChatroomClient {
  @override
  Future<ChatroomSession> connect({
    required String worldInstanceId,
    required String locationId,
    String? userId,
    required String senderId,
    required String senderName,
  }) async {
    throw StateError('test connection failed');
  }
}

class _FakeChatroomClient implements ChatroomClient {
  late final _FakeChatroomSession session;
  String? worldInstanceId;
  String? locationId;
  String? userId;
  String? senderId;
  String? senderName;

  @override
  Future<ChatroomSession> connect({
    required String worldInstanceId,
    required String locationId,
    String? userId,
    required String senderId,
    required String senderName,
  }) async {
    this.worldInstanceId = worldInstanceId;
    this.locationId = locationId;
    this.userId = userId;
    this.senderId = senderId;
    this.senderName = senderName;
    session = _FakeChatroomSession(
      worldInstanceId: worldInstanceId,
      locationId: locationId,
    );
    return session;
  }
}

class _FakeChatroomSession implements ChatroomSession {
  _FakeChatroomSession({
    required this.worldInstanceId,
    required this.locationId,
  });

  @override
  final String worldInstanceId;

  @override
  final String locationId;

  final sentMessages = <String>[];
  final _events = StreamController<ChatroomEvent>.broadcast();
  final _errors = StreamController<ChatroomErrorEvent>.broadcast();
  final _streams = StreamController<ChatroomAiMessageStream>.broadcast();

  @override
  ChatroomJoined? get joined => ChatroomJoined(
    sessionId: 'sess-1',
    worldInstanceId: worldInstanceId,
    locationId: locationId,
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
  Stream<ChatroomAiMessageStream> get streams => _streams.stream;

  @override
  Future<ChatroomAck> sendMessage(String text, {String? clientMsgId}) async {
    sentMessages.add(text);
    return ChatroomAck(
      sessionId: 'sess-1',
      messageId: 42,
      conversationRoundId: 'round-1',
      clientMsgId: clientMsgId ?? 'client-1',
      queuePosition: 0,
    );
  }

  @override
  ChatroomAiMessageStream? streamForMessage(int messageId) => null;

  @override
  Future<void> close() async {
    await _events.close();
    await _errors.close();
    await _streams.close();
  }
}
