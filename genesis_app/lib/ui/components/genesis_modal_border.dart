import 'package:flutter/material.dart';

import '../theme/genesis_semantic_colors.dart';

const double genesisModalBorderOpacity = 0.14;
const double genesisModalBorderWidth = 1;

Color genesisModalBorderColor(BuildContext context) => context
    .genesisColors
    .textPrimary
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
