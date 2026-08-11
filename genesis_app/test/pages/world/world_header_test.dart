import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/models/world.dart';
import 'package:genesis_flutter_android/pages/world/world_header.dart';

void main() {
  test('world map time label includes the current sub-tick number', () {
    expect(
      worldTimeLabel(tickIndex: 7, subTickNo: 3, worldTime: 'Day 45, 19:30'),
      'Tick 7-3 · Day 45, 19:30',
    );
  });

  test('world map time label keeps sub-tick when tick number is zero', () {
    expect(
      worldTimeLabel(tickIndex: 0, subTickNo: 3, worldTime: 'Day 1, 20:25'),
      'Tick 0-3 · Day 1, 20:25',
    );
  });

  test('world detail reads an explicit sub-tick for tick number zero', () {
    final world = WorldDetail.fromJson(const {
      'world_id': 'world-0',
      'tick_count': 0,
      'sub_tick_no': 3,
    });

    expect(world.subTickNo, 3);
  });

  test('world detail does not derive a missing sub-tick from ticks', () {
    final world = WorldDetail.fromJson(const {
      'world_id': 'world-1',
      'tick_count': 7,
      'ticks': [
        {'tick_no': 7, 'sub_tick_no': 3},
      ],
    });

    expect(world.subTickNo, 0);
  });
}
