import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../app/config/app_config.dart';

class AppleSignInService {
  AppleSignInService._();

  static const String _webClientId = AppConfig.defaultAppleWebClientId;
  static const String _webRedirectUri = AppConfig.defaultAppleWebRedirectUri;

  static bool get isSupportedPlatform =>
      !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  static Future<AppleIdentitySession> signIn() async {
    debugPrint('[Auth][AppleSignInService] signIn start');
    if (!isSupportedPlatform) {
      throw const _AppleSignInFailure('当前平台不支持 Apple 登录');
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

    final session = AppleIdentitySession(
      appleIdentityToken: identityToken,
      displayName: _resolveDisplayName(credential),
      photoUrl: '',
    );
    debugPrint('[Auth][AppleSignInService] signIn success');
    return session;
  }

  static String _resolveDisplayName(AuthorizationCredentialAppleID credential) {
    final givenName = credential.givenName?.trim() ?? '';
    final familyName = credential.familyName?.trim() ?? '';
    return [
      givenName,
      familyName,
    ].where((part) => part.isNotEmpty).join(' ').trim();
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

class AppleIdentitySession {
  const AppleIdentitySession({
    required this.appleIdentityToken,
    required this.displayName,
    required this.photoUrl,
  });

  final String appleIdentityToken;
  final String displayName;
  final String photoUrl;
}

class _AppleSignInFailure implements Exception {
  const _AppleSignInFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
