abstract interface class UserSessionStore {
  Future<String?> readUid();
  Future<void> saveUid(String uid);
  Future<String?> readAuthToken();
  Future<void> saveAuthToken(String token);
  Future<void> clearUid();
}
