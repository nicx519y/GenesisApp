import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../apple_sign_in_service.dart';
import '../google_sign_in_service.dart';
import '../session/user_session_store.dart';
import 'auth_cancelled_exception.dart';
import 'auth_session.dart';
import 'identity_auth_service.dart';

typedef GoogleIdentitySignIn = Future<GoogleIdentitySession> Function();
typedef GoogleIdentityRefresh = Future<GoogleIdentitySession?> Function();
typedef AppleIdentitySignIn = Future<AppleIdentitySession> Function();
typedef IdentitySignOut = Future<void> Function();

class ProviderIdentityAuthService implements IdentityAuthService {
  ProviderIdentityAuthService({
    required UserSessionStore sessionStore,
    GoogleIdentitySignIn? googleSignIn,
    GoogleIdentityRefresh? googleRefresh,
    AppleIdentitySignIn? appleSignIn,
    IdentitySignOut? googleSignOut,
  }) : _sessionStore = sessionStore,
       _googleSignIn = googleSignIn ?? GoogleSignInService.signIn,
       _googleRefresh = googleRefresh ?? GoogleSignInService.refreshSilently,
       _appleSignIn = appleSignIn ?? AppleSignInService.signIn,
       _googleSignOut = googleSignOut ?? GoogleSignInService.signOut;

  final UserSessionStore _sessionStore;
  final GoogleIdentitySignIn _googleSignIn;
  final GoogleIdentityRefresh _googleRefresh;
  final AppleIdentitySignIn _appleSignIn;
  final IdentitySignOut _googleSignOut;

  @override
  Future<AuthSession> signIn(IdentityProvider provider) async {
    try {
      switch (provider) {
        case IdentityProvider.google:
          return _fromGoogleSession(await _googleSignIn());
        case IdentityProvider.apple:
          return _fromAppleSession(
            await _appleSignIn(),
            cachedDisplayName: await _readCachedDisplayName(),
          );
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
    final userInfo = await _sessionStore.readUserInfo();
    final provider = (userInfo?['login_provider'] ?? '').toString().trim();
    if (provider != IdentityProvider.google.name) return null;

    final session = await _googleRefresh();
    return session == null ? null : _fromGoogleSession(session);
  }

  @override
  Future<void> signOutIdentity() => _googleSignOut();

  Future<String> _readCachedDisplayName() async {
    final userInfo = await _sessionStore.readUserInfo();
    if (userInfo == null) return '';
    for (final key in const [
      'display_name',
      'name',
      'nickname',
      'user_name',
      'displayName',
    ]) {
      final value = (userInfo[key] ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }
}

AuthSession _fromGoogleSession(GoogleIdentitySession session) {
  return AuthSession(
    provider: IdentityProvider.google,
    providerIdToken: session.googleIdToken,
    displayName: session.displayName,
    photoUrl: session.photoUrl,
  );
}

AuthSession _fromAppleSession(
  AppleIdentitySession session, {
  required String cachedDisplayName,
}) {
  return AuthSession(
    provider: IdentityProvider.apple,
    providerIdToken: session.appleIdentityToken,
    displayName: session.displayName.isNotEmpty
        ? session.displayName
        : cachedDisplayName,
    photoUrl: session.photoUrl,
  );
}
