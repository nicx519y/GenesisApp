import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../app/membership/membership_access_store.dart';
import '../common/genesis_action_box.dart';
import 'gem_assets.dart';
import '../../ui/tokens/genesis_colors.dart';
import 'gem_purchase_bottom_sheet.dart';
import '../../utils/gem_amount.dart';

const int dailyCheckInPreviewRewardCent = 5000;
const String dailyCheckInTaskCode = 'daily_checkin';
const Duration dailyCheckInSuccessDuration = Duration(seconds: 3);

enum DailyCheckInDialogStatus { checkIn, claim, claimed }

enum _DailyCheckInAction { subscribe, checkIn, cancel }

Future<bool> showDailyCheckInDialog(
  BuildContext context, {
  required DailyCheckInDialogStatus status,
  int rewardGemsCent = dailyCheckInPreviewRewardCent,
  MembershipAccessStore? membershipAccess,
}) async {
  final claimed = status == DailyCheckInDialogStatus.claimed;
  final services = AppServicesScope.maybeRead(context);
  final session = services?.sessionRevision.value;
  final route = ModalRoute.of(context);
  final membership = membershipAccess ?? services?.membership;
  bool? isVip = false;
  if (!claimed && membership != null) {
    final result = Completer<bool?>();
    membership.checkVip(result.complete);
    isVip = await result.future;
    if (!context.mounted ||
        route?.isCurrent == false ||
        !identical(services, AppServicesScope.maybeRead(context)) ||
        services?.sessionRevision.value != session) {
      return false;
    }
  }
  // Only confirmed non-members see the subscription offer. An unavailable
  // membership lookup must not promote another subscription to an existing VIP.
  final showSubscriptionOffer =
      status == DailyCheckInDialogStatus.checkIn && isVip == false;
  final showCheckInActions = showSubscriptionOffer || isVip == true && !claimed;
  final action = await showGenesisActionBox<_DailyCheckInAction>(
    context: context,
    title: 'Daily Check-in',
    titleContent: _GemTaskReward(
      rewardGemsCent: rewardGemsCent,
      showWholeReward: true,
    ),
    titleContentSpacing: 10,
    actions: [
      if (showCheckInActions)
        GenesisActionBoxAction<_DailyCheckInAction>(
          label: showSubscriptionOffer ? 'Get 100' : 'Cancel',
          value: showSubscriptionOffer
              ? _DailyCheckInAction.subscribe
              : _DailyCheckInAction.cancel,
          color: GenesisColors.redSecondary,
          trailing: showSubscriptionOffer
              ? SvgPicture.asset(
                  gemIconAsset,
                  key: const ValueKey('daily-check-in-subscription-gem'),
                  width: gemSmallIconSize,
                  height: gemSmallIconSize,
                  excludeFromSemantics: true,
                )
              : null,
        ),
      GenesisActionBoxAction<_DailyCheckInAction>(
        label: switch (status) {
          DailyCheckInDialogStatus.checkIn => 'Check in',
          DailyCheckInDialogStatus.claim =>
            isVip == true ? 'Check in' : 'Claim',
          DailyCheckInDialogStatus.claimed => 'Claimed',
        },
        value: _DailyCheckInAction.checkIn,
        fontWeight: showCheckInActions ? FontWeight.w400 : FontWeight.w600,
        color: claimed
            ? GenesisColors.darkTextTertiary
            : showCheckInActions
            ? GenesisColors.darkTextPrimary
            : GenesisColors.redSecondary,
        enabled: !claimed,
      ),
    ],
    cancelLabel: 'Cancel',
    showCancel: !showCheckInActions,
  );
  if (action == _DailyCheckInAction.subscribe && context.mounted) {
    await showSubscriptionPurchaseBottomSheet(context);
  }
  return action == _DailyCheckInAction.checkIn;
}

Future<void> showDailyCheckInSuccessDialog(
  BuildContext context, {
  int rewardGemsCent = dailyCheckInPreviewRewardCent,
  Duration duration = dailyCheckInSuccessDuration,
}) async {
  return showGemTaskSuccessDialog(
    context,
    title: 'Check in successful!',
    rewardGemsCent: rewardGemsCent,
    duration: duration,
  );
}

Future<void> showGemTaskSuccessDialog(
  BuildContext context, {
  required String title,
  required int rewardGemsCent,
  Duration duration = dailyCheckInSuccessDuration,
  bool showWholeReward = true,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final timer = Timer(duration, () {
    if (navigator.mounted && navigator.canPop()) navigator.pop();
  });
  try {
    await showGenesisActionBox<void>(
      context: context,
      title: title,
      titleContent: _GemTaskReward(
        rewardGemsCent: rewardGemsCent,
        showWholeReward: showWholeReward,
      ),
      titleContentSpacing: 10,
      actions: const [],
      showCancel: false,
    );
  } finally {
    timer.cancel();
  }
}

class _GemTaskReward extends StatelessWidget {
  const _GemTaskReward({
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
