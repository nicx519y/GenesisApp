import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../app/bootstrap/service_registry.dart';
import '../../app/recent_chat/recent_world_chat_store.dart';
import '../../app/telemetry/genesis_telemetry.dart';
import '../../components/common/genesis_center_toast.dart';
import '../../components/origin/origin_role_launch_sheet.dart';
import '../../network/models/origin.dart';

Future<String?> startOriginLaunch({
  required BuildContext context,
  required OriginDetail origin,
  required OriginRoleLaunchSelection roleSelection,
}) async {
  try {
    final services = AppServicesScope.of(context);
    final api = services.api;
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
    if (!context.mounted) return null;

    final wid = '${result['world_id'] ?? result['wid'] ?? ''}'.trim();
    if (wid.isEmpty) {
      showGenesisToast(context, 'Launch failed');
      return null;
    }
    unawaited(_markLaunchedWorldActivity(services, wid));
    GenesisTelemetry.collectLog(
      actionType: 'event',
      action: 'worldo_launch_submit_success',
      object1: origin.oid,
      object2: wid,
    );
    return wid;
  } catch (_) {
    if (context.mounted) {
      showGenesisToast(context, 'Launch failed');
    }
    return null;
  }
}

Future<void> _markLaunchedWorldActivity(
  AppServices services,
  String worldId,
) async {
  try {
    final uid = await resolveRecentWorldChatUid(services);
    await worldActivityTagStore.markLastLaunch(uid: uid, worldId: worldId);
  } catch (_) {
    // Activity metadata must not delay or fail a successful launch.
  }
}
