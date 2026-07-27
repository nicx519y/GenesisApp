part of 'origin_world_page.dart';

String _resolveAssetUrl(String raw) {
  return resolveAssetUrl(raw);
}

String _resolvedProfileAvatar(
  Map<String, dynamic> userInfo,
  String profileAvatar,
) {
  final resolved = asResolvedImageUrl(
    _mapValue(userInfo, const ['avatar']),
    resolveAssetUrl,
    fallback: _mapValue(userInfo, const [
      'avatar_url',
      'photoUrl',
      'photo_url',
      'picture',
    ]),
  );
  if (resolved.isNotEmpty) return resolved;
  return asResolvedImageUrl(profileAvatar, resolveAssetUrl);
}

Object? _mapValue(Map<dynamic, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value == null) continue;
    if (value is String && value.trim().isEmpty) continue;
    return value;
  }
  return null;
}

String _mapString(Map<dynamic, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value == null) continue;
    final text = '$value'.trim();
    if (text.isNotEmpty) return text;
  }
  return '';
}

int _mapInt(Map<dynamic, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) return parsed;
    }
  }
  return 0;
}

List<OriginLocation> _rootOriginLocations(List<OriginLocation> locations) {
  return locations
      .where((location) => location.parentLocationId.trim().isEmpty)
      .toList(growable: false);
}

List<WorldMapLocationNode> _originMapLocationNodes(
  List<LocationTreeNode<OriginLocation>> nodes,
  Map<String, List<UserAvatar>> avatarsByLocation,
  ProcessedLocationTree<OriginLocation> processedLocationTree, {
  bool markAsMapRoot = true,
}) {
  return nodes
      .map((node) {
        return WorldMapLocationNode(
          id: node.id,
          isRoot: markAsMapRoot && node.children.isNotEmpty,
          point: _pointsFromLocations(
            [node.value],
            avatarsByLocation,
            depths: [node.depth],
            isLeafLocations: [node.children.isEmpty],
            usersByIndex: [
              processedLocationTree.aggregateValues<UserAvatar>(
                node.id,
                avatarsByLocation,
                idOf: worldMapAvatarStableId,
              ),
            ],
          ).first,
          mapImageUrl: _resolveAssetUrl(node.value.mapUrl),
          children: _originMapLocationNodes(
            node.children,
            avatarsByLocation,
            processedLocationTree,
            markAsMapRoot: false,
          ),
        );
      })
      .toList(growable: false);
}

int _originLeafLocationNodeCount(List<WorldMapLocationNode> nodes) {
  var count = 0;
  for (final node in nodes) {
    if (node.children.isEmpty) {
      count += 1;
    } else {
      count += _originLeafLocationNodeCount(node.children);
    }
  }
  return count;
}

String _originRootMapImageUrl(List<LocationTreeNode<OriginLocation>> nodes) {
  for (final node in nodes) {
    final url = _resolveAssetUrl(node.value.mapUrl);
    if (url.isNotEmpty) return url;
  }
  return '';
}

List<WorldPoint> _pointsFromLocations(
  List<OriginLocation> locations,
  Map<String, List<UserAvatar>> avatarsByLocation, {
  List<int>? depths,
  List<bool>? isLeafLocations,
  List<List<UserAvatar>>? usersByIndex,
}) {
  if (locations.isEmpty) return const <WorldPoint>[];

  return List<WorldPoint>.generate(locations.length, (i) {
    final l = locations[i];
    final locationId = l.locationId.trim().isEmpty
        ? '${l.id}'
        : l.locationId.trim();
    final rawDx = l.xPercent > 0 ? (l.xPercent / 100) : null;
    final rawDy = l.yPercent > 0 ? (l.yPercent / 100) : null;
    final col = i % 3;
    final row = i ~/ 3;
    final dx = rawDx ?? (0.18 + col * 0.30);
    final dy = rawDy ?? (0.22 + row * 0.22);
    final type = switch (i % 5) {
      0 => WorldPointType.castle,
      1 => WorldPointType.shop,
      2 => WorldPointType.portal,
      3 => WorldPointType.tavern,
      _ => WorldPointType.camp,
    };
    return WorldPoint(
      id: '${l.id}',
      name: l.name,
      type: type,
      position: Offset(
        dx.clamp(0.0, 1.0).toDouble(),
        dy.clamp(0.0, 1.0).toDouble(),
      ),
      users: usersByIndex == null || i >= usersByIndex.length
          ? (avatarsByLocation[locationId] ??
                avatarsByLocation['${l.id}'] ??
                const <UserAvatar>[])
          : usersByIndex[i],
      sceneId: locationId,
      pointId: locationId,
      iconUrl: _resolveAssetUrl(l.icon),
      mapImageUrl: _resolveAssetUrl(l.mapUrl),
      description: l.description,
      locationDescription: l.description,
      depth: depths == null || i >= depths.length ? 0 : depths[i],
      isLeafLocation: isLeafLocations == null || i >= isLeafLocations.length
          ? true
          : isLeafLocations[i],
    );
  });
}

