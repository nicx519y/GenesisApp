import 'package:flutter/material.dart';

import '../../components/world_map.dart';
import '../../network/json_utils.dart';
import '../../network/models/location_tree.dart';
import '../../ui/components/genesis_avatar.dart';
import 'world_value_helpers.dart';

String worldRootMapImageUrl(
  List<LocationTreeNode<Map<String, dynamic>>> rootLocationNodes,
) {
  for (final node in rootLocationNodes) {
    final url = worldLocationMapImageUrl(node.value);
    if (url.isNotEmpty) return url;
  }
  return '';
}

List<WorldPoint> worldPointsFromLocationNodes(
  List<LocationTreeNode<Map<String, dynamic>>> nodes,
  Map<String, List<UserAvatar>> avatarsByLocation,
  ProcessedLocationTree<Map<String, dynamic>> processedLocationTree,
) {
  return worldPointsFromLocations(
    nodes.map((node) => node.value).toList(growable: false),
    avatarsByLocation,
    depths: nodes.map((node) => node.depth).toList(growable: false),
    isLeafLocations: nodes
        .map((node) => node.children.isEmpty)
        .toList(growable: false),
    usersByIndex: nodes
        .map(
          (node) => processedLocationTree.aggregateValues<UserAvatar>(
            node.id,
            avatarsByLocation,
            idOf: worldMapAvatarStableId,
          ),
        )
        .toList(growable: false),
  );
}

List<WorldMapLocationNode> worldMapLocationNodes(
  List<LocationTreeNode<Map<String, dynamic>>> nodes,
  Map<String, List<UserAvatar>> avatarsByLocation,
  ProcessedLocationTree<Map<String, dynamic>> processedLocationTree, {
  bool markAsMapRoot = true,
}) {
  return nodes
      .map((node) {
        return WorldMapLocationNode(
          id: node.id,
          isRoot: markAsMapRoot && node.children.isNotEmpty,
          point: worldPointsFromLocationNodes(
            [node],
            avatarsByLocation,
            processedLocationTree,
          ).first,
          mapImageUrl: worldLocationMapImageUrl(node.value),
          children: worldMapLocationNodes(
            node.children,
            avatarsByLocation,
            processedLocationTree,
            markAsMapRoot: false,
          ),
        );
      })
      .toList(growable: false);
}

String worldLocationMapImageUrl(
  Map<String, dynamic> location, {
  String fallback = '',
}) {
  final url = worldResolveAssetUrl(
    worldMapString(location, const ['map_url', 'mapUrl']),
  );
  return url.isEmpty ? fallback : url;
}

String worldLocationChatImageUrl(
  Map<String, dynamic> location, {
  required String preferredKey,
}) {
  final image = worldMapValue(location, const ['image']);
  if (image is Map) {
    final imageMap = asJsonMap(image);
    final preferredUrl = worldResolveAssetUrl(
      worldMapString(imageMap, [preferredKey]),
    );
    if (preferredUrl.isNotEmpty) return preferredUrl;

    final fallbackUrl = worldResolveAssetUrl(
      worldMapString(imageMap, const ['xl_url', 'sm_url', 'url', 'image_url']),
    );
    if (fallbackUrl.isNotEmpty) return fallbackUrl;
  }

  final iconUrl = worldResolveAssetUrl(
    worldMapString(location, const ['icon']),
  );
  if (iconUrl.isNotEmpty) return iconUrl;

  return worldLocationMapImageUrl(location);
}

Map<String, List<UserAvatar>> worldAvatarsByLocationFromCharacterPositions(
  List<Map<String, dynamic>> characterPositions, {
  required String currentUid,
}) {
  final map = <String, List<UserAvatar>>{};
  for (final cp in characterPositions) {
    final rawLocationId = cp['location_id'] ?? cp['current_location_id'];
    final locationId = '$rawLocationId'.trim();
    if (locationId.isEmpty) continue;
    final character = cp['character'];
    if (character is! Map) continue;
    final c = character.map((key, value) => MapEntry('$key', value));
    if (worldIsCurrentUserCharacter(c, currentUid)) continue;
    final name = (c['name'] ?? '').toString();
    final avatar = worldResolveAssetUrl((c['avatar'] ?? '').toString());
    final showStar = worldMapCharacterShouldShowStarForTesting(c);
    final isPlayerControlledRole = worldMapString(c, const [
      'player_uid',
      'user_id',
      'uid',
    ]).isNotEmpty;
    final id = worldMapString(c, const [
      'character_id',
      'char_id',
      'id',
      'uid',
      'player_uid',
    ]);
    (map[locationId] ??= <UserAvatar>[]).add(
      UserAvatar(
        worldInitials(name),
        id: id,
        name: name,
        avatarUrl: avatar,
        showStar: showStar,
        isPlayerControlledRole: isPlayerControlledRole,
      ),
    );
  }
  return map;
}

