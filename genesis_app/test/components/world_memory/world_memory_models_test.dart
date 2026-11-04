import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/world_memory/world_memory_models.dart';

void main() {
  test('const empty snapshot carries no inferred story data', () {
    const snapshot = WorldMemorySnapshot.empty();
    expect(snapshot.events, isEmpty);
    expect(snapshot.cast, isEmpty);
    expect(snapshot.relations, isEmpty);
    expect(snapshot.summaryTicks, isEmpty);
    expect(snapshot.hasStoryMemory, isFalse);
  });

  test('summary ticks can be replaced without replacing other data', () {
    const person = WorldMemoryPerson(id: 'a', name: 'A');
    const snapshot = WorldMemorySnapshot(
      cast: [WorldMemoryCharacter(person: person)],
      summaryTicks: [
        WorldMemorySummaryTick(tickNo: 1, bodies: ['old']),
      ],
    );
    final updated = snapshot.copyWith(
      summaryTicks: const [
        WorldMemorySummaryTick(
          tickNo: 2,
          bodies: ['Full P5\nSecond paragraph'],
        ),
      ],
    );
    expect(updated.summaryTicks.single.tickNo, 2);
    expect(updated.cast, same(snapshot.cast));
    expect(snapshot.summaryTicks.single.bodies, ['old']);
    expect(updated.copyWith(summaryTicks: const []).summaryTicks, isEmpty);
  });
}
