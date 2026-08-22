import 'package:flutter/material.dart';

import '../theme/genesis_semantic_colors.dart';

const double genesisModalBorderOpacity = 0.14;
const double genesisModalBorderWidth = 1;

// The 14% outline is a white rule on dark and an ink rule on light, so it
// hangs off foregroundStrong rather than textPrimary — the latter now sits on
// the soft-white tier and would tint the hairline.
Color genesisModalBorderColor(BuildContext context) => context
    .genesisColors
    .foregroundStrong
    .withValues(alpha: genesisModalBorderOpacity);

BorderSide genesisModalBorderSide(BuildContext context) => BorderSide(
  color: genesisModalBorderColor(context),
  width: genesisModalBorderWidth,
);

Border genesisModalBorder(BuildContext context) => Border.all(
  color: genesisModalBorderColor(context),
  width: genesisModalBorderWidth,
);

RoundedRectangleBorder genesisModalShape(
  BuildContext context, {
  required BorderRadius borderRadius,
}) => RoundedRectangleBorder(
  borderRadius: borderRadius,
  side: genesisModalBorderSide(context),
);
