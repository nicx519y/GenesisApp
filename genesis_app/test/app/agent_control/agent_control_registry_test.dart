import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/agent_control/agent_control_models.dart';
import 'package:genesis_flutter_android/app/agent_control/agent_control_registry.dart';
import 'package:genesis_flutter_android/app/bootstrap/service_registry.dart';
import 'package:genesis_flutter_android/app/config/app_config.dart';
import 'package:genesis_flutter_android/platform/session/memory_user_session_store.dart';

void main() {
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
}
