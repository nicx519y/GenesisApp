import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:genesis_flutter_android/app/bootstrap/app_services_scope.dart';
import 'package:genesis_flutter_android/app/bootstrap/service_registry.dart';
import 'package:genesis_flutter_android/app/config/app_config.dart';
import 'package:genesis_flutter_android/app/config/platform_config.dart';
import 'package:genesis_flutter_android/app/version/app_version_check_service.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_client.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_message_storage.dart';
import 'package:genesis_flutter_android/network/direct_message_conversation_store.dart';
import 'package:genesis_flutter_android/network/direct_message_message_store.dart';
import 'package:genesis_flutter_android/network/genesis_api.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';
import 'package:genesis_flutter_android/network/models/user.dart';
import 'package:genesis_flutter_android/pages/edit/edit_origin_page.dart';
import 'package:genesis_flutter_android/pages/origin_editor/origin_pending_submission_coordinator.dart';
import 'package:genesis_flutter_android/platform/platform_services.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    OriginPendingSubmissionCoordinator.instance.resetForTesting();
  });

  tearDown(() {
    OriginPendingSubmissionCoordinator.instance.resetForTesting();
  });

  testWidgets(
    'edit loads V2 foredit and publishes its Opening without clearing absent fields',
    (tester) async {
      final transport = _EditOriginTransport();
      final services = await _editTestServices(transport);

      await tester.pumpWidget(
        AppServicesScope(
          services: services,
          child: const MaterialApp(home: EditOriginPage(originId: 'o_edit_v2')),
        ),
      );
      await _waitForRequest(tester, transport, '/api/v2/origin/foredit');
      await tester.pumpAndSettle();

      expect(transport.requestsFor('/api/v2/origin/foredit'), hasLength(1));
      expect(transport.requestsFor('/api/v1/origin/foredit'), isEmpty);
      expect(transport.requestsFor('/api/v1/origin/detail'), isEmpty);
      expect(find.text('Archive'), findsOneWidget);
      expect(find.text('Character dialogue : 1'), findsOneWidget);
      expect(find.text('Narrator : 1'), findsOneWidget);
      expect(find.text('Image : 1'), findsOneWidget);

      await tester.tap(find.text('Basics'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Edited V2 Origin');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, -360));
      await tester.pump();
      await tester.enterText(
        find.byType(TextField).last,
        'Keep the restored Opening.',
      );
      await tester.pump();
      final publishButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Publish'),
      );
      expect(publishButton.onPressed, isNotNull);
      publishButton.onPressed!();

      await _waitForRequest(tester, transport, '/api/v2/origin/update');
      await _waitForRequest(tester, transport, '/api/v1/origin/info');
      await tester.pump();

      expect(transport.requestsFor('/api/v1/origin/update'), isEmpty);
      final updateRequest = transport
          .requestsFor('/api/v2/origin/update')
          .single;
      final body = transport.decodedBody(updateRequest);
      expect(body['origin_id'], 'o_edit_v2');
      expect(body['origin_name'], 'Edited V2 Origin');
      expect(body['update_notes'], 'Keep the restored Opening.');
      expect(body['deleted_char_ids'], isEmpty);
      expect(body['deleted_location_ids'], isEmpty);
      expect(body, isNot(contains('setting')));
      expect(body, isNot(contains('events')));
      expect((body['characters'] as List).single, isNot(contains('bio')));
      expect(body['init_location_group'], {
        'location_id': 'loc_archive',
        'initial_dialogue': [
          {'char_id': 'nar', 'content': 'The archive opens.'},
          {'char_id': 'char_mira', 'content': 'Welcome.'},
          {'char_id': 'nar_pic', 'content': 'opening.webp'},
        ],
      });
    },
  );
}