@visibleForTesting
bool worldMapCharacterShouldShowStarForTesting(Map<String, dynamic> character) {
  final type = character['type'];
  final isAiRole = type is num
      ? type == 1
      : {'1', 'ai'}.contains('$type'.trim().toLowerCase());
  final playerUid = worldMapString(character, const ['player_uid']);
  return isAiRole && playerUid.isEmpty;
}

String worldInitials(String name) {
  return initialsForAvatarName(name);
}

List<Map<String, dynamic>> worldRootWorldLocations(
  List<Map<String, dynamic>> locations,
) {
  return locations
      .where(
        (location) => worldMapString(location, const ['location_pid']).isEmpty,
      )
      .toList(growable: false);
}

List<WorldPoint> worldPointsFromLocations(
  List<Map<String, dynamic>> locations,
  Map<String, List<UserAvatar>> avatarsByLocation, {
  List<int>? depths,
  List<bool>? isLeafLocations,
  List<List<UserAvatar>>? usersByIndex,
}) {
  if (locations.isEmpty) return const <WorldPoint>[];

  return List<WorldPoint>.generate(locations.length, (i) {
    final l = locations[i];
    final locationId = '${l['location_id'] ?? ''}'.trim();
    final pointId = '${l['point_id'] ?? locationId}'.trim();
    final id = pointId.isNotEmpty
        ? pointId
        : (locationId.isNotEmpty ? locationId : '$i');
    final name = (l['location_name'] ?? '').toString();
    final locationSummary = worldMapString(l, const ['location_summary']);
    final locationDescription = worldMapString(l, const [
      'location_description',
    ]);
    final description = locationSummary.isNotEmpty ? locationSummary : '';
    final descriptionFallback = locationDescription;
    final icon = worldResolveAssetUrl((l['icon'] ?? '').toString());

    final rawXP = l['x_percent'];
    final rawYP = l['y_percent'];
    final xPercent = rawXP is num
        ? rawXP.toDouble()
        : double.tryParse('$rawXP') ?? 0;
    final yPercent = rawYP is num
        ? rawYP.toDouble()
        : double.tryParse('$rawYP') ?? 0;

    double? dx;
    double? dy;
    if (xPercent > 0 && yPercent > 0) {
      dx = xPercent / 100;
      dy = yPercent / 100;
    } else {
      final posX = l['x'] ?? l['pos_x'] ?? l['position_x'];
      final posY = l['y'] ?? l['pos_y'] ?? l['position_y'];
      dx = posX is num ? posX.toDouble() : double.tryParse('$posX');
      dy = posY is num ? posY.toDouble() : double.tryParse('$posY');
    }

    if (dx == null || dy == null) {
      final positionRaw = l['position'];
      final position = positionRaw is int
          ? positionRaw
          : int.tryParse('$positionRaw');
      final index = (position == null || position <= 0) ? i : (position - 1);
      final col = index % 3;
      final row = index ~/ 3;
      dx = 0.18 + col * 0.30;
      dy = 0.22 + row * 0.22;
    }

    final type = switch (i % 5) {
      0 => WorldPointType.castle,
      1 => WorldPointType.shop,
      2 => WorldPointType.portal,
      3 => WorldPointType.tavern,
      _ => WorldPointType.camp,
    };

    return WorldPoint(
      id: id,
      name: name,
      type: type,
      position: Offset(
        dx.clamp(0.0, 1.0).toDouble(),
        dy.clamp(0.0, 1.0).toDouble(),
      ),
      users: usersByIndex == null || i >= usersByIndex.length
          ? (avatarsByLocation[locationId] ?? const <UserAvatar>[])
          : usersByIndex[i],
      sceneId: locationId,
      pointId: pointId,
      iconUrl: icon,
      description: description,
      locationDescription: descriptionFallback,
      depth: depths == null || i >= depths.length ? 0 : depths[i],
      isLeafLocation: isLeafLocations == null || i >= isLeafLocations.length
          ? true
          : isLeafLocations[i],
    );
  });
}

List<WorldPoint> worldPointsFromLocationIds(
  List<dynamic> locationIds,
  Map<String, List<UserAvatar>> avatarsByLocation,
) {
  final ids =
      locationIds
          .map((e) => '$e'.trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList(growable: false)
        ..sort((a, b) => a.compareTo(b));

  if (ids.isEmpty) return const <WorldPoint>[];

  return List<WorldPoint>.generate(ids.length, (i) {
    final id = ids[i];
    final col = i % 3;
    final row = i ~/ 3;
    final dx = 0.18 + col * 0.30;
    final dy = 0.22 + row * 0.22;
    final type = switch (i % 5) {
      0 => WorldPointType.castle,
      1 => WorldPointType.shop,
      2 => WorldPointType.portal,
      3 => WorldPointType.tavern,
      _ => WorldPointType.camp,
    };

    return WorldPoint(
      id: id,
      name: 'Location $id',
      type: type,
      position: Offset(
        dx.clamp(0.0, 1.0).toDouble(),
        dy.clamp(0.0, 1.0).toDouble(),
      ),
      users: (avatarsByLocation[id] ?? const <UserAvatar>[]),
      sceneId: id,
      pointId: id,
      description: '',
    );
  });
}
