import 'auth_session.dart';

abstract interface class IdentityAuthService {
  bool hasLocalIdentitySession();
  IdentityProfile? currentProfile();
  Future<AuthSession> signIn();
  Future<AuthSession?> refreshSilently();
  Future<void> signOutIdentity();
}
