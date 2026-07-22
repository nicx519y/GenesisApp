enum IdentityProvider { google, apple }

class AuthSession {
  const AuthSession({
    required this.provider,
    required this.providerIdToken,
    required this.displayName,
    required this.photoUrl,
  });

  final IdentityProvider provider;
  final String providerIdToken;
  final String displayName;
  final String photoUrl;

  bool get hasProviderToken => providerIdToken.trim().isNotEmpty;
}
