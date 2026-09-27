import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/agent_control/agent_control_models.dart';
import 'package:genesis_flutter_android/app/agent_control/agent_control_registry.dart';
import 'package:genesis_flutter_android/app/agent_control/agent_control_server.dart';
import 'package:genesis_flutter_android/app/bootstrap/service_registry.dart';
import 'package:genesis_flutter_android/app/config/app_config.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_models.dart';
import 'package:genesis_flutter_android/platform/session/memory_user_session_store.dart';
import 'package:genesis_flutter_android/routers/app_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
  });
  tearDownAll(() {
    debugDefaultTargetPlatformOverride = null;
  });

  late MemoryUserSessionStore sessionStore;
  late AgentControlRegistry registry;
  late AgentControlContext context;

  setUp(() {
    sessionStore = MemoryUserSessionStore();
    registry = AgentControlRegistry();
    context = AgentControlContext(
      services: ServiceRegistry.build(
        config: const AppConfig(useMock: true),
        sessionStoreOverride: sessionStore,
      ),
    );
  });

  test('returns failure for unknown methods', () async {
    final response = await registry.execute(
      const AgentControlRequest(
        id: '1',
        method: 'missing.method',
        params: {},
        timeoutMs: 1000,
        dryRun: false,
      ),
      context,
    );

    expect(response.ok, false);
    expect(response.error?['code'], 'unknown_method');
  });

  test('returns app ping response', () async {
    final response = await registry.execute(
      const AgentControlRequest(
        id: '1',
        method: 'app.ping',
        params: {},
        timeoutMs: 1000,
        dryRun: false,
      ),
      context,
    );

    expect(response.ok, true);
    expect(response.result, {'message': 'pong'});
  });

  test('clears auth state', () async {
    await sessionStore.saveUid('user-123456');
    await sessionStore.saveAuthToken('token-123456');

    final response = await registry.execute(
      const AgentControlRequest(
        id: '1',
        method: 'auth.clear',
        params: {},
        timeoutMs: 1000,
        dryRun: false,
      ),
      context,
    );

    expect(response.ok, true);
    expect(await sessionStore.readUid(), isNull);
    expect(await sessionStore.readAuthToken(), isNull);
  });

  test('auth profile exposes only allowlisted account fields', () async {
    await sessionStore.saveUid('user-123456');
    await sessionStore.saveAuthToken('secret-bearer-token');
    await sessionStore.saveUserInfo({
      'nickname': 'Worldo Builder',
      'avatar_url': 'https://cdn.example/avatar.png',
      'auth_token': 'must-not-leak',
    });

    final response = await registry.execute(
      const AgentControlRequest(
        id: 'profile',
        method: 'auth.profile',
        params: {},
        timeoutMs: 1000,
        dryRun: false,
      ),
      context,
    );

    expect(response.ok, true);
    final result = response.result as Map<String, Object?>;
    expect(result['uid'], 'user-123456');
    expect(result['name'], 'Worldo Builder');
    expect(result['hasAuthToken'], true);
    expect(result.containsValue('secret-bearer-token'), false);
    expect(result.containsValue('must-not-leak'), false);
  });

  test('worldo capabilities advertise bounded bridge methods', () async {
    final response = await registry.execute(
      const AgentControlRequest(
        id: 'capabilities',
        method: 'worldo.capabilities',
        params: {},
        timeoutMs: 1000,
        dryRun: false,
      ),
      context,
    );

    expect(response.ok, true);
    final result = response.result as Map<String, Object?>;
    expect(result['protocolVersion'], 1);
    expect(result['methods'], contains('worldo.create'));
    expect(result['methods'], isNot(contains('http.request')));
  });

  test('worldo methods require the phone login session', () async {
    final response = await registry.execute(
      const AgentControlRequest(
        id: 'mine',
        method: 'worldo.list',
        params: {},
        timeoutMs: 1000,
        dryRun: false,
      ),
      context,
    );

    expect(response.ok, false);
    expect(response.error?['code'], 'login_required');
  });

  test('asset validation checks bytes against declared image type', () {
    expect(
      validateWorldoAssetForTesting(const [
        0x89,
        0x50,
        0x4e,
        0x47,
        0x0d,
        0x0a,
        0x1a,
        0x0a,
      ], 'image/png'),
      isNull,
    );
    expect(
      validateWorldoAssetForTesting(const [0xff, 0xd8, 0xff], 'image/png'),
      isNotNull,
    );
  });

  test('lists world locations by wid', () async {
    final response = await registry.execute(
      const AgentControlRequest(
        id: '1',
        method: 'world.locations',
        params: {'wid': 'w_mock_001'},
        timeoutMs: 1000,
        dryRun: false,
      ),
      context,
    );

    expect(response.ok, true);
    final result = response.result as Map<String, Object?>;
    expect(result['wid'], 'w_mock_001');
    expect(result['firstLeafLocationId'], isNotEmpty);
    final locations = result['locations'] as List;
    expect(
      locations,
      contains(
        isA<Map<String, Object?>>()
            .having((item) => item['locationId'], 'locationId', 'loc_hub')
            .having((item) => item['locationName'], 'locationName', isNotEmpty),
      ),
    );
  });

  test('validates allowed route in dry run navigation', () async {
    final response = await registry.execute(
      const AgentControlRequest(
        id: '1',
        method: 'app.navigate',
        params: {'route': '/search', 'q': 'alice'},
        timeoutMs: 1000,
        dryRun: true,
      ),
      context,
    );

    expect(response.ok, true);
    expect(response.result, {
      'route': '/search',
      'arguments': {'q': 'alice'},
      'dryRun': true,
    });
  });

  test('rejects disallowed routes', () async {
    final response = await registry.execute(
      const AgentControlRequest(
        id: '1',
        method: 'app.navigate',
        params: {'route': '/admin'},
        timeoutMs: 1000,
        dryRun: true,
      ),
      context,
    );

    expect(response.ok, false);
    expect(response.error?['code'], 'route_not_allowed');
  });

  test('returns location chat debug snapshot in disabled mode', () async {
    final response = await registry.execute(
      const AgentControlRequest(
        id: '1',
        method: 'debug.locationChat.snapshot',
        params: {},
        timeoutMs: 1000,
        dryRun: false,
      ),
      context,
    );

    expect(response.ok, true);
    final result = response.result as Map<String, Object?>;
    expect(result['available'], true);
    expect(result['enabled'], false);
    expect(result['events'], isEmpty);
  });

  test('reuses current location chat page for the same world and location', () {
    expect(
      agentControlShouldReuseLocationChatPageForTesting(
        currentRouteName: RouteNames.locationChat,
        currentRouteArguments: const {'wid': 'world-1', 'location_id': 'loc-1'},
        worldId: 'world-1',
        locationId: 'loc-1',
      ),
      true,
    );
  });

  test('does not reuse location chat page for a different location', () {
    expect(
      agentControlShouldReuseLocationChatPageForTesting(
        currentRouteName: RouteNames.locationChat,
        currentRouteArguments: const {'wid': 'world-1', 'location_id': 'loc-1'},
        worldId: 'world-1',
        locationId: 'loc-2',
      ),
      false,
    );
  });

  test('agent retries only transport and ack timeout receipt failures', () {
    expect(
      isRetriableAgentReceiptFailureForTesting(TimeoutException('receipt')),
      isTrue,
    );
    expect(
      isRetriableAgentReceiptFailureForTesting(
        const ChatroomProtocolException('chatroom is not connected'),
      ),
      isTrue,
    );
    expect(
      isRetriableAgentReceiptFailureForTesting(
        const ChatroomFailureEvent(code: 'ack_timeout', message: 'timeout'),
      ),
      isTrue,
    );
    expect(
      isRetriableAgentReceiptFailureForTesting(
        const ChatroomFailureEvent(
          code: 'send_message_send_failed',
          message: 'transport failed',
        ),
      ),
      isTrue,
    );
    expect(
      isRetriableAgentReceiptFailureForTesting(
        const ChatroomFailureEvent(
          code: '3001',
          message: 'business rejected',
          sourceType: 'ack',
          requestType: 'send_message',
        ),
      ),
      isFalse,
    );
  });
}
