import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'channels/genesis_method_channels.dart';

class AppleSignInService {
  AppleSignInService._();

  static const String _webClientId = String.fromEnvironment(
    'APPLE_WEB_CLIENT_ID',
    defaultValue: 'com.worldo.ai.signin',
  );
  static const String _webRedirectUri = String.fromEnvironment(
    'APPLE_WEB_REDIRECT_URI',
    defaultValue: 'https://dev.hushie.ai/callbacks/signinwithapple',
  );

  static bool get isSupportedPlatform =>
      !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  static Future<AppleFirebaseSession> signInToFirebase() async {
    debugPrint('[Auth][AppleSignInService] signInToFirebase start');
    if (!isSupportedPlatform) {
      throw const _AppleSignInFailure('当前平台不支持 Apple 登录');
    }
    if (Firebase.apps.isEmpty) {
      throw const _AppleSignInFailure('Firebase 尚未初始化');
    }
    final webAuthenticationOptions = _webAuthenticationOptions();

    final rawNonce = _generateNonce();
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: _sha256ofString(rawNonce),
      webAuthenticationOptions: webAuthenticationOptions,
    );
    final identityToken = credential.identityToken?.trim() ?? '';
    if (identityToken.isEmpty) {
      throw const _AppleSignInFailure('Apple 未返回 identityToken，请稍后重试');
    }

    final oauthCredential = Platform.isAndroid
        ? OAuthProvider(
            'apple.com',
          ).credential(idToken: identityToken, rawNonce: rawNonce)
        : AppleAuthProvider.credentialWithIDToken(
            identityToken,
            rawNonce,
            AppleFullPersonName(
              givenName: credential.givenName,
              familyName: credential.familyName,
            ),
          );
    final UserCredential userCredential;
    try {
      userCredential = await FirebaseAuth.instance.signInWithCredential(
        oauthCredential,
      );
    } on FirebaseAuthException catch (e, st) {
      debugPrint(
        '[Auth][AppleSignInService] Firebase sign-in failed '
        'code=${e.code} message=${e.message} plugin=${e.plugin}',
      );
      await _logSignInDiagnostics();
      if (e.code == 'network-request-failed') {
        await _logFirebaseAuthNetworkProbe();
      }
      debugPrint('[Auth][AppleSignInService] stacktrace:\n$st');
      throw _AppleSignInFailure(
        'Firebase Apple 登录失败：${e.code}${e.message == null ? '' : ' ${e.message}'}',
      );
    }
    final firebaseUser = userCredential.user;
    if (firebaseUser == null) {
      throw const _AppleSignInFailure('Firebase 登录失败，请稍后重试');
    }

    final firebaseIdToken = (await firebaseUser.getIdToken())?.trim() ?? '';
    final displayName = _resolveDisplayName(credential, firebaseUser);
    if (displayName.isNotEmpty && (firebaseUser.displayName ?? '').isEmpty) {
      await firebaseUser.updateDisplayName(displayName);
    }

