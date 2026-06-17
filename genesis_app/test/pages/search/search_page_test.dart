import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/bootstrap/app_services_scope.dart';
import 'package:genesis_flutter_android/app/bootstrap/service_registry.dart';
import 'package:genesis_flutter_android/app/config/app_config.dart';
import 'package:genesis_flutter_android/network/api_client.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_message_storage.dart';
import 'package:genesis_flutter_android/network/direct_message_conversation_store.dart';
import 'package:genesis_flutter_android/network/direct_message_message_store.dart';
import 'package:genesis_flutter_android/network/genesis_api.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';
import 'package:genesis_flutter_android/pages/search/search_page.dart';
import 'package:genesis_flutter_android/platform/session/memory_user_session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('does not request search before two letters or chinese chars', (
    tester,
  ) async {
    final transport = _SearchPageTransport();
    await _pumpSearchPage(tester, transport);

    await tester.enterText(find.byType(TextField), 'a');
    await tester.pump(const Duration(milliseconds: 700));

    expect(transport.searchRequests, isEmpty);

    await tester.enterText(find.byType(TextField), '1你');
    await tester.pump(const Duration(milliseconds: 700));

    expect(transport.searchRequests, isEmpty);

    await tester.enterText(find.byType(TextField), 'ab');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();

    expect(transport.searchRequests, hasLength(1));
    expect(
      transport.searchRequests.single.uri.queryParameters['keyword'],
      'ab',
    );
  });

  testWidgets('limits all sections to three results and opens more tab', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1800);
    addTearDown(tester.view.reset);

    final transport = _SearchPageTransport();
    await _pumpSearchPage(tester, transport);

    await tester.enterText(find.byType(TextField), 'ab');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(find.text('#Origin 1'), findsOneWidget);
    expect(find.text('#Origin 3'), findsOneWidget);
    expect(find.text('#Origin 4'), findsNothing);
    expect(find.text('More >'), findsNWidgets(3));

    await tester.tap(find.text('More >').first);
    await tester.pumpAndSettle();

    expect(transport.searchRequests, hasLength(2));
    expect(transport.searchRequests.last.uri.queryParameters['type'], 'origin');
    expect(find.text('#Origin 4'), findsOneWidget);
  });

  testWidgets('shows origin latest version from prefixed string fields', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1200);
    addTearDown(tester.view.reset);

    final transport = _SearchPageTransport();
    await _pumpSearchPage(tester, transport);

    await tester.enterText(find.byType(TextField), 'ab');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(find.textContaining('Latest Version: V1'), findsOneWidget);
    expect(find.textContaining('Latest Version: -'), findsNothing);
  });

  testWidgets('dismisses search focus when tapping result area', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1200);
    addTearDown(tester.view.reset);

    final transport = _SearchPageTransport();
    await _pumpSearchPage(tester, transport);

    await tester.enterText(find.byType(TextField), 'ab');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    final editable = tester.state<EditableTextState>(find.byType(EditableText));
    expect(editable.widget.focusNode.hasFocus, isTrue);

    await tester.tap(find.text('Origins').first);
    await tester.pump();

    expect(editable.widget.focusNode.hasFocus, isFalse);
  });
}

Future<void> _pumpSearchPage(
  WidgetTester tester,
  _SearchPageTransport transport,
) async {
  await tester.pumpWidget(
    AppServicesScope(
      services: await _servicesWithTransport(transport),
      child: const MaterialApp(home: SearchPage()),
    ),
  );
  await tester.pump();
}

Future<AppServices> _servicesWithTransport(
  _SearchPageTransport transport,
) async {
  final base = ServiceRegistry.build(config: const AppConfig(useMock: true));
  final apiClient = ApiClient(
    baseUrl: 'http://localhost:8080/api/',
    defaultHeaders: const {
      'content-type': 'application/json',
      'accept': 'application/json',
    },
    transport: transport,
  );
  final healthClient = ApiClient(
    baseUrl: 'http://localhost:8080/',
    defaultHeaders: const {'accept': 'application/json'},
    transport: transport,
  );
  final sessionStore = MemoryUserSessionStore();
  await sessionStore.saveUid('u_test');
  await sessionStore.saveAuthToken('test-token');
  final api = GenesisApi(
    apiClient: apiClient,
    healthClient: healthClient,
    sessionStore: sessionStore,
  );
  return AppServices(
    config: base.config,
    platformConfig: base.platformConfig,
    deviceId: base.deviceId,
    sessionStore: sessionStore,
    identityAuth: base.identityAuth,
    backendAuth: base.backendAuth,
    api: api,
    chatroom: base.chatroom,
    chatroomMessages: MemoryChatroomMessageStorage(),
    directMessageConversations: DirectMessageConversationStore(
      api: api,
      sessionStore: sessionStore,
      storage: MemoryDirectMessageConversationStorage(),
    ),
    directMessageMessages: DirectMessageMessageStore(
      api: api,
      sessionStore: sessionStore,
      storage: MemoryDirectMessageMessageStorage(),
    ),
  );
}

class _SearchPageTransport implements HttpTransport {
  final List<TransportRequest> requests = <TransportRequest>[];

  List<TransportRequest> get searchRequests => requests
      .where((request) => request.uri.path.endsWith('/v1/search'))
      .toList(growable: false);

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    requests.add(request);
    if (request.uri.path.endsWith('/v1/search')) {
      return _jsonResponse({
        'keyword': request.uri.queryParameters['keyword'] ?? '',
        'type': request.uri.queryParameters['type'] ?? '',
        'origins': _section('origin', request.uri.queryParameters['type']),
        'worlds': _section('world', request.uri.queryParameters['type']),
        'users': _section('user', request.uri.queryParameters['type']),
      });
    }
    return _jsonResponse(const <String, dynamic>{});
  }
}

Map<String, dynamic> _section(String type, String? requestedType) {
  if (requestedType != null &&
      requestedType.isNotEmpty &&
      requestedType != type) {
    return const {'list': <Object?>[], 'total': 0, 'pn': 1, 'rn': 20};
  }
  return {
    'list': [for (var index = 1; index <= 4; index += 1) _item(type, index)],
    'total': 4,
    'pn': 1,
    'rn': 20,
  };
}

Map<String, dynamic> _item(String type, int index) {
  return switch (type) {
    'origin' => {
      'info': {
        'origin_id': 'origin_$index',
        'origin_name': 'Origin $index',
        'origin_version': '-',
        'latestVersion': {'versionNum': index},
        'origin_version_time': 1777680000 + index,
        'cover': '',
      },
      'stats': {
        'copy_cnt': index,
        'connect_cnt': index,
        'character_cnt': index,
      },
    },
    'world' => {
      'info': {
        'world_id': 'world_$index',
        'world_name': 'World $index',
        'cover': '',
      },
      'stats': {'tick_cnt': index, 'connect_cnt': index, 'player_cnt': index},
    },
    _ => {
      'user': {
        'uid': 'user_$index',
        'name': 'User $index',
        'bio': 'Bio $index',
        'avatar': '',
      },
      'relation': const <String, dynamic>{},
    },
  };
}

TransportResponse _jsonResponse(Map<String, dynamic> data) {
  return TransportResponse(
    statusCode: 200,
    headers: const {'content-type': 'application/json'},
    body: jsonEncode({'err_no': 0, 'err_msg': 'succ', 'data': data}),
  );
}
