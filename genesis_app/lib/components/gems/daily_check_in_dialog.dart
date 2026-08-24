import 'dart:async';

import 'package:flutter/material.dart';

import '../common/genesis_action_box.dart';
import 'gem_colors.dart';
import '../../ui/theme/genesis_semantic_colors.dart';
import '../../ui/tokens/genesis_typography.dart';

const int dailyCheckInPreviewReward = 50;
const String dailyCheckInTaskCode = 'daily_checkin';
const Duration dailyCheckInSuccessDuration = Duration(seconds: 3);

enum DailyCheckInDialogStatus { checkIn, claim, claimed }

Future<bool> showDailyCheckInDialog(
  BuildContext context, {
  required DailyCheckInDialogStatus status,
  int rewardGems = dailyCheckInPreviewReward,
}) async {
  final claimed = status == DailyCheckInDialogStatus.claimed;
  final shouldCheckIn = await showGenesisActionBox<bool>(
    context: context,
    title: 'Daily Check-in',
    titleContent: _GemTaskReward(rewardGems: rewardGems),
    titleContentSpacing: 10,
    actions: [
      GenesisActionBoxAction<bool>(
        label: switch (status) {
          DailyCheckInDialogStatus.checkIn => 'Check in',
          DailyCheckInDialogStatus.claim => 'Claim',
          DailyCheckInDialogStatus.claimed => 'Claimed',
        },
        value: true,
        color: claimed
            ? context.genesisGemColors.taskClaimedForeground
            : context.genesisGemColors.accent,
        enabled: !claimed,
      ),
    ],
    cancelLabel: 'Cancel',
    borderColor: context.genesisColors.foregroundStrong.withValues(alpha: 0.14),
  );
  return shouldCheckIn == true;
}

Future<void> showDailyCheckInSuccessDialog(
  BuildContext context, {
  int rewardGems = dailyCheckInPreviewReward,
  Duration duration = dailyCheckInSuccessDuration,
}) async {
  return showGemTaskSuccessDialog(
    context,
    title: 'Check in successful!',
    rewardGems: rewardGems,
    duration: duration,
  );
}

Future<void> showGemTaskSuccessDialog(
  BuildContext context, {
  required String title,
  required int rewardGems,
  Duration duration = dailyCheckInSuccessDuration,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final timer = Timer(duration, () {
    if (navigator.mounted && navigator.canPop()) navigator.pop();
  });
  try {
    await showGenesisActionBox<void>(
      context: context,
      title: title,
      titleContent: _GemTaskReward(rewardGems: rewardGems),
      titleContentSpacing: 10,
      actions: const [],
      showCancel: false,
      borderColor: context.genesisColors.foregroundStrong.withValues(
        alpha: 0.14,
      ),
    );
  } finally {
    timer.cancel();
  }
}

class _GemTaskReward extends StatelessWidget {
  const _GemTaskReward({required this.rewardGems});

  final int rewardGems;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '+$rewardGems',
          key: const ValueKey<String>('gem-task-reward-value'),
          style: GenesisTypography.prominentMetricValue.copyWith(
            color: context.genesisColors.textPrimary,
          ),
        ),
        const SizedBox(width: 7),
        Text(
          'Gems',
          key: const ValueKey<String>('gem-task-reward-icon'),
          style: TextStyle(
            fontSize: 13,
            height: 1,
            fontWeight: FontWeight.w400,
            color: context.genesisColors.textMuted,
          ),
        ),
      ],
    );
  }
}
