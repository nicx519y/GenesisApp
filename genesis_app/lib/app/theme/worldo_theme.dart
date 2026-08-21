import 'package:flutter/material.dart';

import '../../components/genesis_feature_themes.dart';
import '../../ui/theme/genesis_theme.dart';

/// Application-level composition of the Worldo skin and feature themes.
///
/// The shared UI layer owns only semantic roles and reusable component
/// metrics. Feature extensions are registered here so adding or removing a
/// product domain cannot introduce a reverse dependency from `lib/ui`.
abstract final class WorldoTheme {
  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final extensions = <ThemeExtension<dynamic>>[
      GenesisGemColors.forBrightness(brightness),
      GenesisChatTheme.forBrightness(brightness),
      GenesisOriginColors.forBrightness(brightness),
      GenesisDiscussColors.forBrightness(brightness),
      GenesisCreateColors.forBrightness(brightness),
      GenesisWorldColors.forBrightness(brightness),
      GenesisMessageColors.forBrightness(brightness),
    ];
    return brightness == Brightness.dark
        ? GenesisTheme.worldoDark(extensions: extensions)
        : GenesisTheme.worldoLight(extensions: extensions);
  }
}
