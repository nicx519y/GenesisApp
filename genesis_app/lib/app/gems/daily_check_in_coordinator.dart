import 'dart:async';

import 'package:flutter/material.dart';

import '../../components/common/genesis_center_toast.dart';
import '../../components/gems/daily_check_in_dialog.dart';
import '../../network/models/gem_task.dart';
import '../../network/models/gem_task_action.dart';
import '../bootstrap/app_services_scope.dart';

typedef DailyCheckInTaskAction = Future<GemTaskActionResult> Function();
typedef DailyCheckInWalletRefresh = Future<void> Function();

Future<void> showDailyCheckInAfterLogin(BuildContext context) async {
  if (!context.mounted) return;
  final services = AppServicesScope.read(context);
  late final GemTask? task;
  try {
    task = _findDailyCheckInTask((await services.api.v1.gem.tasks()).groups);
  } catch (_) {
    return;
  }
  if (task == null || !context.mounted) return;

  await runDailyCheckInFlow(
    context,
    task: task,
    reportTask: () => services.api.v1.gem.reportTask(dailyCheckInTaskCode),
    claimTask: () => services.api.v1.gem.claimTask(dailyCheckInTaskCode),
    refreshWallet: services.gemWallet.refresh,
  );
}

Future<void> runDailyCheckInFlow(
  BuildContext context, {
  required GemTask task,
  required DailyCheckInTaskAction reportTask,
  required DailyCheckInTaskAction claimTask,
  required DailyCheckInWalletRefresh refreshWallet,
}) async {
  var status = _dialogStatusForValue(task.status);
  if (status == DailyCheckInDialogStatus.claimed) return;
  while (context.mounted) {
    final shouldAct = await showDailyCheckInDialog(
      context,
      status: status,
      rewardGems: task.rewardGems,
    );
    if (!shouldAct || !context.mounted) return;

    try {
      final actionStatus = status;
      final action = switch (status) {
        DailyCheckInDialogStatus.checkIn => reportTask(),
        DailyCheckInDialogStatus.claim => claimTask(),
        DailyCheckInDialogStatus.claimed => null,
      };
      if (action == null) return;
      status = _dialogStatusForValue((await action).status);
      if (actionStatus == DailyCheckInDialogStatus.checkIn &&
          status == DailyCheckInDialogStatus.claim) {
        status = _dialogStatusForValue((await claimTask()).status);
      }
      if (!context.mounted) return;
      if (status == DailyCheckInDialogStatus.claimed) {
        final successDialog = showDailyCheckInSuccessDialog(
          context,
          rewardGems: task.rewardGems,
        );
        unawaited(refreshWallet());
        await successDialog;
        return;
      }
    } catch (_) {
      if (!context.mounted) return;
      showGenesisToast(
        context,
        status == DailyCheckInDialogStatus.claim
            ? 'Claim failed.'
            : 'Check in failed.',
      );
      return;
    }
  }
}

GemTask? _findDailyCheckInTask(List<GemTaskGroup> groups) {
  for (final group in groups) {
    for (final task in group.tasks) {
      if (task.taskCode.trim() == dailyCheckInTaskCode) return task;
    }
  }
  return null;
}

DailyCheckInDialogStatus _dialogStatusForValue(String value) {
  return switch (value.trim().toLowerCase()) {
    'claimed' => DailyCheckInDialogStatus.claimed,
    'claimable' => DailyCheckInDialogStatus.claim,
    _ => DailyCheckInDialogStatus.checkIn,
  };
}
