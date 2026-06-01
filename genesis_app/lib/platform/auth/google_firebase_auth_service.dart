import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../apple_sign_in_service.dart';
import '../google_sign_in_service.dart';
import 'auth_cancelled_exception.dart';
import 'auth_session.dart';
import 'identity_auth_service.dart';

class FirebaseIdentityAuthService implements IdentityAuthService {
  const FirebaseIdentityAuthService();

  @override
  bool hasLocalIdentitySession() => GoogleSignInService.hasFirebaseSession();

  @override
  IdentityProfile? currentProfile() {
    final user = fb.FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return IdentityProfile(
      uid: user.uid.trim(),
      displayName: user.displayName?.trim() ?? '',
      email: user.email?.trim() ?? '',
      photoUrl: user.photoURL?.trim() ?? '',
    );
  }

  @override
  Future<AuthSession> signIn(IdentityProvider provider) async {
    try {
      switch (provider) {
        case IdentityProvider.google:
          return _fromGoogleSession(
            await GoogleSignInService.signInToFirebase(),
          );
        case IdentityProvider.apple:
          return _fromAppleSession(await AppleSignInService.signInToFirebase());
      }
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthCancelledException();
      }
      rethrow;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw const AuthCancelledException();
      }
      rethrow;
    }
  }

  @override
  Future<AuthSession?> refreshSilently() async {
    if (!kIsWeb && Platform.isIOS) {
      final appleSession = await AppleSignInService.refreshFirebaseSession();
      if (appleSession != null) return _fromAppleSession(appleSession);
    }

    final session = await GoogleSignInService.refreshTokenOrSignInSilently();
    if (session == null) return null;
    return _fromGoogleSession(session);
  }

  @override
  Future<void> signOutIdentity() async {
    await GoogleSignInService.signOutFirebase();
  }
}

AuthSession _fromGoogleSession(GoogleFirebaseSession session) {
  return AuthSession(
    provider: IdentityProvider.google,
    providerIdToken: session.googleIdToken,
    firebaseIdToken: session.firebaseIdToken,
    identityUid: session.firebaseUid,
    email: session.email,
    displayName: session.displayName,
    photoUrl: session.photoUrl,
  );
}

AuthSession _fromAppleSession(AppleFirebaseSession session) {
  return AuthSession(
    provider: IdentityProvider.apple,
    providerIdToken: session.appleIdentityToken,
    firebaseIdToken: session.firebaseIdToken,
    identityUid: session.firebaseUid,
    email: session.email,
    displayName: session.displayName,
    photoUrl: session.photoUrl,
  );
}

typedef GoogleFirebaseAuthService = FirebaseIdentityAuthService;
