import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../app/bootstrap/service_registry.dart';
import '../../app/recent_chat/recent_world_chat_store.dart';
import '../../app/telemetry/genesis_telemetry.dart';
import '../../components/common/genesis_action_box.dart';
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

Future<bool> showOriginLaunchSuccessPrompt({
  required BuildContext context,
  required String worldId,
}) async {
  final normalizedWorldId = worldId.trim();
  final title = 'Worldo #$normalizedWorldId launched!';
  final shouldEnter = await showGenesisActionBox<bool>(
    context: context,
    title: title,
    titleWidget: _originLaunchSuccessTitle(normalizedWorldId),
    actions: const [GenesisActionBoxAction<bool>(label: 'Enter', value: true)],
  );
  return shouldEnter == true;
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

Widget _originLaunchSuccessTitle(String worldId) {
  const baseStyle = TextStyle(
    color: Color(0xFF111111),
    fontSize: 15,
    height: 1.16,
    fontWeight: FontWeight.w600,
  );
  return RichText(
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    textAlign: TextAlign.center,
    text: TextSpan(
      style: baseStyle,
      children: [
        const TextSpan(text: 'Worldo '),
        TextSpan(
          text: '#$worldId',
          style: baseStyle.copyWith(color: const Color(0xFF4B6192)),
        ),
        const TextSpan(text: ' launched!'),
      ],
    ),
  );
}
