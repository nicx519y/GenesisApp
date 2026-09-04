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
  /// Reads the UID that defines the app's local login state.
  ///
  /// A missing backend token does not sign the user out. Token restoration is
  /// handled separately by the backend authentication flow.
  Future<String?> readLoginUid() async {
    final uid = (await readUid())?.trim() ?? '';
    if (uid.isEmpty || uid.startsWith('guest_')) return null;
    return uid;
  }

  /// Reads the credentials required by requests that need backend auth.
  ///
  /// Partial state is preserved so a missing token can be restored without
  /// destroying the UID-backed local login state.
  Future<CompleteUserSession?> readCompleteSession() async {
    final values = await Future.wait<String?>([readUid(), readAuthToken()]);
    final uid = values[0]?.trim() ?? '';
    final authToken = values[1]?.trim() ?? '';
    if (uid.isNotEmpty && !uid.startsWith('guest_') && authToken.isNotEmpty) {
      return (uid: uid, authToken: authToken);
    }
    return null;
  }
}
