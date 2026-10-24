import 'dart:convert';
import '../../../../platform/session/user_session_store.dart';
import '../../qa_bridge.dart';

/// A bridge instance owns exactly one identity snapshot. No navigation or
/// personalization changes are part of this resource.
class WorldTestIdentity {
  WorldTestIdentity(this.store, this.resource)
    : uid =
          'qa_test_world_${base64Url.encode(utf8.encode(resource)).replaceAll('=', '')}';
  final UserSessionStore store;
  final String resource;
  final String uid;
  Map<String, Object?>? _snapshot;
  bool _restored = false;
  bool _prepared = false;
  bool _restoring = false;

  Future<Map<String, Object?>> _state() async => {
    'uid': await store.readUid(),
    'token': await store.readAuthToken(),
    'info': jsonDecode(jsonEncode(await store.readUserInfo())),
  };

  Future<Map<String, Object?>> read() async {
    final actual = await store.readLoginUid();
    return {
      'loggedIn': actual != null,
      'isolated': _snapshot != null && !_restored && actual == uid,
      'uid': actual,
      'resource': resource,
    };
  }

  Future<Map<String, Object?>> prepare() async {
    if (_snapshot != null) {
      if (_restored || _restoring || await store.readLoginUid() != uid) {
        throw StateError('Identity lease changed or already restored');
      }
      return read();
    }
    if (resource.isEmpty) throw StateError('Missing bridge resource');
    // Snapshot before the first fallible write, so cleanup remains possible.
    _snapshot = await _state();
    await store.clearUid();
    await store.saveUid(uid);
    _prepared = true;
    return read();
  }

  Future<Map<String, Object?>> restore() async {
    final before = _snapshot;
    if (before == null) throw StateError('No identity snapshot was acquired');
    final current = await store.readUid();
    if (_restored) {
      if (jsonEncode(await _state()) != jsonEncode(before)) {
        throw StateError('Restored identity subsequently changed');
      }
    } else {
      // A failed prepare can leave the original UID or null after clearUid.
      if ((_prepared && !_restoring && current != uid) ||
          ((!_prepared || _restoring) &&
              current != uid &&
              current != before['uid'] &&
              current != null)) {
        throw StateError('Foreign identity; refusing to overwrite it');
      }
      _restoring = true;
      await store.clearUid();
      if (before['uid'] != null) await store.saveUid(before['uid'] as String);
      if (before['token'] != null)
        await store.saveAuthToken(before['token'] as String);
      if (before['info'] != null) {
        await store.saveUserInfo(
          Map<String, dynamic>.from(before['info'] as Map),
        );
      }
    }
    final matches = jsonEncode(await _state()) == jsonEncode(before);
    if (!matches) throw StateError('Identity snapshot restoration mismatch');
    _restored = true;
    return {
      'restored': matches,
      'matchesSnapshot': matches,
      'resource': resource,
    };
  }
}

final _resources = Expando<WorldTestIdentity>();
WorldTestIdentity worldIdentityResource() {
  final bridge = QaBridge.current;
  if (bridge == null ||
      const String.fromEnvironment('GENESIS_API_ENV') != 'mock') {
    throw StateError('Requires an authenticated mock bridge');
  }
  return _resources[bridge] ??= WorldTestIdentity(
    bridge.store,
    bridge.resource,
  );
}

Future<Object?> readWorldIdentity(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  if (p.isNotEmpty) throw ArgumentError('Identity read takes no parameters');
  return worldIdentityResource().read();
}

Future<Object?> prepareWorldIdentity(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  if (prepared || !started || p.isNotEmpty)
    throw StateError('Requires a started Case session');
  return worldIdentityResource().prepare();
}

Future<Object?> restoreWorldIdentity(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  if (prepared || p.isNotEmpty) throw StateError('Requires a Case session');
  return worldIdentityResource().restore();
}

Future<Object?> contractWorldIdentity(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  if (!prepared || p.length != 1)
    throw StateError('Requires an isolated contract session');
  final resource = worldIdentityResource();
  return switch (p['operation']) {
    'prepare' => resource.prepare(),
    'restore' => resource.restore(),
    'read' => resource.read(),
    _ => throw ArgumentError('Unknown identity contract operation'),
  };
}
