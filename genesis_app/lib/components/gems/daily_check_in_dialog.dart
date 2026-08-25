import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../common/genesis_action_box.dart';
import 'gem_assets.dart';
import 'gem_colors.dart';
import '../../ui/theme/genesis_semantic_colors.dart';
import '../../ui/tokens/genesis_typography.dart';

const int dailyCheckInPreviewReward = 50;
const String dailyCheckInTaskCode = 'daily_checkin';
const Duration dailyCheckInSuccessDuration = Duration(seconds: 3);

/// Claim-success card, design 9r: a 38x59 gem over the title, then the reward
/// line and the caption, every block 14 apart inside a 24/22 padded box.
const String gemTaskSuccessCaption = 'Added to your balance';
const double gemTaskSuccessIconWidth = 38;
const double gemTaskSuccessIconHeight = 59;
const double _gemTaskSuccessBlockSpacing = 14;
const double _gemTaskSuccessTitleHeight =
    24 +
    gemTaskSuccessIconHeight +
    _gemTaskSuccessBlockSpacing +
    17 +
    _gemTaskSuccessBlockSpacing +
    30 +
    _gemTaskSuccessBlockSpacing +
    16 +
    24;

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
      titleWidget: _GemTaskSuccessHeading(title: title),
      titleContent: _GemTaskReward(
        rewardGems: rewardGems,
        caption: gemTaskSuccessCaption,
      ),
      titleContentSpacing: _gemTaskSuccessBlockSpacing,
      titleHorizontalPadding: 22,
      titleHeight: _gemTaskSuccessTitleHeight,
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

class _GemTaskSuccessHeading extends StatelessWidget {
  const _GemTaskSuccessHeading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(
          gemIconAsset,
          key: const ValueKey<String>('gem-task-success-icon'),
          width: gemTaskSuccessIconWidth,
          height: gemTaskSuccessIconHeight,
        ),
        const SizedBox(height: _gemTaskSuccessBlockSpacing),
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: GenesisTypography.navigationTitle.copyWith(
            color: context.genesisColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _GemTaskReward extends StatelessWidget {
  const _GemTaskReward({required this.rewardGems, this.caption});

  final int rewardGems;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final captionStyle = TextStyle(
      fontSize: 11,
      height: 1.45,
      fontWeight: FontWeight.w400,
      color: context.genesisColors.textMuted,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
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
                fontWeight: FontWeight.w500,
                color: context.genesisColors.textMuted,
              ),
            ),
          ],
        ),
        if (caption case final caption?) ...[
          const SizedBox(height: _gemTaskSuccessBlockSpacing),
          Text(
            caption,
            key: const ValueKey<String>('gem-task-reward-caption'),
            textAlign: TextAlign.center,
            style: captionStyle,
          ),
        ],
      ],
    );
  }
}
