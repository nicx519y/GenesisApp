import 'package:flutter/foundation.dart';

typedef CompleteUserSession = ({String uid, String authToken});

abstract interface class UserSessionStore {
  ValueListenable<int> get userInfoRevision;

  Future<String?> readUid();
  Future<void> saveUid(String uid);
  Future<String?> readAuthToken();
  Future<void> saveAuthToken(String token);
  Future<Map<String, dynamic>?> readUserInfo();
  Future<void> saveUserInfo(Map<String, dynamic> userInfo);
  Future<void> clearUid();
}

extension UserSessionStoreAuthentication on UserSessionStore {
  /// Reads the local session using the single definition of an authenticated
  /// account used throughout the app.
  ///
  /// Storage failures are allowed to propagate and never clear the account.
  /// Only a successfully read partial or legacy guest session is cleaned up;
  /// an already signed-out store is left untouched.
  Future<CompleteUserSession?> readCompleteSession() async {
    final values = await Future.wait<String?>([readUid(), readAuthToken()]);
    final uid = values[0]?.trim() ?? '';
    final authToken = values[1]?.trim() ?? '';
    if (uid.isNotEmpty && !uid.startsWith('guest_') && authToken.isNotEmpty) {
      return (uid: uid, authToken: authToken);
    }
    if (uid.isNotEmpty || authToken.isNotEmpty) await clearUid();
    return null;
  }
}
