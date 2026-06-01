import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/bootstrap/app_services_scope.dart';
import 'package:genesis_flutter_android/app/bootstrap/service_registry.dart';
import 'package:genesis_flutter_android/app/config/app_config.dart';
import 'package:genesis_flutter_android/network/api_client.dart';
import 'package:genesis_flutter_android/network/genesis_api.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';
import 'package:genesis_flutter_android/pages/discuss/discuss_page.dart';
import 'package:genesis_flutter_android/platform/session/memory_user_session_store.dart';

void main() {
  testWidgets('loads more discuss items on scroll without View More', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 760);
    addTearDown(tester.view.reset);

    final transport = _DiscussPageTransport();
    await tester.pumpWidget(
      AppServicesScope(
        services: _servicesWithTransport(transport),
        child: const MaterialApp(home: DiscussPage(oid: 'o_auto')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('View More >'), findsNothing);
    expect(find.text('Discuss item 1'), findsOneWidget);
    expect(find.text('Discuss item 20'), findsOneWidget);
    expect(
      transport.discussRequests.map((request) => request.uri.queryParameters),
      contains(
        allOf(
          containsPair('pn', '1'),
          containsPair('rn', '20'),
          containsPair('biz_id', 'o_auto'),
        ),
      ),
    );

    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pumpAndSettle();

    expect(find.text('View More >'), findsNothing);
    expect(find.text('Discuss item 21'), findsOneWidget);
    expect(
      transport.discussRequests.map((request) => request.uri.queryParameters),
      contains(
        allOf(
          containsPair('pn', '2'),
          containsPair('rn', '20'),
          containsPair('biz_id', 'o_auto'),
        ),
      ),
    );
  });
}

AppServices _servicesWithTransport(_DiscussPageTransport transport) {
  final base = ServiceRegistry.build(config: const AppConfig(useMock: true));
  final apiClient = ApiClient(
    baseUrl: 'http://localhost:8080/api/',
    defaultHeaders: const {
      'content-type': 'application/json',
      'accept': 'application/json',
    },
    transport: transport,
    responseProcessor: (response) =>
        ApiClient.defaultResponseProcessor(response),
  );
  final healthClient = ApiClient(
    baseUrl: 'http://localhost:8080/',
    defaultHeaders: const {'accept': 'application/json'},
    transport: transport,
    responseProcessor: (response) =>
        ApiClient.defaultResponseProcessor(response),
  );
  final sessionStore = MemoryUserSessionStore();
  return AppServices(
    config: base.config,
    platformConfig: base.platformConfig,
    deviceId: base.deviceId,
    sessionStore: sessionStore,
    identityAuth: base.identityAuth,
    backendAuth: base.backendAuth,
    api: GenesisApi(
      apiClient: apiClient,
      healthClient: healthClient,
      sessionStore: sessionStore,
    ),
    chatroom: base.chatroom,
    directMessageConversations: base.directMessageConversations,
    directMessageMessages: base.directMessageMessages,
  );
}

class _DiscussPageTransport implements HttpTransport {
  final List<TransportRequest> requests = <TransportRequest>[];

  List<TransportRequest> get discussRequests => requests
      .where((request) => request.uri.path.endsWith('/discuss/list'))
      .toList(growable: false);

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    requests.add(request);
    if (request.uri.path.endsWith('/origin/detail')) {
      return _jsonResponse({
        'err_no': 0,
        'err_msg': 'succ',
        'data': {
          'info': {
            'origin_id': 'o_auto',
            'origin_name': 'Auto Load Origin',
            'cover': '',
            'map_url': '',
            'world_setting': 'A test origin for discuss page paging.',
            'world_view': 'A test origin for discuss page paging.',
            'owner_name': 'Tester',
            'origin_version': 1,
            'updated_at': '2026-02-09T00:00:00Z',
            'tags': <String>[],
          },
          'stats': {'discuss_cnt': 40},
          'characters': <Object?>[],
          'locations': <Object?>[],
        },
      });
    }
    if (request.uri.path.endsWith('/discuss/list')) {
      final bizId = request.uri.queryParameters['biz_id'] ?? 'o_auto';
      final page = int.tryParse(request.uri.queryParameters['pn'] ?? '') ?? 1;
      final rn = int.tryParse(request.uri.queryParameters['rn'] ?? '') ?? 20;
      final start = (page - 1) * rn;
      final end = (start + rn).clamp(0, 40);
      return _jsonResponse({
        'err_no': 0,
        'err_msg': 'succ',
        'data': {
          'list': [
            for (var index = start; index < end; index += 1)
              {
                'comment': {
                  'discuss_id': 'dis_${index + 1}',
                  'biz_type': 1,
                  'biz_id': bizId,
                  'world_id': 'w_auto',
                  'author': {
                    'uid': 'u_${index + 1}',
                    'name': 'User ${index + 1}',
                  },
                  'content': 'Discuss item ${index + 1}',
                  'reply_cnt': index,
                  'like_cnt': index,
                  'is_liked': false,
                  'created_at': '2026-02-09T00:00:00Z',
                },
                'latest_replies': <Object?>[],
              },
          ],
          'top_total': 40,
          'total_all': 40,
          'pn': page,
          'rn': rn,
        },
      });
    }
    return _jsonResponse({
      'err_no': 0,
      'err_msg': 'succ',
      'data': <String, dynamic>{},
    });
  }
}

TransportResponse _jsonResponse(Map<String, dynamic> body) {
  return TransportResponse(
    statusCode: 200,
    headers: const {'content-type': 'application/json'},
    body: jsonEncode(body),
  );
}
