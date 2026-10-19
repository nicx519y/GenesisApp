import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../ui/tokens/genesis_colors.dart';
import '../../utils/gem_amount.dart';
import 'gem_assets.dart';

/// Shared reward amount and gem icon for task dialogs.
class GemTaskReward extends StatelessWidget {
  const GemTaskReward({
    super.key,
    required this.rewardGemsCent,
    this.showWholeReward = false,
  });

  final int rewardGemsCent;
  final bool showWholeReward;

  @override
  Widget build(BuildContext context) {
    final rewardText = showWholeReward
        ? formatWholeGemCent(rewardGemsCent)
        : formatGemCent(rewardGemsCent);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '+$rewardText',
          key: const ValueKey<String>('gem-task-reward-value'),
          style: const TextStyle(
            color: GenesisColors.darkTextSecondary,
            fontSize: 15,
            height: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 4),
        SvgPicture.asset(
          gemIconAsset,
          key: const ValueKey<String>('gem-task-reward-icon'),
          width: gemSmallIconSize,
          height: gemSmallIconSize,
        ),
      ],
    );
  }
}
