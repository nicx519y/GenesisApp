import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../app/recent_chat/recent_world_chat_store.dart';
import '../../app/telemetry/genesis_telemetry.dart';
import '../../components/common/genesis_center_toast.dart';
import '../../components/origin/origin_role_launch_sheet.dart';
import '../../network/models/origin.dart';
import 'origin_launch_coordinator.dart';

Future<bool> startOriginLaunch({
  required BuildContext context,
  required OriginDetail origin,
  required OriginRoleLaunchSelection roleSelection,
  OriginLaunchCoordinator? coordinator,
}) async {
  try {
    final services = AppServicesScope.of(context);
    final api = services.api;
    final launchCoordinator = coordinator ?? OriginLaunchCoordinator.instance;
    GenesisTelemetry.collectLog(
      actionType: 'event',
      action: 'worldo_launch_submit_start',
      object1: origin.oid,
    );
    final result = await api.v1.origin.launch(
      oid: origin.oid,
      presetCharacterId: roleSelection.presetCharacterId,
      customRole: roleSelection.customRole?.toPayload(),
    );
    if (!context.mounted) return false;

    final wid = '${result['world_id'] ?? result['wid'] ?? ''}'.trim();
    if (wid.isEmpty) {
      showGenesisToast(context, 'Launch failed');
      return false;
    }
    final uid = await resolveRecentWorldChatUid(services);
    if (!context.mounted) return false;
    unawaited(worldActivityTagStore.markLastLaunch(uid: uid, worldId: wid));
    GenesisTelemetry.collectLog(
      actionType: 'event',
      action: 'worldo_launch_submit_success',
      object1: origin.oid,
      object2: wid,
    );

    await launchCoordinator.start(
      originId: origin.oid,
      worldId: wid,
      loadWorld: api.getWorld,
      context: context,
    );
    return true;
  } catch (_) {
    if (context.mounted) {
      showGenesisToast(context, 'Launch failed');
    }
    return false;
  }
}
