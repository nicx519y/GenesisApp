import '../../l10n/genesis_l10n.dart';
import 'package:flutter/material.dart';

import '../tokens/genesis_colors.dart';

/// Standard circular close action for dark sheets and panels.
class GenesisDarkCloseButton extends StatelessWidget {
  const GenesisDarkCloseButton({
    super.key,
    required this.onPressed,
    this.size = dimension,
    this.glyphSize = iconSize,
    this.background = GenesisColors.darkFaintFill,
  });

  static const double dimension = 28;
  static const double iconSize = 17;

  final VoidCallback? onPressed;
  final double size;
  final double glyphSize;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: IconButton(
        tooltip: GenesisL10n.current.commonClose,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size.square(size),
          maximumSize: Size.square(size),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: background,
          disabledBackgroundColor: background,
          foregroundColor: GenesisColors.darkTextPrimary,
          disabledForegroundColor: GenesisColors.darkTextTertiary,
          shape: const CircleBorder(),
        ),
        icon: Icon(Icons.close_rounded, size: glyphSize),
      ),
    );
  }
}
