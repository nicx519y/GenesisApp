import 'user_session_store.dart';

class MemoryUserSessionStore implements UserSessionStore {
  String? _uid;
  String? _authToken;
  Map<String, dynamic>? _userInfo;

  @override
  Future<void> clearUid() async {
    _uid = null;
    _authToken = null;
    _userInfo = null;
  }

  @override
  Future<String?> readUid() async {
    final value = (_uid ?? '').trim();
    return value.isEmpty ? null : value;
  }

  @override
  Future<void> saveUid(String uid) async {
    final value = uid.trim();
    if (value.isEmpty) return;
    _uid = value;
  }

  @override
  Future<String?> readAuthToken() async {
    final value = (_authToken ?? '').trim();
    return value.isEmpty ? null : value;
  }

  @override
  Future<void> saveAuthToken(String token) async {
    final value = token.trim();
    if (value.isEmpty) return;
    _authToken = value;
  }

  @override
  Future<Map<String, dynamic>?> readUserInfo() async {
    final value = _userInfo;
    if (value == null || value.isEmpty) return null;
    return Map<String, dynamic>.from(value);
  }

  @override
  Future<void> saveUserInfo(Map<String, dynamic> userInfo) async {
    if (userInfo.isEmpty) return;
    _userInfo = Map<String, dynamic>.from(userInfo);
  }
}
