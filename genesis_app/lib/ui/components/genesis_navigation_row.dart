import 'package:flutter/material.dart';

import '../theme/genesis_semantic_colors.dart';
import '../tokens/genesis_typography.dart';

class GenesisNavigationRow extends StatelessWidget {
  const GenesisNavigationRow({
    super.key,
    required this.label,
    required this.onTap,
    this.leading,
    this.labelTrailing,
    this.trailing,
    this.showChevron = true,
    this.showDivider = true,
    this.height = 47,
    this.labelStyle,
  });

  final String label;
  final VoidCallback? onTap;
  final Widget? leading;
  final Widget? labelTrailing;
  final Widget? trailing;
  final bool showChevron;
  final bool showDivider;
  final double height;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    final colors = context.genesisColors;
    final row = InkWell(
      onTap: onTap,
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 10)],
            Text(
              label,
              style:
                  labelStyle ??
                  GenesisTypography.bodyStrong.copyWith(
                    color: colors.foregroundStrong,
                    height: 1,
                  ),
            ),
            if (labelTrailing != null) ...[
              const SizedBox(width: 9),
              labelTrailing!,
            ],
            const Spacer(),
            if (trailing != null) trailing!,
            if (showChevron) ...[
              if (trailing != null) const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: colors.textTimestamp,
              ),
            ],
          ],
        ),
      ),
    );
    if (!showDivider) return row;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.divider)),
      ),
      child: row,
    );
  }
}
