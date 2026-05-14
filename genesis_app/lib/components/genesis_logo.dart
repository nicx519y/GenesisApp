import 'package:flutter/material.dart';

class GenesisLogo extends StatelessWidget {
  const GenesisLogo({super.key, this.height = 32, this.width});

  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/Genesis.png',
      height: height,
      width: width,
      fit: BoxFit.contain,
    );
  }
}