Future<void> _waitForRequest(
  WidgetTester tester,
  _EditOriginTransport transport,
  String path,
) async {
  await tester.runAsync(() async {
    for (var attempt = 0; attempt < 100; attempt += 1) {
      if (transport.requestsFor(path).isNotEmpty) return;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  });
  await tester.pump();
}

Future<AppServices> _editTestServices(_EditOriginTransport transport) async {
  const config = AppConfig(useMock: false);
  final platformConfig = DefaultPlatformConfig(appConfig: config);
  const deviceId = _FakeDeviceIdService();
  final sessionStore = MemoryUserSessionStore();
  await sessionStore.saveUid('u_editor');
  await sessionStore.saveAuthToken('backend-token');
  const identityAuth = _FakeIdentityAuthService();
  final api = GenesisApi(
    useMock: false,
    transport: transport,
    platformConfig: platformConfig,
    deviceIdService: deviceId,
    sessionStore: sessionStore,
    identityAuthService: identityAuth,
    appHeaderProvider: () async => const <String, String>{},
  );
  return AppServices(
    config: config,
    platformConfig: platformConfig,
    deviceId: deviceId,
    sessionStore: sessionStore,
    identityAuth: identityAuth,
    backendAuth: const _AuthenticatedBackendAuthCoordinator(),
    api: api,
    chatroom: ChatroomClient(
      wsBaseUrl: config.chatroomWsBaseUrl,
      sessionStore: sessionStore,
    ),
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
    appVersionCheck: const _NoUpgradeVersionCheckService(),
    externalUrlOpener: const _FakeExternalUrlOpener(),
  );
}

class _EditOriginTransport implements HttpTransport {
  final requests = <TransportRequest>[];

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    requests.add(request);
    Object data = const <String, Object?>{};
    if (request.method == 'GET' &&
        request.uri.path == '/api/v2/origin/foredit') {
      data = {
        'info': {
          'origin_id': 'o_edit_v2',
          'origin_name': 'Editable Origin',
          'origin_version': '2',
          'definition_version': 2,
          'brief': 'A public brief.',
          'metric': const <String, Object?>{},
          'cover': const <String, Object?>{
            'sm_url': 'assets/images/map_default/root_default.webp',
            'xl_url': 'assets/images/map_default/root_default.webp',
            'object_key': '',
          },
        },
        'stats': const <String, Object?>{},
        'init_location_group': const <String, Object?>{
          'location_id': 'loc_archive',
          'initial_dialogue': [
            {'char_id': 'nar', 'content': 'The archive opens.'},
            {'char_id': 'char_mira', 'content': 'Welcome.'},
            {'char_id': 'nar_pic', 'content': 'opening.webp'},
          ],
        },
        'characters': [
          {
            'char_id': 'char_mira',
            'name': 'Mira',
            'identity': 'Archivist',
            'brief': 'Patient',
            'initial_location_id': 'loc_archive',
            'location_id': 'loc_archive',
          },
        ],
        'locations': [
          {
            'location_id': 'loc_archive',
            'level': 3,
            'location_name': 'Archive',
            'location_description': 'A quiet tower.',
          },
        ],
        'ticks': const <Object?>[],
      };
    } else if (request.method == 'POST' &&
        request.uri.path == '/api/v2/origin/update') {
      data = {
        'origin_id': 'o_edit_v2',
        'origin_version': '3',
        'origin_version_time': 1780000000,
        'origin_name': 'Edited V2 Origin',
      };
    } else if (request.method == 'GET' &&
        request.uri.path == '/api/v1/origin/info') {
      data = {
        'info': const {
          'origin_id': 'o_edit_v2',
          'origin_name': 'Edited V2 Origin',
          'status': 10,
        },
        'stats': const <String, Object?>{},
      };
    }
    return TransportResponse(
      statusCode: 200,
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({'err_no': 0, 'err_msg': 'succ', 'data': data}),
    );
  }

  List<TransportRequest> requestsFor(String path) {
    return requests.where((request) => request.uri.path == path).toList();
  }

  Map<String, dynamic> decodedBody(TransportRequest request) {
    return jsonDecode(utf8.decode(request.bodyBytes ?? const <int>[]))
        as Map<String, dynamic>;
  }
}

class _NoUpgradeVersionCheckService implements AppVersionCheckService {
  const _NoUpgradeVersionCheckService();

  @override
  Future<AppVersionCheckResult> check() async {
    return const AppVersionCheckResult.noUpgrade();
  }
}

class _FakeDeviceIdService implements DeviceIdService {
  const _FakeDeviceIdService();

  @override
  Future<String> getDeviceId() async => 'test-device-id';
}

class _FakeIdentityAuthService implements IdentityAuthService {
  const _FakeIdentityAuthService();

  @override
  Future<AuthSession?> refreshSilently() async => null;

  @override
  Future<AuthSession> signIn(IdentityProvider provider) {
    throw UnsupportedError('Identity sign-in is not used in this test.');
  }

  @override
  Future<void> signOutIdentity() async {}
}

class _AuthenticatedBackendAuthCoordinator implements BackendAuthCoordinator {
  const _AuthenticatedBackendAuthCoordinator();

  @override
  Future<void> deleteAccount() async {}

  @override
  Future<bool> hasAuthenticatedBackendSession({
    bool tryAutoRefresh = true,
  }) async {
    return true;
  }

  @override
  Future<User> loginWithIdentity(AuthSession session) {
    throw UnsupportedError('Backend login is not used in this test.');
  }

  @override
  Future<void> signOut() async {}
}

class _FakeExternalUrlOpener implements ExternalUrlOpener {
  const _FakeExternalUrlOpener();

  @override
  Future<bool> open(String url) async => true;
}
