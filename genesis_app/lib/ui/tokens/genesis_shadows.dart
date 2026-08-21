import 'package:flutter/widgets.dart';

abstract final class GenesisShadows {
  static List<BoxShadow> raised(Color color) => <BoxShadow>[
    BoxShadow(color: color, blurRadius: 16, offset: const Offset(0, 8)),
  ];

  static List<BoxShadow> floating(Color color) => <BoxShadow>[
    BoxShadow(color: color, blurRadius: 24, offset: const Offset(0, 12)),
  ];
}
