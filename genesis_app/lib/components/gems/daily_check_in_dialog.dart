import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../common/genesis_action_box.dart';
import 'gem_assets.dart';
import 'gem_colors.dart';

const int dailyCheckInPreviewReward = 50;
const Duration dailyCheckInSuccessDuration = Duration(seconds: 3);

Future<bool> showDailyCheckInDialog(
  BuildContext context, {
  required bool claimed,
  int rewardGems = dailyCheckInPreviewReward,
}) async {
  final shouldCheckIn = await showGenesisActionBox<bool>(
    context: context,
    title: 'Daily Check-in',
    titleContent: _DailyCheckInReward(rewardGems: rewardGems),
    titleContentSpacing: 10,
    actions: [
      GenesisActionBoxAction<bool>(
        label: claimed ? 'Claimed' : 'Check in',
        value: true,
        color: claimed ? kGemTaskClaimedForegroundColor : kGemAccentColor,
        enabled: !claimed,
      ),
    ],
    cancelLabel: 'Cancel',
  );
  return shouldCheckIn == true;
}

Future<void> showDailyCheckInSuccessDialog(
  BuildContext context, {
  int rewardGems = dailyCheckInPreviewReward,
  Duration duration = dailyCheckInSuccessDuration,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final timer = Timer(duration, () {
    if (navigator.mounted && navigator.canPop()) navigator.pop();
  });
  try {
    await showGenesisActionBox<void>(
      context: context,
      title: 'Check in successful!',
      titleContent: _DailyCheckInReward(rewardGems: rewardGems),
      titleContentSpacing: 10,
      actions: const [],
      showCancel: false,
    );
  } finally {
    timer.cancel();
  }
}

class _DailyCheckInReward extends StatelessWidget {
  const _DailyCheckInReward({required this.rewardGems});

  final int rewardGems;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '+$rewardGems',
          key: const ValueKey<String>('daily-check-in-reward-value'),
          style: const TextStyle(
            color: Color(0xFF111111),
            fontSize: 15,
            height: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 4),
        SvgPicture.asset(
          gemIconAsset,
          key: const ValueKey<String>('daily-check-in-reward-icon'),
          width: gemSmallIconSize,
          height: gemSmallIconSize,
        ),
      ],
    );
  }
}
