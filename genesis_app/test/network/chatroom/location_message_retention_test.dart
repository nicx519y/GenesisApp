import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/chatroom/location_message_retention.dart';

void main() {
  const policy = LocationMessageRetention();
  List<int> select(
    List<int> items, {
    Set<Object> protected = const {},
    int? focus,
  }) => policy.select(
    items,
    identity: (i) => i,
    protected: protected,
    focus: focus,
  );

  test('high water avoids trimming on each appended message', () {
    final items = List.generate(240, (i) => i);
    expect(select(items), same(items));
    expect(select([...items, 240]), List.generate(200, (i) => i + 41));
  });

  test(
    'protect history viewport, active anchors and latest within one budget',
    () {
      final selected = select(
        List.generate(1000, (i) => i),
        protected: {100, 101, 102, 700},
        focus: 101,
      );
      expect(selected.length, 200);
      expect(
        selected,
        containsAll([100, 101, 102, 700, ...List.generate(40, (i) => 960 + i)]),
      );
      expect(selected, orderedEquals(selected.toList()..sort()));
      expect(selected, isNot(contains(500)));
    },
  );

  test('protected oversize is allowed then reclaimed when lease changes', () {
    final items = List.generate(300, (i) => i);
    final protected = items.take(260).toSet();
    final held = select(items, protected: protected, focus: 100);
    expect(held.length, 300);
    expect(select(held, protected: {100, 101}, focus: 100).length, 200);
  });

  test('incoming history page is retained rather than immediately clipped', () {
    final selected = select(
      List.generate(260, (i) => i),
      protected: Set.of(List.generate(20, (i) => i)),
      focus: 30,
    );
    expect(selected.take(20), List.generate(20, (i) => i));
    expect(selected.length, 200);
  });
}
