import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleSignInService {
  GoogleSignInService._();

  static const MethodChannel _deviceChannel = MethodChannel(
    'com.worldo.ai/device',
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
      serverClientId: serverClientId.trim().isEmpty ? null : serverClientId,
    );
    _initializeFuture = init;
    return init;
  }

  static Future<GoogleIdentitySession> signIn() async {
    debugPrint('[Auth][GoogleSignInService] signIn start');
    if (!kIsWeb && !Platform.isAndroid && !Platform.isIOS) {
      debugPrint('[Auth][GoogleSignInService] unsupported platform');
      throw const _GoogleSignInFailure('当前平台不支持 Google 登录');
    }
    final diagnostics = await _fetchSignInDiagnostics();
    final serverClientId = _resolveServerClientId(diagnostics);
    if (!kIsWeb && Platform.isAndroid && serverClientId.isEmpty) {
      throw const _GoogleSignInFailure(
        '未找到 Google OAuth Web Client ID，请检查 Google 登录配置和 SHA-1。',
      );
    }
    if (!kIsWeb && Platform.isAndroid) {
      debugPrint('[Auth][GoogleSignInService] using legacy Android sign-in');
      return _signInWithLegacyAndroid(serverClientId);
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
    final session = _sessionFromAccount(account);
    debugPrint('[Auth][GoogleSignInService] signIn success');
    return session;
  }

  static Future<GoogleIdentitySession> _signInWithLegacyAndroid(
    String serverClientId,
  ) async {
    final Object? raw;
    try {
      raw = await _deviceChannel.invokeMethod<Object?>('signInGoogleLegacy', {
        'serverClientId': serverClientId,
      });
    } on PlatformException catch (error) {
      if (error.code == 'google_sign_in_cancelled') {
        throw const GoogleSignInException(
          code: GoogleSignInExceptionCode.canceled,
          description: 'Google sign-in cancelled.',
        );
      }
      rethrow;
    }
    final result = raw is Map
        ? raw.map((key, value) => MapEntry(key.toString(), value))
        : const <String, Object?>{};
    final googleIdToken = (result['idToken'] ?? '').toString().trim();
    if (googleIdToken.isEmpty) {
      throw const _GoogleSignInFailure('Google 未返回 idToken，请稍后重试');
    }
    debugPrint('[Auth][GoogleSignInService] legacy Android sign-in success');
    return GoogleIdentitySession(
      googleIdToken: googleIdToken,
      displayName: (result['displayName'] ?? '').toString().trim(),
      photoUrl: (result['photoUrl'] ?? '').toString().trim(),
    );
  }

  static Future<GoogleIdentitySession?> refreshSilently() async {
    debugPrint('[Auth][GoogleSignInService] silent refresh start');
    if (!kIsWeb && !Platform.isAndroid && !Platform.isIOS) {
      debugPrint(
        '[Auth][GoogleSignInService] silent refresh unsupported platform',
      );
      return null;
    }

    try {
      final diagnostics = await _fetchSignInDiagnostics();
      final serverClientId = _resolveServerClientId(diagnostics);
      if (!kIsWeb && Platform.isAndroid && serverClientId.isEmpty) {
        debugPrint(
          '[Auth][GoogleSignInService] silent refresh skipped: missing web client id',
        );
        return null;
      }
      await _ensureInitialized(serverClientId: serverClientId);

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
      final session = GoogleIdentitySession(
        googleIdToken: googleIdToken,
        displayName: account.displayName?.trim() ?? '',
        photoUrl: account.photoUrl?.trim() ?? '',
      );
      debugPrint('[Auth][GoogleSignInService] silent refresh success');
      return session;
    } catch (e, st) {
      debugPrint('[Auth][GoogleSignInService] silent refresh failed: $e');
      debugPrint('[Auth][GoogleSignInService] silent refresh stacktrace:\n$st');
      return null;
    }
  }

  static Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      debugPrint('[Auth][GoogleSignInService] Google sign out failed: $e');
    }
  }

  static GoogleIdentitySession _sessionFromAccount(
    GoogleSignInAccount account,
  ) {
    final googleIdToken = account.authentication.idToken?.trim() ?? '';
    if (googleIdToken.isEmpty) {
      debugPrint(
        '[Auth][GoogleSignInService] idToken empty after authenticate',
      );
      throw const _GoogleSignInFailure(
        'Google 未返回 idToken，请检查 Google OAuth 配置和 SHA-1。',
      );
    }
    return GoogleIdentitySession(
      googleIdToken: googleIdToken,
      displayName: account.displayName?.trim() ?? '',
      photoUrl: account.photoUrl?.trim() ?? '',
    );
  }

  static Future<Map<String, Object?>> _fetchSignInDiagnostics() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return const <String, Object?>{};
    }
    try {
      final raw = await _deviceChannel.invokeMethod<Object>(
        'getSignInDiagnostics',
      );
      final map = raw is Map
          ? raw.map((key, value) => MapEntry(key.toString(), value))
          : const <String, Object?>{};
      debugPrint('[Auth][GoogleSignInService] sign-in diagnostics: $map');
      return map;
    } catch (e) {
      debugPrint('[Auth][GoogleSignInService] diagnostics unavailable: $e');
      return const <String, Object?>{};
    }
  }

  static String _resolveServerClientId(Map<String, Object?> diagnostics) {
    final fromDefine = _serverClientId.trim();
    if (fromDefine.isNotEmpty) return fromDefine;
    final fromGoogleServices = (diagnostics['defaultWebClientId'] ?? '')
        .toString()
        .trim();
    if (fromGoogleServices.isNotEmpty) return fromGoogleServices;
    final fromIosInfoPlist = (diagnostics['gidServerClientId'] ?? '')
        .toString()
        .trim();
    if (fromIosInfoPlist.isNotEmpty) return fromIosInfoPlist;
    final fromIosGoogleServices =
        (diagnostics['googleServiceServerClientId'] ?? '').toString().trim();
    if (fromIosGoogleServices.isNotEmpty) return fromIosGoogleServices;
    return '';
  }
}

class GoogleIdentitySession {
  const GoogleIdentitySession({
    required this.googleIdToken,
    required this.displayName,
    required this.photoUrl,
  });

  final String googleIdToken;
  final String displayName;
  final String photoUrl;
}

class _GoogleSignInFailure implements Exception {
  const _GoogleSignInFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
