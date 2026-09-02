import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
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
    final result = await api.v1.origin.launch(
      oid: origin.oid,
      presetCharacterId: roleSelection.presetCharacterId,
      presetRoleOverride: roleSelection.presetRoleOverride?.toPayload(),
      customRole: roleSelection.customRole?.toPayload(),
    );
    if (!context.mounted) return null;

    final wid = '${result['world_id'] ?? result['wid'] ?? ''}'.trim();
    if (wid.isEmpty) {
      showGenesisToast(context, 'Launch failed');
      return null;
    }
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
