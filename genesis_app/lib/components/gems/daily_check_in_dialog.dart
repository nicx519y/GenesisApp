import '../../l10n/genesis_l10n.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/membership/subscription_analytics.dart';
import '../../app/bootstrap/app_services_scope.dart';
import '../../app/membership/membership_access_store.dart';
import '../../app/membership/membership_purchase_service.dart';
import '../common/genesis_action_box.dart';
import 'gem_assets.dart';
import '../../ui/tokens/genesis_colors.dart';
import 'gem_purchase_bottom_sheet.dart';
import 'gem_task_reward.dart';

const int dailyCheckInPreviewRewardCent = 5000;
const String dailyCheckInTaskCode = 'daily_checkin';
const Duration dailyCheckInSuccessDuration = Duration(seconds: 3);

enum DailyCheckInDialogStatus { checkIn, claimed }

enum _DailyCheckInAction { subscribe, checkIn }

Future<bool> showDailyCheckInDialog(
  BuildContext context, {
  required DailyCheckInDialogStatus status,
  int rewardGemsCent = dailyCheckInPreviewRewardCent,
  MembershipAccessStore? membershipAccess,
  MembershipPurchaseService? membershipPurchases,
}) async {
  final claimed = status == DailyCheckInDialogStatus.claimed;
  final services = AppServicesScope.maybeRead(context);
  final session = services?.sessionRevision.value;
  final route = ModalRoute.of(context);
  final membership = membershipAccess ?? services?.membership;
  final purchases = membershipPurchases ?? services?.membershipPurchases;
  bool? isVip = false;
  if (!claimed && purchases != null) {
    try {
      final settled = await purchases.waitForGuestClaim().timeout(
        membership?.requestTimeout ?? const Duration(seconds: 20),
      );
      if (!settled) isVip = null;
    } catch (_) {
      isVip = null;
    }
    if (!context.mounted ||
        route?.isCurrent == false ||
        !identical(services, AppServicesScope.maybeRead(context)) ||
        services?.sessionRevision.value != session) {
      return false;
    }
  }
  if (!claimed && membership != null && isVip != null) {
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
  // Unknown membership uses the non-member dialog as a presentation fallback.
  final showSubscriptionOffer =
      status == DailyCheckInDialogStatus.checkIn && isVip != true;
  final action = await showGenesisActionBox<_DailyCheckInAction>(
    context: context,
    title: GenesisL10n
        .current
        .meDailyCheck,
    titleContent: GemTaskReward(
      rewardGemsCent: rewardGemsCent,
      showWholeReward: true,
    ),
    titleContentSpacing: 10,
    actions: [
      if (showSubscriptionOffer)
        GenesisActionBoxAction<_DailyCheckInAction>(
          label: GenesisL10n
              .current
              .gemsDailyCheckInReward,
          value: _DailyCheckInAction.subscribe,
          color: GenesisColors.redSecondary,
          trailing: SvgPicture.asset(
            gemIconAsset,
            key: const ValueKey('daily-check-in-subscription-gem'),
            width: gemSmallIconSize,
            height: gemSmallIconSize,
            excludeFromSemantics: true,
          ),
        ),
      if (showSubscriptionOffer)
        GenesisActionBoxAction<_DailyCheckInAction>(
          label: GenesisL10n
              .current
              .meCheck,
          value: _DailyCheckInAction.checkIn,
          color: GenesisColors.darkTextPrimary,
          fontWeight: FontWeight.w400,
        )
      else
        GenesisActionBoxAction<_DailyCheckInAction>(
          label: switch (status) {
            DailyCheckInDialogStatus.checkIn =>
              GenesisL10n
                  .current
                  .meCheck,
            DailyCheckInDialogStatus.claimed =>
              GenesisL10n
                  .current
                  .gemsClaimed,
          },
          value: _DailyCheckInAction.checkIn,
          enabled: !claimed,
        ),
    ],
    cancelLabel: GenesisL10n.current.searchCancel,
    showCancel: !showSubscriptionOffer,
  );
  if (action == _DailyCheckInAction.subscribe && context.mounted) {
    await showSubscriptionPurchaseBottomSheet(
      context,
      source: SubscriptionSource.dailyCheckIn,
    );
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
    title: GenesisL10n
        .current
        .meCheckSuccessful,
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
      titleContent: GemTaskReward(
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
