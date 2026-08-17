import 'package:flutter/services.dart';

/// Centralized build-variant capabilities.
///
/// Business code is shared by every flavor. Keep flavor-specific behavior in
/// this boundary instead of scattering `appFlavor` checks across features.
class AppFlavorConfig {
  const AppFlavorConfig._({
    required this.name,
    required this.supportsAppleSignIn,
  });

  static const production = AppFlavorConfig._(
    name: 'production',
    supportsAppleSignIn: true,
  );
  static const internal = AppFlavorConfig._(
    name: 'internal',
    supportsAppleSignIn: false,
  );

  static const currentIsInternal = appFlavor == 'internal';
  static const currentSupportsAppleSignIn = appFlavor != 'internal';
  static const current = currentIsInternal ? internal : production;

  factory AppFlavorConfig.forName(String? name) {
    return name?.trim().toLowerCase() == internal.name ? internal : production;
  }

  final String name;
  final bool supportsAppleSignIn;

  bool get isInternal => name == internal.name;
}
