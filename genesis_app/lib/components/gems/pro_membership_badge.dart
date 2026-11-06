import '../../l10n/genesis_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../icons/custom_icon_assets.dart';

/// Membership mark for inline username labels — the 26a crown on its own,
/// as design 9k2 sets it beside the profile name. No plate, no wordmark.
class ProMembershipBadge extends StatelessWidget {
  const ProMembershipBadge({
    super.key,
    this.height = _nameHeight,
    this.deluxe = false,
  });

  /// Scales the crown consistently with the adjacent name or metadata text.
  const ProMembershipBadge.beside({
    super.key,
    required double fontSize,
    this.deluxe = false,
  }) : height = fontSize * _heightPerTextSize;

  /// A 20px name uses a 24 × 17px crown.
  static const double _nameHeight = 17;
  static const double _heightPerTextSize = _nameHeight / 20;

  /// The crown's own proportions; width follows from it.
  static const double _aspect = 96 / 68;

  final double height;
  final bool deluxe;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: deluxe
          ? GenesisL10n.current.memoryMembershipDeluxe
          : GenesisL10n.current.a11yPremiumMembership,
      image: true,
      excludeSemantics: true,
      child: SvgPicture.asset(
        deluxe ? proCrownDeluxeIconAsset : proCrownGoldIconAsset,
        width: height * _aspect,
        height: height,
        fit: BoxFit.contain,
      ),
    );
  }
}
