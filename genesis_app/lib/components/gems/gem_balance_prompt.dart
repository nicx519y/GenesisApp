import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/gems/gem_wallet_store.dart';
import '../../network/chatroom/world_chatroom_service.dart';
import '../../platform/billing/billing_service.dart';
import 'gem_purchase_bottom_sheet.dart';

const String insufficientGemBalancePrompt = 'Insufficient Gems';
const String lowGemBalancePrompt = 'Low Gems';
const String gemPurchaseSheetTriggerTick = 'tick_no_balance';
const String gemPurchaseSheetTriggerMessageLowBalance = 'msg_low_balance';
const String gemPurchaseSheetTriggerMessageNoBalance = 'msg_no_balance';

StreamSubscription<GemBalanceAlert> bindGemBalancePrompt(
  BuildContext context,
  Stream<GemBalanceAlert> alerts,
) {
  var promptVisible = false;
  return alerts.listen((alert) {
    if (promptVisible || !context.mounted) return;
    promptVisible = true;
    unawaited(
      showGemBalancePrompt(
        context,
        alert,
      ).whenComplete(() => promptVisible = false),
    );
  });
}

Future<void> showGemBalancePrompt(
  BuildContext context,
  GemBalanceAlert alert, {
  String? analyticsTrigger,
  GemPurchaseProductsLoader? productsLoader,
  GemWalletStore? walletStore,
  BillingService? billingService,
}) {
  return showGemPurchaseBottomSheet(
    context,
    alert: alert,
    analyticsTrigger: _resolvedGemPurchaseSheetTrigger(alert, analyticsTrigger),
    productsLoader: productsLoader,
    walletStore: walletStore,
    billingService: billingService,
  );
}

String _resolvedGemPurchaseSheetTrigger(
  GemBalanceAlert alert,
  String? analyticsTrigger,
) {
  final trigger = analyticsTrigger?.trim() ?? '';
  if (trigger.isNotEmpty) return trigger;
  return switch (alert.kind) {
    GemBalanceAlertKind.low => gemPurchaseSheetTriggerMessageLowBalance,
    GemBalanceAlertKind.insufficient => gemPurchaseSheetTriggerMessageNoBalance,
  };
}
