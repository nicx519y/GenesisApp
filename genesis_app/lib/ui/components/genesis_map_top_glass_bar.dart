import 'dart:ui';

import 'package:flutter/material.dart';

const Color genesisMapTopGlassBarColor = Color(0x80151517);
const double genesisMapTopGlassBarBlurSigma = 10;
const double genesisMapTopGlassBarRadius = 12;

class GenesisMapGlassBackButton extends StatelessWidget {
  const GenesisMapGlassBackButton({
    super.key,
    required this.dimension,
    required this.onPressed,
    this.glassKey,
    this.surfaceKey,
  });

  final double dimension;
  final VoidCallback onPressed;
  final Key? glassKey;
  final Key? surfaceKey;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: dimension,
      height: dimension,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(genesisMapTopGlassBarRadius),
        child: BackdropFilter(
          key: glassKey,
          filter: ImageFilter.blur(
            sigmaX: genesisMapTopGlassBarBlurSigma,
            sigmaY: genesisMapTopGlassBarBlurSigma,
          ),
          child: Material(
            key: surfaceKey,
            color: genesisMapTopGlassBarColor,
            child: IconButton(
              iconSize: 18,
              onPressed: onPressed,
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              padding: EdgeInsets.zero,
            ),
          ),
        ),
      ),
    );
  }
}
