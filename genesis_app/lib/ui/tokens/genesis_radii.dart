import 'package:flutter/widgets.dart';

abstract final class GenesisRadii {
  static const Radius sm = Radius.circular(8);
  static const Radius compactControl = Radius.circular(9);
  static const Radius md = Radius.circular(11);
  static const Radius lg = Radius.circular(12);
  static const Radius xl = Radius.circular(14);
  static const Radius xxl = Radius.circular(16);
  static const double sheetTopRadiusValue = 24;
  static const Radius sheetTopRadius = Radius.circular(sheetTopRadiusValue);
  static const Radius pill = Radius.circular(999);
  static const Radius tag = Radius.circular(6);

  static const BorderRadius input = BorderRadius.all(md);
  static const BorderRadius button = BorderRadius.all(md);
  static const BorderRadius card = BorderRadius.all(xl);
  static const BorderRadius panel = BorderRadius.all(xl);
  static const BorderRadius sheet = BorderRadius.vertical(top: sheetTopRadius);
}
