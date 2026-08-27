import 'package:flutter/material.dart';

import '../tokens/genesis_typography.dart';

TextStyle genesisSoftItalicStyle(
  TextStyle style, {
  required TargetPlatform platform,
  bool useIosSkew = GenesisTypography.useIosSoftItalicSkew,
}) {
  return GenesisTypography.withFallback(
    GenesisTypography.inlineEmphasis(
      style,
      platform: platform,
      useIosSkew: useIosSkew,
    ),
  );
}

Widget genesisSoftItalicForPlatform({
  required Widget child,
  required TargetPlatform platform,
  bool useIosSkew = GenesisTypography.useIosSoftItalicSkew,
}) {
  if (platform != TargetPlatform.iOS || !useIosSkew) return child;
  return Transform(
    alignment: Alignment.center,
    transform: Matrix4.skewX(GenesisTypography.iosInlineEmphasisSkew),
    transformHitTests: false,
    child: child,
  );
}

class GenesisSoftItalicText extends StatelessWidget {
  const GenesisSoftItalicText(
    this.text, {
    super.key,
    required this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final TextStyle style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    return genesisSoftItalicForPlatform(
      platform: platform,
      child: Text(
        text,
        style: genesisSoftItalicStyle(style, platform: platform),
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      ),
    );
  }
}
