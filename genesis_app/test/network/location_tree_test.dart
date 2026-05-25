import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/models/location_tree.dart';

void main() {
  test('buildLocationTree orders locations by parent hierarchy depth', () {
    final locations = [
      {'location_id': 'root', 'location_pid': ''},
      {'location_id': 'sibling', 'location_pid': ''},
      {'location_id': 'child', 'location_pid': 'root'},
      {'location_id': 'grandchild', 'location_pid': 'child'},
    ];

    final tree = buildLocationTree(
      locations,
      idOf: (location) => '${location['location_id']}',
      parentIdOf: (location) => '${location['location_pid']}',
    );
    final flattened = flattenLocationTree(tree);

    expect(flattened.map((node) => node.id), [
      'root',
      'child',
      'grandchild',
      'sibling',
    ]);
    expect(flattened.map((node) => node.depth), [0, 1, 2, 0]);
  });
}
