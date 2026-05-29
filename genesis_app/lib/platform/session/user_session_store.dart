abstract interface class UserSessionStore {
  Future<String?> readUid();
  Future<void> saveUid(String uid);
  Future<String?> readAuthToken();
  Future<void> saveAuthToken(String token);
  Future<Map<String, dynamic>?> readUserInfo();
  Future<void> saveUserInfo(Map<String, dynamic> userInfo);
  Future<void> clearUid();
}
