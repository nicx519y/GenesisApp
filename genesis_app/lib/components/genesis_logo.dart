import 'package:flutter/material.dart';
import 'package:genesis_flutter_android/ui/components/genesis_svg_asset.dart';

class GenesisLogo extends StatelessWidget {
  const GenesisLogo({super.key, this.height = 32, this.width});

  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return GenesisSvgAsset.asset(
      'assets/svg/worldo-logo.svg',
      height: height,
      width: width,
      fit: BoxFit.contain,
    );
  }
}
