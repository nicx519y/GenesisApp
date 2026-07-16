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
