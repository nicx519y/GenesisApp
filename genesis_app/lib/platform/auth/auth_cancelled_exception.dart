class AuthCancelledException implements Exception {
  const AuthCancelledException();

  @override
  String toString() => 'Sign-in cancelled';
}
