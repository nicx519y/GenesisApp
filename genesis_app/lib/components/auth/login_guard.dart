import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../platform/auth/auth_session.dart';
import '../login_sheet.dart';

Future<bool> ensureGenesisLogin(BuildContext context) async {
  if (await hasGenesisLoginSession(context)) return true;
  if (!context.mounted) return false;
  final loginContext = context;

  final loggedIn = await showModalBottomSheet<bool>(
    context: loginContext,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => LoginSheet(
      onLogin: (provider) {
        return _loginWithProvider(loginContext, provider);
      },
    ),
  );
  if (!loginContext.mounted || loggedIn != true) return false;
  return hasGenesisLoginSession(loginContext);
}

Future<bool> hasGenesisLoginSession(BuildContext context) async {
  final services = AppServicesScope.read(context);
  final uid = (await services.sessionStore.readUid())?.trim() ?? '';
  final authToken = (await services.sessionStore.readAuthToken())?.trim() ?? '';
  return uid.isNotEmpty && !uid.startsWith('guest_') && authToken.isNotEmpty;
}

Future<bool> _loginWithProvider(
  BuildContext context,
  IdentityProvider provider,
) async {
  final services = AppServicesScope.read(context);
  final session = await services.identityAuth.signIn(provider);
  final user = await services.backendAuth.loginWithIdentity(session);
  if (user.uid.trim().isNotEmpty) {
    await services.sessionStore.saveUid(user.uid);
  }
  final cachedUserInfo = await services.sessionStore.readUserInfo();
  final loginUserInfo = <String, dynamic>{
    if (cachedUserInfo != null) ...cachedUserInfo,
    'uid': user.uid,
  };
  if (user.nickname.trim().isNotEmpty) {
    loginUserInfo['name'] = user.nickname;
  }
  if (user.avatar.trim().isNotEmpty) {
    loginUserInfo['avatar'] = user.avatar;
  }
  await services.sessionStore.saveUserInfo(loginUserInfo);
  return true;
}
