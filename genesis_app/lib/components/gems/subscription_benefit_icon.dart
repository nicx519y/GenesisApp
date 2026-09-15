import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../icons/custom_icon_assets.dart';
import '../../ui/tokens/genesis_colors.dart';
import 'gem_assets.dart';

/// Subscription artwork selected solely by the backend's icon_key.
/// Unknown identifiers deliberately retain the original circled-star fallback.
class SubscriptionBenefitIcon extends StatelessWidget {
  const SubscriptionBenefitIcon({
    super.key,
    required this.iconKey,
    this.size = 20,
    this.color = GenesisColors.darkTextPrimary,
  });

  final String iconKey;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final asset = switch (iconKey) {
      'gem' => gemDiamondIconAsset,
      'inspiration' => inspirationIconAsset,
      'edit' => editSquareIconAsset,
      'badge' => proCrownIconAsset,
      'recharge' => upgradeIconAsset,
      _ => null,
    };
    if (asset != null) {
      // These wider silhouettes need a smaller drawing inside the same slot.
      final scale = iconKey == 'edit' || iconKey == 'inspiration' ? 0.85 : 1.0;
      return SizedBox.square(
        dimension: size,
        child: Center(child: _svg(asset, size * scale)),
      );
    }
    final icon = switch (iconKey) {
      'memory' => Icons.auto_stories_outlined,
      _ => Icons.stars_outlined,
    };
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: Center(
          child: Icon(icon, size: size * 0.9, color: color),
        ),
      ),
    );
  }

  Widget _svg(String asset, double dimension) => SvgPicture.asset(
    asset,
    width: dimension,
    height: dimension,
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    excludeFromSemantics: true,
  );
}
