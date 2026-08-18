import 'package:flutter/material.dart';

import '../../network/models/origin.dart';
import '../../ui/theme/genesis_semantic_colors.dart';

List<OriginCharacter> originCharactersRecommendedFirst(
  Iterable<OriginCharacter> characters,
) {
  return <OriginCharacter>[
    ...characters.where((character) => character.isRecommended),
    ...characters.where((character) => !character.isRecommended),
  ];
}

class OriginRecommendedRoleMark extends StatelessWidget {
  const OriginRecommendedRoleMark({
    super.key,
    this.badgeKey,
    this.showBackground = false,
  });

  final Key? badgeKey;
  final bool showBackground;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Recommended role',
      child: SizedBox(
        key: badgeKey,
        width: 22,
        height: 22,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: showBackground
                ? context.genesisColors.textInverse.withValues(alpha: 0.8)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Icon(
              Icons.star_rounded,
              size: 22,
              color: context.genesisColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}
