import 'world_point.dart';

/// The navigation decision shared by the legacy image map and the tile map.
class WorldMapLocationAction {
  const WorldMapLocationAction.openChat(this.chatTarget) : drillTarget = null;

  const WorldMapLocationAction.drillDown(this.drillTarget) : chatTarget = null;

  final WorldPoint? chatTarget;
  final WorldMapLocationNode? drillTarget;

  bool get opensChat => chatTarget != null;
  bool get drillsDown => drillTarget != null;
}

class WorldMapChatTargetNavigation {
  const WorldMapChatTargetNavigation({
    required this.currentLocationId,
    required this.locationTrail,
  });

  final String currentLocationId;
  final List<String> locationTrail;
}

WorldMapLocationAction resolveWorldMapLocationAction(
  WorldMapLocationNode node,
) {
  final explicitTarget = node.chatTargetPoint;
  if (explicitTarget != null) {
    return WorldMapLocationAction.openChat(explicitTarget);
  }
  if (node.children.isEmpty) {
    return WorldMapLocationAction.openChat(node.point);
  }

  final singleLeaf = _singleLeafDescendant(node);
  if (singleLeaf != null) {
    return WorldMapLocationAction.openChat(singleLeaf.point);
  }
  return WorldMapLocationAction.drillDown(_displayNodeForDrill(node));
}

WorldMapLocationNode? findWorldMapLocationNode(
  List<WorldMapLocationNode> roots,
  String nodeId,
) {
  final targetId = nodeId.trim();
  if (targetId.isEmpty) return null;

  WorldMapLocationNode? visit(WorldMapLocationNode node) {
    if (node.id.trim() == targetId) return node;
    for (final child in node.children) {
      final match = visit(child);
      if (match != null) return match;
    }
    return null;
  }

  for (final root in roots) {
    final match = visit(root);
    if (match != null) return match;
  }
  return null;
}

WorldMapChatTargetNavigation? resolveWorldMapChatTargetNavigation({
  required String initialLocationId,
  required String targetLocationId,
  required List<WorldMapLocationNode> locationNodes,
}) {
  final initialId = initialLocationId.trim();
  final targetId = targetLocationId.trim();
  if (initialId.isEmpty || targetId.isEmpty || locationNodes.isEmpty) {
    return null;
  }

  var currentLocationId = initialId;
  final locationTrail = <String>[];
  final visitedMapIds = <String>{};
  while (visitedMapIds.add(currentLocationId)) {
    final candidates = _worldMapNavigationCandidates(
      currentLocationId: currentLocationId,
      locationNodes: locationNodes,
    );
    WorldMapLocationNode? targetBranch;
    for (final candidate in candidates) {
      if (_worldMapNodeContainsLocation(candidate, targetId)) {
        targetBranch = candidate;
        break;
      }
    }
    if (targetBranch == null) return null;

    final action = resolveWorldMapLocationAction(targetBranch);
    final chatTarget = action.chatTarget;
    if (chatTarget != null &&
        _worldPointMatchesLocation(chatTarget, targetId)) {
      return WorldMapChatTargetNavigation(
        currentLocationId: currentLocationId,
        locationTrail: List<String>.unmodifiable(locationTrail),
      );
    }

    final drillTargetId = action.drillTarget?.id.trim() ?? '';
    if (drillTargetId.isEmpty || drillTargetId == currentLocationId) {
      return null;
    }
    locationTrail.add(currentLocationId);
    currentLocationId = drillTargetId;
  }
  return null;
}

List<WorldMapLocationNode> _worldMapNavigationCandidates({
  required String currentLocationId,
  required List<WorldMapLocationNode> locationNodes,
}) {
  if (currentLocationId == 'root') {
    if (locationNodes.length == 1 && locationNodes.single.children.isNotEmpty) {
      return locationNodes.single.children;
    }
    return locationNodes;
  }
  return findWorldMapLocationNode(locationNodes, currentLocationId)?.children ??
      const <WorldMapLocationNode>[];
}

bool _worldMapNodeContainsLocation(
  WorldMapLocationNode node,
  String targetLocationId,
) {
  if (node.id.trim() == targetLocationId ||
      _worldPointMatchesLocation(node.point, targetLocationId) ||
      (node.chatTargetPoint != null &&
          _worldPointMatchesLocation(
            node.chatTargetPoint!,
            targetLocationId,
          ))) {
    return true;
  }
  return node.children.any(
    (child) => _worldMapNodeContainsLocation(child, targetLocationId),
  );
}

bool _worldPointMatchesLocation(WorldPoint point, String targetLocationId) {
  return point.sceneId.trim() == targetLocationId ||
      point.pointId.trim() == targetLocationId ||
      point.id.trim() == targetLocationId;
}

WorldMapLocationNode? _singleLeafDescendant(WorldMapLocationNode node) {
  var current = node;
  while (current.children.length == 1) {
    current = current.children.single;
  }
  return current.children.isEmpty ? current : null;
}

WorldMapLocationNode _displayNodeForDrill(WorldMapLocationNode node) {
  var current = node;
  while (current.children.length == 1 &&
      current.children.single.children.isNotEmpty) {
    current = current.children.single;
  }
  return current;
}
