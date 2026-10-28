import '../../l10n/genesis_l10n.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/gems/gem_wallet_store.dart';
import '../../network/gem_balance_alert.dart';
import '../../platform/billing/billing_service.dart';
import 'gem_purchase_bottom_sheet.dart';

String get insufficientGemBalancePrompt =>
    GenesisL10n.current.gemBalancePromptInsufficientGems;
String get lowGemBalancePrompt => GenesisL10n.current.gemBalancePromptLowGems;
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

final _balancePrompts = Expando<Future<void>>();

Future<void> showGemBalancePrompt(
  BuildContext context,
  GemBalanceAlert alert, {
  String? analyticsTrigger,
  GemPurchaseProductsLoader? productsLoader,
  GemWalletStore? walletStore,
  BillingService? billingService,
}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  final existing = _balancePrompts[navigator];
  if (existing != null) return existing;
  final completion = Completer<void>();
  _balancePrompts[navigator] = completion.future;
  Future<void> present() async {
    try {
      await showGemPurchaseBottomSheet(
        context,
        analyticsTrigger: _resolvedGemPurchaseSheetTrigger(
          alert,
          analyticsTrigger,
        ),
        productsLoader: productsLoader,
        walletStore: walletStore,
        billingService: billingService,
      );
      completion.complete();
    } catch (error, stack) {
      completion.completeError(error, stack);
    } finally {
      _balancePrompts[navigator] = null;
    }
  }

  unawaited(present());
  return completion.future;
}

String _resolvedGemPurchaseSheetTrigger(
  GemBalanceAlert alert,
  String? analyticsTrigger,
) {
  final trigger = (analyticsTrigger ?? alert.analyticsTrigger)?.trim() ?? '';
  if (trigger.isNotEmpty) return trigger;
  return switch (alert.kind) {
    GemBalanceAlertKind.low => gemPurchaseSheetTriggerMessageLowBalance,
    GemBalanceAlertKind.insufficient => gemPurchaseSheetTriggerMessageNoBalance,
  };
}