Map<String, List<UserAvatar>> _originAvatarsByLocation(
  List<OriginCharacter> characters,
  List<OriginLocation> locations,
) {
  final map = <String, List<UserAvatar>>{};
  final locationIdsByStableId = <int, List<String>>{};
  for (final location in locations) {
    locationIdsByStableId
        .putIfAbsent(location.id, () => <String>[])
        .add(location.locationId.trim());
  }

  for (final c in characters) {
    final locationId = c.currentLocationId > 0
        ? c.currentLocationId
        : c.initialLocationId;
    if (locationId <= 0) continue;
    final avatar = UserAvatar(
      _initials(c.name),
      id: _originCharacterMapAvatarId(c),
      name: c.name,
      avatarUrl: _resolveAssetUrl(c.avatar),
      showStar: true,
    );
    final keys = <String>{'$locationId', ...?locationIdsByStableId[locationId]}
      ..remove('');
    for (final key in keys) {
      (map[key] ??= <UserAvatar>[]).add(avatar);
    }
  }
  return map;
}

String _originCharacterMapAvatarId(OriginCharacter character) {
  if (character.id > 0) return '${character.id}';
  return character.characterId.trim();
}

List<WorldMapMessageBubble> _originMapMessageBubbles(OriginDetail origin) {
  return originMapMessageBubblesForTesting(origin);
}

@visibleForTesting
List<WorldMapMessageBubble> originMapMessageBubblesForTesting(
  OriginDetail origin,
) {
  final charactersByCharId = <String, OriginCharacter>{};
  for (final character in origin.characters) {
    final key = character.characterId.trim().toLowerCase();
    if (key.isEmpty) continue;
    charactersByCharId.putIfAbsent(key, () => character);
  }
  if (charactersByCharId.isEmpty) return const <WorldMapMessageBubble>[];

  final bubbles = <WorldMapMessageBubble>[];
  final locations = origin.allLocations.isNotEmpty
      ? origin.allLocations
      : _flattenOriginLocations(origin.locations);
  for (final location in locations) {
    for (final line in location.dialogue) {
      final charId = line.charId.trim();
      final normalizedCharId = charId.toLowerCase();
      if (normalizedCharId.isEmpty ||
          normalizedCharId == 'nar' ||
          normalizedCharId == 'narrator') {
        continue;
      }
      final character = charactersByCharId[normalizedCharId];
      if (character == null) continue;
      final content = worldMapBubbleDisplayContent(line.content);
      if (content.isEmpty) continue;
      final avatarId = _originCharacterMapAvatarId(character);
      if (avatarId.isEmpty) continue;
      bubbles.add(
        WorldMapMessageBubble(characterId: avatarId, content: content),
      );
    }
  }
  return List<WorldMapMessageBubble>.unmodifiable(bubbles);
}

List<OriginLocation> _flattenOriginLocations(List<OriginLocation> locations) {
  final out = <OriginLocation>[];
  void visit(OriginLocation location) {
    out.add(location);
    for (final child in location.locations) {
      visit(child);
    }
  }

  for (final location in locations) {
    visit(location);
  }
  return out;
}

String _initials(String name) {
  return initialsForAvatarName(name);
}
