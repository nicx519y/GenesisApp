import 'package:flutter/foundation.dart';

import '../../network/genesis_api.dart';
import '../../network/models/user.dart';
import '../session/user_session_store.dart';
import 'auth_session.dart';
import 'identity_auth_service.dart';

abstract interface class BackendAuthCoordinator {
  Future<bool> hasAuthenticatedBackendSession({bool tryAutoRefresh = true});
  Future<User> loginWithIdentity(AuthSession session);
  Future<void> signOut();
}

class GenesisBackendAuthCoordinator implements BackendAuthCoordinator {
  const GenesisBackendAuthCoordinator({
    required GenesisApi api,
    required IdentityAuthService identityAuth,
    required UserSessionStore sessionStore,
  }) : _api = api,
       _identityAuth = identityAuth,
       _sessionStore = sessionStore;

  final GenesisApi _api;
  final IdentityAuthService _identityAuth;
  final UserSessionStore _sessionStore;

  @override
  Future<bool> hasAuthenticatedBackendSession({bool tryAutoRefresh = true}) {
    return _api.hasAuthenticatedSession(tryAutoRefresh: tryAutoRefresh);
  }

  @override
  Future<User> loginWithIdentity(AuthSession session) {
    return _api.loginWithIdentity(session);
  }

  @override
  Future<void> signOut() async {
    try {
      await _api.logout();
    } catch (e) {
      debugPrint('[Auth][BackendAuthCoordinator] backend logout failed: $e');
    }

    try {
      await _identityAuth.signOutIdentity();
    } finally {
      await _sessionStore.clearUid();
    }
  }
}
