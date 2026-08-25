import 'package:flutter/material.dart';

import '../../ui/theme/genesis_semantic_colors.dart';
import '../create/genesis_create_theme.dart';
import 'genesis_origin_theme.dart';

enum OriginRoleSelectionMarkStyle { checkbox, star, circle }

class OriginRoleSelectionMark extends StatelessWidget {
  const OriginRoleSelectionMark({
    super.key,
    required this.selected,
    this.semanticLabel,
    this.style = OriginRoleSelectionMarkStyle.checkbox,
    this.dimension = 16,
  });

  final bool selected;
  final String? semanticLabel;
  final OriginRoleSelectionMarkStyle style;

  /// Only used by [OriginRoleSelectionMarkStyle.circle].
  final double dimension;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: selected,
      inMutuallyExclusiveGroup: style != OriginRoleSelectionMarkStyle.checkbox,
      label: semanticLabel,
      child: switch (style) {
        OriginRoleSelectionMarkStyle.star => _OriginRoleStarMark(
          selected: selected,
        ),
        OriginRoleSelectionMarkStyle.circle => _OriginRoleCircleMark(
          selected: selected,
          dimension: dimension,
        ),
        OriginRoleSelectionMarkStyle.checkbox => _OriginRoleCheckboxMark(
          selected: selected,
        ),
      },
    );
  }
}

class _OriginRoleCircleMark extends StatelessWidget {
  const _OriginRoleCircleMark({required this.selected, required this.dimension});

  final bool selected;
  final double dimension;

  @override
  Widget build(BuildContext context) {
    // Same circular check as the Opening location picker rows:
    // selected state is white with an ink check, not red.
    final createColors = context.genesisCreateColors;
    return Container(
      width: dimension,
      height: dimension,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected
            ? createColors.selectedOptionSurface
            : Colors.transparent,
        border: Border.all(
          color: selected
              ? createColors.selectedOptionSurface
              : context.genesisOriginColors.roleSetupMuted,
          width: 1,
        ),
      ),
      child: selected
          ? Icon(
              Icons.check,
              size: dimension * 0.68,
              color: createColors.selectedOptionText,
            )
          : null,
    );
  }
}

class _OriginRoleStarMark extends StatelessWidget {
  const _OriginRoleStarMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 16,
      child: Transform.scale(
        scale: 1.2,
        child: Icon(
          selected ? Icons.star_rounded : Icons.star_border_rounded,
          size: 16,
          color: selected
              ? context.genesisColors.primary
              : context.genesisOriginColors.roleSetupMuted,
        ),
      ),
    );
  }
}

class _OriginRoleCheckboxMark extends StatelessWidget {
  const _OriginRoleCheckboxMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: selected
            ? context.genesisColors.primary
            : context.genesisColors.textInverse.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: context.genesisColors.textInverse, width: 2),
        boxShadow: [
          BoxShadow(
            color: context.genesisColors.scrim.withValues(alpha: 0.2),
            blurRadius: 5,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: selected
          ? Icon(
              Icons.check,
              size: 18,
              color: context.genesisColors.textInverse,
            )
          : null,
    );
  }
}
