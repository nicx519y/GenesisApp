import 'package:flutter/material.dart';

import '../theme/genesis_semantic_colors.dart';
import '../tokens/genesis_typography.dart';

class GenesisSectionHeader extends StatelessWidget {
  const GenesisSectionHeader({
    super.key,
    required this.title,
    this.leading,
    this.trailing,
    this.subtitle,
    this.compact = false,
    this.titleStyle,
  });

  final String title;
  final Widget? leading;
  final Widget? trailing;
  final String? subtitle;
  final bool compact;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    final colors = context.genesisColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (leading != null) ...[leading!, SizedBox(width: compact ? 5 : 8)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style:
                    titleStyle ??
                    (compact
                            ? GenesisTypography.bodyStrong
                            : GenesisTypography.sectionTitle)
                        .copyWith(color: colors.textPrimary),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: GenesisTypography.supporting.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
