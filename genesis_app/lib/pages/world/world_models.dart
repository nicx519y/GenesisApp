import 'package:flutter/material.dart';

import 'world_constants.dart';

enum WorldBottomSheetKind { detail, locations, events, status, cast }

String worldBottomSheetPageName(WorldBottomSheetKind kind) {
  return switch (kind) {
    WorldBottomSheetKind.detail => 'world_detail',
    WorldBottomSheetKind.locations => 'world_locations',
    WorldBottomSheetKind.events => 'world_events',
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

const worldBottomTagItems = <WorldBottomTagItem>[
  WorldBottomTagItem(
    label: 'Detail',
    kind: WorldBottomSheetKind.detail,
    asset: worldDetailIconAsset,
  ),
  WorldBottomTagItem(
    label: 'Locations',
    kind: WorldBottomSheetKind.locations,
    icon: Icons.place_outlined,
  ),
  WorldBottomTagItem(
    label: 'Events',
    kind: WorldBottomSheetKind.events,
    asset: worldSectionEventsIconAsset,
  ),
  WorldBottomTagItem(
    label: 'Status',
    kind: WorldBottomSheetKind.status,
    asset: worldSectionStatusIconAsset,
  ),
];

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
      return const WorldHeaderAction(
        WorldHeaderActionKind.request,
        'Request',
        true,
      );
    case 'pending':
      return const WorldHeaderAction(
        WorldHeaderActionKind.pending,
        'Requested',
        false,
      );
    case 'approved':
      return const WorldHeaderAction(
        WorldHeaderActionKind.launch,
        'Launch',
        true,
      );
    case 'owner':
    case 'joined':
      return const WorldHeaderAction(
        WorldHeaderActionKind.progress,
        'Progress',
        true,
      );
    default:
      return const WorldHeaderAction(
        WorldHeaderActionKind.unavailable,
        'Unavailable',
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
      return 'Request';
    case WorldHeaderActionKind.launch:
      return 'Launch';
    case WorldHeaderActionKind.progress:
      return 'Progress';
    case WorldHeaderActionKind.pending:
      return 'Requested';
    case WorldHeaderActionKind.unavailable:
      return 'Unavailable';
  }
}
