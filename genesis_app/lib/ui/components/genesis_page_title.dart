import 'package:flutter/widgets.dart';

import '../theme/genesis_semantic_colors.dart';
import '../tokens/genesis_typography.dart';

class GenesisPageTitle extends StatelessWidget {
  const GenesisPageTitle({super.key, required this.text, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: GenesisTypography.pageTitle
          .copyWith(color: context.genesisColors.textPrimary)
          .merge(style),
    );
  }
}