    final session = AppleFirebaseSession(
      appleIdentityToken: identityToken,
      firebaseIdToken: firebaseIdToken,
      firebaseUid: firebaseUser.uid,
      email: (credential.email ?? firebaseUser.email ?? '').trim(),
      displayName: displayName,
      photoUrl: firebaseUser.photoURL?.trim() ?? '',
    );
    debugPrint(
      '[Auth][AppleSignInService] signInToFirebase success uid=${session.firebaseUid}',
    );
    return session;
  }

  static Future<AppleFirebaseSession?> refreshFirebaseSession() async {
    debugPrint('[Auth][AppleSignInService] silent refresh start');
    if (!kIsWeb && Platform.isAndroid) return null;
    if (!isSupportedPlatform || Firebase.apps.isEmpty) return null;
    final current = FirebaseAuth.instance.currentUser;
    if (current == null) return null;
    final providers = current.providerData
        .map((provider) => provider.providerId)
        .toSet();
    if (!providers.contains('apple.com')) return null;

    try {
      final firebaseIdToken = (await current.getIdToken(true))?.trim() ?? '';
      if (firebaseIdToken.isEmpty) return null;
      return AppleFirebaseSession(
        appleIdentityToken: '',
        firebaseIdToken: firebaseIdToken,
        firebaseUid: current.uid,
        email: current.email?.trim() ?? '',
        displayName: current.displayName?.trim() ?? '',
        photoUrl: current.photoURL?.trim() ?? '',
      );
    } catch (e, st) {
      debugPrint('[Auth][AppleSignInService] silent refresh failed: $e');
      debugPrint('[Auth][AppleSignInService] stacktrace:\n$st');
      return null;
    }
  }

  static String _resolveDisplayName(
    AuthorizationCredentialAppleID credential,
    User firebaseUser,
  ) {
    final givenName = credential.givenName?.trim() ?? '';
    final familyName = credential.familyName?.trim() ?? '';
    final appleName = [
      givenName,
      familyName,
    ].where((part) => part.isNotEmpty).join(' ').trim();
    if (appleName.isNotEmpty) return appleName;
    return firebaseUser.displayName?.trim() ?? '';
  }

  static WebAuthenticationOptions? _webAuthenticationOptions() {
    if (!Platform.isAndroid) return null;
    final clientId = _webClientId.trim();
    final redirectUri = _webRedirectUri.trim();
    if (clientId.isEmpty || redirectUri.isEmpty) {
      throw const _AppleSignInFailure('Android Apple 登录暂未配置');
    }
    final uri = Uri.tryParse(redirectUri);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const _AppleSignInFailure('Android Apple 登录回调地址配置无效');
    }
    return WebAuthenticationOptions(clientId: clientId, redirectUri: uri);
  }

  static Future<void> _logSignInDiagnostics() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;
    try {
      final raw = await GenesisMethodChannels.device.invokeMethod<Object>(
        GenesisMethodChannels.getSignInDiagnostics,
      );
      final map = raw is Map
          ? raw.map((key, value) => MapEntry(key.toString(), value))
          : const <String, Object?>{};
      debugPrint('[Auth][AppleSignInService] signIn diagnostics: $map');
    } catch (e) {
      debugPrint('[Auth][AppleSignInService] diagnostics unavailable: $e');
    }
  }

  static Future<void> _logFirebaseAuthNetworkProbe() async {
    const host = 'identitytoolkit.googleapis.com';
    try {
      final addresses = await InternetAddress.lookup(
        host,
      ).timeout(const Duration(seconds: 6));
      debugPrint(
        '[Auth][AppleSignInService] Firebase Auth DNS $host -> '
        '${addresses.map((address) => address.address).join(', ')}',
      );
    } catch (e) {
      debugPrint('[Auth][AppleSignInService] Firebase Auth DNS failed: $e');
      return;
    }

    Socket? socket;
    try {
      socket = await Socket.connect(
        host,
        443,
        timeout: const Duration(seconds: 6),
      );
      debugPrint('[Auth][AppleSignInService] Firebase Auth TCP 443 reachable');
    } catch (e) {
      debugPrint('[Auth][AppleSignInService] Firebase Auth TCP failed: $e');
      return;
    } finally {
      await socket?.close();
    }

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    try {
      final request = await client
          .getUrl(Uri.https(host, '/'))
          .timeout(const Duration(seconds: 6));
      final response = await request.close().timeout(
        const Duration(seconds: 6),
      );
      debugPrint(
        '[Auth][AppleSignInService] Firebase Auth HTTPS status '
        '${response.statusCode}',
      );
      await response.drain<void>();
    } catch (e) {
      debugPrint('[Auth][AppleSignInService] Firebase Auth HTTPS failed: $e');
    } finally {
      client.close(force: true);
    }
  }

  static String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  static String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}

class AppleFirebaseSession {
  const AppleFirebaseSession({
    required this.appleIdentityToken,
    required this.firebaseIdToken,
    required this.firebaseUid,
    required this.email,
    required this.displayName,
    required this.photoUrl,
  });

  final String appleIdentityToken;
  final String firebaseIdToken;
  final String firebaseUid;
  final String email;
  final String displayName;
  final String photoUrl;
}

class _AppleSignInFailure implements Exception {
  const _AppleSignInFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
