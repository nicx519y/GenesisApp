import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleSignInService {
  GoogleSignInService._();
  static const MethodChannel _deviceChannel = MethodChannel(
    'com.genesis.ai/device',
  );

  static const String _serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '',
  );
  static Future<void>? _initializeFuture;
  static String _initializedServerClientId = '';
  static const List<String> _scopeHint = <String>['openid', 'email', 'profile'];

  static Future<void> _ensureInitialized({required String serverClientId}) {
    final pending = _initializeFuture;
    if (pending != null && _initializedServerClientId == serverClientId) {
      return pending;
    }
    _initializedServerClientId = serverClientId;
    final init = GoogleSignIn.instance.initialize(
      serverClientId: serverClientId,
    );
    _initializeFuture = init;
    return init;
  }

  static bool hasFirebaseSession() {
    try {
      return Firebase.apps.isNotEmpty &&
          FirebaseAuth.instance.currentUser != null;
    } catch (_) {
      return false;
    }
  }

  static Future<GoogleFirebaseSession> signInToFirebase() async {
    debugPrint('[Auth][GoogleSignInService] signInToFirebase start');
    if (!kIsWeb && !Platform.isAndroid && !Platform.isIOS) {
      debugPrint('[Auth][GoogleSignInService] unsupported platform');
      throw const _GoogleSignInFailure('当前平台不支持 Google 登录');
    }
    if (Firebase.apps.isEmpty) {
      throw const _GoogleSignInFailure(
        'Firebase 尚未初始化，请先在 Firebase 控制台下载并放置 google-services.json。',
      );
    }
    final diagnostics = await _fetchAndroidSignInDiagnostics();
    final serverClientId = _resolveServerClientId(diagnostics);
    if (serverClientId.isEmpty) {
      throw const _GoogleSignInFailure(
        '未找到 Web Client ID。请在 Firebase 启用 Google 登录、补齐 SHA-1 后重新下载 google-services.json。',
      );
    }

    debugPrint('[Auth][GoogleSignInService] initializing GoogleSignIn');
    await _ensureInitialized(serverClientId: serverClientId);
    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      debugPrint(
        '[Auth][GoogleSignInService] GoogleSignIn does not support authenticate on this client',
      );
      throw const _GoogleSignInFailure('当前端不支持直接拉起 Google 登录');
    }
    debugPrint('[Auth][GoogleSignInService] launching authenticate');
    final account = await GoogleSignIn.instance.authenticate(
      scopeHint: _scopeHint,
    );

    final googleIdToken = account.authentication.idToken?.trim() ?? '';
    if (googleIdToken.isEmpty) {
      debugPrint(
        '[Auth][GoogleSignInService] idToken empty after authenticate',
      );
      throw const _GoogleSignInFailure(
        'Google 未返回 idToken，请确认 Firebase Google 登录配置和 SHA-1 是否正确',
      );
    }
    final session = await _signInToFirebaseWithGoogleIdToken(
      googleIdToken,
      forceRefreshFirebaseIdToken: false,
    );
    debugPrint(
      '[Auth][GoogleSignInService] signInToFirebase success uid=${session.firebaseUid}',
    );
    return session;
  }

  static Future<String> signInAndGetIdToken() async {
    final session = await signInToFirebase();
    return session.googleIdToken;
  }

  static Future<GoogleFirebaseSession?> refreshTokenOrSignInSilently() async {
    debugPrint('[Auth][GoogleSignInService] silent refresh start');
    if (!kIsWeb && !Platform.isAndroid && !Platform.isIOS) {
      debugPrint(
        '[Auth][GoogleSignInService] silent refresh unsupported platform',
      );
      return null;
    }
    if (Firebase.apps.isEmpty) {
      debugPrint(
        '[Auth][GoogleSignInService] silent refresh skipped: Firebase not initialized',
      );
      return null;
    }

    try {
      final diagnostics = await _fetchAndroidSignInDiagnostics();
      final serverClientId = _resolveServerClientId(diagnostics);
      if (serverClientId.isEmpty) {
        debugPrint(
          '[Auth][GoogleSignInService] silent refresh skipped: missing web client id',
        );
        return null;
      }
      await _ensureInitialized(serverClientId: serverClientId);
      await _refreshFirebaseIdTokenIfPossible();

      final lightweightAttempt = GoogleSignIn.instance
          .attemptLightweightAuthentication();
      final account = lightweightAttempt == null
          ? null
          : await lightweightAttempt;
      if (account == null) {
        debugPrint(
          '[Auth][GoogleSignInService] silent refresh no account restored',
        );
        return null;
      }

      final googleIdToken = account.authentication.idToken?.trim() ?? '';
      if (googleIdToken.isEmpty) {
        debugPrint(
          '[Auth][GoogleSignInService] silent refresh failed: empty idToken',
        );
        return null;
      }

      final session = await _signInToFirebaseWithGoogleIdToken(
        googleIdToken,
        forceRefreshFirebaseIdToken: true,
      );
      debugPrint(
        '[Auth][GoogleSignInService] silent refresh success uid=${session.firebaseUid}',
      );
      return session;
    } catch (e, st) {
      debugPrint('[Auth][GoogleSignInService] silent refresh failed: $e');
      debugPrint('[Auth][GoogleSignInService] silent refresh stacktrace:\n$st');
      return null;
    }
  }

  static Future<void> signOutFirebase() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      debugPrint('[Auth][GoogleSignInService] google signOut failed: $e');
    }
    try {
      if (Firebase.apps.isNotEmpty) {
        await FirebaseAuth.instance.signOut();
      }
    } catch (e) {
      debugPrint('[Auth][GoogleSignInService] firebase signOut failed: $e');
    }
  }

  static Future<Map<String, Object?>> _fetchAndroidSignInDiagnostics() async {
    if (kIsWeb || !Platform.isAndroid) return const <String, Object?>{};
    try {
      final raw = await _deviceChannel.invokeMethod<Object>(
        'getSignInDiagnostics',
      );
      final map = raw is Map
          ? raw.map((key, value) => MapEntry(key.toString(), value))
          : const <String, Object?>{};
      debugPrint(
        '[Auth][GoogleSignInService] android signIn diagnostics: $map',
      );
      return map;
    } catch (e) {
      debugPrint('[Auth][GoogleSignInService] diagnostics unavailable: $e');
      return const <String, Object?>{};
    }
  }

  static Future<void> _refreshFirebaseIdTokenIfPossible() async {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null) return;
    try {
      await current.getIdToken(true);
      debugPrint(
        '[Auth][GoogleSignInService] refreshed Firebase token uid=${current.uid}',
      );
    } catch (e) {
      debugPrint(
        '[Auth][GoogleSignInService] refresh Firebase token failed: $e',
      );
    }
  }

  static Future<GoogleFirebaseSession> _signInToFirebaseWithGoogleIdToken(
    String googleIdToken, {
    required bool forceRefreshFirebaseIdToken,
  }) async {
    final credential = GoogleAuthProvider.credential(idToken: googleIdToken);
    final userCredential = await FirebaseAuth.instance.signInWithCredential(
      credential,
    );
    final firebaseUser = userCredential.user;
    if (firebaseUser == null) {
      throw const _GoogleSignInFailure('Firebase 登录失败，请稍后重试');
    }

    final firebaseIdToken =
        (await firebaseUser.getIdToken(forceRefreshFirebaseIdToken))?.trim() ??
        '';

    return GoogleFirebaseSession(
      googleIdToken: googleIdToken,
      firebaseIdToken: firebaseIdToken,
      firebaseUid: firebaseUser.uid,
      email: firebaseUser.email?.trim() ?? '',
      displayName: firebaseUser.displayName?.trim() ?? '',
      photoUrl: firebaseUser.photoURL?.trim() ?? '',
    );
  }

  static String _resolveServerClientId(Map<String, Object?> diagnostics) {
    final fromDefine = _serverClientId.trim();
    if (fromDefine.isNotEmpty) return fromDefine;
    final fromGoogleServices = (diagnostics['defaultWebClientId'] ?? '')
        .toString()
        .trim();
    if (fromGoogleServices.isNotEmpty) return fromGoogleServices;
    return '';
  }
}

class GoogleFirebaseSession {
  const GoogleFirebaseSession({
    required this.googleIdToken,
    required this.firebaseIdToken,
    required this.firebaseUid,
    required this.email,
    required this.displayName,
    required this.photoUrl,
  });

  final String googleIdToken;
  final String firebaseIdToken;
  final String firebaseUid;
  final String email;
  final String displayName;
  final String photoUrl;
}

class _GoogleSignInFailure implements Exception {
  const _GoogleSignInFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
