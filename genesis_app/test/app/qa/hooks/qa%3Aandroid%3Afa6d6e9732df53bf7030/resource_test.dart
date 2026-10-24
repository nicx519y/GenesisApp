import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/models/location_tree.dart';
import 'package:genesis_flutter_android/network/models/world.dart';
// Import the actual resource, including its restoration path. Adapter-only
// tests cannot catch missing Dart symbols in that path.
import 'package:genesis_flutter_android/app/qa/hooks/qa%253Aandroid%253Afa6d6e9732df53bf7030/resource.dart';

void main() {
  ProcessedLocationTree<Map<String, dynamic>> tree(
    List<Map<String, dynamic>> locations,
  ) => processLocationTree(buildWorldLocationTree(locations, worldMapUrl: ''));

  test('selects real parent below the production synthetic world root', () {
    final actual = tree([
      {'location_id': 'P', 'location_pid': '', 'location_name': 'Parent'},
      {'location_id': 'C', 'location_pid': 'P', 'location_name': 'Child'},
      {'location_id': 'G', 'location_pid': 'C', 'location_name': 'Grandchild'},
    ]);
    expect(actual.flattened.first.id, worldSyntheticRootLocationId);
    final parent = selectParentLocation(actual);
    expect(parent.id, 'P');
    expect(parent.value['location_name'], 'Parent');
    expect(actual.descendantsOf(parent.id, includeSelf: false).map((n) => n.id),
        orderedEquals(['C', 'G']));
    expect(actual.chatTargetFor(parent.id), isNull);
  });

  test('synthetic root with only leaf children is not a valid parent', () {
    expect(() => selectParentLocation(tree([
      {'location_id': 'leaf', 'location_pid': '', 'location_name': 'Leaf'},
    ])), throwsStateError);
    expect(() => selectParentLocation(tree([])), throwsStateError);
  });

  test('does not manufacture a name for an incomplete real parent', () {
    final parent = selectParentLocation(tree([
      {'location_id': 'P', 'location_pid': '', 'location_name': ''},
      {'location_id': 'C', 'location_pid': 'P', 'location_name': 'Child'},
    ]));
    expect(parent.id, 'P');
    expect(parent.value['location_name'], isEmpty);
  });

  test('runtime requires readiness before acquiring a resource', () async {
    await expectLater(
      invoke({'operation': 'prepare'}, false, false),
      throwsArgumentError,
    );
  });

  test('contract and Case preparation remain isolated', () async {
    await expectLater(
      invoke({'operation': 'prepare'}, true, true),
      throwsStateError,
    );
    await expectLater(
      contract({'operation': 'prepare'}, false, true),
      throwsStateError,
    );
  });

  test('unowned restoration cannot claim a cleanup receipt', () async {
    await expectLater(
      invoke({'operation': 'restore'}, false, true),
      throwsStateError,
    );
  });

  test('cleanup failure retains each original cause', () {
    final overlay = StateError('foreign overlay');
    final transport = StateError('transport close failed');
    final failure = ParentCleanupFailure([overlay, transport]);
    expect(failure.errors, orderedEquals([overlay, transport]));
    expect(failure.toString(), contains('foreign overlay'));
    expect(failure.toString(), contains('transport close failed'));
  });
}
