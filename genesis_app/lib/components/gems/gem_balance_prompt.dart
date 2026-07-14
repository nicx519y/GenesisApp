import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/gems/gem_wallet_store.dart';
import '../../network/chatroom/world_chatroom_service.dart';
import '../../platform/billing/billing_service.dart';
import 'gem_purchase_bottom_sheet.dart';

const String insufficientGemBalancePrompt = 'Not enough Gems';
const String lowGemBalancePrompt = 'Low on Gems';

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
  GemPurchaseProductsLoader? productsLoader,
  GemWalletStore? walletStore,
  BillingService? billingService,
}) {
  return showGemPurchaseBottomSheet(
    context,
    alert: alert,
    productsLoader: productsLoader,
    walletStore: walletStore,
    billingService: billingService,
  );
}
