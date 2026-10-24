import 'dart:convert';
import '../../../../platform/session/user_session_store.dart';
import '../../qa_bridge.dart';

/// Contract-only resource. Never used by the read primitive or Case execution.
class NavigationContractIdentity {
  NavigationContractIdentity(this.store);
  final UserSessionStore store;
  String? _run, _uid, _token;
  Map<String, dynamic>? _info;
  static const testUid = 'qa_test_current_page';

  Future<Object?> call(String operation, String run) async {
    if (run.isEmpty) throw ArgumentError('Missing contract run');
    if (operation == 'prepare') {
      if (_run != null) throw StateError('Identity snapshot already owned');
      if (await store.readLoginUid() != null) {
        throw StateError('Navigation contract requires a signed-out session');
      }
      _uid = await store.readUid();
      _token = await store.readAuthToken();
      final info = await store.readUserInfo();
      _info = info == null
          ? null
          : jsonDecode(jsonEncode(info)) as Map<String, dynamic>;
      _run = run; // Own the snapshot before the first fallible mutation.
      await store.saveUid(testUid);
      return {'runId': run, 'identity': await store.readLoginUid()};
    }
    if (operation != 'restore' || _run != run) {
      throw StateError('No identity snapshot owned by this run');
    }
    final current = await store.readUid();
    if (current != testUid && current != _uid) {
      throw StateError('Foreign identity; refusing restoration');
    }
    await store.clearUid();
    if (_uid != null) await store.saveUid(_uid!);
    if (_token != null) await store.saveAuthToken(_token!);
    if (_info != null) await store.saveUserInfo(_info!);
    final restored =
        await store.readUid() == _uid &&
        await store.readAuthToken() == _token &&
        jsonEncode(await store.readUserInfo()) == jsonEncode(_info);
    if (!restored) throw StateError('Identity snapshot did not restore');
    _run = null;
    return {
      'runId': run,
      'restored': restored,
      'identity': await store.readLoginUid(),
    };
  }
}

final _fixtures = Expando<NavigationContractIdentity>();
Future<Object?> navigationContractIdentity(
  Map<String, dynamic> parameters,
  bool prepared,
  bool started,
) async {
  if (!prepared ||
      !started ||
      const String.fromEnvironment('GENESIS_API_ENV') != 'mock') {
    throw StateError('Requires a started, prepared mock contract session');
  }
  if (parameters.length != 2 ||
      parameters['runId'] is! String ||
      !['prepare', 'restore'].contains(parameters['operation'])) {
    throw ArgumentError('Invalid navigation identity contract request');
  }
  final bridge = QaBridge.current;
  if (bridge == null) throw StateError('Missing contract bridge');
  final fixture = _fixtures[bridge] ??= NavigationContractIdentity(
    bridge.store,
  );
  return fixture.call(
    parameters['operation'] as String,
    parameters['runId'] as String,
  );
}
