import '../../l10n/genesis_localizations.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/membership/subscription_analytics.dart';
import '../../app/bootstrap/app_services_scope.dart';
import '../../app/membership/membership_access_store.dart';
import '../../app/membership/membership_purchase_service.dart';
import '../../network/models/membership_order_product.dart';
import '../../utils/gem_amount.dart';
import '../common/genesis_action_box.dart';
import 'gem_assets.dart';
import '../../ui/tokens/genesis_colors.dart';
import 'gem_purchase_bottom_sheet.dart';
import 'gem_task_reward.dart';
import '../common/genesis_modal_routes.dart';
import '../../ui/components/genesis_primary_button.dart';
import 'memory_membership_style.dart';

part 'daily_check_in_dialog_view.dart';

const int dailyCheckInPreviewRewardCent = 5000;
const String dailyCheckInTaskCode = 'daily_checkin';
const Duration dailyCheckInSuccessDuration = Duration(seconds: 3);

enum DailyCheckInDialogStatus { checkIn, claimed }

enum _DailyCheckInAction { premium, deluxe, checkIn }

Future<bool> showDailyCheckInDialog(
  BuildContext context, {
  required DailyCheckInDialogStatus status,
  int rewardGemsCent = dailyCheckInPreviewRewardCent,
  int? rewardGemsCentPremium,
  int? rewardGemsCentDeluxe,
  MembershipAccessStore? membershipAccess,
  MembershipPurchaseService? membershipPurchases,
  ValueChanged<List<MembershipType>>? onConfirmed,
}) async {
  final claimed = status == DailyCheckInDialogStatus.claimed;
  final services = AppServicesScope.maybeRead(context);
  final session = services?.sessionRevision.value;
  final route = ModalRoute.of(context);
  final membership = membershipAccess ?? services?.membership;
  final purchases = membershipPurchases ?? services?.membershipPurchases;
  var guestClaimSettled = true;
  if (!claimed && purchases != null) {
    try {
      guestClaimSettled = await purchases.waitForGuestClaim().timeout(
        membership?.requestTimeout ?? const Duration(seconds: 20),
      );
    } catch (_) {
      guestClaimSettled = false;
    }
    if (!context.mounted ||
        route?.isCurrent == false ||
        !identical(services, AppServicesScope.maybeRead(context)) ||
        services?.sessionRevision.value != session) {
      return false;
    }
  }
  ({bool premium, bool deluxe})? activeTiers;
  if (!claimed && membership != null && guestClaimSettled) {
    activeTiers = await membership.checkActiveTiers();
    if (!context.mounted ||
        route?.isCurrent == false ||
        !identical(services, AppServicesScope.maybeRead(context)) ||
        services?.sessionRevision.value != session) {
      return false;
    }
  }
  final offers = <(_DailyCheckInAction, int)>[];
  if (activeTiers != null) {
    final premium = rewardGemsCentPremium;
    final deluxe = rewardGemsCentDeluxe;
    if (!activeTiers.premium && premium != null) {
      offers.add((_DailyCheckInAction.premium, rewardGemsCent + premium));
    }
    if (!activeTiers.deluxe && deluxe != null) {
      offers.add((_DailyCheckInAction.deluxe, rewardGemsCent + deluxe));
    }
  }
  final memberships = [
    if (activeTiers?.premium == true) MembershipType.premium,
    if (activeTiers?.deluxe == true) MembershipType.deluxe,
  ];
  final action = await showGenesisDialog<_DailyCheckInAction>(
    context: context,
    barrierColor: const Color(0x52000000),
    builder: (context) => _DailyCheckInPanel(
      title: context.l10n.meDailyCheck,
      rewardGemsCent: rewardGemsCent,
      memberships: memberships,
      actions: [
        for (final (tier, amount) in offers) ...[
          _DailyCheckInOffer(
            tier: tier == _DailyCheckInAction.premium
                ? MembershipType.premium
                : MembershipType.deluxe,
            amount: amount,
            onPressed: () => Navigator.of(context).pop(tier),
          ),
          const SizedBox(height: 8),
        ],
        if (offers.isNotEmpty) const SizedBox(height: 10),
        GenesisPrimaryButton(
          key: const ValueKey('daily-check-in-confirm'),
          label: claimed ? context.l10n.gemsClaimed : context.l10n.meCheck,
          borderRadius: BorderRadius.circular(8),
          onPressed: claimed
              ? null
              : () => Navigator.of(context).pop(_DailyCheckInAction.checkIn),
        ),
      ],
    ),
  );
  final tier = switch (action) {
    _DailyCheckInAction.premium => MembershipType.premium,
    _DailyCheckInAction.deluxe => MembershipType.deluxe,
    _ => null,
  };
  if (tier != null && context.mounted) {
    await showSubscriptionPurchaseBottomSheet(
      context,
      source: SubscriptionSource.dailyCheckIn,
      initialMembershipType: tier,
    );
  }
  final confirmed = action == _DailyCheckInAction.checkIn;
  if (confirmed) onConfirmed?.call(memberships);
  return confirmed;
}

Future<void> showDailyCheckInSuccessDialog(
  BuildContext context, {
  int rewardGemsCent = dailyCheckInPreviewRewardCent,
  Duration duration = dailyCheckInSuccessDuration,
  List<MembershipType> memberships = const [],
}) async {
  ModalRoute<void>? successRoute;
  final timer = Timer(duration, () {
    final route = successRoute;
    final navigator = route?.navigator;
    if (route == null || navigator == null || !route.isActive) return;
    if (route.isCurrent) {
      navigator.pop();
    } else {
      navigator.removeRoute(route);
    }
  });
  try {
    await showGenesisDialog<void>(
      context: context,
      barrierColor: const Color(0x52000000),
      builder: (context) {
        successRoute = ModalRoute.of<void>(context);
        return _DailyCheckInPanel(
          title: context.l10n.meCheckSuccessful,
          rewardGemsCent: rewardGemsCent,
          memberships: memberships,
        );
      },
    );
  } finally {
    timer.cancel();
  }
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
