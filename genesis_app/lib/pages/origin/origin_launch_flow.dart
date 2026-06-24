import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
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
    final api = AppServicesScope.of(context).api;
    final launchCoordinator = coordinator ?? OriginLaunchCoordinator.instance;
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
