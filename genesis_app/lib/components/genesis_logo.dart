import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class GenesisLogo extends StatelessWidget {
  const GenesisLogo({super.key, this.height = 32, this.width});

  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/svg/worldo-logo.svg',
      height: height,
      width: width,
      fit: BoxFit.contain,
    );
  }
}
