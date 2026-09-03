import 'package:flutter/material.dart';

import '../../network/models/origin.dart';
import '../../ui/tokens/genesis_colors.dart';

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
    this.size = 22,
  });

  final Key? badgeKey;
  final bool showBackground;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Recommended role',
      child: SizedBox(
        key: badgeKey,
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: showBackground
                ? const Color(0xCCFFFFFF)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Icon(
              Icons.star_rounded,
              size: size,
              color: GenesisColors.brand,
            ),
          ),
        ),
      ),
    );
  }
}
