import 'dart:convert';
import '../../../../platform/session/user_session_store.dart';

/// One bridge instance owns the original source, including partial credentials.
/// Contract aliases are registered separately; Case dispatch retains its guard.
class LocalIdentityHook {
  LocalIdentityHook(this.store, {required this.resource});
  final UserSessionStore store;
  final String resource;
  bool _owned = false;
  String? _uid, _token;
  Map<String, dynamic>? _info;

  static const interfaces = [
    'fixture.localIdentity.prepare',
    'fixture.localIdentity.read',
    'fixture.localIdentity.cleanup',
    'contract.localIdentity.prepare',
    'contract.localIdentity.read',
    'contract.localIdentity.cleanup',
  ];
  Map<String, Future<Object?> Function(Map<String, dynamic>, bool, bool)>
  get handlers => {
    'fixture.localIdentity.prepare': (p, prepared, _) =>
        _case(prepared, () => prepare(p)),
    'fixture.localIdentity.read': (p, prepared, _) =>
        _case(prepared, () => read(p)),
    'fixture.localIdentity.cleanup': (p, prepared, _) =>
        _case(prepared, () => cleanup(p)),
    'contract.localIdentity.prepare': (p, prepared, _) =>
        _contract(prepared, () => prepare(p)),
    'contract.localIdentity.read': (p, prepared, _) =>
        _contract(prepared, () => read(p)),
    'contract.localIdentity.cleanup': (p, prepared, _) =>
        _contract(prepared, () => cleanup(p)),
  };
  Future<Object?> _case(bool prepared, Future<Object?> Function() action) {
    if (prepared)
      throw StateError('Case fixture cannot reuse contract preparation');
    return action();
  }

  Future<Object?> _contract(bool prepared, Future<Object?> Function() action) {
    if (!prepared)
      throw StateError('Contract hook requires a prepared session');
    _requireMock();
    return action();
  }

  void _validate(Map<String, dynamic> p, {bool prepare = false}) {
    if (p.keys.any((k) => !prepare || k != 'uid')) {
      throw ArgumentError('Unknown local identity parameter');
    }
    if (prepare && p.containsKey('uid')) {
      final uid = p['uid'];
      if (uid != null &&
          (uid is! String ||
              !uid.startsWith('qa_test_') ||
              uid.length <= 8 ||
              uid.trim() != uid)) {
        throw ArgumentError('Only nonempty QA identities are accepted');
      }
    }
  }

  void _requireMock() {
    if (const String.fromEnvironment('GENESIS_API_ENV') != 'mock') {
      throw StateError('Identity overrides require mock environment');
    }
  }

  Future<Object?> prepare(Map<String, dynamic> p) async {
    _validate(p, prepare: true);
    _requireMock();
    final uid = p.containsKey('uid')
        ? p['uid'] as String?
        : 'qa_test_$resource';
    if (!_owned) {
      _uid = await store.readUid();
      _token = await store.readAuthToken();
      final info = await store.readUserInfo();
      _info = info == null
          ? null
          : jsonDecode(jsonEncode(info)) as Map<String, dynamic>;
      _owned = true; // Retain restoration even if a later write fails.
    }
    await store.clearUid();
    if (uid != null) await store.saveUid(uid);
    final actual = await store.readLoginUid();
    if (actual != uid) throw StateError('Identity override did not persist');
    return actual;
  }

  Future<Object?> read(Map<String, dynamic> p) async {
    _validate(p);
    return store.readLoginUid();
  }

  Future<Object?> cleanup(Map<String, dynamic> p) async {
    _validate(p);
    _requireMock();
    if (_owned) {
      await store.clearUid();
      if (_uid != null) await store.saveUid(_uid!);
      if (_token != null) await store.saveAuthToken(_token!);
      if (_info != null) await store.saveUserInfo(_info!);
      if (await store.readUid() != _uid ||
          await store.readAuthToken() != _token ||
          jsonEncode(await store.readUserInfo()) != jsonEncode(_info)) {
        throw StateError('Original identity source was not restored');
      }
      _owned = false;
      _uid = null;
      _token = null;
      _info = null;
    }
    return 'restored';
  }
}
