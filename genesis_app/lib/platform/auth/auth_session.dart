enum IdentityProvider { google, apple }

class AuthSession {
  const AuthSession({
    required this.provider,
    required this.providerIdToken,
    required this.firebaseIdToken,
    required this.identityUid,
    required this.email,
    required this.displayName,
    required this.photoUrl,
  });

  final IdentityProvider provider;
  final String providerIdToken;
  final String firebaseIdToken;
  final String identityUid;
  final String email;
  final String displayName;
  final String photoUrl;

  bool get hasProviderToken => providerIdToken.trim().isNotEmpty;
  bool get hasFirebaseToken => firebaseIdToken.trim().isNotEmpty;
}

class IdentityProfile {
  const IdentityProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.photoUrl,
  });

  final String uid;
  final String displayName;
  final String email;
  final String photoUrl;
}
