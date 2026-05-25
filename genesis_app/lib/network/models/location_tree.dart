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
