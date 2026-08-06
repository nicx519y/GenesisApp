import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/world_map_location_action.dart';
import 'package:genesis_flutter_android/components/world_point.dart';

void main() {
  test('leaf and explicit chat target open location chat', () {
    final leaf = _node('leaf');
    expect(resolveWorldMapLocationAction(leaf).chatTarget?.id, 'leaf');

    final explicitTarget = _point('chat_target');
    final branch = WorldMapLocationNode(
      id: 'branch',
      point: _point('branch'),
      chatTargetPoint: explicitTarget,
      children: [_node('child_a'), _node('child_b')],
    );
    expect(
      resolveWorldMapLocationAction(branch).chatTarget,
      same(explicitTarget),
    );
  });

  test('a single descendant chain resolves directly to its leaf chat', () {
    final leaf = _node('leaf');
    final root = _node(
      'root',
      children: [
        _node('middle', children: [leaf]),
      ],
    );

    final action = resolveWorldMapLocationAction(root);

    expect(action.opensChat, true);
    expect(action.chatTarget?.id, 'leaf');
  });

  test('a branching location drills to the shared display target', () {
    final branch = _node(
      'branch',
      children: [_node('leaf_a'), _node('leaf_b')],
    );
    final root = _node(
      'root',
      children: [
        _node('middle', children: [branch]),
      ],
    );

    final action = resolveWorldMapLocationAction(root);

    expect(action.drillsDown, true);
    expect(action.drillTarget?.id, 'branch');
  });

  test('location lookup searches nested nodes and trims the id', () {
    final target = _node('target');
    final roots = [
      _node(
        'root',
        children: [
          _node('middle', children: [target]),
        ],
      ),
    ];

    expect(findWorldMapLocationNode(roots, ' target '), same(target));
    expect(findWorldMapLocationNode(roots, 'missing'), isNull);
  });

  test('chat target navigation keeps a single-child target on root map', () {
    final roots = [
      _node(
        '__world_root__',
        children: [
          _node(
            'corridor',
            children: [
              _node('middle', children: [_node('leaf')]),
            ],
          ),
        ],
      ),
    ];

    final navigation = resolveWorldMapChatTargetNavigation(
      initialLocationId: 'root',
      targetLocationId: 'leaf',
      locationNodes: roots,
    );

    expect(navigation?.currentLocationId, 'root');
    expect(navigation?.locationTrail, isEmpty);
  });

  test('chat target navigation builds the parent map drill trail', () {
    final roots = [
      _node(
        '__world_root__',
        children: [
          _node('branch', children: [_node('leaf_a'), _node('leaf_b')]),
          _node('other_leaf'),
        ],
      ),
    ];

    final navigation = resolveWorldMapChatTargetNavigation(
      initialLocationId: 'root',
      targetLocationId: 'leaf_b',
      locationNodes: roots,
    );

    expect(navigation?.currentLocationId, 'branch');
    expect(navigation?.locationTrail, ['root']);
  });
}

WorldMapLocationNode _node(
  String id, {
  List<WorldMapLocationNode> children = const <WorldMapLocationNode>[],
}) {
  return WorldMapLocationNode(id: id, point: _point(id), children: children);
}

WorldPoint _point(String id) {
  return WorldPoint(
    id: id,
    name: id,
    type: WorldPointType.portal,
    position: Offset.zero,
    users: const <UserAvatar>[],
  );
}
