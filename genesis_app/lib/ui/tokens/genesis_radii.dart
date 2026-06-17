import 'package:flutter/widgets.dart';

abstract final class GenesisRadii {
  static const Radius sm = Radius.circular(8);
  static const Radius md = Radius.circular(10);
  static const Radius lg = Radius.circular(12);
  static const Radius xl = Radius.circular(14);
  static const Radius xxl = Radius.circular(16);
  static const Radius pill = Radius.circular(999);

  static const BorderRadius input = BorderRadius.all(md);
  static const BorderRadius button = BorderRadius.all(sm);
  static const BorderRadius card = BorderRadius.all(lg);
  static const BorderRadius panel = BorderRadius.all(xl);
  static const BorderRadius sheet = BorderRadius.vertical(top: xxl);
}
