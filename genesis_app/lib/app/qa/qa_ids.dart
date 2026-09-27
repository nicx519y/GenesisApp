/// Stable accessibility identifiers used by local QA automation.
///
/// These identifiers are part of the test interface, not user-visible copy.
/// Changing labels or visual structure must not change an existing identifier.
abstract final class QaIds {
  static const String homeTab = 'qa.bottom_navigation.home';
  static const String worldoTab = 'qa.bottom_navigation.worldo';
  static const String createTab = 'qa.bottom_navigation.create';
  static const String inboxTab = 'qa.bottom_navigation.inbox';
  static const String meTab = 'qa.bottom_navigation.me';
  static const String appleLogin = 'qa.login.provider.apple';
  static const String googleLogin = 'qa.login.provider.google';
  static const String signedOutMe = 'qa.me.signed_out';

  static const String loginSheet = 'qa.login.sheet';
  static const String loginClose = 'qa.login.close';

  static String bottomNavigation(String label) =>
      'qa.bottom_navigation.${_slug(label)}';

  static String loginProvider(String provider) => switch (provider) {
    'apple' => appleLogin,
    'google' => googleLogin,
    _ => 'qa.login.provider.${_slug(provider)}',
  };

  static String _slug(String value) {
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return normalized.isEmpty ? 'unknown' : normalized;
  }
}
