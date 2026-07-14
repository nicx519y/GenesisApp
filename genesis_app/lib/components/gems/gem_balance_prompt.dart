import 'dart:async';

import 'package:flutter/material.dart';

import '../../network/chatroom/world_chatroom_service.dart';
import '../../routers/app_router.dart';
import '../common/genesis_action_box.dart';

const String insufficientGemBalancePrompt = '余额不足，请先充值';
const String lowGemBalancePrompt = '余额不多了';
const String rechargeGemBalanceAction = '去充值';

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
  GemBalanceAlert alert,
) async {
  final shouldRecharge = await showGenesisActionBox<bool>(
    context: context,
    title: alert.kind == GemBalanceAlertKind.insufficient
        ? insufficientGemBalancePrompt
        : lowGemBalancePrompt,
    actions: const [
      GenesisActionBoxAction<bool>(
        label: rechargeGemBalanceAction,
        value: true,
        color: Color(0xFFFF2D4F),
      ),
    ],
    cancelLabel: '取消',
  );
  if (shouldRecharge != true || !context.mounted) return;
  await Navigator.of(
    context,
    rootNavigator: true,
  ).pushNamed(RouteNames.gemWallet);
}
