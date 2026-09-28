import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../bootstrap/service_registry.dart';
import '../../network/local_mock_genesis_transport.dart';
import '../../platform/session/user_session_store.dart';
import 'fixtures/personalization/fixture.dart';

Map<String, Future<Object?> Function(Map<String, dynamic>, bool)>
createQaEnvironmentOperations(AppServices services, {required bool enabled}) {
  if (!enabled ||
      !kDebugMode ||
      appFlavor != 'internal' ||
      !const bool.fromEnvironment('GENESIS_QA_BRIDGE')) {
    return {};
  }
  final transport = LocalMockGenesisTransport.instance;
  final fixture = PersonalizationFixture(
    identity: services.sessionStore.readLoginUid,
    owner: () async => transport.personalizationOwner(
      await services.deviceId.getDeviceId(),
      authenticated: await services.sessionStore.readLoginUid() != null,
    ),
    snapshot: transport.personalizationSnapshot,
    write: transport.restorePersonalizationSnapshot,
    observed: () {
      final state = services.personalization.state.value;
      return {
        'loaded': state.data != null,
        'completed': state.data?.profile.completed,
        'gender': state.data?.profile.gender,
        'age': state.data?.profile.age,
        'presenting': services.personalization.isPresenting,
        'error': state.error?.toString(),
      };
    },
  );
  return {
    for (final op in ['prepare', 'read', 'restore'])
      'fixture.personalization.$op': (p, started) =>
          fixture.call(op, p, started),
  };
}
