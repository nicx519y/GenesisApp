import 'user_session_store.dart';

const List<String> _currentUserInfoSiblingKeys = <String>[
  'uuid',
  'selected_model_code',
];

Future<Map<String, dynamic>?> cacheCurrentUserInfoResponse({
  required UserSessionStore sessionStore,
  required Map<String, dynamic> response,
  String fallbackUid = '',
}) async {
  final rawUser = response['user'];
  if (rawUser is! Map || rawUser.isEmpty) return null;

  final current = await sessionStore.readUserInfo();
  final merged = <String, dynamic>{
    if (current != null) ...current,
    ...Map<String, dynamic>.from(rawUser),
  };
  if (_stringValue(merged['uid']).isEmpty && fallbackUid.trim().isNotEmpty) {
    merged['uid'] = fallbackUid.trim();
  }
  for (final key in _currentUserInfoSiblingKeys) {
    if (response.containsKey(key)) merged[key] = response[key];
  }

  await sessionStore.saveUserInfo(merged);
  return merged;
}

String _stringValue(Object? value) => value?.toString().trim() ?? '';
