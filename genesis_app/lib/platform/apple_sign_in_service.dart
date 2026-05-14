import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AppleSignInService {
  AppleSignInService._();

  static bool get isSupportedPlatform => !kIsWeb && Platform.isIOS;

  static Future<AppleFirebaseSession> signInToFirebase() async {
    debugPrint('[Auth][AppleSignInService] signInToFirebase start');
    if (!isSupportedPlatform) {
      throw const _AppleSignInFailure('当前平台不支持 Apple 登录');
    }
    if (Firebase.apps.isEmpty) {
      throw const _AppleSignInFailure('Firebase 尚未初始化');
    }

    final rawNonce = _generateNonce();
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: _sha256ofString(rawNonce),
    );
    final identityToken = credential.identityToken?.trim() ?? '';
    if (identityToken.isEmpty) {
      throw const _AppleSignInFailure('Apple 未返回 identityToken，请稍后重试');
    }

    final oauthCredential = OAuthProvider(
      'apple.com',
    ).credential(idToken: identityToken, rawNonce: rawNonce);
    final userCredential = await FirebaseAuth.instance.signInWithCredential(
      oauthCredential,
    );
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
