import 'package:flutter/foundation.dart';

typedef LocationIdReader<T> = String Function(T location);

@immutable
class LocationTreeNode<T> {
  const LocationTreeNode({
    required this.id,
    required this.parentId,
    required this.value,
    required this.depth,
    required this.children,
  });

  final String id;
  final String parentId;
  final T value;
  final int depth;
  final List<LocationTreeNode<T>> children;
}

@immutable
class ProcessedLocationTree<T> {
  ProcessedLocationTree(List<LocationTreeNode<T>> roots)
    : roots = List<LocationTreeNode<T>>.unmodifiable(roots),
      root = _singleRoot(roots),
      _nodesById = _indexNodes(roots);

  final List<LocationTreeNode<T>> roots;
  final LocationTreeNode<T>? root;
  final Map<String, LocationTreeNode<T>> _nodesById;

  List<LocationTreeNode<T>> get mapRoots {
    final singleRoot = root;
    if (singleRoot == null) return roots;
    return <LocationTreeNode<T>>[singleRoot];
  }

  List<LocationTreeNode<T>> get renderRoots {
    final singleRoot = root;
    if (singleRoot == null) return roots;
    return singleRoot.children;
  }

  List<LocationTreeNode<T>> get flattened => flattenLocationTree(roots);

  List<LocationTreeNode<T>> get flattenedRenderNodes =>
      flattenLocationTree(renderRoots);

  LocationTreeNode<T>? nodeById(String nodeId) {
    return _nodesById[nodeId.trim()];
  }

  List<LocationTreeNode<T>> descendantsOf(
    String nodeId, {
    bool includeSelf = true,
  }) {
    final node = nodeById(nodeId);
    if (node == null) return <LocationTreeNode<T>>[];
    final flattened = flattenLocationTree(<LocationTreeNode<T>>[node]);
    if (includeSelf) return flattened;
    return flattened.skip(1).toList(growable: false);
  }

  LocationTreeNode<T>? chatTargetFor(String nodeId) {
    final node = nodeById(nodeId);
    if (node == null) return null;
    if (node.children.isEmpty) return node;
    if (node.children.length == 1 && node.children.single.children.isEmpty) {
      return node.children.single;
    }
    return null;
  }

  bool shouldDrillInto(String nodeId) => chatTargetFor(nodeId) == null;

  List<R> aggregateValues<R>(
    String nodeId,
    Map<String, List<R>> valuesByLocation, {
    required String Function(R value) idOf,
  }) {
    final deduped = <String, R>{};
    var fallbackIndex = 0;
    for (final node in descendantsOf(nodeId)) {
      final values = valuesByLocation[node.id] ?? <R>[];
      for (final value in values) {
        final id = idOf(value).trim();
        deduped[id.isEmpty ? '__value_${fallbackIndex++}' : id] = value;
      }
    }
    return deduped.values.toList(growable: false);
  }
}

ProcessedLocationTree<T> processLocationTree<T>(
  List<LocationTreeNode<T>> roots,
) {
  return ProcessedLocationTree<T>(roots);
}

List<LocationTreeNode<T>> buildLocationTree<T>(
  List<T> locations, {
  required LocationIdReader<T> idOf,
  required LocationIdReader<T> parentIdOf,
}) {
  if (locations.isEmpty) return const <LocationTreeNode<Never>>[];

  final nodesById = <String, _MutableLocationTreeNode<T>>{};
  final orderedNodes = <_MutableLocationTreeNode<T>>[];
  for (var i = 0; i < locations.length; i++) {
    final location = locations[i];
    final rawId = idOf(location).trim();
    final id = rawId.isEmpty ? '__location_$i' : rawId;
    final node = _MutableLocationTreeNode<T>(
      id: id,
      parentId: parentIdOf(location).trim(),
      value: location,
    );
    nodesById[id] = node;
    orderedNodes.add(node);
  }

  final roots = <_MutableLocationTreeNode<T>>[];
  for (final node in orderedNodes) {
    final parent = nodesById[node.parentId];
    if (parent == null || _wouldCreateCycle(node, parent, nodesById)) {
      roots.add(node);
    } else {
      parent.children.add(node);
    }
  }

  return roots.map((node) => node.freeze(0)).toList(growable: false);
}

LocationTreeNode<T>? _singleRoot<T>(List<LocationTreeNode<T>> roots) {
  if (roots.length != 1) return null;
  return roots.single;
}

Map<String, LocationTreeNode<T>> _indexNodes<T>(
  List<LocationTreeNode<T>> roots,
) {
  return <String, LocationTreeNode<T>>{
    for (final node in flattenLocationTree(roots)) node.id: node,
  };
}

List<LocationTreeNode<T>> flattenLocationTree<T>(
  List<LocationTreeNode<T>> roots,
) {
  final flattened = <LocationTreeNode<T>>[];
  void visit(LocationTreeNode<T> node) {
    flattened.add(node);
    for (final child in node.children) {
      visit(child);
    }
  }

  for (final root in roots) {
    visit(root);
  }
  return flattened;
}

bool _wouldCreateCycle<T>(
  _MutableLocationTreeNode<T> child,
  _MutableLocationTreeNode<T> parent,
  Map<String, _MutableLocationTreeNode<T>> nodesById,
) {
  var current = parent;
  final seen = <String>{child.id};
  while (true) {
    if (!seen.add(current.id)) return true;
    final next = nodesById[current.parentId];
    if (next == null) return false;
    current = next;
  }
}

class _MutableLocationTreeNode<T> {
  _MutableLocationTreeNode({
    required this.id,
    required this.parentId,
    required this.value,
  });

  final String id;
  final String parentId;
  final T value;
  final List<_MutableLocationTreeNode<T>> children =
      <_MutableLocationTreeNode<T>>[];

  LocationTreeNode<T> freeze(int depth) {
    return LocationTreeNode<T>(
      id: id,
      parentId: parentId,
      value: value,
      depth: depth,
      children: children
          .map((child) => child.freeze(depth + 1))
          .toList(growable: false),
    );
  }
}
