import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../app/telemetry/genesis_telemetry.dart';
import '../../network/genesis_api.dart';
import '../../network/models/user.dart';
import '../session/user_session_store.dart';
import 'auth_session.dart';
import 'identity_auth_service.dart';

abstract interface class BackendAuthCoordinator {
  Future<bool> hasAuthenticatedBackendSession({bool tryAutoRefresh = true});
  Future<User> loginWithIdentity(AuthSession session);
  Future<void> deleteAccount();
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
  Future<User> loginWithIdentity(AuthSession session) async {
    final stopwatch = Stopwatch()..start();
    GenesisTelemetry.event(
      'login_start',
      category: 'auth',
      data: <String, Object?>{'provider': session.provider.name},
    );
    try {
      final user = await _api.loginWithIdentity(session);
      stopwatch.stop();
      GenesisTelemetry.setUserId(user.uid);
      GenesisTelemetry.collectLog(actionType: 'event', action: 'login');
      GenesisTelemetry.event(
        'login_success',
        category: 'auth',
        data: <String, Object?>{
          'provider': session.provider.name,
          'duration_ms': stopwatch.elapsedMilliseconds,
        },
      );
      return user;
    } catch (error) {
      stopwatch.stop();
      GenesisTelemetry.event(
        'login_failure',
        category: 'auth',
        data: <String, Object?>{
          'provider': session.provider.name,
          'duration_ms': stopwatch.elapsedMilliseconds,
          'error_type': error.runtimeType.toString(),
        },
        level: GenesisTelemetryLevel.warning,
      );
      await _signOutIdentity();
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    final stopwatch = Stopwatch()..start();
    GenesisTelemetry.event('logout_start', category: 'auth');
    final authToken = (await _sessionStore.readAuthToken())?.trim();
    unawaited(_logoutBackend(authToken: authToken));
    GenesisTelemetry.collectLog(actionType: 'event', action: 'logout');
    await _sessionStore.clearUid();
    unawaited(_signOutIdentity());
    GenesisTelemetry.clearUser();
    stopwatch.stop();
    GenesisTelemetry.event(
      'logout_success',
      category: 'auth',
      data: <String, Object?>{'duration_ms': stopwatch.elapsedMilliseconds},
    );
  }

  @override
  Future<void> deleteAccount() async {
    final stopwatch = Stopwatch()..start();
    GenesisTelemetry.event('delete_account_start', category: 'auth');
    final authToken = (await _sessionStore.readAuthToken())?.trim();
    unawaited(_deleteBackend(authToken: authToken));
    GenesisTelemetry.collectLog(actionType: 'event', action: 'delete_account');
    await _sessionStore.clearUid();
    unawaited(_signOutIdentity());
    GenesisTelemetry.clearUser();
    stopwatch.stop();
    GenesisTelemetry.event(
      'delete_account_success',
      category: 'auth',
      data: <String, Object?>{'duration_ms': stopwatch.elapsedMilliseconds},
    );
  }

  Future<void> _logoutBackend({String? authToken}) async {
    try {
      await _api.logout(headers: _authHeadersFromToken(authToken));
    } catch (e) {
      GenesisTelemetry.event(
        'logout_failure',
        category: 'auth',
        data: <String, Object?>{'error_type': e.runtimeType.toString()},
        level: GenesisTelemetryLevel.warning,
      );
      debugPrint('[Auth][BackendAuthCoordinator] backend logout failed: $e');
    }
  }

  Future<void> _deleteBackend({String? authToken}) async {
    try {
      await _api.deleteAccount(headers: _authHeadersFromToken(authToken));
    } catch (e) {
      GenesisTelemetry.event(
        'delete_account_failure',
        category: 'auth',
        data: <String, Object?>{'error_type': e.runtimeType.toString()},
        level: GenesisTelemetryLevel.warning,
      );
      debugPrint(
        '[Auth][BackendAuthCoordinator] backend account delete failed: $e',
      );
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
