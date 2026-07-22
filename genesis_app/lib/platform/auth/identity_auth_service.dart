import 'auth_session.dart';

abstract interface class IdentityAuthService {
  Future<AuthSession> signIn(IdentityProvider provider);
  Future<AuthSession?> refreshSilently();
  Future<void> signOutIdentity();
}
