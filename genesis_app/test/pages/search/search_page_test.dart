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
import 'package:genesis_flutter_android/pages/world/world_page_result.dart';
import 'package:genesis_flutter_android/platform/session/memory_user_session_store.dart';
import 'package:genesis_flutter_android/routers/app_router.dart';
import 'package:genesis_flutter_android/ui/components/genesis_avatar.dart';
import 'package:genesis_flutter_android/ui/components/genesis_list_image.dart';
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

  testWidgets('shows world stats as ticks, connects, characters, players', (
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

    final tick = find.text('101');
    final connect = find.text('201');
    final character = find.text('301');
    final player = find.text('401');
    expect(tick, findsOneWidget);
    expect(connect, findsOneWidget);
    expect(character, findsOneWidget);
    expect(player, findsOneWidget);

    final tickOffset = tester.getTopLeft(tick);
    final connectOffset = tester.getTopLeft(connect);
    final characterOffset = tester.getTopLeft(character);
    final playerOffset = tester.getTopLeft(player);

    expect(connectOffset.dx, greaterThan(tickOffset.dx));
    expect(characterOffset.dx, greaterThan(connectOffset.dx));
    expect(playerOffset.dx, greaterThan(characterOffset.dx));
    expect(connectOffset.dy, moreOrLessEquals(tickOffset.dy, epsilon: 1));
    expect(characterOffset.dy, moreOrLessEquals(tickOffset.dy, epsilon: 1));
    expect(playerOffset.dy, moreOrLessEquals(tickOffset.dy, epsilon: 1));
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

  testWidgets('shows deleted for deleted origin owner in search results', (
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

    expect(find.textContaining('Originator: deleted'), findsOneWidget);
    expect(find.textContaining('Originator: Eve'), findsNothing);
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

    await tester.tap(find.text('Worldos').first);
    await tester.pump();

    expect(editable.widget.focusNode.hasFocus, isFalse);
  });

  testWidgets('uses compact result item spacing for origins and users', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1400);
    addTearDown(tester.view.reset);

    final transport = _SearchPageTransport();
    await _pumpSearchPage(tester, transport);

    await tester.enterText(find.byType(TextField), 'ab');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    final originTile = find
        .ancestor(
          of: find.text('#Origin 1'),
          matching: find.byType(GestureDetector),
        )
        .first;
    final originImage = tester.widget<GenesisListImage>(
      find.descendant(of: originTile, matching: find.byType(GenesisListImage)),
    );
    expect(originImage.width, 52);
    expect(originImage.height, 52);

    final originSizedBoxes = tester
        .widgetList<SizedBox>(
          find.descendant(of: originTile, matching: find.byType(SizedBox)),
        )
        .toList();
    expect(
      originSizedBoxes.any((box) => box.width == 10),
      isTrue,
      reason: 'Origin image-to-text gap should match Me collection rows.',
    );
    expect(
      originSizedBoxes.any((box) => box.height == 5),
      isTrue,
      reason: 'Origin title-to-subtitle gap should match Me collection rows.',
    );
    expect(
      originSizedBoxes.any((box) => box.height == 8),
      isTrue,
      reason: 'Origin subtitle-to-stats gap should match Me collection rows.',
    );
    final originSubtitle = tester.widget<Text>(
      find.descendant(
        of: originTile,
        matching: find.textContaining('Latest Version'),
      ),
    );
    expect(originSubtitle.style?.height, 1.3);

    final userTile = find
        .ancestor(
          of: find.text('User 1'),
          matching: find.byType(GestureDetector),
        )
        .first;
    final userAvatar = tester.widget<GenesisAvatar>(
      find.descendant(of: userTile, matching: find.byType(GenesisAvatar)),
    );
    expect(userAvatar.size, 52);

    final userSizedBoxes = tester
        .widgetList<SizedBox>(
          find.descendant(of: userTile, matching: find.byType(SizedBox)),
        )
        .toList();
    expect(userSizedBoxes.any((box) => box.width == 10), isTrue);
    expect(userSizedBoxes.any((box) => box.height == 5), isTrue);
  });

  testWidgets('removes deleted world from search results after detail closes', (
    tester,
  ) async {
    final transport = _SearchPageTransport(singleWorldResult: true);
    await _pumpSearchPage(
      tester,
      transport,
      onGenerateRoute: (settings) {
        if (settings.name != RouteNames.world) return null;
        return MaterialPageRoute<WorldPageResult>(
          settings: settings,
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(
                  context,
                ).pop(const WorldPageResult.deleted(deletedWorldId: 'world_1')),
                child: const Text('Delete world'),
              ),
            ),
          ),
        );
      },
    );

    await tester.enterText(find.byType(TextField), 'ab');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(find.text('World 1'), findsOneWidget);
    await tester.tap(find.text('World 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete world'));
    await tester.pumpAndSettle();

    expect(find.text('World 1'), findsNothing);
    expect(find.text('No results.'), findsOneWidget);
  });
}

Future<void> _pumpSearchPage(
  WidgetTester tester,
  _SearchPageTransport transport, {
  RouteFactory? onGenerateRoute,
}) async {
  await tester.pumpWidget(
    AppServicesScope(
      services: await _servicesWithTransport(transport),
      child: MaterialApp(
        home: const SearchPage(),
        onGenerateRoute: onGenerateRoute,
      ),
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
    appVersionCheck: base.appVersionCheck,
    externalUrlOpener: base.externalUrlOpener,
  );
}

class _SearchPageTransport implements HttpTransport {
  _SearchPageTransport({this.singleWorldResult = false});

  final bool singleWorldResult;
  final List<TransportRequest> requests = <TransportRequest>[];

  List<TransportRequest> get searchRequests => requests
      .where((request) => request.uri.path.endsWith('/v1/search'))
      .toList(growable: false);

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    requests.add(request);
    if (request.uri.path.endsWith('/v1/search')) {
      if (singleWorldResult) {
        return _jsonResponse({
          'keyword': request.uri.queryParameters['keyword'] ?? '',
          'type': request.uri.queryParameters['type'] ?? '',
          'origins': _emptySection(),
          'worlds': {
            'list': [_item('world', 1)],
            'total': 1,
            'pn': 1,
            'rn': 20,
          },
          'users': _emptySection(),
        });
      }
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

Map<String, dynamic> _emptySection() {
  return const {'list': <Object?>[], 'total': 0, 'pn': 1, 'rn': 20};
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
        'owner_name': index == 1 ? 'Eve' : 'Owner $index',
        'owner_user': {'deleted': index == 1, 'name': 'Owner $index'},
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
      'stats': {
        'tick_cnt': 100 + index,
        'connect_cnt': 200 + index,
        'character_cnt': 300 + index,
        'player_cnt': 400 + index,
      },
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
