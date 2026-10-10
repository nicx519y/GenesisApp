import '../../l10n/genesis_l10n.dart';
import 'package:flutter/material.dart';

import 'world_constants.dart';
import '../../network/models/origin.dart';
import '../../network/json_utils.dart';
import 'world_value_helpers.dart';

enum WorldBottomSheetKind { detail, locations, events, recap, status, cast }

String worldBottomSheetPageName(WorldBottomSheetKind kind) {
  return switch (kind) {
    WorldBottomSheetKind.detail => 'world_detail_shell',
    WorldBottomSheetKind.locations => 'world_locations',
    WorldBottomSheetKind.events => 'world_events',
    WorldBottomSheetKind.recap => 'world_recap',
    WorldBottomSheetKind.status => 'world_status',
    WorldBottomSheetKind.cast => 'world_cast',
  };
}

class WorldBottomSheetSelection {
  const WorldBottomSheetSelection({
    required this.kind,
    required this.eventsLatestRevision,
    this.eventsTargetTickNumber,
  });

  final WorldBottomSheetKind kind;
  final int eventsLatestRevision;
  final int? eventsTargetTickNumber;
}

class WorldBottomTagItem {
  const WorldBottomTagItem({
    required this.label,
    required this.kind,
    this.asset,
    this.icon,
  });

  final String label;
  final WorldBottomSheetKind kind;
  final String? asset;
  final IconData? icon;
}

class WorldNewUserJoinNotice {
  const WorldNewUserJoinNotice({
    required this.characterId,
    required this.characterType,
    required this.characterName,
    required this.playerUid,
    this.playerUser = const OriginUserInfo(),
    required this.playerUsername,
    required this.ts,
  });

  final String characterId;
  final String characterType;
  final String characterName;
  final String playerUid;
  final OriginUserInfo playerUser;
  final String playerUsername;
  final DateTime? ts;

  factory WorldNewUserJoinNotice.fromCharacter(Map<String, dynamic> character) {
    return WorldNewUserJoinNotice(
      playerUser: OriginUserInfo.fromJson(
        asOptionalJsonMap(character['player_user']),
      ),
      characterId: worldMapString(character, const ['char_id', 'id']),
      characterType: worldMapString(character, const ['type']),
      characterName: worldMapString(character, const ['name']),
      playerUid: worldMapString(character, const ['player_uid']),
      playerUsername: worldMapString(character, const ['player_username']),
      ts: null,
    );
  }

  String get displayPlayerUsername {
    final username = playerUsername.trim();
    if (username.isNotEmpty) return username;
    return GenesisL10n.current.someoneFallback;
  }

  String get displayCharacterName {
    final name = characterName.trim();
    if (name.isNotEmpty) return name;
    return GenesisL10n.current.aCharacterFallback;
  }
}

WorldNewUserJoinNotice? worldLatestPlayerJoinNotice(
  List<Map<String, dynamic>> characters,
) {
  Map<String, dynamic>? latestCharacter;
  var latestJoinedAt = 0;
  for (final character in characters) {
    final playerUid = worldMapString(character, const ['player_uid']);
    if (playerUid.isEmpty) continue;
    final rawJoinedAt = character['player_joined_at'];
    final joinedAt = rawJoinedAt is num
        ? rawJoinedAt.toInt()
        : int.tryParse('$rawJoinedAt'.trim()) ?? 0;
    if (joinedAt <= 0 || joinedAt < latestJoinedAt) continue;
    latestJoinedAt = joinedAt;
    latestCharacter = character;
  }
  if (latestCharacter == null) return null;
  return WorldNewUserJoinNotice.fromCharacter(latestCharacter);
}

final worldBottomTagItems = <WorldBottomTagItem>[
  WorldBottomTagItem(
    label: GenesisL10n.current.worldModelsDetail,
    kind: WorldBottomSheetKind.detail,
    asset: worldDetailIconAsset,
  ),
  WorldBottomTagItem(
    label: GenesisL10n.current.worldModelsLocations,
    kind: WorldBottomSheetKind.locations,
    icon: Icons.place_outlined,
  ),
  WorldBottomTagItem(
    label: GenesisL10n.current.worldModelsEvents,
    kind: WorldBottomSheetKind.events,
    asset: worldSectionEventsIconAsset,
  ),
  WorldBottomTagItem(
    label: GenesisL10n.current.worldRecap,
    kind: WorldBottomSheetKind.recap,
    icon: Icons.auto_stories_outlined,
  ),
  WorldBottomTagItem(
    label: GenesisL10n.current.worldModelsStatus,
    kind: WorldBottomSheetKind.status,
    asset: worldSectionStatusIconAsset,
  ),
];

String get worldParticipationRequiredMessage =>
    GenesisL10n.current.chatRequestApprovalLaunch;

bool canAccessWorldSection(WorldBottomSheetKind kind, String relationStatus) {
  switch (kind) {
    case WorldBottomSheetKind.events:
    case WorldBottomSheetKind.recap:
    case WorldBottomSheetKind.status:
      return shouldConnectWorldChatroom(relationStatus);
    default:
      return true;
  }
}

enum WorldHeaderActionKind { request, pending, launch, progress, unavailable }

class WorldHeaderAction {
  const WorldHeaderAction(this.kind, this.label, this.isClickable);

  final WorldHeaderActionKind kind;
  final String label;
  final bool isClickable;
}

WorldHeaderAction worldHeaderActionFor(String relationStatus) {
  switch (relationStatus.trim().toLowerCase()) {
    case 'anonymous':
    case 'reject':
    case 'rejected':
    case 'none':
      return WorldHeaderAction(
        WorldHeaderActionKind.request,
        GenesisL10n.current.requestAction,
        true,
      );
    case 'pending':
      return WorldHeaderAction(
        WorldHeaderActionKind.pending,
        GenesisL10n.current.requestedStatus,
        false,
      );
    case 'approved':
      return WorldHeaderAction(
        WorldHeaderActionKind.launch,
        GenesisL10n.current.launchAction,
        true,
      );
    case 'owner':
    case 'joined':
      return WorldHeaderAction(
        WorldHeaderActionKind.progress,
        GenesisL10n.current.tickNowAction,
        true,
      );
    default:
      return WorldHeaderAction(
        WorldHeaderActionKind.unavailable,
        GenesisL10n.current.worldDetailUnavailable,
        false,
      );
  }
}

bool shouldConnectWorldChatroom(String relationStatus) {
  switch (relationStatus.trim().toLowerCase()) {
    case 'owner':
    case 'joined':
      return true;
    default:
      return false;
  }
}

String worldHeaderActionLabel(WorldHeaderActionKind action) {
  switch (action) {
    case WorldHeaderActionKind.request:
      return GenesisL10n.current.requestAction;
    case WorldHeaderActionKind.launch:
      return GenesisL10n.current.launchAction;
    case WorldHeaderActionKind.progress:
      return GenesisL10n.current.tickNowAction;
    case WorldHeaderActionKind.pending:
      return GenesisL10n.current.requestedStatus;
    case WorldHeaderActionKind.unavailable:
      return GenesisL10n.current.worldDetailUnavailable;
  }
}
