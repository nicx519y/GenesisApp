import 'dart:async';

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
    final authToken = (await _sessionStore.readAuthToken())?.trim();
    unawaited(_logoutBackend(authToken: authToken));
    await _sessionStore.clearUid();
    unawaited(_signOutIdentity());
  }

  Future<void> _logoutBackend({String? authToken}) async {
    try {
      await _api.logout(headers: _authHeadersFromToken(authToken));
    } catch (e) {
      debugPrint('[Auth][BackendAuthCoordinator] backend logout failed: $e');
    }
  }

  Future<void> _signOutIdentity() async {
    try {
      await _identityAuth.signOutIdentity();
    } catch (e) {
      debugPrint('[Auth][BackendAuthCoordinator] identity sign out failed: $e');
    }
  }

  Map<String, String>? _authHeadersFromToken(String? authToken) {
    final value = (authToken ?? '').trim();
    if (value.isEmpty) return null;
    return {
      'authorization': value.toLowerCase().startsWith('bearer ')
          ? value
          : 'Bearer $value',
    };
  }
}
