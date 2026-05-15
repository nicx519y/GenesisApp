import 'package:flutter/widgets.dart';

abstract final class GenesisSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 6;
  static const double md = 8;
  static const double lg = 10;
  static const double xl = 12;
  static const double xxl = 14;
  static const double page = 16;
  static const double pageWide = 20;
  static const double section = 24;

  static const EdgeInsets pagePadding = EdgeInsets.symmetric(horizontal: page);
  static const EdgeInsets formPagePadding = EdgeInsets.symmetric(
    horizontal: pageWide,
  );
}
