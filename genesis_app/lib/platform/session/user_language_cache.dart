import 'user_session_store.dart';

/// Update only the current account's language, preserving its other profile data.
Future<void> cacheUserLanguage({
  required UserSessionStore store,
  required CompleteUserSession session,
  required String language,
  required bool Function() canSave,
}) async {
  final user = await store.readUserInfo();
  final cachedUid = user?['uid']?.toString().trim() ?? '';
  if (cachedUid.isNotEmpty && cachedUid != session.uid) return;
  if (user?['language'] == language) return;
  if (await store.readCompleteSession() != session || !canSave()) return;
  await store.saveUserInfo({
    if (user != null) ...user,
    'uid': session.uid,
    'language': language,
  });
}
