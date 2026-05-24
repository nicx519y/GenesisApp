import 'dart:math' as math;

import 'package:flutter/material.dart';

class LocationChatAiBadge extends StatelessWidget {
  const LocationChatAiBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: math.pi / 4,
      child: Container(width: 16, height: 16, color: Colors.red),
    );
  }
}
