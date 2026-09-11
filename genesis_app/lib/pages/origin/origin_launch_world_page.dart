import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/telemetry/genesis_telemetry.dart';
import '../../components/chat/shared/chat_ui.dart';
import '../../components/origin/origin_role_launch_sheet.dart';
import '../../network/chatroom/world_chatroom_service.dart';
import '../../network/models/origin.dart';
import '../chat/location_chat_page.dart';
import '../world/world_location_chat_host.dart';
import '../world/world_page.dart';
import 'origin_launch_flow.dart';

/// Everything needed to render the opening and outgoing message before Launch.
class OriginLaunchEntry {
  const OriginLaunchEntry({
    required this.origin,
    required this.roleSelection,
    required this.telemetryRoleId,
    required this.location,
    required this.message,
    required this.mentionCatalog,
    required this.openingPreviewMessages,
    required this.openingPreviewEntities,
  });

  final OriginDetail origin;
  final OriginRoleLaunchSelection roleSelection;
  final String telemetryRoleId;
  final WorldLocationChatPanelDescriptor location;
  final ChatMessageVm message;
  final ChatMentionCatalog mentionCatalog;
  final List<WorldChatroomMessage> openingPreviewMessages;
  final List<WorldChatroomEntity> openingPreviewEntities;
}

class OriginLaunchWorldPage extends StatefulWidget {
  const OriginLaunchWorldPage({super.key, required this.entry});

  final OriginLaunchEntry entry;

  @override
  State<OriginLaunchWorldPage> createState() => _OriginLaunchWorldPageState();
}

class _OriginLaunchWorldPageState extends State<OriginLaunchWorldPage> {
  String? _worldId;
  bool _launching = false;
  bool _exited = false;

  @override
  void initState() {
    super.initState();
    // Render the pending bubble before starting the request.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_launch());
    });
  }

  Future<void> _launch() async {
    if (_launching || _worldId != null || _exited) return;
    final entry = widget.entry;
    setState(() {
      _launching = true;
      entry.message.status = 'sending';
      entry.message.error = null;
    });
    GenesisTelemetry.collectLog(
      actionType: 'event',
      action: OriginLaunchSource.openingMessage.startAction,
      object1: entry.origin.oid,
      object2: entry.telemetryRoleId,
    );
    final worldId = await startOriginLaunch(
      context: context,
      origin: entry.origin,
      roleSelection: entry.roleSelection,
      launchSource: OriginLaunchSource.openingMessage,
      shouldHandleResult: () => !_exited,
    );
    if (!mounted || _exited) return;
    setState(() {
      _launching = false;
      _worldId = worldId;
      if (worldId == null) entry.message.status = 'failed';
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _exited = true;
      },
      child: _buildChat(context),
    );
  }

  Widget _buildChat(BuildContext context) {
    final entry = widget.entry;
    return WorldPage(
      wid: _worldId ?? '',
      initialLocationId: entry.location.locationId,
      initialLocationDescriptor: entry.location,
      initialMessageToSend: entry.message.text,
      initialOutgoingMessage: entry.message,
      initialMentionCatalog: entry.mentionCatalog,
      initialOpeningPreview: LocationChatOpeningPreview(
        locationId: entry.location.locationId,
        messages: entry.openingPreviewMessages,
        entities: entry.openingPreviewEntities,
        playerCharacterId: entry.roleSelection.presetCharacterId ?? '',
      ),
      onRetryInitialLaunch: _worldId == null
          ? () => unawaited(_launch())
          : null,
    );
  }
}
