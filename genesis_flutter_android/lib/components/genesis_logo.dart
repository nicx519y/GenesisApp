import 'package:flutter/material.dart';

class GenesisLogo extends StatelessWidget {
  const GenesisLogo({super.key, this.height = 32});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/Genesis.png',
      height: height,
      fit: BoxFit.contain,
    );
  }
}

