import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../components/common/genesis_center_toast.dart';
import '../../components/origin/origin_role_launch_sheet.dart';
import '../../components/world_tick1_wait_dialog.dart';
import '../../network/models/origin.dart';
import '../../network/models/world.dart';

Future<WorldDetail?> launchOriginAndWaitForFirstTick({
  required BuildContext context,
  required OriginDetail origin,
  required OriginRoleLaunchSelection roleSelection,
}) async {
  try {
    final result = await AppServicesScope.of(context).api.v1.origin.launch(
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

    final world = await showWorldTick1WaitDialog(
      context: context,
      loadWorld: () => AppServicesScope.read(context).api.getWorld(wid),
    );
    if (world == null) return null;
    return world.worldId.trim().isEmpty ? world.copyWith(worldId: wid) : world;
  } catch (_) {
    if (context.mounted) {
      showGenesisToast(context, 'Launch failed');
    }
    return null;
  }
}
