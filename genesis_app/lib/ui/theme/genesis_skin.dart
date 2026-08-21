import 'package:flutter/material.dart';

/// Visual skin identity, intentionally independent from Material brightness.
enum GenesisSkin { worldoRedesign }

@immutable
class GenesisSkinTheme extends ThemeExtension<GenesisSkinTheme> {
  const GenesisSkinTheme({required this.skin});

  final GenesisSkin skin;

  @override
  GenesisSkinTheme copyWith({GenesisSkin? skin}) {
    return GenesisSkinTheme(skin: skin ?? this.skin);
  }

  @override
  GenesisSkinTheme lerp(
    covariant ThemeExtension<GenesisSkinTheme>? other,
    double t,
  ) {
    if (other is! GenesisSkinTheme) return this;
    return t < 0.5 ? this : other;
  }
}
